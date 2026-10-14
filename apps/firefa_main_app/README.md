# FIREFA Main App

FIREFA Main App is the owner/operator application for outlet operations.

## Finalized scope — v1.0.0 local MVP

- Outlet-aware point of sale and order lifecycle.
- Menu management, inventory ingredients, recipes, stock movements, and stock-opname workflow.
- Table reservations and dine-in occupancy.
- Staff management, role permissions, attendance, and activity-log foundations.
- Order receipts and operational reports.
- Offline outbox, retry state, conflict inbox, and local reconciliation workflow.
- Local persistence for supported workflows.

The existing app UI and navigation remain the target. Do not replace this app with the separate `firefa_main_app_rebuild` prototype.

## Validation evidence

On 14 October 2026, the project owner reported running these commands locally from this directory:

```powershell
flutter analyze
flutter test
flutter run
```

Reported result: analyzer clean, **197 tests passed**, and the app launched in Chrome. This is the latest user-reported local validation; the latest repository metadata/workflow changes still need a fresh local run and GitHub Actions result before claiming those exact commits passed CI.

## Release boundary

**Finalized as a local MVP, not a production-connected deployment.**

- Local persistence uses SharedPreferences in relevant modules; it is not a transactional database.
- Offline sync is a local client workflow. Authenticated cloud transport and a deployed sync API are not enabled.
- Local/demo payment state is not a bank or payment-provider settlement.
- Printer configuration does not itself guarantee routing to physical printer devices.
- Production authentication, tenant authorization, cloud persistence, and deployment are not claimed complete.

These are explicit integration boundaries, not hidden successful integrations. A production-connected release requires a separately implemented and verified backend/payment/printer/auth deployment.

## Local acceptance

Run from `apps/firefa_main_app` after pulling the latest `development` branch:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

The GitHub Actions Flutter validation workflow now also runs for pushes and pull requests targeting `development`, in addition to `main`.
