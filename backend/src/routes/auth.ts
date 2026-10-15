import { createHash, randomBytes, timingSafeEqual } from "node:crypto";
import argon2 from "argon2";
import type { FastifyPluginAsync, FastifyReply } from "fastify";
import type { Pool, PoolClient } from "pg";
import { z } from "zod";

type Role = "owner" | "cashier" | "staff";

interface Membership {
  tenant_id: string;
  role: Role;
  outlet_ids: string[];
}

interface AuthRouteOptions {
  pool: Pool;
  bootstrapToken: string;
}

const bootstrapSchema = z.object({
  tenantName: z.string().trim().min(2).max(120),
  outletName: z.string().trim().min(2).max(120),
  outletCode: z.string().trim().regex(/^[A-Za-z0-9_-]{2,32}$/),
  email: z.string().trim().email().max(254),
  password: z.string().min(12).max(128),
  displayName: z.string().trim().min(2).max(120),
  latitude: z.number().min(-90).max(90).optional(),
  longitude: z.number().min(-180).max(180).optional(),
  geofenceRadiusM: z.number().int().min(25).max(2000).default(100),
}).refine(
  (body) => (body.latitude === undefined) === (body.longitude === undefined),
  { message: "latitude and longitude must be provided together" },
);

const loginSchema = z.object({
  email: z.string().trim().email().max(254),
  password: z.string().min(1).max(128),
  tenantId: z.string().uuid().optional(),
});

const refreshSchema = z.object({
  refreshToken: z.string().min(32).max(256),
});

function safeTokenEquals(provided: string, expected: string): boolean {
  const left = Buffer.from(provided);
  const right = Buffer.from(expected);
  return left.length === right.length && timingSafeEqual(left, right);
}

function hashRefreshToken(token: string): string {
  return createHash("sha256").update(token).digest("hex");
}

async function findMembership(
  client: PoolClient,
  userId: string,
  tenantId?: string,
): Promise<Membership | undefined> {
  const result = await client.query<Membership>(
    "SELECT tm.tenant_id::text AS tenant_id, tm.role, " +
      "COALESCE(array_agg(o.id::text) FILTER (WHERE o.id IS NOT NULL), ARRAY[]::text[]) AS outlet_ids " +
      "FROM tenant_memberships tm " +
      "JOIN tenants t ON t.id = tm.tenant_id AND t.status = 'active' " +
      "LEFT JOIN outlet_memberships om ON om.user_id = tm.user_id " +
      "LEFT JOIN outlets o ON o.id = om.outlet_id AND o.tenant_id = tm.tenant_id AND o.status = 'active' " +
      "WHERE tm.user_id = $1 AND tm.status = 'active' " +
      "AND ($2::uuid IS NULL OR tm.tenant_id = $2::uuid) " +
      "GROUP BY tm.tenant_id, tm.role, tm.created_at ORDER BY tm.created_at LIMIT 1",
    [userId, tenantId ?? null],
  );

  return result.rows[0];
}

async function createRefreshToken(
  client: PoolClient,
  userId: string,
  tenantId: string,
): Promise<string> {
  const token = randomBytes(32).toString("base64url");
  const tokenHash = hashRefreshToken(token);
  const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);

  await client.query(
    "INSERT INTO refresh_tokens (user_id, tenant_id, token_hash, expires_at) VALUES ($1, $2, $3, $4)",
    [userId, tenantId, tokenHash, expiresAt],
  );

  return token;
}

function createAccessToken(
  app: Parameters<FastifyPluginAsync<AuthRouteOptions>>[0],
  userId: string,
  membership: Membership,
): string {
  return app.jwt.sign(
    {
      sub: userId,
      tenantId: membership.tenant_id,
      role: membership.role,
      outletIds: membership.outlet_ids,
    },
    { expiresIn: "15m" },
  );
}

function invalidRequest(reply: FastifyReply) {
  return reply.code(400).send({ error: "invalid_request" });
}

