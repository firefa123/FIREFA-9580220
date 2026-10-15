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
        customerName: "must-not-be-synced",
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

});