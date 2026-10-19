import type { FastifyPluginAsync, FastifyReply } from "fastify";
import type { Pool, PoolClient } from "pg";
import { z } from "zod";

interface OutletLocationOptions {
  pool: Pool;
}

const uuid = z.string().uuid();
const locationInput = z.object({
  outletId: uuid,
  latitude: z.number().finite().min(-90).max(90),
  longitude: z.number().finite().min(-180).max(180),
});

function invalid(reply: FastifyReply) {
  return reply.code(400).send({ error: "invalid_request" });
}

async function outletRole(client: PoolClient, userId: string, tenantId: string, outletId: string) {
  const result = await client.query<{ role: string }>(
    "SELECT tm.role FROM tenant_memberships tm " +
    "JOIN tenants t ON t.id = tm.tenant_id AND t.status = 'active' " +
    "JOIN users u ON u.id = tm.user_id AND u.status = 'active' " +
    "JOIN outlet_memberships om ON om.tenant_id = tm.tenant_id AND om.user_id = tm.user_id " +
    "JOIN outlets o ON o.id = om.outlet_id AND o.tenant_id = tm.tenant_id AND o.status = 'active' " +
    "WHERE tm.user_id = $1 AND tm.tenant_id = $2 AND tm.status = 'active' AND om.outlet_id = $3",
    [userId, tenantId, outletId],
  );
  return result.rows[0]?.role;
}

export const outletLocationRoutes: FastifyPluginAsync<OutletLocationOptions> = async (app, options) => {
  // Only an authenticated Owner may update the outlet's geofence center.
  // This update deliberately never writes geofence_radius_m.
  app.patch("/staff/geofence-location", {
    preHandler: async (request, reply) => {
      try {
        await request.jwtVerify();
      } catch {
        return reply.code(401).send({ error: "unauthorized" });
      }
    },
  }, async (request, reply) => {
    if (request.user.role !== "owner") {
      return reply.code(403).send({ error: "owner_required" });
    }

    const parsed = locationInput.safeParse(request.body);
    if (!parsed.success) return invalid(reply);

    const input = parsed.data;
    const client = await options.pool.connect();
    try {
      const role = await outletRole(client, request.user.sub, request.user.tenantId, input.outletId);
      if (role !== "owner") {
        return reply.code(403).send({
          error: role ? "owner_required" : "outlet_forbidden",
        });
      }

      const result = await client.query(
        "UPDATE outlets SET latitude = $1, longitude = $2, updated_at = now() " +
        "WHERE id = $3 AND tenant_id = $4 AND status = 'active' " +
        "RETURNING id::text AS \"outletId\", latitude::float8 AS latitude, " +
        "longitude::float8 AS longitude, geofence_radius_m AS \"radiusMeters\"",
        [input.latitude, input.longitude, input.outletId, request.user.tenantId],
      );
      if (!result.rowCount) return reply.code(404).send({ error: "outlet_not_found" });
      return { geofence: result.rows[0] };
    } finally {
      client.release();
    }
  });
};
