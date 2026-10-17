# FIREFA 7K-A — Backend Sync Contract (Draft v1)

Status: **CLIENT AND SERVER IMPLEMENTATIONS PRESENT; LIVE DEPLOYMENT AND END-TO-END VALIDATION OUTSTANDING.** The repository contains the authenticated client session, durable local outbox, HTTP adapter for `POST /api/v1/sync/events`, foreground retry worker, conflict inbox, Fastify sync endpoint, transactional PostgreSQL order receipts, and inventory movement API. The inventory/order tables required by those routes are now included in the migration chain. A provisioned staging/production endpoint and credentials were not available to verify the live network path; do not claim production cloud sync is complete until the acceptance tests below pass against that endpoint.

## Scope and invariants

- One monorepo for Main App, Staff App, Customer Web, Super Admin, backend, database and documentation.
- Offline-first: local checkout and order changes must work without a connection.
- Every subscription tier has the same features; tiers differ only by outlet limits.
- No event is marked `synced` without a verified authenticated backend acknowledgment.
- Never treat the current local `ORD-1001`-style order ID as globally unique.
- The local outbox is persisted through `SharedPreferences` and combined order/outbox snapshots. Interrupted `syncing` entries are restored as `pending`, and server idempotency allows safe replay after an uncertain acknowledgment. `SharedPreferences` is not a transactional database, so this is not a guarantee against storage corruption, device loss, or abrupt power loss during a write; use a transactional local database before claiming that stronger durability.
- Do not send raw customer secrets, credentials, or unnecessary PII in event payloads.

## Implemented authenticated API

`POST /api/v1/sync/events`

- TLS required.
- `Authorization: Bearer <access-token>`; server derives tenant, user, and allowed outlets from verified identity. Never trust tenant IDs supplied by a client.
- `Content-Type: application/json`.
- `Idempotency-Key: <eventId>` matches the JSON event ID.
- Start with one event per request; batching is a future extension.
- Enforce request size limits, schema validation, and rate limiting.
- Server must authorize the event's outlet before accessing or changing tenant data.

### Request (illustrative)

```json
{
  "schemaVersion": 1,
  "eventId": "evt-128bit-random-1",
  "deviceId": "7a2aeb3a-4b76-4e51-8c51-3cb4f8a4c2d0",
  "outletId": "2b6b7b60-8b90-4a56-92b0-9b6e0d1f3a10",
  "orderId": "ORD-1001",
  "eventType": "order.created",
  "createdAt": "2026-10-09T04:00:00Z",
  "orderSnapshot": {
    "id": "ORD-1001",
    "outletId": "2b6b7b60-8b90-4a56-92b0-9b6e0d1f3a10",
    "orderType": "Take Away",
    "tableId": null,
    "createdAt": "2026-10-09T04:00:00Z",
    "items": [{"productName": "Example", "quantity": 1, "unitPrice": 1000, "details": ""}],
    "subtotal": 1000,
    "discount": 0,
    "tax": 0,
    "service": 0,
    "total": 1000,
    "status": "confirmed",
    "paymentStatus": "unpaid"
  }
}
```

`order.updated` requires `expectedServerVersion` and is rejected when the client version is stale. `order.recovered` is owner-only and is subject to existing-order identity checks; it must not be used as an automatic way to overwrite a server order. Treat the snapshot as an asserted client state, **not** automatically authoritative server state. The `deviceId` is a stable UUID per installation, and `outletId` is the server-issued outlet UUID; a future client adapter must map local outlet IDs to this UUID.

### Acknowledged response (illustrative)

HTTP 200 or 201, only after durable transaction commit:

```json
{
  "schemaVersion": 1,
  "eventId": "evt-128bit-random-1",
  "outcome": "acknowledged",
  "serverReference": "sync-receipt-uuid",
  "globalOrderId": "order-uuid",
  "serverVersion": 1
}
```

