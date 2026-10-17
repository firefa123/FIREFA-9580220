# FIREFA Stage 5 — Offline Inventory and Production Recovery Runbook

## Current deployment boundary

The Main App is offline-first. Orders and the sync outbox use a combined local snapshot plus a separately persisted outbox. The queue merge prefers the dedicated outbox state and recovers events present only in the combined snapshot. A checkout stock-intent journal is saved before an order is created; startup replays the exact captured ingredient quantities if the process stops before the stock deduction completes. Cancellation recovery remains idempotent.

The authenticated order HTTP adapter targets POST /api/v1/sync/events. A foreground worker retries order events and inventory movements on startup, app resume, outbox changes, and a 30-second poll while the app is open. It validates the full order receipt, persists server versions for optimistic concurrency, uses the same event ID on retries, and routes verifiable 409 snapshots to conflict review. Inventory movements are retried with stable idempotency keys; reconciliation reports differences without overwriting local balances. The backend base URL, outlet mapping, item mapping, authenticated session, and live server endpoint must all be configured for cloud transport to run.

The local preference store is not a transactional database. These journals protect ordinary process-stop/reopen recovery and uncertain network acknowledgements, but they are not a guarantee against device loss, storage corruption, or abrupt power failure during a preference write. A transactional local database and cross-device tests remain necessary before making stronger durability claims.

**Deployment boundary:** the Fastify backend and PostgreSQL migration files exist in this repository, but no live staging host, provisioned database, or credentials were available to this task. Client/server code and CI can be validated here; live authenticated cloud sync, migration-on-a-real-database, multi-device conflict behavior, and production reconciliation remain unverified until a real staging backend is provisioned.

## Configure the cloud transport

The transport runs only when a backend URL is provided and the authenticated session is valid. Release builds must use HTTPS. Supply real server UUID mappings; never put passwords, refresh tokens, or bootstrap secrets in Dart defines.

Example build configuration (replace every placeholder with the provisioned staging values):

~~~powershell
flutter build web --release `
  --dart-define=FIREFA_BACKEND_ENABLED=true `
  --dart-define=FIREFA_API_BASE_URL=https://<staging-host> `
  --dart-define=FIREFA_OUTLET_MAP='{"outlet-001":"<server-outlet-uuid>","outlet-002":"<server-outlet-uuid>"}' `
  --dart-define=FIREFA_INVENTORY_ITEM_MAP='{"<local-item-id>":"<server-inventory-item-uuid>"}'
~~~

A successful build does not prove the URL is reachable. Verify login, event receipts, movement receipts, restart recovery, conflict review, and server-side idempotency against the same staging database before production sign-off.

## Offline → restart → reconnect acceptance test

1. Start Main App with the device offline; keep cloud sync configured but unavailable.
2. As Owner, create a test inventory item with a known stock balance.
3. Record two stock movements and wait for the UI action to finish.
4. Force-close and reopen the app. Verify the balance and both movement history rows are unchanged and in order.
5. Force-close the app between order creation and stock consumption in a test build. On restart, verify the persisted stock intent consumes the captured ingredient quantities exactly once; an abandoned intent with no durable order must be discarded.
6. Restore connectivity while the app is foregrounded or resume the app. The worker should retry automatically; send the oldest unsent movement first. Mark it sent only after validating the server's event/idempotency key, outlet, inventory item, and non-negative resulting balance.
7. Simulate a timeout after the server commits. Retry using the exact same idempotency key. Confirm one ledger row and one stock delta on the server.
8. If an earlier movement fails, later movements for the same item must remain queued behind it.
9. Run reconciliation. Every unmapped item, missing server item, or quantity mismatch must be reported for review; never overwrite stock balances automatically.

## Local CI commands

From repository root:

PowerShell:

~~~powershell
cd apps/firefa_main_app
flutter pub get
flutter analyze
flutter test
~~~

Do not report a backend CI result unless the backend workflow and its actual run are visible. Client Flutter CI does not prove that a cloud endpoint is deployed or that server transactions are durable.

## Production deployment, when a host is available

### Before migration

- Confirm the exact production host, database name, current migration version, and owner responsible for approval.
- Put secrets in the host's secret manager or an untracked root .env; never commit or paste secrets into chat.
- Stop or quiesce stock writes during the final backup/cutover window.
- Create a timestamped PostgreSQL custom-format backup and verify it can be listed:

~~~bash
mkdir -p backups
chmod 700 backups
docker compose -f docker-compose.backend.yml exec -T db sh -lc 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' > "backups/firefa-pre-migration-$(date -u +%Y%m%dT%H%M%SZ).dump"
test -s backups/firefa-pre-migration-*.dump
pg_restore --list backups/firefa-pre-migration-*.dump >/dev/null
~~~

- Copy the backup off the host and test restoration to a separate disposable database. Never test restore against production.

### Deploy and verify

From repository root on the intended host:

~~~bash
docker compose -f docker-compose.backend.yml up -d --build
docker compose -f docker-compose.backend.yml ps
docker compose -f docker-compose.backend.yml logs --tail=200 api
curl --fail --show-error --include http://127.0.0.1:3000/health/ready
~~~

Pass criteria:
- API and PostgreSQL containers are healthy.
- /health/ready returns HTTP 200 after the API can execute SELECT 1.
- Logs show the migration command completed with no error.
- The migration runner can be executed again without changing the schema unexpectedly.
- Public API access is only via HTTPS/TLS reverse proxy; PostgreSQL is not publicly exposed.

### Inventory reconciliation verification

Use a valid Owner access token and the server-issued outlet UUID from a secure shell:

~~~bash
curl --fail --show-error \
  -H "Authorization: Bearer $OWNER_TOKEN" \
  "$API_URL/api/v1/inventory/reconcile?outletId=$OUTLET_UUID"
~~~

Pass criteria:
- Each server inventory row reports ledgerMatches=true and unexplainedDelta=0.
- Local item/outlet mapping is explicit and validated; no unmapped local or server-only item is silently ignored.
- Local and server quantities match after all queued movements have valid acknowledgements.
- A replayed event returns the original movement identity and does not change stock again.
- Offline/reconnect test and backup/restore drill are documented with timestamps and evidence.

Do not mark Stage 5 production verification complete until the real host, backup artifact, migration output, readiness response, reconciliation response, and replay test results have been recorded. If no server exists yet, record production verification as DEFERRED — host not provisioned, not passed.
