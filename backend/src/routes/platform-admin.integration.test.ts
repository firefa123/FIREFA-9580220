import { afterAll, beforeAll, describe, expect, it } from "vitest";
import Fastify from "fastify";
import jwt from "@fastify/jwt";
import argon2 from "argon2";
import { randomUUID } from "node:crypto";
import { Pool } from "pg";
import { platformAdminRoutes } from "./platform-admin";

const databaseUrl = process.env.TEST_DATABASE_URL;
const describeDb = databaseUrl ? describe : describe.skip;

describeDb("platform admin PostgreSQL integration", () => {
  const pool = new Pool({ connectionString: databaseUrl });
  const userId = randomUUID();
  const email = `platform-admin-${randomUUID()}@firefa.test`;
  const password = "integration-test-password-strong";
  const app = Fastify({ logger: false });
  let token = "";

  beforeAll(async () => {
    await app.register(jwt, { secret: "integration-test-jwt-secret-at-least-32-characters" });
    await app.register(platformAdminRoutes, {
      prefix: "/api/v1/platform-admin",
      pool,
      bootstrapToken: "integration-test-platform-bootstrap-token",
    });
    const passwordHash = await argon2.hash(password, { type: argon2.argon2id });
    await pool.query(
      "INSERT INTO users (id,email,password_hash,display_name) VALUES ($1,$2,$3,$4)",
      [userId,email,passwordHash,"Integration Platform Admin"],
    );
    await pool.query("INSERT INTO platform_admins (user_id) VALUES ($1)",[userId]);
  });

  afterAll(async () => {
    await app.close();
    await pool.query("DELETE FROM platform_admin_audit_logs WHERE actor_user_id=$1",[userId]);
    await pool.query("DELETE FROM platform_admins WHERE user_id=$1",[userId]);
    await pool.query("DELETE FROM users WHERE id=$1",[userId]);
    await pool.end();
  });

  it("authenticates a platform account and returns a distinct scope", async () => {
    const response = await app.inject({
      method:"POST",
      url:"/api/v1/platform-admin/auth/login",
      payload:{email,password},
    });
    expect(response.statusCode).toBe(200);
    expect(response.json().scope).toBe("platform_admin");
    token=response.json().accessToken;
  });

  it("serves real database overview only to the platform scope", async () => {
    const denied = await app.inject({method:"GET",url:"/api/v1/platform-admin/overview"});
    expect(denied.statusCode).toBe(401);
    const response = await app.inject({
      method:"GET",
      url:"/api/v1/platform-admin/overview",
      headers:{authorization:`Bearer ${token}`},
    });
    expect(response.statusCode).toBe(200);
    expect(Number.isInteger(response.json().overview.tenants_total)).toBe(true);
  });

  it("rejects tenant-owner JWT claims even if signed by the same JWT issuer", async () => {
    const ownerToken=app.jwt.sign({sub:userId,tenantId:randomUUID(),role:"owner",outletIds:[]} as never);
    const response=await app.inject({
      method:"GET",
      url:"/api/v1/platform-admin/tenants",
      headers:{authorization:`Bearer ${ownerToken}`},
    });
    expect(response.statusCode).toBe(403);
  });

  it("writes a tenant and records the platform action atomically", async () => {
    const response=await app.inject({
      method:"POST",
      url:"/api/v1/platform-admin/tenants",
      headers:{authorization:`Bearer ${token}`},
      payload:{name:`Integration tenant ${randomUUID()}`},
    });
    expect(response.statusCode).toBe(201);
    const tenantId=response.json().tenant.id as string;
    const audit=await pool.query(
      "SELECT action,resource_id FROM platform_admin_audit_logs WHERE actor_user_id=$1 AND resource_id=$2",
      [userId,tenantId],
    );
    expect(audit.rows.some((row)=>row.action==="platform_admin.tenant.create")).toBe(true);
    await pool.query("DELETE FROM platform_admin_audit_logs WHERE resource_id=$1",[tenantId]);
    await pool.query("DELETE FROM tenants WHERE id=$1",[tenantId]);
  });
});
