# FIREFA Backend

Self-managed REST API foundation for FIREFA. This directory is additive: it does not replace or rebuild `apps/firefa_main_app` or `apps/firefa_staff_app`.

## Current stage

Implemented in this foundation slice:
- Fastify REST server with `/health/live` and database-backed `/health/ready`.
- Environment validation and graceful shutdown.
- PostgreSQL schema migration runner.
- Initial tenant, outlet, user, membership, refresh-token, order, sync receipt, and order-event tables.
- Automated route tests and a dedicated backend CI workflow.

Not implemented yet: login/token issuance, password hashing and verification, authorization middleware, staff-management endpoints, attendance/geofence endpoints, transactional sync endpoint, or production deployment. Do not connect Flutter clients or mark events synced yet.

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
npm run build
npm run db:migrate
npm test
npm run typecheck
npm start
```

Health checks:
- `GET /health/live` — process liveness only.
- `GET /health/ready` — returns 200 only when PostgreSQL responds to `SELECT 1`; otherwise 503.

## Docker Compose

Set `POSTGRES_PASSWORD` in the shell or a root `.env` file before starting:

```powershell
$env:POSTGRES_PASSWORD="replace-with-a-long-local-secret"
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