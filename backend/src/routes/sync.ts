import { createHash, randomUUID } from "node:crypto";
import type { FastifyPluginAsync, FastifyReply } from "fastify";
import type { Pool, PoolClient } from "pg";
import { z } from "zod";

type OrderStatus = "draft" | "confirmed" | "preparing" | "ready" | "served" | "completed" | "cancelled";
type EventType = "order.created" | "order.updated" | "order.recovered";

interface SyncRouteOptions {
  pool: Pool;
}

const money = z.number().finite().min(0).max(999999999999);
const orderStatus = z.enum([
  "draft",
  "confirmed",
  "preparing",
  "ready",
  "served",
  "completed",
  "cancelled",
]);

const snapshotSchema = z.object({
  id: z.string().trim().min(1).max(128),
  outletId: z.string().uuid(),
  orderType: z.string().trim().min(1).max(64),
  tableId: z.string().max(128).nullable().optional(),
  createdAt: z.string().datetime({ offset: true }),
  items: z.array(z.object({
    productName: z.string().trim().min(1).max(200),
    quantity: z.number().int().positive().max(100000),
    unitPrice: money,
    details: z.string().max(1000).default(""),
  })).min(1).max(500),
  subtotal: money,
  discount: money,
  tax: money,
  service: money,
  total: money,
  status: orderStatus,
  paymentStatus: z.enum(["unpaid", "paid", "refunded"]).default("unpaid"),
  paymentMethod: z.string().trim().max(64).nullable().optional(),
  cashPaidAmount: money.default(0),
  paidAt: z.string().datetime({ offset: true }).nullable().optional(),
}).superRefine((snapshot, context) => {
  const calculatedSubtotal = snapshot.items.reduce(
    (sum, item) => sum + item.quantity * item.unitPrice,
    0,
  );
  if (Math.abs(calculatedSubtotal - snapshot.subtotal) > 0.01) {
    context.addIssue({
      code: z.ZodIssueCode.custom,
      path: ["subtotal"],
      message: "subtotal must equal the sum of order items",
    });
  }
  if (snapshot.discount > snapshot.subtotal) {
    context.addIssue({
      code: z.ZodIssueCode.custom,
      path: ["discount"],
      message: "discount cannot exceed subtotal",
    });
  }
  const expectedTotal = snapshot.subtotal - snapshot.discount + snapshot.tax + snapshot.service;
  if (Math.abs(expectedTotal - snapshot.total) > 0.01) {
    context.addIssue({
      code: z.ZodIssueCode.custom,
      path: ["total"],
      message: "total must equal subtotal minus discount plus tax and service",
    });
  }
  if (snapshot.cashPaidAmount > snapshot.total) {
    context.addIssue({
      code: z.ZodIssueCode.custom,
      path: ["cashPaidAmount"],
      message: "cashPaidAmount cannot exceed total",
    });
  }
});

const syncEventSchema = z.object({
  schemaVersion: z.literal(1),
  eventId: z.string().trim().min(16).max(128),
  deviceId: z.string().uuid(),
  outletId: z.string().uuid(),
  orderId: z.string().trim().min(1).max(128),
  eventType: z.enum(["order.created", "order.updated", "order.recovered"]),
  createdAt: z.string().datetime({ offset: true }),
  expectedServerVersion: z.number().int().positive().optional(),
  orderSnapshot: snapshotSchema,
}).superRefine((event, context) => {
  if (event.orderSnapshot.id !== event.orderId) {
    context.addIssue({
      code: z.ZodIssueCode.custom,
      path: ["orderSnapshot", "id"],
      message: "snapshot id must match orderId",
    });
  }
  if (event.orderSnapshot.outletId !== event.outletId) {
    context.addIssue({
      code: z.ZodIssueCode.custom,
      path: ["orderSnapshot", "outletId"],
      message: "snapshot outletId must match event outletId",
    });
  }
  if (event.eventType === "order.created" && event.expectedServerVersion !== undefined) {
    context.addIssue({
      code: z.ZodIssueCode.custom,
      path: ["expectedServerVersion"],
      message: "order.created must not specify expectedServerVersion",
    });
  }
  if (event.eventType === "order.updated" && event.expectedServerVersion === undefined) {
    context.addIssue({
      code: z.ZodIssueCode.custom,
      path: ["expectedServerVersion"],
      message: "updates must specify expectedServerVersion",
    });
  }
});

function hashPayload(payload: unknown): string {
  return createHash("sha256").update(JSON.stringify(payload)).digest("hex");
}

function invalidRequest(reply: FastifyReply) {
  return reply.code(400).send({ error: "invalid_request" });
}

