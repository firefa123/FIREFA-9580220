# Stage 7 — Comprehensive validation

## Scope and execution contract

Stage 7 validates the existing offline-first application without claiming that a local/CI test is a production deployment test. CI is expected to run on the dedicated `firefa_test` PostgreSQL database; PostgreSQL integration tests must not silently skip in test mode when the database URL is missing or unsafe.

## Test matrix

| Area | Automated coverage in this repository | Execution environment | Evidence |
|---|---|---|---|
| Offline/online sync | Persisted outbox, outlet-scoped batching, retries with the same event ID, simulated timeout/retry, interrupted-send recovery, conflict inbox and validated acknowledgements | Flutter unit tests with deterministic fake adapters | `apps/firefa_main_app/test/sync_engine_test.dart` and related store/sync tests |
| Multi-outlet isolation | Local outbox batching by outlet, outlet mapping authorization, reused order IDs scoped by outlet for inventory/cancellation, backend outlet membership enforcement | Flutter tests plus PostgreSQL-backed API integration tests | `backend_outlet_mapping_test.dart`, `backend_session_outlet_test.dart`, `order_stock_cancellation_test.dart`, `backend/test/auth.integration.test.ts` |
| Roles | Only Owner/Kasir are accepted by app session/permissions; owner-only recovery is forbidden to Kasir at API level | Flutter unit tests and PostgreSQL-backed API integration tests | `system_roles_test.dart`, `backend/test/auth.integration.test.ts` |
| Transactions and payment | Order sync commit/idempotency, mismatched payload rejection, server payment status does not trust client-reported paid state, payment/refund/receivable audit coverage | Flutter tests plus PostgreSQL-backed API integration tests | Stage 6 payment/refund tests and backend integration suite |
| Inventory | Negative stock rejection, exact acknowledgement checks, reconciliation differences, order cancellation stock reversal and recovery idempotency; backend stock ledger, payload replay and reconciliation | Flutter tests plus PostgreSQL-backed API integration tests | `inventory_hybrid_sync_test.dart`, inventory/store/order tests and backend integration suite |
| PostgreSQL migrations | Apply all SQL migrations on PostgreSQL 16, execute the migration command again, verify required tables, run API readiness against the migrated DB | GitHub Actions PostgreSQL service | `.github/workflows/backend-validation.yml` |
| UI regression | Main and staff app static analysis and widget/unit test suites | Flutter stable on Ubuntu CI | `.github/workflows/flutter-validation.yml` |

## Rules for interpreting results

- A failed test or CI job is a failure until fixed and rerun; do not count an earlier green run on a different commit as proof.
- PostgreSQL integration tests may be skipped for an intentional local unit-only run with no test database. When `NODE_ENV=test`, an absent/unsafe `TEST_DATABASE_URL` is a hard error so CI cannot report green while silently omitting the integration suite.
- Fake-adapter tests exercise offline/online state transitions deterministically; they do not prove connectivity to a deployed production server.
- PostgreSQL migration and readiness checks run against an ephemeral CI database. Production migration, backup/restore, and live-network verification remain unverified until a production/staging endpoint and credentials are provisioned.
- The workflow does not intentionally exclude any relevant test suite. Any skipped test reported by CI must be explained in the run record before Stage 7 is accepted.

## Completion evidence

Record the final commit SHA and links to both Flutter and backend validation runs after the Stage 7 PR head has completed. Do not mark the stage complete while either run is pending or failing.
