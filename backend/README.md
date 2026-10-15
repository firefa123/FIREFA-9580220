# FIREFA Backend

Self-managed REST API foundation for FIREFA. This directory is additive: it does not replace or rebuild `apps/firefa_main_app` or `apps/firefa_staff_app`.

## Current stage

Implemented in this foundation slice:
- Fastify REST server with `/health/live` and database-backed `/health/ready`.
- Environment validation and graceful shutdown.
- PostgreSQL schema migration runner.
- One-time owner bootstrap, login, access JWT, refresh-token rotation, logout, and `/api/v1/auth/me`.
- Authenticated `/api/v1/sync/events` for transactional order create/update, idempotency receipts, device-scoped order IDs, stale-version conflict handling, and owner-only recovery of missing orders.
- Authenticated catalog endpoints: `GET/POST /api/v1/products` and `PATCH /api/v1/products/:id`.
- Authenticated inventory endpoints: `GET/POST /api/v1/inventory/items` and idempotent `POST /api/v1/inventory/movements` with stock floor enforcement.
- Passwords hashed with Argon2id; refresh tokens stored as SHA-256 hashes and revocable.
- PostgreSQL migrations for tenant/outlet/auth, orders and normalized order items, products/categories, inventory ledger, reported payments, devices, sync receipts, order events, and audit logs.
- Main App has opt-in backend login and a REST sync adapter. Existing local-first mode stays unchanged unless explicitly enabled at build time.

Not implemented yet: staff CRUD, attendance/geofence endpoints, collection/settlement endpoints for BON receivables, external payment-provider verification for non-cash payments/refunds, automatic menu/inventory migration from local stores, and production deployment. Cash refunds are recorded as cashier-reported entries; they are not provider-verified. Do not treat the database as deployed until the Compose stack is started on the target server.

## Requirements

- Node.js 22+
- PostgreSQL 16+ (or Docker Compose)

## Local development

From the repository root, create a local `.env` file using the root variables shown below, or set equivalent environment variables in your shell. Never commit production secrets.

For a direct Node run:

```powershell
cd backend
npm install
$env:DATABASE_URL="postgresql://firefa:YOUR_LOCAL_PASSWORD@localhost:5432/firefa"
$env:JWT_SECRET="replace-with-at-least-32-random-characters"
$env:BOOTSTRAP_TOKEN="replace-with-another-32-character-random-secret"
npm run build
npm run db:migrate
npm test
npm run typecheck
npm start
```

For authentication integration tests, set `TEST_DATABASE_URL` to a **disposable database whose name includes `_test`** (for example `firefa_test`) and apply migrations to that database first. The integration suite deliberately skips unless the URL identifies a test database, and it clears test tables before each case. Never point `TEST_DATABASE_URL` at production or valuable development data.

### Create the database locally or on your self-managed server

1. Install Docker Engine + Compose on the target machine.
2. Copy the repository root `.env.example` to `.env` and replace every example password/secret with unique random values.
3. Run `docker compose -f docker-compose.backend.yml up --build -d` from the repository root.
4. Check `docker compose -f docker-compose.backend.yml ps` and `curl http://127.0.0.1:3000/health/ready`. Compose automatically creates the PostgreSQL database and applies all versioned migrations before starting the API.
5. Keep PostgreSQL bound to loopback/private network. Put the API behind a TLS reverse proxy before connecting production Flutter clients.

The database is persistent in the `firefa_postgres_data` Docker volume. To back it up from a machine with PostgreSQL client tools installed:

```powershell
$env:DATABASE_URL="postgresql://firefa:YOUR_PASSWORD@localhost:5432/firefa"
./backend/scripts/db-backup.ps1
```

Restore only to the intended target database and only after confirming the target:

```powershell
$env:DATABASE_URL="postgresql://firefa:YOUR_PASSWORD@localhost:5432/firefa"
./backend/scripts/db-restore.ps1 -BackupFile .\\backups\\firefa-YYYYMMDDTHHMMSSZ.dump -ConfirmRestore
```

Health checks:
- `GET /health/live` — process liveness only.
- `GET /health/ready` — returns 200 only when PostgreSQL responds to `SELECT 1`; otherwise 503.

## Authentication endpoints

