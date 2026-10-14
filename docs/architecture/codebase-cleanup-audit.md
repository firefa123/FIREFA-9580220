# FIREFA Codebase Cleanup Audit

Audit branch: `development`

## Pass 1 — confirmed orphaned and duplicate scaffolding

Removed from the tracked repository:

- 41 Dart files under the repository-root `lib/` directory. The repository has no root `pubspec.yaml`; the Flutter package is `apps/firefa_main_app/`, so those files were outside the package build and were not part of its import graph.
- 16 files belonging to a parallel, unused shell/navigation/page scaffold: `AppShell`, `AppRoutes`, the unused owner sidebar family, duplicate presentation pages, and their isolated placeholder settings/stat-card dependencies.
- 1 unused alternate navigation entry point: `FirefaMainNavigation`.
- 5 unreferenced alternate role-dashboard prototype files (`RoleDashboardRouter` and the owner, manager, cashier, and kitchen dashboard widgets). The active app already routes role access through its current dashboard/module navigation; these alternate widgets had no in-repository entry point.
- 7 unreferenced scaffolding/placeholder files: unused settings/branding binding DTOs, an unused payment UI binding, a disconnected inventory-dashboard bridge, and a customer list page containing hard-coded sample customers.

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
