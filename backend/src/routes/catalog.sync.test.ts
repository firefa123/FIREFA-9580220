import Fastify, { type FastifyInstance } from "fastify";
import jwt from "@fastify/jwt";
import type { Pool, PoolClient } from "pg";
import { afterEach, describe, expect, it, vi } from "vitest";

import { catalogRoutes } from "./catalog.js";

const tenantId = "2b6b7b60-8b90-4a56-92b0-9b6e0d1f3a10";
const outletId = "8b86c49a-fac8-4bd0-a6c5-f3d850b9a15f";
const userId = "f9d1a6b0-4c47-4b82-85e6-1d9e6e0d11f1";
const deviceId = "7a2aeb3a-4b76-4e51-8c51-3cb4f8a4c2d0";
const orderId = "c02d0b52-b79d-43d2-91bc-fcd39d5bbd7b";
const itemId = "2c6b2c3a-17a2-41e2-8e42-8b3fdcb55ad7";

type Options = {
  role?: string;
  orderStatus?: string;
  priorBusiness?: { id: string; quantity_delta: string; movement_type: string } | null;
  priorSale?: { quantity_delta: string } | null;
};

function makePool(options: Options = {}) {
  const clientQuery = vi.fn(async (sql: string, _values?: unknown[]) => {
    if (sql.includes("SELECT tm.role FROM tenant_memberships")) {
      return { rows: [{ role: options.role ?? "cashier" }], rowCount: 1 };
    }
    if (sql.includes("SELECT status FROM orders WHERE id = $1")) {
      return { rows: [{ status: options.orderStatus ?? "confirmed" }], rowCount: 1 };
    }
    if (sql.includes("SELECT id::text AS id, inventory_item_id::text AS inventory_item_id")) {
      return { rows: [], rowCount: 0 };
    }
    if (sql.includes("SELECT id::text AS id, quantity_delta::text, movement_type FROM inventory_movements")) {
      return {
        rows: options.priorBusiness ? [options.priorBusiness] : [],
        rowCount: options.priorBusiness ? 1 : 0,
      };
    }
    if (sql.includes("SELECT quantity_delta::text FROM inventory_movements")) {
      return {
        rows: options.priorSale ? [options.priorSale] : [],
        rowCount: options.priorSale ? 1 : 0,
      };
    }
    if (sql.startsWith("UPDATE inventory_items SET quantity_on_hand")) {
      return { rows: [{ id: itemId, quantity_on_hand: "8" }], rowCount: 1 };
    }
    if (sql.includes("INSERT INTO inventory_movements")) {
      return { rows: [{ id: "e5a7d8e4-3f0f-4a93-96e0-1e3a22a7cabc" }], rowCount: 1 };
    }
    return { rows: [], rowCount: 0 };
  });
  const client = {
    query: clientQuery,
    release: vi.fn(),
  };
  const poolQuery = vi.fn(async () => ({
    rows: [{ quantity_on_hand: "8" }],
    rowCount: 1,
  }));
  const pool = {
    connect: vi.fn(async () => client),
    query: poolQuery,
  } as unknown as Pool;
  return { pool, clientQuery, poolQuery };
}

async function makeApp(pool: Pool): Promise<FastifyInstance> {
  const app = Fastify();
  await app.register(jwt, { secret: "offline-sync-test-secret" });
  await app.register(catalogRoutes, { prefix: "/api/v1", pool });
  await app.ready();
  return app;
}

function salePayload(idempotencyKey: string) {
  return {
    outletId,
    inventoryItemId: itemId,
    deviceId,
    movementType: "sale",
    quantityDelta: -2,
    unitCost: 100,
    sourceType: "pos_order",
    sourceId: orderId,
    note: "POS order ORD-1001",
    idempotencyKey,
  };
}

async function postMovement(
  app: FastifyInstance,
  payload: Record<string, unknown>,
  idempotencyKey: string,
) {
  const token = app.jwt.sign({ sub: userId, tenantId, role: 'cashier', outletIds: [outletId] });
  return app.inject({
    method: "POST",
    url: "/api/v1/inventory/movements",
    headers: {
      authorization: `Bearer ${token}`,
      "idempotency-key": idempotencyKey,
    },
    payload,
  });
}

