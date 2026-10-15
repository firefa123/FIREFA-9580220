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
});