function safeSnapshot(
  snapshot: z.infer<typeof snapshotSchema>,
  paymentStatus: string,
): Record<string, unknown> {
  return {
    id: snapshot.id,
    outletId: snapshot.outletId,
    orderType: snapshot.orderType,
    tableId: snapshot.tableId ?? null,
    createdAt: snapshot.createdAt,
    items: snapshot.items.map((item) => ({
      productName: item.productName,
      quantity: item.quantity,
      unitPrice: item.unitPrice,
      details: item.details,
    })),
    subtotal: snapshot.subtotal,
    discount: snapshot.discount,
    tax: snapshot.tax,
    service: snapshot.service,
    total: snapshot.total,
    status: snapshot.status,
    // Client-side paid/refunded flags are not proof of settlement.
    paymentStatus,
    paymentMethod: snapshot.paymentMethod ?? null,
    cashPaidAmount: snapshot.cashPaidAmount,
    paidAt: snapshot.paidAt ?? null,
  };
}

function hasReportedCashPayment(snapshot: z.infer<typeof snapshotSchema>): boolean {
  return snapshot.paymentMethod?.toLowerCase() === "cash" &&
    snapshot.cashPaidAmount >= snapshot.total &&
    snapshot.total > 0 &&
    snapshot.paymentStatus === "paid";
}

async function insertOrderItems(
  client: PoolClient,
  tenantId: string,
  outletId: string,
  orderId: string,
  snapshot: z.infer<typeof snapshotSchema>,
): Promise<void> {
  for (const item of snapshot.items) {
    await client.query(
      "INSERT INTO order_items (tenant_id, outlet_id, order_id, product_name, quantity, unit_price, line_total, details) " +
        "VALUES ($1, $2, $3, $4, $5, $6, $7, $8)",
      [tenantId, outletId, orderId, item.productName, item.quantity, item.unitPrice,
       item.quantity * item.unitPrice, item.details],
    );
  }
}

function isAllowedStatusTransition(current: OrderStatus, next: OrderStatus): boolean {
  const allowed: Record<OrderStatus, OrderStatus[]> = {
    draft: ["draft", "confirmed", "cancelled"],
    confirmed: ["confirmed", "preparing", "cancelled"],
    preparing: ["preparing", "ready"],
    ready: ["ready", "served"],
    served: ["served", "completed"],
    completed: ["completed"],
    cancelled: ["cancelled"],
  };
  return allowed[current].includes(next);
}

