# FIREFA Codebase Cleanup Audit

Audit branch: `development`

## Pass 1 — confirmed orphaned and duplicate scaffolding

Removed from the tracked repository:

- 41 Dart files under the repository-root `lib/` directory. The repository has no root `pubspec.yaml`; the Flutter package is `apps/firefa_main_app/`, so those files were outside the package build and were not part of its import graph.
- 16 files belonging to a parallel, unused shell/navigation/page scaffold: `AppShell`, `AppRoutes`, the unused owner sidebar family, duplicate presentation pages, and their isolated placeholder settings/stat-card dependencies.
- 1 unused alternate navigation entry point: `FirefaMainNavigation`.
- 5 unreferenced alternate role-dashboard prototype files (`RoleDashboardRouter` and the owner, manager, cashier, and kitchen dashboard widgets). The active app already routes role access through its current dashboard/module navigation; these alternate widgets had no in-repository entry point.
- 7 unreferenced scaffolding/placeholder files: unused settings/branding binding DTOs, an unused payment UI binding, a disconnected inventory-dashboard bridge, and a customer list page containing hard-coded sample customers.
- 11 additional unused placeholders: six backend architecture placeholder classes with no runtime callers, one unused customer cart UI DTO, and four disconnected branding preview/resolver/provider classes. The backend architecture design should live in maintained architecture docs until real service contracts are implemented.
- 4 additional disconnected branding prototypes: app branding binding, fake branding persistence, multi-outlet branding resolver, and store branding page foundation; the active settings model/controller path remains.
- 10 disconnected dashboard DTO/controller/adapter files that formed a second unused dashboard data path, separate from the active `features/dashboard/dashboard_page.dart` and its widgets.
- 6 duplicate kitchen/manager order files using a separate in-memory `KitchenOrderStore`; active order lifecycle remains in the main order store/workflow.
- 3 unused legacy cart files (`CartItem`, `CartRepository`, `CartStore`); active POS cart persistence remains in `FirefaPersistentCartStore`, and the customer cart is separate.
- 14 obsolete offline-sync files containing a no-op API sync service and a simulator that removed pending orders. The active offline outbox/sync/conflict modules remain untouched.
- 1 unused legacy POS screen with hard-coded demo products. The active POS screen under `features/modules/pos_page.dart` remains.

The separate `apps/firefa_main_app_rebuild/` prototype had already been removed in an earlier commit and remains absent. The active app directory `apps/firefa_main_app/` is retained.

## Why the cleanup was scoped this way

Only files that were clearly outside the active package or isolated in an unused alternate navigation/page tree were removed. Operational modules, stores, controllers, sync/conflict handling, role/permission logic, backend contract foundations, and tests were not deleted just because they are not directly imported by `main.dart`; many are reached through feature navigation or validate important behavior.

## Validation still required after cleanup

The last reported local validation before this cleanup was 197 passing tests and a clean analyzer. That result does **not** prove the cleanup commits pass. Pull the latest `development` branch and run from `apps/firefa_main_app`:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

Only call this cleanup validated after the commands complete successfully on the latest commit. The GitHub Flutter workflow is configured to validate pushes and pull requests to both `development` and `main`.

## Follow-up audit boundary

This is the first cleanup pass, not a claim that every remaining file is dead code. Remaining candidate modules must be traced through imports, navigation, tests, and the product brief before deletion. Do not delete functional inventory, payment, purchasing, customer-ordering, staff, role, or offline-sync code solely because it is not directly imported by the app entry point.