The client verifies schema version, matching event ID, `acknowledged` outcome, non-empty receipt reference, UUID global order ID, and a positive server version. The backend independently enforces authorization context. A 2xx response alone is insufficient.

### Failure policy

| Condition | Proposed response | Client behavior |
| --- | --- | --- |
| Duplicate event ID, identical payload and authorized scope | 200 with original receipt | Safe acknowledgment; no duplicate mutation |
| Same event ID with different payload | 409 conflict | Permanent failure; manual investigation |
| Stale order version / concurrent update | 409 conflict with typed code | Do not overwrite; reconcile |
| Unauthorized / forbidden outlet | 401 / 403 | Stop sending; require auth or access correction |
| Invalid schema or business transition | 400 / 422 | Permanent failure; preserve local event for review |
| Timeout, network loss, 429, 5xx | No receipt / retryable | Keep event pending; exponential backoff with jitter |
| Unexpected or mismatched acknowledgment | Invalid receipt | Never mark synced; log safe diagnostic |

Never claim payment was captured by the backend: the current checkout's `paid` status is a local simulation.

## Server-side transaction and idempotency

Recommended PostgreSQL constraints:
- `tenants(id)`
- `outlets(id, tenant_id)`
- `orders(id UUID PRIMARY KEY, tenant_id, outlet_id, device_id, client_order_id, version, ...)`; unique `(tenant_id, device_id, client_order_id)`.
- `sync_receipts(tenant_id, event_id, payload_hash, server_reference, global_order_id, response_body, created_at)`; unique `(tenant_id, event_id)`.
- `order_events(...)` with immutable audit history.

In **one database transaction**: authorize tenant/outlet, check existing idempotency receipt and payload hash, validate state/version, apply allowed order change, store immutable event and receipt, then commit. Return acknowledgment only after successful commit. Enforce tenant/outlet scoping in queries and preferably database row-level security.

## Global identity migration

Existing client order IDs are display/local IDs, not global IDs. Before multi-device writes, introduce a persisted random `deviceId` or stable installation ID, plus a global UUID/ULID for each new order; migrate existing local orders without changing their display IDs. Resolve legacy orders using a scoped tuple such as `(tenantId, deviceId, localOrderId)`. The server must not merge unrelated orders sharing `ORD-1001`.

## Ordering and conflict strategy

- Outbox events are FIFO **per outlet** in the current preparation helper, but network delivery and device clocks cannot guarantee global ordering.
- Add per-order monotonic client revision and server version; server rejects stale transitions rather than blindly applying last-write-wins.
- `order.recovered` requires a specific reconciliation policy and cannot bypass state validation.
- Financial and payment transitions need stronger domain checks, audit trails, and eventual integration with a verified payment provider.
- Tenant identity and outlet membership must be checked for every request, including retries.

## Planned implementation boundaries

1. 7K-A: contract and threat model documented.
2. 7K-B: backend auth, scoped order endpoint, transactional idempotency receipts, and inventory movement endpoint are implemented; the operational schema migration was added. Live database migration and deployment tests remain outstanding.
3. 7K-C: client HTTP adapter and outlet mapping are implemented; live endpoint and cross-device identity behavior remain unverified.
4. 7K-D: foreground retry worker, jittered order-event retry, app-resume recovery, and manual retry controls are implemented; background execution when the app is terminated is not guaranteed.
5. 7K-E: **outstanding** — run cross-device, crash/restart, conflict, payment, and tenant-isolation tests against a real staging backend.

## Acceptance criteria before production sign-off

- Authenticated tenant/outlet access proven by negative tests.
- Duplicate event requests return the same durable receipt without duplicate orders.
- Payload mismatch with same event ID is rejected.
- Two devices with identical local order IDs do not collide.
- Lost response after committed write can be retried safely.
- Stale updates cannot overwrite newer server state.
- Offline checkout remains functional and events remain pending when backend is unavailable.
- No production credentials embedded in Flutter source or Git history.
