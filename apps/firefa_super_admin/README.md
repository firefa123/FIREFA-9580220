# FIREFA Super Admin & Cloud Sync

Standalone web portal for the fourth FIREFA workstream. It is intentionally separate from Main App, Staff App, and Customer Web.

## Run locally

Serve this directory with any static HTTP server, then open `index.html`. Configure the backend URL (default `http://localhost:3000`).

## Current functionality
- Public backend liveness and database readiness checks.
- Configurable backend URL stored in browser local storage.
- Login smoke test against `POST /api/v1/auth/login`; access token remains in tab memory only.
- Displays the authenticated tenant and outlet IDs returned by the existing API.
- Clearly identifies unavailable global admin and queue-monitoring APIs rather than displaying fake tenant or sync data.

## Important boundary

The current backend auth route only issues `owner` and `cashier` roles. This portal does **not** grant Super Admin privileges or expose cross-tenant data. A production Super Admin requires a separately provisioned role, backend authorization guards, audited tenant-management and sync-monitor endpoints, and integration tests before the controls are enabled.

Cloud sync remains opt-in and must use an authenticated, deployed backend. This static portal does not deploy the backend or claim production readiness.