export const authRoutes: FastifyPluginAsync<AuthRouteOptions> = async (app, options) => {
  app.post("/bootstrap-owner", async (request, reply) => {
    const providedToken = request.headers["x-bootstrap-token"];
    if (
      typeof providedToken !== "string" ||
      !safeTokenEquals(providedToken, options.bootstrapToken)
    ) {
      return reply.code(401).send({ error: "unauthorized" });
    }

    const parsed = bootstrapSchema.safeParse(request.body);
    if (!parsed.success) return invalidRequest(reply);
    const body = parsed.data;
    const email = body.email.toLowerCase();
    const passwordHash = await argon2.hash(body.password, { type: argon2.argon2id });
    const client = await options.pool.connect();

    try {
      await client.query("BEGIN");
      await client.query("SELECT pg_advisory_xact_lock($1)", [81726354]);

      const existingUser = await client.query("SELECT 1 FROM users LIMIT 1");
      if (existingUser.rowCount) {
        await client.query("ROLLBACK");
        return reply.code(409).send({ error: "bootstrap_already_completed" });
      }

      const tenantResult = await client.query<{ id: string }>(
        "INSERT INTO tenants (name) VALUES ($1) RETURNING id::text AS id",
        [body.tenantName],
      );
      const tenantId = tenantResult.rows[0]!.id;

      const outletResult = await client.query<{ id: string }>(
        "INSERT INTO outlets (tenant_id, code, name, latitude, longitude, geofence_radius_m) " +
          "VALUES ($1, $2, $3, $4, $5, $6) RETURNING id::text AS id",
        [
          tenantId,
          body.outletCode,
          body.outletName,
          body.latitude ?? null,
          body.longitude ?? null,
          body.geofenceRadiusM,
        ],
      );
      const outletId = outletResult.rows[0]!.id;

      const userResult = await client.query<{ id: string }>(
        "INSERT INTO users (email, password_hash, display_name) VALUES ($1, $2, $3) " +
          "RETURNING id::text AS id",
        [email, passwordHash, body.displayName],
      );
      const userId = userResult.rows[0]!.id;

      await client.query(
        "INSERT INTO tenant_memberships (tenant_id, user_id, role) VALUES ($1, $2, 'owner')",
        [tenantId, userId],
      );
      await client.query(
        "INSERT INTO outlet_memberships (outlet_id, user_id) VALUES ($1, $2)",
        [outletId, userId],
      );

      const membership: Membership = {
        tenant_id: tenantId,
        role: "owner",
        outlet_ids: [outletId],
      };
      const refreshToken = await createRefreshToken(client, userId, tenantId);
      const accessToken = createAccessToken(app, userId, membership);
      await client.query("COMMIT");

      return reply.code(201).send({
        accessToken,
        refreshToken,
        expiresIn: 900,
        user: { id: userId, email, displayName: body.displayName },
        tenantId,
        role: membership.role,
        outletIds: membership.outlet_ids,
      });
    } catch (error) {
      await client.query("ROLLBACK").catch(() => undefined);
      app.log.error({ err: error }, "Owner bootstrap failed");
      return reply.code(500).send({ error: "internal_error" });
    } finally {
      client.release();
    }
  });

  app.post("/login", async (request, reply) => {
    const parsed = loginSchema.safeParse(request.body);
    if (!parsed.success) return invalidRequest(reply);

    const client = await options.pool.connect();
    try {
      const userResult = await client.query<{
        id: string;
        email: string;
        display_name: string;
        password_hash: string;
        status: string;
      }>(
        "SELECT id::text AS id, email, display_name, password_hash, status " +
          "FROM users WHERE lower(email) = lower($1) LIMIT 1",
        [parsed.data.email],
      );
      const user = userResult.rows[0];

      if (
        !user ||
        user.status !== "active" ||
        !(await argon2.verify(user.password_hash, parsed.data.password).catch(() => false))
      ) {
        return reply.code(401).send({ error: "invalid_credentials" });
      }

      const membership = await findMembership(client, user.id, parsed.data.tenantId);
      if (!membership) return reply.code(401).send({ error: "invalid_credentials" });

      await client.query("BEGIN");
      const refreshToken = await createRefreshToken(client, user.id, membership.tenant_id);
      const accessToken = createAccessToken(app, user.id, membership);
      await client.query("COMMIT");

      return reply.code(200).send({
        accessToken,
        refreshToken,
        expiresIn: 900,
        user: { id: user.id, email: user.email, displayName: user.display_name },
        tenantId: membership.tenant_id,
        role: membership.role,
        outletIds: membership.outlet_ids,
      });
    } catch (error) {
      await client.query("ROLLBACK").catch(() => undefined);
      app.log.error({ err: error }, "Login failed");
      return reply.code(500).send({ error: "internal_error" });
    } finally {
      client.release();
    }
  });

  app.post("/refresh", async (request, reply) => {
    const parsed = refreshSchema.safeParse(request.body);
    if (!parsed.success) return invalidRequest(reply);

    const client = await options.pool.connect();
    try {
      await client.query("BEGIN");
      const tokenHash = hashRefreshToken(parsed.data.refreshToken);
      const tokenResult = await client.query<{
        user_id: string;
        tenant_id: string;
        email: string;
        display_name: string;
        status: string;
      }>(
        "SELECT rt.user_id::text AS user_id, rt.tenant_id::text AS tenant_id, " +
          "u.email, u.display_name, u.status " +
          "FROM refresh_tokens rt JOIN users u ON u.id = rt.user_id " +
          "WHERE rt.token_hash = $1 AND rt.revoked_at IS NULL AND rt.expires_at > now() " +
          "FOR UPDATE OF rt",
        [tokenHash],
      );
      const tokenRow = tokenResult.rows[0];

      if (!tokenRow || tokenRow.status !== "active") {
        await client.query("ROLLBACK");
        return reply.code(401).send({ error: "invalid_refresh_token" });
      }

      const membership = await findMembership(client, tokenRow.user_id, tokenRow.tenant_id);
      if (!membership) {
        await client.query(
          "UPDATE refresh_tokens SET revoked_at = now() WHERE token_hash = $1",
          [tokenHash],
        );
        await client.query("COMMIT");
        return reply.code(401).send({ error: "invalid_refresh_token" });
      }

      await client.query(
        "UPDATE refresh_tokens SET revoked_at = now() WHERE token_hash = $1",
        [tokenHash],
      );
      const refreshToken = await createRefreshToken(client, tokenRow.user_id, tokenRow.tenant_id);
      const accessToken = createAccessToken(app, tokenRow.user_id, membership);
      await client.query("COMMIT");

      return reply.code(200).send({
        accessToken,
        refreshToken,
        expiresIn: 900,
        user: {
          id: tokenRow.user_id,
          email: tokenRow.email,
          displayName: tokenRow.display_name,
        },
        tenantId: membership.tenant_id,
        role: membership.role,
        outletIds: membership.outlet_ids,
      });
    } catch (error) {
      await client.query("ROLLBACK").catch(() => undefined);
      app.log.error({ err: error }, "Token refresh failed");
      return reply.code(500).send({ error: "internal_error" });
    } finally {
      client.release();
    }
  });

  app.post("/logout", async (request, reply) => {
    const parsed = refreshSchema.safeParse(request.body);
    if (!parsed.success) return invalidRequest(reply);

    await options.pool.query(
      "UPDATE refresh_tokens SET revoked_at = now() " +
        "WHERE token_hash = $1 AND revoked_at IS NULL",
      [hashRefreshToken(parsed.data.refreshToken)],
    );
    return reply.code(204).send();
  });

  app.get("/me", {
    preHandler: async (request, reply) => {
      try {
        await request.jwtVerify();
      } catch {
        return reply.code(401).send({ error: "unauthorized" });
      }
    },
  }, async (request, reply) => {
    const client = await options.pool.connect();
    try {
      const userResult = await client.query<{
        id: string;
        email: string;
        display_name: string;
        status: string;
      }>(
        "SELECT id::text AS id, email, display_name, status FROM users WHERE id = $1 LIMIT 1",
        [request.user.sub],
      );
      const user = userResult.rows[0];
      if (!user || user.status !== "active") {
        return reply.code(401).send({ error: "unauthorized" });
      }

      const membership = await findMembership(
        client,
        request.user.sub,
        request.user.tenantId,
      );
      if (!membership) return reply.code(403).send({ error: "membership_inactive" });

      return {
        user: { id: user.id, email: user.email, displayName: user.display_name },
        tenantId: membership.tenant_id,
        role: membership.role,
        outletIds: membership.outlet_ids,
      };
    } finally {
      client.release();
    }
  });
};