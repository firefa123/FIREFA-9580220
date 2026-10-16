# FIREFA Baseline Audit — 2026-10-16

## Purpose

This document records the verified starting point for the staged FIREFA integration work. It is an audit baseline, not a claim that the cloud-connected product is production-ready.

## Repository and branch

- Repository: `firefa123/FIREFA-9580220`
- Working branch: `development`
- Audited branch HEAD: `a05825deb89d4640aafd86ef87ea60ab98347e79`
- Latest change in the audit baseline: `test(sync): verify backend payload and outlet validation`
- Branch protection: GitHub reports `development` is not protected and has no required status checks.
- GitHub comparison reports `development` is 787 commits ahead of `main`, 0 behind. Do not merge or fast-forward this branch to `main` as a cleanup shortcut; review the release diff deliberately.

## Repository structure

- `apps/firefa_main_app`: primary Flutter owner/outlet application.
- `apps/firefa_staff_app`: separate staff Flutter app; CI also analyzes and tests it.
- `backend`: TypeScript/Fastify REST API, PostgreSQL migrations and tests.
- `docs`: project documentation.
- `.github/workflows/flutter-validation.yml`: validates both Flutter apps on pushes and pull requests to `main` and `development`.
- `.github/workflows/backend-validation.yml`: backend validation on backend-related path changes.

The primary app README explicitly names the current scope a local MVP and says authenticated cloud transport and a deployed sync API are not enabled. Preserve the existing primary app and do not replace it with the former rebuild prototype.

## Validation evidence

### Latest Flutter CI

Both jobs passed on the latest audited Flutter commits:
- `a05825deb89d4640aafd86ef87ea60ab98347e79`: https://github.com/firefa123/FIREFA-9580220/actions/runs/38846181958
- `1a8f2bc092266db1dd8c1aaf64dc061b98c30380`: https://github.com/firefa123/FIREFA-9580220/actions/runs/38846139245

The workflow runs `flutter pub get`, `flutter analyze`, and `flutter test --reporter expanded` for both `apps/firefa_main_app` and `apps/firefa_staff_app`.

### Backend CI

Backend validation passed on `0efc623c8b31fa7b6740f2712ecbc1fad0a64574`:
https://github.com/firefa123/FIREFA-9580220/actions/runs/38844556059

Verified successful workflow steps include Node setup, dependency install, typecheck, build, PostgreSQL migration, unit/integration tests, migration idempotence, required schema table checks, API readiness against PostgreSQL, and Docker build. Later audited commits changed Flutter files only; this backend CI is evidence for the unchanged backend tree, not a fresh run on the Flutter-only commits.

### Local results reported by project owner

- Main app: `flutter analyze` clean.
- Main app: `flutter test` reported 229 passing tests.
- Backend: `npm.cmd run typecheck` and `npm.cmd run build` succeeded.
- Backend local `npm.cmd test`: 3 passed, 16 skipped. The skipped integration suite requires a dedicated test PostgreSQL URL whose database name contains `test`. Never point it at production data.
- These are user-reported local results, not independently re-executed in this audit.

## Completed and do not repeat

- Main app layout overflow fixes in Dashboard, Orders, POS, Reports, Settings, Printer, Cashier Shift, F&B Operations, Inventory and Purchase Orders.
- Role presentation tests for Owner and Kasir.
- Backend foundation for auth/session refresh/logout, outlet membership, order sync events, idempotency, version conflicts, catalog/inventory endpoints, and PostgreSQL schema/migrations.
- Offline outbox persistence and local conflict/retry states.
- Outlet ID resolver that refuses missing mappings and server outlets not authorized for the active session.
- Payload builder for backend order-event contract.
- Unit tests for outlet mapping and payload validation.

Relevant latest Flutter commits:
- `c8d2e50029a4d474afb23620bcc4186244e1bfa0` — outlet mapping validation.
- `aa20a3a0d7a89d368bad8e61876129e1beb150f7` — outlet mapping tests.
- `1a8f2bc092266db1dd8c1aaf64dc061b98c30380` — backend sync payload builder.
- `a05825deb89d4640aafd86ef87ea60ab98347e79` — payload validation tests.

## Known local working-tree changes (last user-reported status)

The local working tree previously showed:
- Modified: `apps/firefa_main_app/pubspec.lock`, `backend/src/app.ts`.
- Untracked: `apps/firefa_main_app/lib/features/modules/pos_page.dart.before-cart-scroll.bak`, `apps/firefa_staff_app/.gitignore`, `.metadata`, `analysis_options.yaml`, `pubspec.lock`, `web/`, `backend/package-lock.json`, and `ersIntelFIREFA-9580220`.

This status came from an earlier user-provided terminal report; it has not been re-read from their computer. Do not reset, clean, delete, or overwrite these paths until the owner inspects and classifies them. A remote GitHub audit cannot prove the current local working tree is clean.

## Concrete gaps to resolve

1. **No verified deployed backend endpoint/configuration**: cloud authentication/sync remains opt-in; no production URL or live tenant/outlet mapping has been established.
2. **Outbox transport is not yet end-to-end**: payload preparation exists, but there is no verified automatic send/acknowledgement/retry loop wired from the persisted queue to the authenticated API.
3. **Outlet mapping is configuration-only**: real server UUIDs must be supplied per environment and checked against the signed-in session. Never guess UUIDs or silently send local demo IDs.
4. **Role coverage needs backend-specific tests**: Flutter role tests are present, and the sync endpoint allows owner/cashier for outlet-scoped events, but ensure every owner-only catalog/inventory/admin mutation rejects cashier at the API boundary.
5. **Payment/refund semantics are intentionally limited**: cash payments/refunds are reported records, not external settlement confirmation. Non-cash refunds are rejected pending provider verification.
6. **Inventory end-to-end sync remains unverified**: backend movement/idempotency logic exists, but app-to-server delivery and reconciliation have not been proven.
7. **Local integration tests are not representative unless PostgreSQL is configured**: local run skipped 16 integration tests; CI uses isolated PostgreSQL and the backend integration workflow passed.
8. **Dependency audit finding**: local npm install reported 5 vulnerabilities (1 moderate, 4 critical). Review the full advisory tree and supported upgrades separately; do not run `npm audit fix --force` without compatibility tests.
9. **Branch governance**: `development` is unprotected and far ahead of `main`; release promotion needs an intentional diff/review plan.

## Ordered follow-up

1. Freeze this baseline; preserve local changes and avoid destructive cleanup.
2. Audit backend authorization and add explicit Owner/Kasir API integration tests.
3. Complete authenticated outbox delivery with mapped outlet IDs, idempotency, retry/backoff, acknowledgement, and conflict handling.
4. Connect and test inventory movement delivery and reconciliation.
5. Test order history, cash/BON reporting, partial/full refund records and payment-state consistency; do not label reported payments as provider-settled.
6. Review npm advisories and dependency updates safely.
7. Run both Flutter apps' analysis/tests and backend PostgreSQL integration/migration/readiness/Docker checks.
8. Review the complete release diff and only then decide whether/how to promote from `development` to `main`.

## Baseline exit criteria

Stage 1 is considered documented when this report is committed. The project is not considered production-connected until the gaps above are implemented, exercised against an isolated test database, and deployed/configured in a verified environment.
