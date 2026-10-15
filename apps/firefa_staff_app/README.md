# FIREFA Staff App

Flutter app for staff-facing outlet workflows in the FIREFA monorepo.

## Initial MVP foundation

- Staff dashboard and quick navigation.
- Demo shift check-in/check-out.
- Example shift-preparation checklist.
- Basic profile placeholder.
- Main App visual direction: teal primary, light surfaces, rounded cards.

## Current limitations

This is a local UI prototype. Demo attendance and task state live in memory and reset when the app restarts. Authentication, staff identity, outlet authorization, official schedules, persistent storage, server APIs, notifications, and synchronization are not implemented. Demo check-in is not verified attendance.

## Run

From this directory:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

## Scope rule

Keep Staff App isolated from `apps/firefa_main_app`. Integrate through explicit shared contracts and authenticated backend APIs when implemented; do not modify Main App directly to add Staff App features.
