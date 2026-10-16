import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it } from "vitest";
import { Pool } from "pg";
import type { FastifyInstance } from "fastify";
import { buildApp } from "../src/app";

const testDatabaseUrl = process.env.TEST_DATABASE_URL;
const safeTestDatabase = (() => {
  if (!testDatabaseUrl) return false;
  try {
    return /(^|[_-])test($|[_-])/i.test(new URL(testDatabaseUrl).pathname);
  } catch {
    return false;
  }
})();

const testJwtSecret = "integration-test-jwt-secret-at-least-thirty-two-characters";
const testBootstrapToken = "integration-test-bootstrap-token-at-least-thirty-two-characters";

const authSuite = describe.skipIf(!safeTestDatabase);

authSuite("authentication endpoints", () => {
  let adminPool: Pool;
  let app: FastifyInstance | undefined;

  beforeAll(() => {
    adminPool = new Pool({ connectionString: testDatabaseUrl });
  });

  beforeEach(async () => {
    await adminPool.query(
      "TRUNCATE TABLE order_events, sync_receipts, orders, refresh_tokens, " +
        "outlet_memberships, tenant_memberships, users, outlets, tenants RESTART IDENTITY CASCADE",
    );
  });

  afterEach(async () => {
    if (app) {
      await app.close();
      app = undefined;
    }
  });

  afterAll(async () => {
    await adminPool.end();
  });

  function createTestApp(): FastifyInstance {
    app = buildApp({
      pool: new Pool({ connectionString: testDatabaseUrl }),
      jwtSecret: testJwtSecret,
      bootstrapToken: testBootstrapToken,
    });
    return app;
  }

  async function bootstrap(ownerApp: FastifyInstance) {
    return ownerApp.inject({
      method: "POST",
      url: "/api/v1/auth/bootstrap-owner",
      headers: { "x-bootstrap-token": testBootstrapToken },
      payload: {
        tenantName: "Test Restaurant Group",
        outletName: "Main Outlet",
        outletCode: "MAIN",
        email: "owner@example.test",
        password: "Correct-Horse-Battery-42",
        displayName: "Test Owner",
        latitude: -6.2,
        longitude: 106.8,
        geofenceRadiusM: 150,
      },
    });
  }

  async function createCashierSession(
    ownerApp: FastifyInstance,
    owner: { tenantId: string; outletIds: string[] },
  ) {
    const userResult = await adminPool.query<{ id: string }>(
      "INSERT INTO users (email, password_hash, display_name) VALUES ($1, $2, $3) RETURNING id::text AS id",
      ["cashier@example.test", "test-only-password-hash", "Test Cashier"],
    );
    const userId = userResult.rows[0]!.id;
    await adminPool.query(
      "INSERT INTO tenant_memberships (tenant_id, user_id, role) VALUES ($1, $2, 'cashier')",
      [owner.tenantId, userId],
    );
    await adminPool.query(
      "INSERT INTO outlet_memberships (outlet_id, user_id) VALUES ($1, $2)",
      [owner.outletIds[0], userId],
    );
    const accessToken = ownerApp.jwt.sign({
      sub: userId,
      tenantId: owner.tenantId,
      role: "cashier",
      outletIds: owner.outletIds,
    });
    return { accessToken, userId };
  }

  function makeSyncEvent(
    outletId: string,
    deviceId: string,
    eventId: string,
    eventType: "order.created" | "order.updated" | "order.recovered" = "order.created",
    expectedServerVersion?: number,
  ) {
    const createdAt = new Date().toISOString();
    return {
      schemaVersion: 1,
      eventId,
      deviceId,
      outletId,
      orderId: "ORD-1001",
      eventType,
      createdAt,
      ...(expectedServerVersion === undefined ? {} : { expectedServerVersion }),
      orderSnapshot: {
        id: "ORD-1001",
        outletId,
        orderType: "Take Away",
        tableId: null,
        createdAt,
        items: [{ productName: "Coffee", quantity: 1, unitPrice: 10000, details: "" }],
        subtotal: 10000,
        discount: 0,
        tax: 0,
        service: 0,
        total: 10000,
        status: eventType === "order.updated" ? "preparing" : "confirmed",
        paymentStatus: "paid",
        paymentMethod: null as string | null,
        cashPaidAmount: 0,
        paidAt: null as string | null,
        customerId: null as string | null,
        customerName: "must-not-be-synced",
        refundAmount: 0,
        cashRefundAmount: 0,
        refundedAt: null as string | null,
        refundMethod: null as string | null,
        refundReason: null as string | null,
        refundRecords: [] as Array<{ amount: number; method: string; reason: string; createdAt: string }>,
      },
    };
  }

  async function postSyncEvent(
    ownerApp: FastifyInstance,
    accessToken: string,
    payload: ReturnType<typeof makeSyncEvent>,
  ) {
    return ownerApp.inject({
      method: "POST",
      url: "/api/v1/sync/events",
      headers: {
        authorization: "Bearer " + accessToken,
        "idempotency-key": payload.eventId,
      },
      payload,
    });
  }

  it("requires the bootstrap secret", async () => {
    const ownerApp = createTestApp();
    const response = await ownerApp.inject({
      method: "POST",
      url: "/api/v1/auth/bootstrap-owner",
      headers: { "x-bootstrap-token": "wrong-token" },
      payload: {
        tenantName: "Test Group",
        outletName: "Main Outlet",
        outletCode: "MAIN",
        email: "owner@example.test",
        password: "Correct-Horse-Battery-42",
        displayName: "Test Owner",
      },
    });

    expect(response.statusCode).toBe(401);
  });

  it("bootstraps one owner and returns an authenticated identity", async () => {
    const ownerApp = createTestApp();
    const response = await bootstrap(ownerApp);
    expect(response.statusCode).toBe(201);

    const tokens = response.json();
    expect(tokens.role).toBe("owner");
    expect(tokens.outletIds).toHaveLength(1);
    expect(tokens.accessToken).toEqual(expect.any(String));
    expect(tokens.refreshToken).toEqual(expect.any(String));

    const me = await ownerApp.inject({
      method: "GET",
      url: "/api/v1/auth/me",
      headers: { authorization: "Bearer " + tokens.accessToken },
    });

    expect(me.statusCode).toBe(200);
    expect(me.json().user.email).toBe("owner@example.test");
    expect(me.json().tenantId).toBe(tokens.tenantId);
  });

  it("prevents bootstrap from creating a second initial owner", async () => {
    const ownerApp = createTestApp();
    expect((await bootstrap(ownerApp)).statusCode).toBe(201);
    expect((await bootstrap(ownerApp)).statusCode).toBe(409);
  });

  it("logs in, rotates refresh tokens, and revokes a logged-out session", async () => {
    const ownerApp = createTestApp();
    await bootstrap(ownerApp);

    const login = await ownerApp.inject({
      method: "POST",
      url: "/api/v1/auth/login",
      payload: { email: "OWNER@example.test", password: "Correct-Horse-Battery-42" },
    });
    expect(login.statusCode).toBe(200);
    const original = login.json();

    const refresh = await ownerApp.inject({
      method: "POST",
      url: "/api/v1/auth/refresh",
      payload: { refreshToken: original.refreshToken },
    });
    expect(refresh.statusCode).toBe(200);
    const rotated = refresh.json();
    expect(rotated.refreshToken).not.toBe(original.refreshToken);

    const replay = await ownerApp.inject({
      method: "POST",
      url: "/api/v1/auth/refresh",
      payload: { refreshToken: original.refreshToken },
    });
    expect(replay.statusCode).toBe(401);

    const logout = await ownerApp.inject({
      method: "POST",
      url: "/api/v1/auth/logout",
      payload: { refreshToken: rotated.refreshToken },
    });
    expect(logout.statusCode).toBe(204);

    const afterLogout = await ownerApp.inject({
      method: "POST",
      url: "/api/v1/auth/refresh",
      payload: { refreshToken: rotated.refreshToken },
    });
    expect(afterLogout.statusCode).toBe(401);
  });

  it("rejects invalid credentials without disclosing whether the email exists", async () => {
    const ownerApp = createTestApp();
    await bootstrap(ownerApp);

    const response = await ownerApp.inject({
      method: "POST",
      url: "/api/v1/auth/login",
      payload: { email: "owner@example.test", password: "not-the-password" },
    });
    expect(response.statusCode).toBe(401);
    expect(response.json()).toEqual({ error: "invalid_credentials" });
  });
  it("acknowledges an order only after commit and safely replays the same event", async () => {
    const ownerApp = createTestApp();
    const owner = (await bootstrap(ownerApp)).json();
    const payload = makeSyncEvent(
      owner.outletIds[0],
      "11111111-1111-4111-8111-111111111111",
      "evt-0123456789abcdef",
    );

    const first = await postSyncEvent(ownerApp, owner.accessToken, payload);
    expect(first.statusCode).toBe(201);
    expect(first.json().outcome).toBe("acknowledged");
    expect(first.json().serverVersion).toBe(1);

    const replay = await postSyncEvent(ownerApp, owner.accessToken, payload);
    expect(replay.statusCode).toBe(200);
    expect(replay.json()).toEqual(first.json());

    const rows = await adminPool.query(
      "SELECT payment_status, snapshot FROM orders WHERE id = $1",
      [first.json().globalOrderId],
    );
    expect(rows.rowCount).toBe(1);
    expect(rows.rows[0].payment_status).toBe("unpaid");
    expect(rows.rows[0].snapshot.paymentStatus).toBe("unpaid");
    expect(rows.rows[0].snapshot.customerName).toBeUndefined();
    const audit = await adminPool.query(
      "SELECT action, resource_type FROM audit_logs WHERE resource_id = $1",
      ["ORD-1001"],
    );
    expect(audit.rows).toContainEqual({ action: "order.created", resource_type: "order" });
  });

  it("rejects reuse of an event ID with a different payload", async () => {
    const ownerApp = createTestApp();
    const owner = (await bootstrap(ownerApp)).json();
    const payload = makeSyncEvent(
      owner.outletIds[0],
      "11111111-1111-4111-8111-111111111111",
      "evt-fedcba9876543210",
    );
    expect((await postSyncEvent(ownerApp, owner.accessToken, payload)).statusCode).toBe(201);

    const altered = makeSyncEvent(
      owner.outletIds[0],
      "11111111-1111-4111-8111-111111111111",
      "evt-fedcba9876543210",
    );
    altered.orderSnapshot.items[0]!.unitPrice = 99999;
    altered.orderSnapshot.subtotal = 99999;
    altered.orderSnapshot.total = 99999;
    const response = await postSyncEvent(ownerApp, owner.accessToken, altered);
    expect(response.statusCode).toBe(409);
    expect(response.json()).toEqual({ error: "event_id_payload_mismatch" });
  });

  it("keeps identical local order IDs from separate devices distinct", async () => {
    const ownerApp = createTestApp();
    const owner = (await bootstrap(ownerApp)).json();
    const firstPayload = makeSyncEvent(
      owner.outletIds[0],
      "11111111-1111-4111-8111-111111111111",
      "evt-device-one-000001",
    );
    const secondPayload = makeSyncEvent(
      owner.outletIds[0],
      "22222222-2222-4222-8222-222222222222",
      "evt-device-two-000002",
    );

    const first = await postSyncEvent(ownerApp, owner.accessToken, firstPayload);
    const second = await postSyncEvent(ownerApp, owner.accessToken, secondPayload);
    expect(first.statusCode).toBe(201);
    expect(second.statusCode).toBe(201);
    expect(first.json().globalOrderId).not.toBe(second.json().globalOrderId);
  });

  it("enforces outlet membership and rejects requests without authentication", async () => {
    const ownerApp = createTestApp();
    const owner = (await bootstrap(ownerApp)).json();
    const payload = makeSyncEvent(
      "33333333-3333-4333-8333-333333333333",
      "11111111-1111-4111-8111-111111111111",
      "evt-wrong-outlet-0001",
    );

    const unauthenticated = await ownerApp.inject({
      method: "POST",
      url: "/api/v1/sync/events",
      headers: { "idempotency-key": payload.eventId },
      payload,
    });
    expect(unauthenticated.statusCode).toBe(401);

    const forbidden = await postSyncEvent(ownerApp, owner.accessToken, payload);
    expect(forbidden.statusCode).toBe(403);
  });

  it("rejects stale order versions and accepts a valid versioned transition", async () => {
    const ownerApp = createTestApp();
    const owner = (await bootstrap(ownerApp)).json();
    const deviceId = "11111111-1111-4111-8111-111111111111";
    const created = makeSyncEvent(owner.outletIds[0], deviceId, "evt-order-create-0001");
    const createResponse = await postSyncEvent(ownerApp, owner.accessToken, created);
    expect(createResponse.statusCode).toBe(201);

    const stale = makeSyncEvent(
      owner.outletIds[0],
      deviceId,
      "evt-order-stale-00002",
      "order.updated",
      8,
    );
    const staleResponse = await postSyncEvent(ownerApp, owner.accessToken, stale);
    expect(staleResponse.statusCode).toBe(409);
    expect(staleResponse.json().error).toBe("stale_order_version");
    expect(staleResponse.json().serverVersion).toBe(1);
    expect(staleResponse.json().serverSnapshot.id).toBe("ORD-1001");

    const validUpdate = makeSyncEvent(
      owner.outletIds[0],
      deviceId,
      "evt-order-update-0003",
      "order.updated",
      1,
    );
    const updateResponse = await postSyncEvent(ownerApp, owner.accessToken, validUpdate);
    expect(updateResponse.statusCode).toBe(201);
    expect(updateResponse.json().serverVersion).toBe(2);
  });

  it("blocks Cashier from using owner-only order recovery through the API", async () => {
    const ownerApp = createTestApp();
    const owner = (await bootstrap(ownerApp)).json();
    const cashier = await createCashierSession(ownerApp, owner);
    const payload = makeSyncEvent(
      owner.outletIds[0],
      "11111111-1111-4111-8111-111111111111",
      "evt-cashier-recover-001",
      "order.recovered",
      1,
    );
    const response = await postSyncEvent(ownerApp, cashier.accessToken, payload);
    expect(response.statusCode).toBe(403);
    expect(response.json()).toEqual({ error: "owner_required_for_recovery" });
  });

  it("allows an owner to restore a missing local order but does not overwrite a server order", async () => {
    const ownerApp = createTestApp();
    const owner = (await bootstrap(ownerApp)).json();
    const payload = makeSyncEvent(
      owner.outletIds[0],
      "11111111-1111-4111-8111-111111111111",
      "evt-order-recovered-01",
      "order.recovered",
      1,
    );

    const response = await postSyncEvent(ownerApp, owner.accessToken, payload);
    expect(response.statusCode).toBe(201);
    expect(response.json().outcome).toBe("acknowledged");
    expect(response.json().serverVersion).toBe(1);

    const duplicate = makeSyncEvent(
      owner.outletIds[0],
      "11111111-1111-4111-8111-111111111111",
      "evt-order-recovered-02",
      "order.recovered",
      1,
    );
    const conflict = await postSyncEvent(ownerApp, owner.accessToken, duplicate);
    expect(conflict.statusCode).toBe(409);
    expect(conflict.json().error).toBe("stale_order_version");
    expect(conflict.json().serverSnapshot.id).toBe("ORD-1001");
  });

  it("restricts product writes to the owner and scopes reads to the outlet", async () => {
    const ownerApp = createTestApp();
    const owner = (await bootstrap(ownerApp)).json();
    const created = await ownerApp.inject({
      method: "POST",
      url: "/api/v1/products",
      headers: { authorization: "Bearer " + owner.accessToken },
      payload: { outletId: owner.outletIds[0], sku: "COFFEE-001", name: "Coffee", unitPrice: 12000, taxRate: 0 },
    });
    expect(created.statusCode).toBe(201);
    const list = await ownerApp.inject({
      method: "GET",
      url: "/api/v1/products?outletId=" + owner.outletIds[0],
      headers: { authorization: "Bearer " + owner.accessToken },
    });
    expect(list.statusCode).toBe(200);
    expect(list.json().products).toHaveLength(1);
    expect(list.json().products[0].name).toBe("Coffee");
    const forbidden = await ownerApp.inject({
      method: "GET",
      url: "/api/v1/products?outletId=33333333-3333-4333-8333-333333333333",
      headers: { authorization: "Bearer " + owner.accessToken },
    });
    expect(forbidden.statusCode).toBe(403);
  });

  it("database rejects unsupported operational membership roles", async () => {
    const ownerApp = createTestApp();
    const owner = (await bootstrap(ownerApp)).json();
    await expect(
      adminPool.query(
        "INSERT INTO tenant_memberships (tenant_id, user_id, role) " +
          "SELECT $1, user_id, 'staff' FROM tenant_memberships WHERE tenant_id = $1 AND role = 'owner' LIMIT 1",
        [owner.tenantId],
      ),
    ).rejects.toThrow();
  });

  it("enforces Owner-only product and inventory creation at the API boundary", async () => {
    const ownerApp = createTestApp();
    const owner = (await bootstrap(ownerApp)).json();
    const cashier = await createCashierSession(ownerApp, owner);
    const product = await ownerApp.inject({
      method: "POST",
      url: "/api/v1/products",
      headers: { authorization: "Bearer " + cashier.accessToken },
      payload: { outletId: owner.outletIds[0], sku: "CASHIER-001", name: "Forbidden Product", unitPrice: 1000, taxRate: 0 },
    });
    expect(product.statusCode).toBe(403);
    expect(product.json().error).toBe("owner_required");

    const productUpdate = await ownerApp.inject({
      method: "PATCH",
      url: "/api/v1/products/11111111-1111-4111-8111-111111111111",
      headers: { authorization: "Bearer " + cashier.accessToken },
      payload: { outletId: owner.outletIds[0], name: "Forbidden Update" },
    });
    expect(productUpdate.statusCode).toBe(403);
    expect(productUpdate.json().error).toBe("owner_required");

    const inventory = await ownerApp.inject({
      method: "POST",
      url: "/api/v1/inventory/items",
      headers: { authorization: "Bearer " + cashier.accessToken },
      payload: { outletId: owner.outletIds[0], sku: "CASHIER-STOCK", name: "Forbidden Stock", initialQuantity: 0 },
    });
    expect(inventory.statusCode).toBe(403);
    expect(inventory.json().error).toBe("owner_required");

    const ownerInventory = await ownerApp.inject({
      method: "POST",
      url: "/api/v1/inventory/items",
      headers: { authorization: "Bearer " + owner.accessToken },
      payload: { outletId: owner.outletIds[0], sku: "OWNER-STOCK", name: "Owner Stock", initialQuantity: 5 },
    });
    expect(ownerInventory.statusCode).toBe(201);
    const movement = await ownerApp.inject({
      method: "POST",
      url: "/api/v1/inventory/movements",
      headers: {
        authorization: "Bearer " + cashier.accessToken,
        "idempotency-key": "cashier-stock-move-001",
      },
      payload: {
        outletId: owner.outletIds[0],
        inventoryItemId: ownerInventory.json().id,
        movementType: "adjustment",
        quantityDelta: 1,
      },
    });
    expect(movement.statusCode).toBe(403);
    expect(movement.json().error).toBe("owner_required");
  });

  it("keeps inventory movement idempotent and prevents negative stock", async () => {
    const ownerApp = createTestApp();
    const owner = (await bootstrap(ownerApp)).json();
    const created = await ownerApp.inject({
      method: "POST",
      url: "/api/v1/inventory/items",
      headers: { authorization: "Bearer " + owner.accessToken },
      payload: {
        outletId: owner.outletIds[0], sku: "BEAN-001", name: "Coffee Beans",
        unit: "kg", initialQuantity: 5, reorderLevel: 1, averageUnitCost: 50000,
      },
    });
    expect(created.statusCode).toBe(201);
    const itemId = created.json().id;
    const payload = {
      outletId: owner.outletIds[0], inventoryItemId: itemId,
      movementType: "sale", quantityDelta: -2, unitCost: 50000,
      sourceType: "test", sourceId: "SALE-1",
    };
    const headers = {
      authorization: "Bearer " + owner.accessToken,
      "idempotency-key": "inventory-sale-0001",
    };
    const movement = await ownerApp.inject({
      method: "POST", url: "/api/v1/inventory/movements", headers, payload,
    });
    expect(movement.statusCode).toBe(201);
    expect(movement.json().quantityOnHand).toBe(3);
    const replay = await ownerApp.inject({
      method: "POST", url: "/api/v1/inventory/movements", headers, payload,
    });
    expect(replay.statusCode).toBe(200);
    expect(replay.json().replayed).toBe(true);
    const mismatch = await ownerApp.inject({
      method: "POST", url: "/api/v1/inventory/movements", headers,
      payload: { ...payload, quantityDelta: -1 },
    });
    expect(mismatch.statusCode).toBe(409);
    const oversell = await ownerApp.inject({
      method: "POST", url: "/api/v1/inventory/movements",
      headers: { ...headers, "idempotency-key": "inventory-sale-0002" },
      payload: { ...payload, quantityDelta: -10 },
    });
    expect(oversell.statusCode).toBe(409);
    expect(oversell.json().error).toBe("insufficient_stock");
  });

  it("stores order items and a cashier-reported cash payment atomically", async () => {
    const ownerApp = createTestApp();
    const owner = (await bootstrap(ownerApp)).json();
    const payload = makeSyncEvent(
      owner.outletIds[0],
      "11111111-1111-4111-8111-111111111111",
      "evt-cash-payment-0001",
    );
    payload.orderSnapshot.status = "completed";
    payload.orderSnapshot.paymentMethod = "Cash";
    payload.orderSnapshot.cashPaidAmount = 10000;
    payload.orderSnapshot.paidAt = new Date().toISOString();

    const response = await postSyncEvent(ownerApp, owner.accessToken, payload);
    expect(response.statusCode).toBe(201);
    const orderId = response.json().globalOrderId;
    const stored = await adminPool.query(
      "SELECT payment_status, status FROM orders WHERE id = $1",
      [orderId],
    );
    expect(stored.rows[0].payment_status).toBe("paid");
    expect(stored.rows[0].status).toBe("completed");
    const items = await adminPool.query(
      "SELECT count(*)::int AS count FROM order_items WHERE order_id = $1",
      [orderId],
    );
    expect(items.rows[0].count).toBe(1);
    const payments = await adminPool.query(
      "SELECT method, amount::float8 AS amount, status FROM payments WHERE order_id = $1",
      [orderId],
    );
    expect(payments.rows).toEqual([{ method: "cash", amount: 10000, status: "reported" }]);
  });

  it("records cash refunds atomically and updates fully refunded payment status", async () => {
    const ownerApp = createTestApp();
    const owner = (await bootstrap(ownerApp)).json();
    const deviceId = "11111111-1111-4111-8111-111111111111";
    const created = makeSyncEvent(owner.outletIds[0], deviceId, "evt-refund-create-0001");
    created.orderSnapshot.status = "completed";
    created.orderSnapshot.paymentMethod = "Cash";
    created.orderSnapshot.cashPaidAmount = 10000;
    created.orderSnapshot.paidAt = new Date().toISOString();
    expect((await postSyncEvent(ownerApp, owner.accessToken, created)).statusCode).toBe(201);

    const updated = makeSyncEvent(
      owner.outletIds[0], deviceId, "evt-refund-update-0002", "order.updated", 1,
    );
    updated.orderSnapshot.status = "completed";
    updated.orderSnapshot.paymentMethod = "Cash";
    updated.orderSnapshot.cashPaidAmount = 10000;
    updated.orderSnapshot.paidAt = created.orderSnapshot.paidAt;
    updated.orderSnapshot.paymentStatus = "refunded";
    updated.orderSnapshot.refundAmount = 10000;
    updated.orderSnapshot.cashRefundAmount = 10000;
    updated.orderSnapshot.refundedAt = new Date().toISOString();
    updated.orderSnapshot.refundMethod = "Cash";
    updated.orderSnapshot.refundReason = "Customer request";
    updated.orderSnapshot.refundRecords = [{
      amount: 10000, method: "Cash", reason: "Customer request",
      createdAt: updated.orderSnapshot.refundedAt,
    }];
    const response = await postSyncEvent(ownerApp, owner.accessToken, updated);
    expect(response.statusCode).toBe(201);

    const order = await adminPool.query("SELECT payment_status FROM orders WHERE id = $1", [response.json().globalOrderId]);
    expect(order.rows[0].payment_status).toBe("refunded");
    const refunds = await adminPool.query("SELECT amount::float8 AS amount, status FROM refunds WHERE order_id = $1", [response.json().globalOrderId]);
    expect(refunds.rows).toEqual([{ amount: 10000, status: "reported" }]);
    const payments = await adminPool.query("SELECT status FROM payments WHERE order_id = $1", [response.json().globalOrderId]);
    expect(payments.rows[0].status).toBe("refunded");
  });

  it("creates an open receivable for a completed BON order with customer identity", async () => {
    const ownerApp = createTestApp();
    const owner = (await bootstrap(ownerApp)).json();
    const deviceId = "11111111-1111-4111-8111-111111111111";
    const created = makeSyncEvent(owner.outletIds[0], deviceId, "evt-bon-create-0001");
    expect((await postSyncEvent(ownerApp, owner.accessToken, created)).statusCode).toBe(201);

    const preparing = makeSyncEvent(
      owner.outletIds[0], deviceId, "evt-bon-update-0002", "order.updated", 1,
    );
    preparing.orderSnapshot.status = "preparing";
    preparing.orderSnapshot.paymentStatus = "unpaid";
    preparing.orderSnapshot.paymentMethod = "BON";
    preparing.orderSnapshot.customerId = "CUSTOMER-001";
    preparing.orderSnapshot.customerName = "Customer Test";
    expect((await postSyncEvent(ownerApp, owner.accessToken, preparing)).statusCode).toBe(201);

    const ready = makeSyncEvent(
      owner.outletIds[0], deviceId, "evt-bon-update-0003", "order.updated", 2,
    );
    ready.orderSnapshot.status = "ready";
    ready.orderSnapshot.paymentStatus = "unpaid";
    ready.orderSnapshot.paymentMethod = "BON";
    ready.orderSnapshot.customerId = "CUSTOMER-001";
    ready.orderSnapshot.customerName = "Customer Test";
    expect((await postSyncEvent(ownerApp, owner.accessToken, ready)).statusCode).toBe(201);

    const served = makeSyncEvent(
      owner.outletIds[0], deviceId, "evt-bon-update-0004", "order.updated", 3,
    );
    served.orderSnapshot.status = "served";
    served.orderSnapshot.paymentStatus = "unpaid";
    served.orderSnapshot.paymentMethod = "BON";
    served.orderSnapshot.customerId = "CUSTOMER-001";
    served.orderSnapshot.customerName = "Customer Test";
    expect((await postSyncEvent(ownerApp, owner.accessToken, served)).statusCode).toBe(201);

    const updated = makeSyncEvent(
      owner.outletIds[0], deviceId, "evt-bon-update-0005", "order.updated", 4,
    );
    updated.orderSnapshot.status = "completed";
    updated.orderSnapshot.paymentStatus = "unpaid";
    updated.orderSnapshot.paymentMethod = "BON";
    updated.orderSnapshot.customerId = "CUSTOMER-001";
    updated.orderSnapshot.customerName = "Customer Test";
    const response = await postSyncEvent(ownerApp, owner.accessToken, updated);
    expect(response.statusCode).toBe(201);
    const receivable = await adminPool.query(
      "SELECT customer_id, customer_name, original_amount::float8 AS original_amount, outstanding_amount::float8 AS outstanding_amount, status " +
        "FROM accounts_receivable WHERE order_id = $1",
      [response.json().globalOrderId],
    );
    expect(receivable.rows).toEqual([{
      customer_id: "CUSTOMER-001",
      customer_name: "Customer Test",
      original_amount: 10000,
      outstanding_amount: 10000,
      status: "open",
    }]);
  });

});