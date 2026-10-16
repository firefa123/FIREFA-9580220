# Staff and attendance API

Migration `007_staff_attendance_geofence.sql` adds staff identities and server-recorded attendance without changing Owner/Kasir tenant membership roles.

## Owner/Kasir APIs

All requests except staff PIN login require a Bearer access token from the existing auth flow.

- `GET /api/v1/staff?outletId=<uuid>` — list staff (Owner/Kasir).
- `POST /api/v1/staff` — Owner only. Body: `{ "outletId": "<uuid>", "staffCode": "KSR-01", "displayName": "Nama Staff", "pin": "123456", "expectedStartTime": "09:00" }`. `expectedStartTime` is optional; omit it for flexible attendance without a punctuality target.
- `PATCH /api/v1/staff/:staffId` — Owner only. Body includes `outletId` and any of `displayName`, `pin`, `expectedStartTime`, or `status`. Send `expectedStartTime: null` to remove a punctuality target.
- `PATCH /api/v1/staff/geofence-radius` — Owner only. Body: `{ "outletId": "<uuid>", "radiusMeters": 100 }`; valid range is 25–2000 metres. The outlet must have latitude and longitude configured for attendance to work.
- `GET /api/v1/staff/performance?outletId=<uuid>&from=YYYY-MM-DD&to=YYYY-MM-DD` — Owner/Kasir attendance-day, scheduled-day, late-day and punctuality summary.

## Staff app APIs

- `POST /api/v1/staff/login` — body: `{ "outletId": "<uuid>", "staffCode": "KSR-01", "pin": "123456" }`. Returns a short-lived-to-workday 12-hour staff access token. PINs are stored as Argon2id hashes and never returned.
- `POST /api/v1/attendance/check-in` — Staff token only. Body: `{ "outletId": "<uuid>", "latitude": -7.25, "longitude": 112.75 }`.
- `POST /api/v1/attendance/check-out` — Staff token only, same body.
- `GET /api/v1/attendance/me` — Staff token only; returns the staff member's latest 60 attendance records.

The server determines attendance timestamps and outlet-local work dates. The client cannot supply timestamps or a staff ID for check-in/out. Check-in is not blocked by a planned start time; lateness is measured only when an Owner has configured an expected start time. Duplicate check-ins on the same outlet-local date are rejected. Check-in and check-out require coordinates inside the configured outlet radius; an unconfigured geofence fails closed.

Location coordinates come from the device and are not cryptographic proof of physical presence. For production use, enable HTTPS, validate device permission flows, and consider additional anti-spoofing controls. Staff app UI integration and a real-device geolocation test must be verified separately from the backend API.

## Staff App configuration

To enable live server attendance in the Staff App, build/run it with the same backend base URL used by Main App plus the selected outlet UUID:

```powershell
flutter run -d chrome --dart-define=FIREFA_BACKEND_ENABLED=true --dart-define=FIREFA_API_BASE_URL=https://your-api-host --dart-define=FIREFA_STAFF_OUTLET_ID=<outlet-uuid>
```

The Staff App asks for the staff code and six-digit PIN created by Owner. It requests device location for each check-in/check-out and sends coordinates to the backend for geofence enforcement. Staff access tokens remain in memory and are not persisted across app reloads. Replace the example host and outlet UUID with actual deployment values; use HTTPS in production.
