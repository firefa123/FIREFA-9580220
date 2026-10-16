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
const testJwtSecret = "inventory-integration-jwt-secret-at-least-thirty-two";
const testBootstrapToken = "inventory-integration-bootstrap-token-at-least-32";

const inventorySuite = describe.skipIf(!safeTestDatabase);

inventorySuite("inventory movement endpoint", () => {
  let adminPool: Pool;
  let app: FastifyInstance | undefined;
  let accessToken = "";
  let outletId = "";
  let tenantId = "";
  let inventoryItemId = "";

  beforeAll(() => {
    adminPool = new Pool({ connectionString: testDatabaseUrl });
  });

  beforeEach(async () => {
    await adminPool.query(
      "TRUNCATE TABLE audit_logs, inventory_movements, inventory_items, products, menu_categories, " +
      "order_events, sync_receipts, orders, refresh_tokens, outlet_memberships, tenant_memberships, " +
      "users, outlets, tenants RESTART IDENTITY CASCADE",
    );
    app = buildApp({
      pool: new Pool({ connectionString: testDatabaseUrl }),
      jwtSecret: testJwtSecret,
      bootstrapToken: testBootstrapToken,
    });
    const bootstrapped = await app.inject({
      method: "POST",
      url: "/api/v1/auth/bootstrap-owner",
      headers: { "x-bootstrap-token": testBootstrapToken },
      payload: {
        tenantName: "Inventory Test Group",
        outletName: "Inventory Test Outlet",
        outletCode: "INV",
        email: "inventory-owner@example.test",
        password: "Correct-Horse-Battery-42",
        displayName: "Inventory Owner",
        latitude: -6.2,
        longitude: 106.8,
        geofenceRadiusM: 150,
      },
    });
    expect(bootstrapped.statusCode).toBe(201);
    const session = bootstrapped.json();
    accessToken = session.accessToken;
    outletId = session.outletIds[0];
    tenantId = session.tenantId;

    const created = await app.inject({
      method: "POST",
      url: "/api/v1/inventory/items",
      headers: { authorization: "Bearer " + accessToken },
      payload: {
        outletId,
        name: "Test Coffee Beans",
        unit: "gram",
        initialQuantity: 100,
        reorderLevel: 10,
        averageUnitCost: 2,
      },
    });
    expect(created.statusCode).toBe(201);
    inventoryItemId = created.json().id;
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

  function movementPayload(quantityDelta = -10) {
    return {
      outletId,
      inventoryItemId,
      movementType: quantityDelta < 0 ? "sale" : "receipt",
      quantityDelta,
      unitCost: 2,
      sourceType: "integration_test",
      sourceId: "test-source-1",
      note: "integration movement",
    };
  }

  function postMovement(key: string, quantityDelta = -10) {
    return app!.inject({
      method: "POST",
      url: "/api/v1/inventory/movements",
      headers: {
        authorization: "Bearer " + accessToken,
        "idempotency-key": key,
      },
      payload: movementPayload(quantityDelta),
    });
  }

  async function currentStock(): Promise<number> {
    const result = await adminPool.query<{ quantity_on_hand: string }>(
      "SELECT quantity_on_hand::text FROM inventory_items WHERE id = $1 AND tenant_id = $2 AND outlet_id = $3",
      [inventoryItemId, tenantId, outletId],
    );
    return Number(result.rows[0]!.quantity_on_hand);
  }

  it("applies one movement and returns the committed stock", async () => {
    const response = await postMovement("inventory-test-event-001");
    expect(response.statusCode).toBe(201);
    expect(response.json().quantityOnHand).toBe(90);
    expect(await currentStock()).toBe(90);
    const ledger = await adminPool.query(
      "SELECT id FROM inventory_movements WHERE tenant_id = $1 AND outlet_id = $2 AND idempotency_key = $3",
      [tenantId, outletId, "inventory-test-event-001"],
    );
    expect(ledger.rowCount).toBe(1);
  });

  it("replays an identical event without applying stock twice", async () => {
    const key = "inventory-test-event-002";
    const first = await postMovement(key);
    const replay = await postMovement(key);
    expect(first.statusCode).toBe(201);
    expect(replay.statusCode).toBe(200);
    expect(replay.json().replayed).toBe(true);
    expect(replay.json().id).toBe(first.json().id);
    expect(await currentStock()).toBe(90);
    const ledger = await adminPool.query(
      "SELECT count(*)::int AS count FROM inventory_movements WHERE tenant_id = $1 AND outlet_id = $2 AND idempotency_key = $3",
      [tenantId, outletId, key],
    );
    expect(ledger.rows[0]!.count).toBe(1);
  });

  it("serializes concurrent retries of the same event", async () => {
    const key = "inventory-test-event-003";
    const [first, second] = await Promise.all([postMovement(key), postMovement(key)]);
    expect([first.statusCode, second.statusCode].sort()).toEqual([200, 201]);
    expect(await currentStock()).toBe(90);
  });

  it("rejects reuse of an event key with a different payload", async () => {
    const key = "inventory-test-event-004";
    expect((await postMovement(key, -10)).statusCode).toBe(201);
    const mismatched = await postMovement(key, -11);
    expect(mismatched.statusCode).toBe(409);
    expect(mismatched.json().error).toBe("idempotency_key_payload_mismatch");
    expect(await currentStock()).toBe(90);
  });

  it("rolls back a movement that would make stock negative", async () => {
    const response = await postMovement("inventory-test-event-005", -101);
    expect(response.statusCode).toBe(409);
    expect(response.json().error).toBe("insufficient_stock");
    expect(await currentStock()).toBe(100);
    const ledger = await adminPool.query(
      "SELECT count(*)::int AS count FROM inventory_movements WHERE tenant_id = $1 AND outlet_id = $2 AND idempotency_key = $3",
      [tenantId, outletId, "inventory-test-event-005"],
    );
    expect(ledger.rows[0]!.count).toBe(0);
  });

  it("rejects a movement without a valid idempotency key", async () => {
    const response = await app!.inject({
      method: "POST",
      url: "/api/v1/inventory/movements",
      headers: { authorization: "Bearer " + accessToken },
      payload: movementPayload(),
    });
    expect(response.statusCode).toBe(400);
    expect(response.json().error).toBe("idempotency_key_required");
    expect(await currentStock()).toBe(100);
  });
});