describe("cashier POS inventory sync", () => {
  let app: FastifyInstance | undefined;

  afterEach(async () => {
    if (app) await app.close();
    app = undefined;
  });

  it("accepts an authenticated cashier POS sale linked to its synced order", async () => {
    const mocks = makePool();
    app = await makeApp(mocks.pool);
    const key = "inventory:device:movement-1";
    const response = await postMovement(app, salePayload(key), key);

    expect(response.statusCode).toBe(201);
    expect(response.json()).toMatchObject({
      eventId: key,
      outletId,
      inventoryItemId: itemId,
      quantityOnHand: 8,
    });
    const insert = mocks.clientQuery.mock.calls.find(([sql]) =>
      sql.includes("INSERT INTO inventory_movements"),
    );
    expect(insert?.[1]?.[6]).toBe("order");
    expect(insert?.[1]?.[7]).toBe(orderId);
    expect(mocks.clientQuery.mock.calls.some(([sql]) =>
      sql.startsWith("UPDATE inventory_items SET quantity_on_hand"),
    )).toBe(true);
  });

  it("does not deduct stock twice when order completion already wrote the sale", async () => {
    const mocks = makePool({
      priorBusiness: {
        id: "7d2dfb7e-9b3f-46a1-8f45-5f19a7cb8a3e",
        quantity_delta: "-2",
        movement_type: "sale",
      },
    });
    app = await makeApp(mocks.pool);
    const key = "inventory:device:movement-replay";
    const response = await postMovement(app, salePayload(key), key);

    expect(response.statusCode).toBe(200);
    expect(response.json()).toMatchObject({
      eventId: key,
      replayed: true,
      quantityOnHand: 8,
    });
    expect(mocks.clientQuery.mock.calls.some(([sql]) =>
      sql.startsWith("UPDATE inventory_items SET quantity_on_hand"),
    )).toBe(false);
  });

  it("rejects cashier adjustments that are not linked to a POS order", async () => {
    const mocks = makePool();
    app = await makeApp(mocks.pool);
    const key = "inventory:device:forbidden-adjustment";
    const response = await postMovement(app, {
      outletId, inventoryItemId: itemId, movementType: "adjustment",
      quantityDelta: -1, unitCost: 0, sourceType: "firefa_local_movement",
      sourceId: "movement-1", note: "manual adjustment",
    }, key);

    expect(response.statusCode).toBe(403);
    expect(mocks.clientQuery.mock.calls.some(([sql]) =>
      sql.startsWith("UPDATE inventory_items SET quantity_on_hand"),
    )).toBe(false);
  });

  it("rejects a different sale delta for an already-recorded order/item", async () => {
    const mocks = makePool({
      priorBusiness: {
        id: "7d2dfb7e-9b3f-46a1-8f45-5f19a7cb8a3e",
        quantity_delta: "-3",
        movement_type: "sale",
      },
    });
    app = await makeApp(mocks.pool);
    const key = "inventory:device:mismatched-order-delta";
    const response = await postMovement(app, salePayload(key), key);

    expect(response.statusCode).toBe(409);
    expect(response.json()).toMatchObject({ error: "pos_inventory_delta_mismatch" });
    expect(mocks.clientQuery.mock.calls.some(([sql]) =>
      sql.startsWith("UPDATE inventory_items SET quantity_on_hand"),
    )).toBe(false);
  });

  it("rejects a POS sale when the linked server order is cancelled", async () => {
    const mocks = makePool({ orderStatus: "cancelled" });
    app = await makeApp(mocks.pool);
    const key = "inventory:device:cancelled-order";
    const response = await postMovement(app, salePayload(key), key);

    expect(response.statusCode).toBe(409);
    expect(response.json()).toMatchObject({ error: "pos_order_cancelled" });
    expect(mocks.clientQuery.mock.calls.some(([sql]) =>
      sql.startsWith("UPDATE inventory_items SET quantity_on_hand"),
    )).toBe(false);
  });

  it("reverses only an existing sale after the order is cancelled", async () => {
    const mocks = makePool({
      orderStatus: "cancelled",
      priorSale: { quantity_delta: "-2" },
    });
    app = await makeApp(mocks.pool);
    const key = "inventory:device:reversal";
    const response = await postMovement(app, {
      outletId, inventoryItemId: itemId, deviceId,
      movementType: "receipt", quantityDelta: 2, unitCost: 100,
      sourceType: "pos_order_reversal", sourceId: orderId,
      note: "Pembatalan POS order ORD-1001",
    }, key);

    expect(response.statusCode).toBe(201);
    expect(mocks.clientQuery.mock.calls.some(([sql]) =>
      sql.startsWith("UPDATE inventory_items SET quantity_on_hand"),
    )).toBe(true);
  });
});