export const syncRoutes: FastifyPluginAsync<SyncRouteOptions> = async (app, options) => {
  app.post("/events", {
    preHandler: async (request, reply) => {
      try {
        await request.jwtVerify();
      } catch {
        return reply.code(401).send({ error: "unauthorized" });
      }
    },
  }, async (request, reply) => {
    const parsed = syncEventSchema.safeParse(request.body);
    if (!parsed.success) return invalidRequest(reply);

    const event = parsed.data;
    const idempotencyKey = request.headers["idempotency-key"];
    if (typeof idempotencyKey !== "string" || idempotencyKey !== event.eventId) {
      return reply.code(400).send({ error: "idempotency_key_mismatch" });
    }

    const client = await options.pool.connect();
    let inTransaction = false;

    try {
      await client.query("BEGIN");
      inTransaction = true;

      const scopeResult = await client.query<{ role: string }>(
        "SELECT tm.role " +
          "FROM users u " +
          "JOIN tenant_memberships tm ON tm.user_id = u.id AND tm.tenant_id = $2 " +
          "JOIN outlet_memberships om ON om.user_id = u.id AND om.tenant_id = tm.tenant_id " +
          "JOIN outlets o ON o.id = om.outlet_id AND o.tenant_id = tm.tenant_id " +
          "JOIN tenants t ON t.id = tm.tenant_id " +
          "WHERE u.id = $1 AND u.status = 'active' AND tm.status = 'active' " +
          "AND t.status = 'active' AND o.status = 'active' AND o.id = $3 " +
          "FOR SHARE OF u, tm, om, o, t",
        [request.user.sub, request.user.tenantId, event.outletId],
      );
      const scope = scopeResult.rows[0];
      if (!scope) {
        await client.query("ROLLBACK");
        inTransaction = false;
        return reply.code(403).send({ error: "outlet_forbidden" });
      }
      if (scope.role !== "owner" && scope.role !== "cashier") {
        await client.query("ROLLBACK");
        inTransaction = false;
        return reply.code(403).send({ error: "role_forbidden" });
      }

      await client.query(
        "SELECT pg_advisory_xact_lock(hashtextextended($1, 0))",
        [request.user.tenantId + ":" + event.eventId],
      );

      const payloadHash = hashPayload(event);
      const priorReceipt = await client.query<{
        payload_hash: string;
        response_body: Record<string, unknown>;
      }>(
        "SELECT payload_hash, response_body FROM sync_receipts WHERE tenant_id = $1 AND event_id = $2",
        [request.user.tenantId, event.eventId],
      );

      if (priorReceipt.rows[0]) {
        await client.query("ROLLBACK");
        inTransaction = false;
        if (priorReceipt.rows[0].payload_hash !== payloadHash) {
          return reply.code(409).send({ error: "event_id_payload_mismatch" });
        }
        return reply.code(200).send(priorReceipt.rows[0].response_body);
      }

      if (event.eventType === "order.recovered") {
        if (scope.role !== "owner") {
          await client.query("ROLLBACK");
          inTransaction = false;
          return reply.code(403).send({ error: "owner_required_for_recovery" });
        }
        const recoveredOrder = await client.query<{
          id: string;
          version: number;
          snapshot: Record<string, unknown>;
        }>(
          "SELECT id::text AS id, version, snapshot FROM orders " +
            "WHERE tenant_id = $1 AND outlet_id = $2 AND device_id = $3 AND client_order_id = $4 FOR UPDATE",
          [request.user.tenantId, event.outletId, event.deviceId, event.orderId],
        );
        if (recoveredOrder.rows[0]) {
          const existing = recoveredOrder.rows[0];
          await client.query("ROLLBACK");
          inTransaction = false;
          return reply.code(409).send({
            error: "stale_order_version",
            serverVersion: existing.version,
            serverSnapshot: existing.snapshot,
          });
        }
      }

      let globalOrderId: string;
      let serverVersion: number;
      let authoritativePaymentStatus = "unpaid";
      let sanitizedSnapshot: Record<string, unknown>;

      if (event.eventType === "order.created" || event.eventType === "order.recovered") {
        if (event.eventType === "order.recovered" && scope.role !== "owner") {
          await client.query("ROLLBACK");
          inTransaction = false;
          return reply.code(403).send({ error: "owner_required_for_recovery" });
        }
        const reportedCashPayment = hasReportedCashPayment(event.orderSnapshot);
        if (event.orderSnapshot.status === "completed" && !reportedCashPayment) {
          await client.query("ROLLBACK");
          inTransaction = false;
          return reply.code(422).send({ error: "payment_verification_required" });
        }

        const existingOrder = await client.query(
          "SELECT id FROM orders WHERE tenant_id = $1 AND device_id = $2 AND client_order_id = $3 FOR UPDATE",
          [request.user.tenantId, event.deviceId, event.orderId],
        );
        if (existingOrder.rowCount) {
          await client.query("ROLLBACK");
          inTransaction = false;
          return reply.code(409).send({ error: "order_identity_conflict" });
        }

        authoritativePaymentStatus = reportedCashPayment ? "paid" : "unpaid";
        sanitizedSnapshot = safeSnapshot(event.orderSnapshot, authoritativePaymentStatus);
        const orderResult = await client.query<{ id: string; version: number }>(
          "INSERT INTO orders " +
            "(tenant_id, outlet_id, device_id, client_order_id, order_type, status, payment_status, " +
            "subtotal, discount, tax, service_charge, total, snapshot) " +
            "VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13::jsonb) " +
            "RETURNING id::text AS id, version",
          [
            request.user.tenantId,
            event.outletId,
            event.deviceId,
            event.orderId,
            event.orderSnapshot.orderType,
            event.orderSnapshot.status,
            authoritativePaymentStatus,
            event.orderSnapshot.subtotal,
            event.orderSnapshot.discount,
            event.orderSnapshot.tax,
            event.orderSnapshot.service,
            event.orderSnapshot.total,
            JSON.stringify(sanitizedSnapshot),
          ],
        );
        globalOrderId = orderResult.rows[0]!.id;
        serverVersion = orderResult.rows[0]!.version;
        await insertOrderItems(client, request.user.tenantId, event.outletId, globalOrderId, event.orderSnapshot);
        if (reportedCashPayment) {
          await client.query(
            "INSERT INTO payments (tenant_id, outlet_id, order_id, method, amount, status, idempotency_key, actor_user_id) " +
              "VALUES ($1, $2, $3, 'cash', $4, 'reported', $5, $6) ON CONFLICT (tenant_id, idempotency_key) DO NOTHING",
            [request.user.tenantId, event.outletId, globalOrderId, event.orderSnapshot.total,
             event.eventId + ":cash-payment", request.user.sub],
          );
        }
      } else {
        const currentResult = await client.query<{
          id: string;
          version: number;
          status: OrderStatus;
          payment_status: string;
          snapshot: Record<string, unknown>;
        }>(
          "SELECT id::text AS id, version, status, payment_status, snapshot FROM orders " +
            "WHERE tenant_id = $1 AND outlet_id = $2 AND device_id = $3 AND client_order_id = $4 FOR UPDATE",
          [request.user.tenantId, event.outletId, event.deviceId, event.orderId],
        );
        const current = currentResult.rows[0];
        if (!current) {
          await client.query("ROLLBACK");
          inTransaction = false;
          return reply.code(404).send({ error: "order_not_found" });
        }
        if (current.version !== event.expectedServerVersion) {
          await client.query("ROLLBACK");
          inTransaction = false;
          return reply.code(409).send({
            error: "stale_order_version",
            serverVersion: current.version,
            serverSnapshot: current.snapshot,
          });
        }
        if (!isAllowedStatusTransition(current.status, event.orderSnapshot.status)) {
          await client.query("ROLLBACK");
          inTransaction = false;
          return reply.code(422).send({
            error: "invalid_order_transition",
            currentStatus: current.status,
            requestedStatus: event.orderSnapshot.status,
          });
        }
        const reportedCashPayment = hasReportedCashPayment(event.orderSnapshot);
        const nextPaymentStatus = current.payment_status === "paid" || reportedCashPayment
          ? "paid"
          : current.payment_status;
        if (
          event.orderSnapshot.status === "completed" &&
          nextPaymentStatus !== "paid"
        ) {
          await client.query("ROLLBACK");
          inTransaction = false;
          return reply.code(422).send({ error: "payment_verification_required" });
        }

        globalOrderId = current.id;
        authoritativePaymentStatus = nextPaymentStatus;
        sanitizedSnapshot = safeSnapshot(event.orderSnapshot, authoritativePaymentStatus);
        sanitizedSnapshot.createdAt = current.snapshot.createdAt;
        const updated = await client.query<{ version: number }>(
          "UPDATE orders SET version = version + 1, order_type = $1, status = $2, payment_status = $3, " +
            "subtotal = $4, discount = $5, tax = $6, service_charge = $7, total = $8, " +
            "snapshot = $9::jsonb, updated_at = now() WHERE id = $10 RETURNING version",
          [
            event.orderSnapshot.orderType,
            event.orderSnapshot.status,
            authoritativePaymentStatus,
            event.orderSnapshot.subtotal,
            event.orderSnapshot.discount,
            event.orderSnapshot.tax,
            event.orderSnapshot.service,
            event.orderSnapshot.total,
            JSON.stringify(sanitizedSnapshot),
            current.id,
          ],
        );
        serverVersion = updated.rows[0]!.version;
        await client.query("DELETE FROM order_items WHERE tenant_id = $1 AND order_id = $2", [request.user.tenantId, globalOrderId]);
        await insertOrderItems(client, request.user.tenantId, event.outletId, globalOrderId, event.orderSnapshot);
        if (current.payment_status !== "paid" && reportedCashPayment) {
          await client.query(
            "INSERT INTO payments (tenant_id, outlet_id, order_id, method, amount, status, idempotency_key, actor_user_id) " +
              "VALUES ($1, $2, $3, 'cash', $4, 'reported', $5, $6) ON CONFLICT (tenant_id, idempotency_key) DO NOTHING",
            [request.user.tenantId, event.outletId, globalOrderId, event.orderSnapshot.total,
             event.eventId + ":cash-payment", request.user.sub],
          );
        }
      }

      const safeEventPayload = {
        schemaVersion: event.schemaVersion,
        eventId: event.eventId,
        deviceId: event.deviceId,
        outletId: event.outletId,
        orderId: event.orderId,
        eventType: event.eventType as EventType,
        createdAt: event.createdAt,
        ...(event.expectedServerVersion === undefined
          ? {}
          : { expectedServerVersion: event.expectedServerVersion }),
        orderSnapshot: sanitizedSnapshot!,
      };

      await client.query(
        "INSERT INTO order_events (tenant_id, outlet_id, order_id, event_id, event_type, actor_user_id, payload) " +
          "VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb)",
        [
          request.user.tenantId,
          event.outletId,
          globalOrderId!,
          event.eventId,
          event.eventType,
          request.user.sub,
          JSON.stringify(safeEventPayload),
        ],
      );

      const responseBody = {
        schemaVersion: 1,
        eventId: event.eventId,
        outcome: "acknowledged",
        serverReference: randomUUID(),
        globalOrderId: globalOrderId!,
        serverVersion: serverVersion!,
      };

      await client.query(
        "INSERT INTO sync_receipts " +
          "(tenant_id, event_id, payload_hash, server_reference, global_order_id, response_body) " +
          "VALUES ($1, $2, $3, $4, $5, $6::jsonb)",
        [
          request.user.tenantId,
          event.eventId,
          payloadHash,
          responseBody.serverReference,
          globalOrderId!,
          JSON.stringify(responseBody),
        ],
      );

      await client.query("COMMIT");
      inTransaction = false;
      return reply.code(201).send(responseBody);
    } catch (error) {
      if (inTransaction) await client.query("ROLLBACK").catch(() => undefined);
      app.log.error({ err: error }, "Sync event rejected by server");
      return reply.code(500).send({ error: "internal_error" });
    } finally {
      client.release();
    }
  });
};