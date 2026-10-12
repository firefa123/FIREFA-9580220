# 7K-A — Offline Sync & Conflict Reconciliation (Local Client Module)

Status: **local client workflow implemented; local validation required**.

This module covers the Flutter client's durable outbox, retry policy, conflict inbox, conflict decisions, audit timeline, and dashboard status. It does not implement or enable the cloud backend.

## Implemented behavior

- Outbox entries are scoped by outlet and selected FIFO.
- Each event has a random event ID suitable as a future idempotency key; local order IDs are not treated as globally unique.
- Outbox state and retry due time are persisted in SharedPreferences.
- Interrupted `syncing` entries recover to `pending` and the recovered state is persisted.
- Retryable failures use exponential backoff with bounded jitter and a five-minute maximum.
- Events with a future retry time are excluded from the eligible batch.
- Only a verified receipt matching the event ID and containing a non-empty server reference can mark an event synced.
- Conflict events are isolated from automatic retry.
- The conflict inbox and resolution audit are stored locally.
- Keep Local and Accept Server are available only for supported concurrent/stale-version conflicts; server snapshots are validated before applying locally.
- The dashboard reports pending, in-flight, failed and conflicted counts.

## State transition invariants

- `pending -> syncing` increments attempts.
- `syncing -> synced` requires a validated acknowledgment.
- `syncing -> conflict` requires a conflict receipt that was recorded in the conflict inbox.
- `syncing -> failed` represents a permanent rejection.
- Retryable failures return to `pending` with a persisted due time.
- An interrupted `syncing` entry returns to `pending` on restore.
- Concurrent sync invocations cannot send the same event twice: only the invocation that successfully transitions `pending -> syncing` may call the adapter.
- Illegal transitions to terminal states are rejected.

## Not implemented / not claimed

- No authenticated cloud transport or deployed sync API exists yet.
- No cloud acknowledgment is simulated by the disabled adapter.
- SharedPreferences is not a transactional database; this module does not promise crash-atomic writes or cross-device consistency.
- Automatic background scheduling and reconnect-triggered sync are not implemented; retries become eligible at their due time and are processed when sync is invoked.
- Tenant authorization, server-side idempotency, global order identity migration and transactional backend writes belong to the separate backend implementation stage.

## Local acceptance checklist

Run from `apps/firefa_main_app`:

```powershell
flutter analyze
flutter test
flutter run
```

Verify analyzer is clean, all tests pass (including concurrent invocation coverage), the dashboard shows accurate local counts, the disabled adapter never reports success, retry due times survive restoration, and conflict events remain out of retry batches.
