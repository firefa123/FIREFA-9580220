# FIREFA Staging End-to-End Acceptance

Status: **BLOCKED — staging is not provisioned or reachable from this repository context.**
Last checked: 2026-10-17
Target branch: `development`

This checklist is an execution record and acceptance gate, not evidence that staging tests passed. Do not mark any item passed until a real staging URL and test accounts have been used and the evidence has been saved.

## Preconditions required to run the live tests

- [ ] HTTPS staging API URL is provisioned and reachable.
- [ ] Main App and Staff App staging builds use that URL; backend integration is enabled, not the local/demo fallback.
- [ ] Disposable staging tenant and outlet exist; outlet UUID is mapped in Main App.
- [ ] Owner and Kasir test accounts are active and scoped to that outlet.
- [ ] A staff test identity/PIN exists, and the outlet has latitude, longitude, timezone, and geofence radius configured.
- [ ] Test product and inventory item exist with a known starting quantity.
- [ ] No real customer or production data is used.
- [ ] A safe reset/reseed procedure is available; do not use the one-time Owner bootstrap against an already initialized environment.
- [ ] CI commit SHA and the corresponding Flutter/backend workflow links are recorded.

## Required live acceptance matrix

### 1. Health and authentication

- [ ] `GET /health/live` returns 200.
- [ ] `GET /health/ready` returns 200 with the database reachable.
- [ ] Owner login succeeds and `GET /api/v1/auth/me` reports role `owner` and the expected outlet.
- [ ] Kasir login succeeds and reports role `cashier` with only authorized outlet membership.
- [ ] Invalid credentials fail; revoked/rotated refresh tokens cannot be reused.
- [ ] Kasir cannot use Owner-only staff administration, geofence configuration, product creation, or owner recovery endpoints.

### 2. POS order and inventory

- [ ] Owner creates a test product and inventory item; both appear after a fresh server read.
- [ ] Record initial stock quantity before the sale.
- [ ] Kasir creates a POS sale with a unique test order ID and valid item quantities.
- [ ] Server receipt is acknowledged only after the transaction commits; order and inventory movement are visible on a fresh read.
- [ ] Re-send the same event ID and identical payload; verify there is one order/effect and the same receipt is returned.
- [ ] Reuse the event ID with a different payload; verify conflict/rejection and no second stock movement.
- [ ] Attempt a sale that would make stock negative; verify rejection and unchanged stock.
- [ ] Cancel/reverse a supported order if that workflow is enabled; verify the stock reversal is applied exactly once.
- [ ] Compare the inventory ledger and current stock; record any reconciliation difference without silently overwriting balances.

### 3. Staff attendance and geofence

- [ ] Owner creates a disposable staff identity and configures an outlet geofence radius.
- [ ] Staff App logs in using the staff code and PIN.
- [ ] On a real device/browser with location permission, check-in inside the radius succeeds and uses the server timestamp.
- [ ] Check-in outside the radius or with an unconfigured geofence is rejected.
- [ ] Duplicate check-in for the same outlet-local work date is rejected.
- [ ] Check-out succeeds and attendance history/performance reflects the record.
- [ ] Validate flexible schedule when no expected start time is configured; when configured, validate late-minute calculation.
- [ ] Record device/browser, permission behavior, coordinates used for test, and server response. Device coordinates alone are not proof against location spoofing.

### 4. Offline, restart, reconnect, and conflict recovery

- [ ] Sign in and confirm the intended staging outlet mapping.
- [ ] Disable network, create a uniquely identified test order and supported stock event, and verify both remain pending locally.
- [ ] Force-close/restart the app while offline; verify pending events remain available.
- [ ] Restore network and verify the worker retries automatically and sends the original event IDs.
- [ ] Confirm server receipts arrive before events are marked synced.
- [ ] Simulate a timeout after the server may have committed; retry and verify no duplicate order or stock movement.
- [ ] Cause a stale-version update from a second session/device; verify 409/current snapshot appears in conflict review and is not silently overwritten.
- [ ] Verify outlet/tenant isolation: a session for one outlet cannot sync or read another outlet's records.
- [ ] Reconcile local and server orders/stock after sync and record the result.

## Evidence required for sign-off

For each check, record PASS/FAIL/BLOCKED, timestamp (UTC), app build/commit SHA, sanitized request/response or screenshot, and a correlation/event ID. Redact passwords, PINs, access/refresh tokens, bootstrap tokens, customer data, and precise personal location data. Keep evidence in the approved private location; do not commit secrets or production data.

## Current blockers and implementation boundaries

- No staging host URL, deployed server, provisioned staging database, or test account credentials are available in this repository context. Therefore no real staging request or multi-device test has been executed.
- GitHub CI uses ephemeral PostgreSQL and validates code, migrations, API readiness, unit/integration tests, and web builds. Green CI is not a live staging pass.
- The Main App must be built with `FIREFA_BACKEND_ENABLED=true`, the actual HTTPS API URL, and the server outlet UUID mapping. The Staff App must use the same API URL and its configured outlet UUID.
- Real device/browser location permission, camera/photo capture for attendance, network loss/recovery, and multi-device concurrency require the deployed staging environment and suitable test devices.
- Keep the release blocked until all required checks above have evidence and all failures are fixed and rerun. Do not merge to `main` or declare staging acceptance based on this checklist alone.
