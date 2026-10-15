# FIREFA Backend

Self-managed REST API foundation for FIREFA. This directory is additive: it does not replace or rebuild `apps/firefa_main_app` or `apps/firefa_staff_app`.

## Current stage

Implemented in this foundation slice:
- Fastify REST server with `/health/live` and database-backed `/health/ready`.
- Environment validation and graceful shutdown.
- PostgreSQL schema migration runner.
- One-time owner bootstrap, login, access JWT, refresh-token rotation, logout, and `/api/v1/auth/me`.
- Passwords hashed with Argon2id; refresh tokens stored as SHA-256 hashes and revocable.
- Initial tenant, outlet, user, membership, refresh-token, order, sync receipt, and order-event tables.
- Automated route tests and a dedicated backend CI workflow.

Not implemented yet: Owner-managed staff CRUD, authorization for POS/inventory/business endpoints, attendance/geofence endpoints, transactional sync endpoint, or production deployment. Do not connect Flutter clients or mark events synced yet.

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

Health checks:
- `GET /health/live` — process liveness only.
- `GET /health/ready` — returns 200 only when PostgreSQL responds to `SELECT 1`; otherwise 503.

## Authentication endpoints

- `POST /api/v1/auth/bootstrap-owner` — one-time initial owner + tenant + outlet creation. Requires `x-bootstrap-token` matching `BOOTSTRAP_TOKEN`; rejects after the first user exists. Password must be at least 12 characters.
- `POST /api/v1/auth/login` — validates credentials and returns a 15-minute access token and rotating refresh token. Pass `tenantId` when the user belongs to multiple tenants.
- `POST /api/v1/auth/refresh` — rotates the refresh token; the previous token cannot be reused.
- `POST /api/v1/auth/logout` — revokes the supplied refresh token.
- `GET /api/v1/auth/me` — requires `Authorization: Bearer <access-token>` and rechecks active user and membership.

Generate unique random secrets of at least 32 characters for `JWT_SECRET` and `BOOTSTRAP_TOKEN`. Keep the bootstrap token private and remove/rotate it after the initial owner is created. Never place production secrets in Flutter source or commit them to Git.

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
5. Flutter adapter behind disabled-by-default configuration, then cross-device tests.
6. Production deployment, TLS, backups, monitoring, and recovery drill.