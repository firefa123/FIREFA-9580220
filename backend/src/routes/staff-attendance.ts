import argon2 from "argon2";
import type { FastifyPluginAsync, FastifyReply } from "fastify";
import type { Pool, PoolClient } from "pg";
import { z } from "zod";
import { distanceMeters, lateMinutes, localWorkDate } from "./staff-attendance-utils";

interface StaffAttendanceOptions { pool: Pool; }
const uuid = z.string().uuid();
const coordinates = z.object({
  latitude: z.number().finite().min(-90).max(90),
  longitude: z.number().finite().min(-180).max(180),
});
const createStaffInput = z.object({
  outletId: uuid,
  staffCode: z.string().trim().min(2).max(32).regex(/^[A-Za-z0-9_-]+$/),
  displayName: z.string().trim().min(2).max(120),
  pin: z.string().regex(/^\d{6}$/),
  expectedStartTime: z.string().regex(/^(?:[01]\d|2[0-3]):[0-5]\d$/).nullable().optional(),
});
const updateStaffInput = z.object({
  outletId: uuid,
  displayName: z.string().trim().min(2).max(120).optional(),
  pin: z.string().regex(/^\d{6}$/).optional(),
  expectedStartTime: z.string().regex(/^(?:[01]\d|2[0-3]):[0-5]\d$/).nullable().optional(),
  status: z.enum(["active", "inactive"]).optional(),
});
const radiusInput = z.object({
  outletId: uuid,
  radiusMeters: z.number().int().min(25).max(2000),
});
const staffLoginInput = z.object({
  outletId: uuid,
  staffCode: z.string().trim().min(2).max(32),
  pin: z.string().regex(/^\d{6}$/),
});
const attendanceInput = z.object({ outletId: uuid, ...coordinates.shape });

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

async function authorizeOwnerOutlet(
  client: PoolClient, userId: string, tenantId: string, outletId: string,
): Promise<"ok" | "forbidden" | "owner_required"> {
  const role = await outletRole(client, userId, tenantId, outletId);
  if (!role) return "forbidden";
  return role === "owner" ? "ok" : "owner_required";
}

async function getOutlet(client: PoolClient, tenantId: string, outletId: string) {
  const result = await client.query<{
    id: string; latitude: number | null; longitude: number | null;
    geofence_radius_m: number; timezone: string;
  }>(
    "SELECT id::text AS id, latitude::float8 AS latitude, longitude::float8 AS longitude, " +
    "geofence_radius_m, timezone FROM outlets WHERE id = $1 AND tenant_id = $2 AND status = 'active'",
    [outletId, tenantId],
  );
  return result.rows[0];
}

function requestStaffRole(request: { user: { role: string; outletIds: string[]; tenantId: string; sub: string } }, outletId: string) {
  return request.user.role === "staff" &&
    request.user.outletIds.includes(outletId) &&
    uuid.safeParse(request.user.tenantId).success;
}

