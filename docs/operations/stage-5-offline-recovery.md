# FIREFA Stage 5 — Offline Inventory and Production Recovery Runbook

## Current deployment boundary

The Main App is offline-first. Inventory balances and the movement ledger are stored locally in SharedPreferences. Inventory synchronization is opt-in and requires a deployed authenticated backend. Do not interpret a passing CI run as a production deployment. Until a production host exists, use the local persistence and CI checks below; defer the production-only checklist.

The local preference store is not a transactional database. Await waitForPendingSave() or the awaited adjustment methods before reporting a stock movement as durably saved. This protects normal app restart/reopen flows, but is not a guarantee against device loss, storage corruption, or power failure during a preference write.

## Offline → restart → reconnect acceptance test

1. Start Main App with backend sync disabled or the device offline.
2. As Owner, create a test inventory item with a known stock balance.
3. Record two stock movements and wait for the UI action to finish.
4. Force-close and reopen the app. Verify the balance and both movement history rows are unchanged and in order.
5. Re-enable connectivity. Until the backend is configured and authenticated, movements must remain in the local ledger; never clear local history because a request was skipped or failed.
6. Once connected to a test backend, send the oldest unsent movement first. Mark it sent only after validating the server's event/idempotency key, outlet, inventory item, and non-negative resulting balance.
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

Backend CI uses a disposable PostgreSQL 16 database and verifies typecheck/build, migrations, integration tests, migration idempotency, required tables, API readiness, and Docker build. It does not touch production.

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
