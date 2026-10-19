import { afterEach, describe, expect, it, vi } from "vitest";
import Fastify from "fastify";
import jwt from "@fastify/jwt";
import { platformAdminRoutes } from "./platform-admin";

const pool = {
  query: vi.fn(async (sql: string, params?: unknown[]) => {
    if (sql.includes("FROM platform_admins pa JOIN users")) {
      return { rowCount: params?.[0] === "active-admin" ? 1 : 0, rows: [] };
    }
    if (sql.includes("AS tenants_total")) {
      return { rowCount: 1, rows: [{tenants_total:2,tenants_active:1,outlets_total:3,outlets_active:2,sync_events_24h:9,audit_events_24h:4}] };
    }
    if (sql.includes("FROM tenants t")) return { rowCount: 1, rows: [{id:"tenant-a",name:"A"}] };
    if (sql.includes("FROM outlets o")) return { rowCount: 1, rows: [{id:"outlet-a",tenant_id:params?.[0] ?? "tenant-a"}] };
    if (sql.includes("FROM audit_logs")) return { rowCount: 1, rows: [{tenant_id:params?.[0] ?? "tenant-a"}] };
    if (sql.includes("FROM sync_receipts")) return { rowCount: 1, rows: [{tenant_id:params?.[0] ?? "tenant-a"}] };
    if (sql.includes("FROM sync_devices")) return { rowCount: 0, rows: [] };
    return { rowCount: 0, rows: [] };
  }),
  connect: vi.fn(),
} as any;

describe("platform admin isolation", () => {
  const apps: any[] = [];
  afterEach(async () => { await Promise.all(apps.splice(0).map((a) => a.close())); vi.clearAllMocks(); });

  async function makeApp() {
    const app = Fastify({ logger: false });
    await app.register(jwt, { secret: "test-secret-that-is-long-enough-for-ci-platform-admin" });
    await app.register(platformAdminRoutes, { prefix: "/api/v1/platform-admin", pool, bootstrapToken: "bootstrap-secret-that-is-long-enough-for-tests" });
    apps.push(app);
    return app;
  }

  it("rejects unauthenticated requests to global tenant data", async () => {
    const app = await makeApp();
    const response = await app.inject({ method: "GET", url: "/api/v1/platform-admin/tenants" });
    expect(response.statusCode).toBe(401);
  });

  it("rejects Owner/Cashier tenant tokens from platform APIs", async () => {
    const app = await makeApp();
    const token = app.jwt.sign({sub:"tenant-owner",tenantId:"tenant-a",role:"owner",outletIds:["outlet-a"]});
    const response = await app.inject({method:"GET",url:"/api/v1/platform-admin/tenants",headers:{authorization:"Bearer "+token}});
    expect(response.statusCode).toBe(403);
    expect(pool.query).not.toHaveBeenCalled();
  });

  it("requires active platform-admin membership, not just a scope claim", async () => {
    const app = await makeApp();
    const token = app.jwt.sign({sub:"disabled-admin",scope:"platform_admin"} as never);
    const response = await app.inject({method:"GET",url:"/api/v1/platform-admin/tenants",headers:{authorization:"Bearer "+token}});
    expect(response.statusCode).toBe(403);
  });

  it("does not permit tenant roles to create global tenants", async () => {
    const app = await makeApp();
    const token = app.jwt.sign({sub:"tenant-owner",tenantId:"tenant-a",role:"owner",outletIds:["outlet-a"]});
    const response = await app.inject({
      method:"POST",
      url:"/api/v1/platform-admin/tenants",
      headers:{authorization:"Bearer "+token},
      payload:{name:"Unauthorized tenant"},
    });
    expect(response.statusCode).toBe(403);
    expect(pool.connect).not.toHaveBeenCalled();
  });

  it("rejects invalid outlet geofence radius before touching the database", async () => {
    const app = await makeApp();
    const token = app.jwt.sign({sub:"active-admin",scope:"platform_admin"} as never);
    const response = await app.inject({
      method:"POST",
      url:"/api/v1/platform-admin/outlets",
      headers:{authorization:"Bearer "+token},
      payload:{
        tenantId:"11111111-1111-4111-8111-111111111111",
        code:"OUTLET-1",
        name:"Outlet Test",
        latitude:-6.2,
        longitude:106.8,
        geofenceRadiusM:2001,
      },
    });
    expect(response.statusCode).toBe(400);
    expect(pool.connect).not.toHaveBeenCalled();
  });

  it("rejects bootstrap requests without the dedicated platform secret", async () => {
    const app = await makeApp();
    const response = await app.inject({
      method:"POST",
      url:"/api/v1/platform-admin/auth/bootstrap",
      headers:{"x-platform-bootstrap-token":"wrong-secret"},
      payload:{email:"admin@example.test",password:"strong-password-123",displayName:"Admin"},
    });
    expect(response.statusCode).toBe(401);
    expect(pool.connect).not.toHaveBeenCalled();
  });

  it("returns global overview only to an active platform administrator", async () => {
    const app = await makeApp();
    const token = app.jwt.sign({sub:"active-admin",scope:"platform_admin"} as never);
    const response = await app.inject({method:"GET",url:"/api/v1/platform-admin/overview",headers:{authorization:"Bearer "+token}});
    expect(response.statusCode).toBe(200);
    expect(response.json().overview.tenants_total).toBe(2);
  });

  it("validates tenant filters and bounds global result sizes", async () => {
    const app = await makeApp();
    const token = app.jwt.sign({sub:"active-admin",scope:"platform_admin"} as never);
    const bad = await app.inject({method:"GET",url:"/api/v1/platform-admin/outlets?tenantId=not-a-uuid&limit=5000",headers:{authorization:"Bearer "+token}});
    expect(bad.statusCode).toBe(400);
    const good = await app.inject({method:"GET",url:"/api/v1/platform-admin/outlets?tenantId=11111111-1111-4111-8111-111111111111&limit=10",headers:{authorization:"Bearer "+token}});
    expect(good.statusCode).toBe(200);
    expect(pool.query).toHaveBeenCalledWith(expect.stringContaining("WHERE ($1::uuid IS NULL OR o.tenant_id=$1)"),["11111111-1111-4111-8111-111111111111",10,0]);
  });
});