export const staffAttendanceRoutes: FastifyPluginAsync<StaffAttendanceOptions> = async (app, options) => {
  // Staff identities are separate from Owner/Kasir tenant memberships.
  app.post("/staff/login", async (request, reply) => {
    const parsed = staffLoginInput.safeParse(request.body);
    if (!parsed.success) return invalid(reply);
    const client = await options.pool.connect();
    try {
      const result = await client.query<{
        id: string; tenant_id: string; outlet_id: string; display_name: string; pin_hash: string; pin_failed_attempts: number; pin_locked_until: Date | null;
      }>(
        "SELECT sm.id::text AS id, sm.tenant_id::text AS tenant_id, sm.outlet_id::text AS outlet_id, " +
        "sm.display_name, sm.pin_hash, sm.pin_failed_attempts, sm.pin_locked_until FROM staff_members sm JOIN tenants t ON t.id = sm.tenant_id " +
        "JOIN outlets o ON o.id = sm.outlet_id AND o.tenant_id = sm.tenant_id " +
        "WHERE sm.outlet_id = $1 AND sm.staff_code = $2 AND sm.status = 'active' " +
        "AND t.status = 'active' AND o.status = 'active' LIMIT 1",
        [parsed.data.outletId, parsed.data.staffCode],
      );
      const staff = result.rows[0];
      if (!staff || (staff.pin_locked_until && new Date(staff.pin_locked_until).getTime() > Date.now())) {
        return reply.code(staff ? 429 : 401).send({ error: staff ? "login_temporarily_locked" : "invalid_credentials" });
      }
      if (!(await argon2.verify(staff.pin_hash, parsed.data.pin).catch(() => false))) {
        await client.query(
          "UPDATE staff_members SET pin_failed_attempts = LEAST(pin_failed_attempts + 1, 5), " +
          "pin_locked_until = CASE WHEN pin_failed_attempts + 1 >= 5 THEN now() + interval '15 minutes' ELSE pin_locked_until END " +
          "WHERE id = $1",
          [staff.id],
        );
        return reply.code(401).send({ error: "invalid_credentials" });
      }
      await client.query("UPDATE staff_members SET pin_failed_attempts = 0, pin_locked_until = NULL WHERE id = $1", [staff.id]);
      const outletIds = [staff.outlet_id];
      const accessToken = app.jwt.sign({
        sub: staff.id, tenantId: staff.tenant_id, role: "staff", outletIds,
      }, { expiresIn: "12h" });
      return reply.code(200).send({
        accessToken, expiresIn: 43200,
        staff: { id: staff.id, displayName: staff.display_name, outletId: staff.outlet_id },
      });
    } finally { client.release(); }
  });

  app.get("/staff", {
    preHandler: async (request, reply) => {
      try { await request.jwtVerify(); } catch { return reply.code(401).send({ error: "unauthorized" }); }
    },
  }, async (request, reply) => {
    if (request.user.role !== "owner" && request.user.role !== "cashier") {
      return reply.code(403).send({ error: "owner_or_cashier_required" });
    }
    const parsed = uuid.safeParse((request.query as { outletId?: string }).outletId);
    if (!parsed.success) return invalid(reply);
    const client = await options.pool.connect();
    try {
      const role = await outletRole(client, request.user.sub, request.user.tenantId, parsed.data);
      if (!role) return reply.code(403).send({ error: "outlet_forbidden" });
      const result = await client.query(
        "SELECT id::text AS id, staff_code AS \"staffCode\", display_name AS \"displayName\", " +
        "expected_start_time::text AS \"expectedStartTime\", status, created_at AS \"createdAt\" " +
        "FROM staff_members WHERE tenant_id = $1 AND outlet_id = $2 ORDER BY display_name",
        [request.user.tenantId, parsed.data],
      );
      return { staff: result.rows };
    } finally { client.release(); }
  });

  app.post("/staff", {
    preHandler: async (request, reply) => {
      try { await request.jwtVerify(); } catch { return reply.code(401).send({ error: "unauthorized" }); }
    },
  }, async (request, reply) => {
    if (request.user.role !== "owner") return reply.code(403).send({ error: "owner_required" });
    const parsed = createStaffInput.safeParse(request.body);
    if (!parsed.success) return invalid(reply);
    const input = parsed.data;
    const client = await options.pool.connect();
    try {
      const role = await authorizeOwnerOutlet(client, request.user.sub, request.user.tenantId, input.outletId);
      if (role !== "ok") return reply.code(403).send({ error: role === "forbidden" ? "outlet_forbidden" : "owner_required" });
      const pinHash = await argon2.hash(input.pin, { type: argon2.argon2id });
      try {
        const result = await client.query(
          "INSERT INTO staff_members (tenant_id, outlet_id, staff_code, display_name, pin_hash, expected_start_time) " +
          "VALUES ($1, $2, $3, $4, $5, $6) RETURNING id::text AS id, staff_code AS \"staffCode\", " +
          "display_name AS \"displayName\", expected_start_time::text AS \"expectedStartTime\", status",
          [request.user.tenantId, input.outletId, input.staffCode, input.displayName, pinHash, input.expectedStartTime ?? null],
        );
        return reply.code(201).send({ staff: result.rows[0] });
      } catch (error) {
        if ((error as { code?: string }).code === "23505") return reply.code(409).send({ error: "staff_code_exists" });
        throw error;
      }
    } finally { client.release(); }
  });

  app.patch("/staff/:staffId", {
    preHandler: async (request, reply) => {
      try { await request.jwtVerify(); } catch { return reply.code(401).send({ error: "unauthorized" }); }
    },
  }, async (request, reply) => {
    if (request.user.role !== "owner") return reply.code(403).send({ error: "owner_required" });
    const params = z.object({ staffId: uuid }).safeParse(request.params);
    const parsed = updateStaffInput.safeParse(request.body);
    if (!params.success || !parsed.success) return invalid(reply);
    const input = parsed.data;
    const client = await options.pool.connect();
    try {
      const role = await authorizeOwnerOutlet(client, request.user.sub, request.user.tenantId, input.outletId);
      if (role !== "ok") return reply.code(403).send({ error: role === "forbidden" ? "outlet_forbidden" : "owner_required" });
      const pinHash = input.pin ? await argon2.hash(input.pin, { type: argon2.argon2id }) : null;
      const result = await client.query(
        "UPDATE staff_members SET display_name = COALESCE($1, display_name), " +
        "pin_hash = COALESCE($2, pin_hash), expected_start_time = CASE WHEN $3 THEN $4::time ELSE expected_start_time END, " +
        "status = COALESCE($5, status), updated_at = now() " +
        "WHERE id = $6 AND tenant_id = $7 AND outlet_id = $8 " +
        "RETURNING id::text AS id, staff_code AS \"staffCode\", display_name AS \"displayName\", " +
        "expected_start_time::text AS \"expectedStartTime\", status",
        [input.displayName ?? null, pinHash, input.expectedStartTime !== undefined,
          input.expectedStartTime ?? null, input.status ?? null, params.data.staffId, request.user.tenantId, input.outletId],
      );
      if (!result.rowCount) return reply.code(404).send({ error: "staff_not_found" });
      return { staff: result.rows[0] };
    } finally { client.release(); }
  });

  app.get("/staff/geofence-radius", {
    preHandler: async (request, reply) => {
      try { await request.jwtVerify(); } catch { return reply.code(401).send({ error: "unauthorized" }); }
    },
  }, async (request, reply) => {
    if (request.user.role !== "owner") return reply.code(403).send({ error: "owner_required" });
    const parsed = uuid.safeParse((request.query as { outletId?: string }).outletId);
    if (!parsed.success) return invalid(reply);
    const client = await options.pool.connect();
    try {
      const role = await authorizeOwnerOutlet(client, request.user.sub, request.user.tenantId, parsed.data);
      if (role !== "ok") return reply.code(403).send({ error: role === "forbidden" ? "outlet_forbidden" : "owner_required" });
      const result = await client.query(
        "SELECT id::text AS \"outletId\", geofence_radius_m AS \"radiusMeters\", " +
        "latitude::float8 AS latitude, longitude::float8 AS longitude FROM outlets WHERE id = $1 AND tenant_id = $2",
        [parsed.data, request.user.tenantId],
      );
      if (!result.rowCount) return reply.code(404).send({ error: "outlet_not_found" });
      return { geofence: result.rows[0] };
    } finally { client.release(); }
  });

  app.patch("/staff/geofence-radius", {
    preHandler: async (request, reply) => {
      try { await request.jwtVerify(); } catch { return reply.code(401).send({ error: "unauthorized" }); }
    },
  }, async (request, reply) => {
    if (request.user.role !== "owner") return reply.code(403).send({ error: "owner_required" });
    const parsed = radiusInput.safeParse(request.body);
    if (!parsed.success) return invalid(reply);
    const client = await options.pool.connect();
    try {
      const role = await authorizeOwnerOutlet(client, request.user.sub, request.user.tenantId, parsed.data.outletId);
      if (role !== "ok") return reply.code(403).send({ error: role === "forbidden" ? "outlet_forbidden" : "owner_required" });
      const result = await client.query(
        "UPDATE outlets SET geofence_radius_m = $1, updated_at = now() WHERE id = $2 AND tenant_id = $3 " +
        "RETURNING id::text AS \"outletId\", geofence_radius_m AS \"radiusMeters\", latitude::float8 AS latitude, longitude::float8 AS longitude",
        [parsed.data.radiusMeters, parsed.data.outletId, request.user.tenantId],
      );
      return { geofence: result.rows[0] };
    } finally { client.release(); }
  });

  app.get("/staff/performance", {
    preHandler: async (request, reply) => {
      try { await request.jwtVerify(); } catch { return reply.code(401).send({ error: "unauthorized" }); }
    },
  }, async (request, reply) => {
    if (request.user.role !== "owner" && request.user.role !== "cashier") {
      return reply.code(403).send({ error: "owner_or_cashier_required" });
    }
    const query = z.object({ outletId: uuid, from: z.string().date().optional(), to: z.string().date().optional() })
      .safeParse(request.query);
    if (!query.success) return invalid(reply);
    const client = await options.pool.connect();
    try {
      const role = await outletRole(client, request.user.sub, request.user.tenantId, query.data.outletId);
      if (!role) return reply.code(403).send({ error: "outlet_forbidden" });
      const result = await client.query(
        "SELECT sm.id::text AS \"staffId\", sm.staff_code AS \"staffCode\", sm.display_name AS \"displayName\", " +
        "COUNT(sa.id)::int AS \"attendanceDays\", COUNT(sa.late_minutes) FILTER (WHERE sa.late_minutes > 0)::int AS \"lateDays\", " +
        "COUNT(sa.late_minutes)::int AS \"evaluatedDays\", " +
        "CASE WHEN COUNT(sa.late_minutes) FILTER (WHERE sa.late_minutes IS NOT NULL) = 0 THEN NULL " +
        "ELSE ROUND(100.0 * COUNT(sa.id) FILTER (WHERE sa.late_minutes = 0) / " +
        "NULLIF(COUNT(sa.late_minutes) FILTER (WHERE sa.late_minutes IS NOT NULL), 0), 1) END AS \"punctualityPercent\" " +
        "FROM staff_members sm LEFT JOIN staff_attendance sa ON sa.staff_id = sm.id AND sa.tenant_id = sm.tenant_id " +
        "AND sa.outlet_id = sm.outlet_id AND ($3::date IS NULL OR sa.work_date >= $3::date) " +
        "AND ($4::date IS NULL OR sa.work_date <= $4::date) " +
        "WHERE sm.tenant_id = $1 AND sm.outlet_id = $2 GROUP BY sm.id ORDER BY sm.display_name",
        [request.user.tenantId, query.data.outletId, query.data.from ?? null, query.data.to ?? null],
      );
      return { performance: result.rows };
    } finally { client.release(); }
  });

  app.post("/attendance/check-in", {
    preHandler: async (request, reply) => {
      try { await request.jwtVerify(); } catch { return reply.code(401).send({ error: "unauthorized" }); }
    },
  }, async (request, reply) => {
    const parsed = attendanceInput.safeParse(request.body);
    if (!parsed.success) return invalid(reply);
    const input = parsed.data;
    if (!requestStaffRole(request, input.outletId)) return reply.code(403).send({ error: "staff_session_required" });
    const client = await options.pool.connect();
    try {
      await client.query("BEGIN");
      const staff = await client.query<{ id: string; expected_start_time: string | null }>(
        "SELECT id::text AS id, expected_start_time::text AS expected_start_time FROM staff_members " +
        "WHERE id = $1 AND tenant_id = $2 AND outlet_id = $3 AND status = 'active' FOR UPDATE",
        [request.user.sub, request.user.tenantId, input.outletId],
      );
      if (!staff.rowCount) {
        await client.query("ROLLBACK");
        return reply.code(403).send({ error: "staff_not_active" });
      }
      const outlet = await getOutlet(client, request.user.tenantId, input.outletId);
      if (!outlet || outlet.latitude == null || outlet.longitude == null) {
        await client.query("ROLLBACK");
        return reply.code(409).send({ error: "outlet_geofence_not_configured" });
      }
      const now = new Date();
      const workDate = localWorkDate(now, outlet.timezone);

      // A missed check-out must not allow a second active shift on a later day.
      // The staff row is locked above, so concurrent check-ins for this identity
      // serialize before checking for an open attendance record.
      const openAttendance = await client.query<{ work_date: string }>(
        "SELECT work_date::text AS work_date FROM staff_attendance " +
        "WHERE tenant_id = $1 AND outlet_id = $2 AND staff_id = $3 AND check_out_at IS NULL " +
        "ORDER BY work_date DESC LIMIT 1 FOR UPDATE",
        [request.user.tenantId, input.outletId, request.user.sub],
      );
      if (openAttendance.rowCount) {
        await client.query("ROLLBACK");
        return reply.code(409).send({
          error: openAttendance.rows[0]!.work_date === workDate
            ? "already_checked_in_today"
            : "previous_attendance_not_closed",
        });
      }

      const distance = distanceMeters(outlet.latitude, outlet.longitude, input.latitude, input.longitude);
      if (distance > outlet.geofence_radius_m) {
        await client.query("ROLLBACK");
        return reply.code(403).send({ error: "outside_geofence", distanceMeters: distance, radiusMeters: outlet.geofence_radius_m });
      }
      const late = lateMinutes(staff.rows[0]!.expected_start_time, now, outlet.timezone);
      const result = await client.query(
        "INSERT INTO staff_attendance (tenant_id, outlet_id, staff_id, work_date, check_in_at, " +
        "check_in_latitude, check_in_longitude, check_in_distance_m, late_minutes) " +
        "VALUES ($1, $2, $3, $4::date, now(), $5, $6, $7, $8) " +
        "ON CONFLICT (tenant_id, outlet_id, staff_id, work_date) DO NOTHING " +
        "RETURNING id::text AS id, work_date::text AS \"workDate\", check_in_at AS \"checkInAt\", late_minutes AS \"lateMinutes\"",
        [request.user.tenantId, input.outletId, request.user.sub, workDate, input.latitude, input.longitude, distance, late],
      );
      if (!result.rowCount) {
        await client.query("ROLLBACK");
        return reply.code(409).send({ error: "already_checked_in_today" });
      }
      await client.query("COMMIT");
      return reply.code(201).send({ attendance: result.rows[0] });
    } catch (error) {
      await client.query("ROLLBACK").catch(() => undefined);
      throw error;
    } finally { client.release(); }
  });

  app.post("/attendance/check-out", {
    preHandler: async (request, reply) => {
      try { await request.jwtVerify(); } catch { return reply.code(401).send({ error: "unauthorized" }); }
    },
  }, async (request, reply) => {
    const parsed = attendanceInput.safeParse(request.body);
    if (!parsed.success) return invalid(reply);
    const input = parsed.data;
    if (!requestStaffRole(request, input.outletId)) return reply.code(403).send({ error: "staff_session_required" });
    const client = await options.pool.connect();
    try {
      await client.query("BEGIN");
      const outlet = await getOutlet(client, request.user.tenantId, input.outletId);
      if (!outlet || outlet.latitude == null || outlet.longitude == null) {
        await client.query("ROLLBACK");
        return reply.code(409).send({ error: "outlet_geofence_not_configured" });
      }
      const distance = distanceMeters(outlet.latitude, outlet.longitude, input.latitude, input.longitude);
      if (distance > outlet.geofence_radius_m) {
        await client.query("ROLLBACK");
        return reply.code(403).send({ error: "outside_geofence", distanceMeters: distance, radiusMeters: outlet.geofence_radius_m });
      }
      const result = await client.query(
        "UPDATE staff_attendance SET check_out_at = now(), check_out_latitude = $1, check_out_longitude = $2, " +
        "check_out_distance_m = $3, updated_at = now() WHERE id = (SELECT id FROM staff_attendance WHERE tenant_id = $4 AND outlet_id = $5 " +
        "AND staff_id = $6 AND check_out_at IS NULL ORDER BY work_date DESC LIMIT 1) " +
        "RETURNING id::text AS id, work_date::text AS \"workDate\", check_in_at AS \"checkInAt\", " +
        "check_out_at AS \"checkOutAt\", late_minutes AS \"lateMinutes\"",
        [input.latitude, input.longitude, distance, request.user.tenantId, input.outletId, request.user.sub],
      );
      if (!result.rowCount) {
        await client.query("ROLLBACK");
        return reply.code(409).send({ error: "no_open_attendance" });
      }
      await client.query("COMMIT");
      return { attendance: result.rows[0] };
    } catch (error) {
      await client.query("ROLLBACK").catch(() => undefined);
      throw error;
    } finally { client.release(); }
  });

  app.get("/attendance/me", {
    preHandler: async (request, reply) => {
      try { await request.jwtVerify(); } catch { return reply.code(401).send({ error: "unauthorized" }); }
    },
  }, async (request, reply) => {
    if (request.user.role !== "staff") return reply.code(403).send({ error: "staff_session_required" });
    const outletId = request.user.outletIds[0];
    const client = await options.pool.connect();
    try {
      const result = await client.query(
        "SELECT work_date::text AS \"workDate\", check_in_at AS \"checkInAt\", check_out_at AS \"checkOutAt\", " +
        "late_minutes AS \"lateMinutes\" FROM staff_attendance WHERE tenant_id = $1 AND outlet_id = $2 AND staff_id = $3 " +
        "ORDER BY work_date DESC LIMIT 60",
        [request.user.tenantId, outletId, request.user.sub],
      );
      return { attendance: result.rows };
    } finally { client.release(); }
  });
};
