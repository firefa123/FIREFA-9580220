# FIREFA Staff App

Flutter app for staff-facing outlet workflows in the FIREFA monorepo. The app supports both a local demo mode and an opt-in authenticated backend mode.

## Features

- Staff login using the staff code and six-digit PIN created by Owner.
- Server-backed check-in/check-out with device coordinates and server-recorded timestamps.
- Backend geofence enforcement using the selected outlet's Owner-configured radius.
- Current staff attendance status refreshed from the server after login.
- Local demo mode for the dashboard, sample tasks, and shift toggle when backend mode is disabled.

## Run in demo mode

From this directory:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

Demo attendance and sample task completion use SharedPreferences and are not official attendance records.

## Run with backend attendance

Configure the backend base URL and outlet UUID using Dart defines:

```powershell
flutter run -d chrome --dart-define=FIREFA_BACKEND_ENABLED=true --dart-define=FIREFA_API_BASE_URL=https://your-api-host --dart-define=FIREFA_STAFF_OUTLET_ID=<outlet-uuid>
```

Use a deployed HTTPS backend in production. Staff tokens are held in memory and are cleared when the app reloads. Location coordinates are checked server-side against the outlet geofence, but device coordinates alone are not cryptographic proof of physical presence.

## Scope rule

Keep Staff App isolated from `apps/firefa_main_app`. Integrate through explicit shared contracts and authenticated backend APIs; do not modify Main App directly to add Staff App features.