- `POST /api/v1/auth/bootstrap-owner` — one-time initial owner + tenant + outlet creation. Requires `x-bootstrap-token` matching `BOOTSTRAP_TOKEN`; rejects after the first user exists. Password must be at least 12 characters.
- `POST /api/v1/auth/login` — validates credentials and returns a 15-minute access token and rotating refresh token. Pass `tenantId` when the user belongs to multiple tenants.
- `POST /api/v1/auth/refresh` — rotates the refresh token; the previous token cannot be reused.
- `POST /api/v1/auth/logout` — revokes the supplied refresh token.
- `GET /api/v1/auth/me` — requires `Authorization: Bearer <access-token>` and rechecks active user and membership.

- `POST /api/v1/sync/events` — requires an access token and `Idempotency-Key` equal to the body `eventId`. `deviceId` and the server-issued `outletId` are UUIDs. `order.updated` requires `expectedServerVersion`; stale versions return 409 with the current snapshot. `order.recovered` is owner-only and creates only if that device/order is missing; it never overwrites a server order.
- Sync writes, immutable order event, and acknowledgment receipt commit in one PostgreSQL transaction. Replaying the same event ID and payload returns the same receipt; reusing the ID with a different payload returns 409.
- The server strips unapproved snapshot fields such as customer name. It records cash payment as a cashier-reported payment only when method is cash and the amount covers the total; non-cash payment-provider settlement is not inferred from client flags. Refund and BON receivable sync remain disabled until dedicated endpoints exist.

Generate unique random secrets of at least 32 characters for `JWT_SECRET` and `BOOTSTRAP_TOKEN`. Keep the bootstrap token private and rotate it after the initial owner is created; the endpoint cannot create a second owner once a user exists. Never place production secrets in Flutter source or commit them to Git.

## Main App configuration

The existing local/demo login remains the default. To opt into the backend after deploying it behind HTTPS, build/run Main App with the real API URL and a map from each existing local outlet ID to its server UUID. Never put passwords, JWT secrets, or the bootstrap token in Flutter build defines.

Example PowerShell command (replace the sample host and UUIDs):

```powershell
flutter run `
  --dart-define=FIREFA_BACKEND_ENABLED=true `
  --dart-define=FIREFA_API_BASE_URL=https://api.your-domain.example `
  '--dart-define=FIREFA_OUTLET_MAP={"outlet-001":"SERVER-OUTLET-UUID-1","outlet-002":"SERVER-OUTLET-UUID-2"}'
```

The first Owner/outlet must be created once through `POST /api/v1/auth/bootstrap-owner` with the private `x-bootstrap-token` header. Main App login then uses the backend account and role. Order sync runs when the dashboard receives order/outlet changes; failed or unsupported events remain in the local outbox and are not marked synced. Refund, non-cash settlement, and BON receivables are intentionally rejected until their dedicated server endpoints are implemented.

## Docker Compose

Set `POSTGRES_PASSWORD` in the shell or a root `.env` file before starting:

```powershell
$env:POSTGRES_PASSWORD="replace-with-a-long-local-secret"
$env:JWT_SECRET="replace-with-at-least-32-random-characters"
$env:BOOTSTRAP_TOKEN="replace-with-another-32-character-random-secret"
docker compose -f docker-compose.backend.yml up --build
```

The Compose file binds API and database ports to loopback by default. For public deployment, put the API behind a TLS reverse proxy/firewall, restrict database network access, configure backups and monitoring, and use unique strong secrets. Do not expose PostgreSQL publicly.

## Architecture rules

- The server is the authority for tenant/user/outlet identity; never trust client-supplied tenant IDs.
- Passwords must only be stored as a strong password hash, never plaintext.
- Access and refresh tokens must be revocable; store only a hash of refresh tokens.
- Tenant and outlet authorization must be checked for every resource operation.
- Sync receipts and order changes must be committed in one PostgreSQL transaction before acknowledgment.
- Local order IDs are scoped by tenant and device; they are not globally unique.
- The Flutter apps remain offline-first and local-only until authenticated integration and failure-mode tests are complete.

## Next stages

1. Authentication and tenant/outlet authorization.
2. Owner account bootstrap and staff/user management.
3. Outlet settings and server-validated attendance/geofence.
4. Idempotent transactional sync endpoint and order conflict handling.
5. Wire menu/inventory stores to catalog and inventory endpoints using the same offline outbox/idempotency rules.
6. Implement refund and BON receivable endpoints, then staff/attendance/geofence.
7. Production deployment, TLS, backups, monitoring, and recovery drill.