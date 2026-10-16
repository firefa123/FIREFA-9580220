# Stage 3 — Account and outlet validation

## Runtime configuration

The Main App backend integration is opt-in. Configure all three Dart defines for a real backend session:

- `FIREFA_BACKEND_ENABLED=true`
- `FIREFA_API_BASE_URL=https://<backend-host>`
- `FIREFA_OUTLET_MAP={"outlet-001":"<server-outlet-uuid>","outlet-002":"<server-outlet-uuid>"}`

Replace each placeholder with the actual outlet UUID returned by the backend/database. Do not infer or reuse UUIDs across tenants. A server UUID may appear only once in the local mapping. The mapping is configuration, not authorization.

## Validation performed by the app

1. Login accepts only the backend `owner` or `cashier` role and validates user ID, tenant ID, access/refresh tokens, and every server outlet ID as UUIDs.
2. Login fails closed if the configured local-to-server mapping does not intersect the outlet IDs returned for the authenticated session.
3. The outlet selector contains only local outlets whose mapped server UUID is in the authenticated session's outlet list. The previous hard-coded Cashier-to-`outlet-001` rule is not used for backend sessions.
4. A sync request resolves the local outlet through the validated mapping and authenticated session before constructing the request. Missing mappings and unauthorized server outlets are rejected before HTTP submission.
5. A sync pass processes only the currently selected, session-authorized local outlet; it does not iterate every mapping configured on the device.
6. Access and refresh tokens are stored in secure storage. Non-secret session metadata is stored separately so the authenticated tenant, role, and outlet scope can be restored. A 401 triggers one refresh attempt.
7. The backend independently checks the JWT tenant and active outlet membership. Client-side mapping is an additional guard, not a replacement for server authorization.

## Tests

`apps/firefa_main_app/test/backend_session_outlet_test.dart` covers explicit mapping, missing mapping, unauthorized outlet, rejecting local IDs where a UUID is required, owner/cashier role validation, UUID identity validation, duplicate outlets, and empty outlet access.

## Deployment boundary

These code changes do not configure deployment secrets, discover actual server outlet UUIDs, or apply migrations to a live database. Before enabling backend mode in a real installation, obtain the outlet UUIDs from that tenant's authenticated backend/database and provide the matching mapping through build configuration. Do not enable cloud sync with guessed IDs.
