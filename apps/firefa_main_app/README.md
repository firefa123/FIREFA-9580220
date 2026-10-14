# FIREFA Main App

A Flutter application for the FIREFA outlet operations workflow.

## Current scope

- Outlet-aware point of sale and order lifecycle.
- Menu management, inventory ingredients, recipes, stock movements, and stock-opname workflow.
- Table reservations and dine-in occupancy.
- Staff management, role permissions, attendance, and activity log foundations.
- Order receipts and operational reports.
- Offline outbox, retry state, conflict inbox, and local reconciliation workflow.
- Local persistence for supported workflows.

## Validation checkpoint

On 14 October 2026, the project owner reported running these commands locally from this directory:

```powershell
flutter analyze
flutter test
flutter run
```

Reported result: analyzer clean, **197 tests passed**, and the app launched in Chrome.

This records the user-reported local validation result; it is not a claim that CI or a production deployment was run.

## Important implementation boundaries

- Current local persistence uses SharedPreferences in relevant modules; it is not a transactional database.
- The offline sync client is implemented as a local workflow, but authenticated cloud transport and a deployed sync API are not enabled.
- A local/demo payment state is not a bank or payment-provider settlement.
- Printer configuration does not itself guarantee routing to physical printer devices.
- Authentication, tenant authorization, cloud persistence, and production deployment must not be considered complete unless separately implemented and verified.

## Local development

Run from `apps/firefa_main_app`:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

Keep changes aligned with the FIREFA brief and existing navigation and UI. Avoid replacing this app with the separate `firefa_main_app_rebuild` prototype.
