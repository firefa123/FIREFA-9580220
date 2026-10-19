import { timingSafeEqual } from "node:crypto";
import argon2 from "argon2";
import type { FastifyPluginAsync } from "fastify";
import type { Pool } from "pg";
import { z } from "zod";

interface Options { pool: Pool; bootstrapToken: string; }
const credentials = z.object({
  email: z.string().trim().email().max(254),
  password: z.string().min(12).max(128),
  displayName: z.string().trim().min(2).max(120).optional(),
});
function tokenMatches(provided: string, expected: string): boolean {
  const a = Buffer.from(provided); const b = Buffer.from(expected);
  return a.length === b.length && timingSafeEqual(a, b);
}
async function authorize(app: any, request: any, reply: any, pool: Pool) {
  try { await request.jwtVerify(); } catch { return reply.code(401).send({ error: "unauthorized" }); }
  if (request.user?.scope !== "platform_admin" || typeof request.user?.sub !== "string") {
    return reply.code(403).send({ error: "platform_admin_required" });
  }
  const result = await pool.query(
    "SELECT 1 FROM platform_admins pa JOIN users u ON u.id = pa.user_id WHERE pa.user_id = $1 AND pa.status = 'active' AND u.status = 'active'",
    [request.user.sub],
  );
  if (!result.rowCount) return reply.code(403).send({ error: "platform_admin_inactive" });
}
export const platformAdminRoutes: FastifyPluginAsync<Options> = async (app, options) => {
  const guard = (request: any, reply: any) => authorize(app, request, reply, options.pool);
  app.post("/auth/bootstrap", async (request, reply) => {
    const provided = request.headers["x-platform-bootstrap-token"];
    if (typeof provided !== "string" || !tokenMatches(provided, options.bootstrapToken)) {
      return reply.code(401).send({ error: "unauthorized" });
    }
    const parsed = credentials.safeParse(request.body);
    if (!parsed.success) return reply.code(400).send({ error: "invalid_request" });
    const email = parsed.data.email.toLowerCase();
    const hash = await argon2.hash(parsed.data.password, { type: argon2.argon2id });
    const client = await options.pool.connect();
    try {
      await client.query("BEGIN");
      await client.query("SELECT pg_advisory_xact_lock($1)", [81726355]);
      const existing = await client.query("SELECT 1 FROM platform_admins LIMIT 1");
      if (existing.rowCount) { await client.query("ROLLBACK"); return reply.code(409).send({ error: "platform_bootstrap_completed" }); }
      const user = await client.query<{id:string}>(
        "INSERT INTO users (email, password_hash, display_name) VALUES ($1,$2,$3) RETURNING id::text AS id",
        [email, hash, parsed.data.displayName ?? email],
      );
      await client.query("INSERT INTO platform_admins (user_id) VALUES ($1)", [user.rows[0]!.id]);
      await client.query("COMMIT");
      return reply.code(201).send({ id: user.rows[0]!.id, email, status: "active" });
    } catch (error) {
      await client.query("ROLLBACK").catch(() => undefined);
      if ((error as {code?:string}).code === "23505") return reply.code(409).send({error:"email_already_exists"});
      app.log.error({err:error}, "Platform admin bootstrap failed");
      return reply.code(500).send({error:"internal_error"});
    } finally { client.release(); }
  });
  app.post("/auth/login", async (request, reply) => {
    const parsed = z.object({email:z.string().trim().email().max(254),password:z.string().min(1).max(128)}).safeParse(request.body);
    if (!parsed.success) return reply.code(400).send({error:"invalid_request"});
    const result = await options.pool.query<{id:string;email:string;display_name:string;password_hash:string}>(
      "SELECT u.id::text AS id,u.email,u.display_name,u.password_hash FROM users u JOIN platform_admins pa ON pa.user_id=u.id WHERE lower(u.email)=lower($1) AND u.status='active' AND pa.status='active' LIMIT 1",
      [parsed.data.email],
    );
    const user = result.rows[0];
    if (!user || !(await argon2.verify(user.password_hash, parsed.data.password).catch(()=>false))) {
      return reply.code(401).send({error:"invalid_credentials"});
    }
    const accessToken = app.jwt.sign({ sub:user.id, scope:"platform_admin" } as never, {expiresIn:"15m"});
    return reply.code(200).send({accessToken,expiresIn:900,user:{id:user.id,email:user.email,displayName:user.display_name},scope:"platform_admin"});
  });
  app.get("/overview", { preHandler: guard }, async () => {
    const result = await options.pool.query(
      "SELECT (SELECT count(*)::int FROM tenants) AS tenants_total, (SELECT count(*)::int FROM tenants WHERE status='active') AS tenants_active, (SELECT count(*)::int FROM outlets) AS outlets_total, (SELECT count(*)::int FROM outlets WHERE status='active') AS outlets_active, (SELECT count(*)::int FROM sync_receipts WHERE created_at >= now()-interval '24 hours') AS sync_events_24h, (SELECT count(*)::int FROM audit_logs WHERE created_at >= now()-interval '24 hours') AS audit_events_24h"
    );
    return {overview:result.rows[0]};
  });
  app.get("/tenants", { preHandler: guard }, async (request) => {
    const q = z.object({limit:z.coerce.number().int().min(1).max(100).default(50),offset:z.coerce.number().int().min(0).max(100000).default(0)}).parse(request.query);
    const rows = await options.pool.query("SELECT t.id::text AS id,t.name,t.status,t.created_at,(SELECT count(*)::int FROM outlets o WHERE o.tenant_id=t.id) AS outlet_count FROM tenants t ORDER BY t.created_at DESC LIMIT $1 OFFSET $2",[q.limit,q.offset]);
    return {tenants:rows.rows,limit:q.limit,offset:q.offset};
  });
  app.get("/outlets", { preHandler: guard }, async (request) => {
    const q = z.object({tenantId:z.string().uuid().optional(),limit:z.coerce.number().int().min(1).max(100).default(50),offset:z.coerce.number().int().min(0).max(100000).default(0)}).parse(request.query);
    const rows = await options.pool.query("SELECT o.id::text AS id,o.tenant_id::text AS tenant_id,t.name AS tenant_name,o.code,o.name,o.status,o.latitude::float8 AS latitude,o.longitude::float8 AS longitude,o.geofence_radius_m,o.created_at FROM outlets o JOIN tenants t ON t.id=o.tenant_id WHERE ($1::uuid IS NULL OR o.tenant_id=$1) ORDER BY o.created_at DESC LIMIT $2 OFFSET $3",[q.tenantId ?? null,q.limit,q.offset]);
    return {outlets:rows.rows,limit:q.limit,offset:q.offset};
  });
  app.get("/audit-logs", { preHandler: guard }, async (request) => {
    const q = z.object({tenantId:z.string().uuid().optional(),limit:z.coerce.number().int().min(1).max(100).default(50),offset:z.coerce.number().int().min(0).max(100000).default(0)}).parse(request.query);
    const rows = await options.pool.query("SELECT id::text AS id,tenant_id::text AS tenant_id,outlet_id::text AS outlet_id,actor_user_id::text AS actor_user_id,action,resource_type,resource_id,changes,created_at FROM audit_logs WHERE ($1::uuid IS NULL OR tenant_id=$1) ORDER BY created_at DESC LIMIT $2 OFFSET $3",[q.tenantId ?? null,q.limit,q.offset]);
    return {auditLogs:rows.rows,limit:q.limit,offset:q.offset};
  });
  app.get("/sync-status", { preHandler: guard }, async (request) => {
    const q = z.object({tenantId:z.string().uuid().optional(),limit:z.coerce.number().int().min(1).max(100).default(50)}).parse(request.query);
    const [receipts,devices] = await Promise.all([
      options.pool.query("SELECT tenant_id::text AS tenant_id,count(*)::int AS events,count(*) FILTER (WHERE created_at >= now()-interval '1 hour')::int AS events_last_hour,max(created_at) AS last_event_at FROM sync_receipts WHERE ($1::uuid IS NULL OR tenant_id=$1) GROUP BY tenant_id ORDER BY max(created_at) DESC LIMIT $2",[q.tenantId ?? null,q.limit]),
      options.pool.query("SELECT tenant_id::text AS tenant_id,count(*)::int AS registered_devices FROM sync_devices WHERE ($1::uuid IS NULL OR tenant_id=$1) GROUP BY tenant_id LIMIT $2",[q.tenantId ?? null,q.limit])
    ]);
    return {syncStatus:receipts.rows,devices:devices.rows,asOf:new Date().toISOString()};
  });
};
