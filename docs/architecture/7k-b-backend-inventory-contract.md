# FIREFA Stage 5 — Inventory and catalog sync contract

## Scope

Stage 5 connects catalog products to outlet inventory items, applies stock movements on the server, rejects negative stock, deduplicates retries, and exposes ledger reconciliation. Local inventory remains usable while offline.

## Server contract

- `GET /api/v1/products?outletId=<server-outlet-uuid>`: outlet catalog.
- `POST /api/v1/products` and `PATCH /api/v1/products/:id`: Owner-only catalog writes.
- `GET /api/v1/inventory/items?outletId=<server-outlet-uuid>`: Owner-only inventory and linked `productId`.
- `POST /api/v1/inventory/items`: Owner-only inventory item creation; optional `productId` must refer to an active product in the same outlet or a tenant-wide product.
- `POST /api/v1/inventory/movements`: Owner-only atomic stock mutation. Requires `Idempotency-Key`. Stock update, movement ledger, and audit row commit in one transaction. A retry with the same key and same payload returns the original movement without applying the delta again; a changed payload returns HTTP 409. A movement that would make stock negative returns HTTP 409.
- `GET /api/v1/inventory/reconcile?outletId=<server-outlet-uuid>`: returns current stock, summed movement ledger, movement count, last movement timestamp, and unexplained delta for each item.

## Flutter configuration

Backend sync must be explicitly enabled as before. Configure:

- `FIREFA_OUTLET_MAP`: JSON map from local outlet IDs to authorized server outlet UUIDs.
- `FIREFA_INVENTORY_ITEM_MAP`: JSON map from local inventory item IDs to server inventory item UUIDs, for example `{"inventory-1":"00000000-0000-4000-8000-000000000001"}`.

Mappings are fail-closed: an unmapped or unauthorized outlet/item is not guessed or silently created. Configure mappings from the actual server inventory records before enabling inventory sync for that outlet.

The Owner dashboard retry pass submits local movement history oldest-first. It uses a persistent device UUID plus the local movement ID as the idempotency key and stores acknowledged movement IDs in SharedPreferences only after a valid 200/201 response. Timeout or connection loss leaves the movement eligible for retry with the same key.

## Reconciliation policy

The Flutter client exposes `FirefaInventoryBackendSync.instance.reconcileOutlet(localOutletId)`. It compares mapped local stock quantities against the server reconciliation endpoint and returns differences. It does not silently overwrite either side: differences must be reviewed before a corrective stock movement is posted.

The backend CI runs PostgreSQL migrations twice, integration tests for product linkage, stock floor enforcement, payload-mismatch rejection, replay after a simulated lost response, and ledger reconciliation, then verifies readiness and Docker build. This does not mean a production database has been migrated; deployment remains an operator-controlled step.
