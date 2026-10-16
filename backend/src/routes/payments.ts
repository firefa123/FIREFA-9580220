import type { FastifyPluginAsync, FastifyReply, FastifyRequest } from "fastify";
import type { Pool, PoolClient } from "pg";
import { z } from "zod";

interface PaymentRouteOptions { pool: Pool; }
const uuid = z.string().uuid();
const paymentMethod = z.enum(["cash", "card", "bank_transfer", "ewallet", "other"]);
const paymentInput = z.object({
  outletId: uuid,
  orderId: uuid,
  method: paymentMethod,
  amount: z.number().finite().min(0.01).max(999999999999),
  provider: z.string().trim().max(100).nullable().optional(),
  providerReference: z.string().trim().max(180).nullable().optional(),
  metadata: z.record(z.unknown()).optional(),
});
const bonInput = z.object({
  outletId: uuid,
  orderId: uuid,
  customerId: z.string().trim().max(120).nullable().optional(),
  customerName: z.string().trim().max(180).nullable().optional(),
});
const refundInput = z.object({
  outletId: uuid,
  orderId: uuid,
  amount: z.number().finite().min(0.01).max(999999999999),
  method: paymentMethod,
  reason: z.string().trim().min(1).max(500),
});

type OrderRow = {
  id: string;
  total: number;
  status: string;
  payment_status: string;
  snapshot: Record<string, unknown>;
};

async function outletRole(client: PoolClient, userId: string, tenantId: string, outletId: string): Promise<string | undefined> {
  const result = await client.query<{ role: string }>(
    "SELECT tm.role FROM tenant_memberships tm " +
    "JOIN tenants t ON t.id = tm.tenant_id AND t.status = 'active' " +
    "JOIN users u ON u.id = tm.user_id AND u.status = 'active' " +
    "JOIN outlet_memberships om ON om.tenant_id = tm.tenant_id AND om.user_id = tm.user_id " +
    "JOIN outlets o ON o.id = om.outlet_id AND o.tenant_id = tm.tenant_id " +
    "WHERE tm.user_id = $1 AND tm.tenant_id = $2 AND tm.status = 'active' " +
    "AND om.outlet_id = $3 AND o.status = 'active' FOR SHARE OF tm, om, o, t, u",
    [userId, tenantId, outletId],
  );
  return result.rows[0]?.role;
}

async function audit(client: PoolClient, tenantId: string, outletId: string, userId: string, action: string, resourceType: string, resourceId: string, changes: Record<string, unknown>): Promise<void> {
  await client.query(
    "INSERT INTO audit_logs (tenant_id, outlet_id, actor_user_id, action, resource_type, resource_id, changes) VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb)",
    [tenantId, outletId, userId, action, resourceType, resourceId, JSON.stringify(changes)],
  );
}

async function event(client: PoolClient, input: {
  tenantId: string; outletId: string; orderId: string; userId: string; type: string;
  status: string; amount: number; method?: string | null; paymentId?: string | null;
  refundId?: string | null; details?: Record<string, unknown>;
}): Promise<void> {
  await client.query(
    "INSERT INTO payment_events (tenant_id, outlet_id, order_id, payment_id, refund_id, event_type, status, amount, method, actor_user_id, details) " +
    "VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11::jsonb)",
    [input.tenantId, input.outletId, input.orderId, input.paymentId ?? null, input.refundId ?? null,
     input.type, input.status, input.amount, input.method ?? null, input.userId, JSON.stringify(input.details ?? {})],
  );
}

async function lockOrder(client: PoolClient, tenantId: string, outletId: string, orderId: string): Promise<OrderRow | undefined> {
  const result = await client.query<OrderRow>(
    "SELECT id::text AS id, total::float8 AS total, status, payment_status, snapshot " +
    "FROM orders WHERE tenant_id = $1 AND outlet_id = $2 AND id = $3 FOR UPDATE",
    [tenantId, outletId, orderId],
  );
  return result.rows[0];
}

async function idempotencyLock(client: PoolClient, tenantId: string, key: string): Promise<void> {
  await client.query("SELECT pg_advisory_xact_lock(hashtextextended($1, 0))", [tenantId + ":" + key]);
}

async function totals(client: PoolClient, tenantId: string, orderId: string): Promise<{ paid: number; refunded: number; paymentReserved: number; refundReserved: number }> {
  const result = await client.query<{ paid: number; refunded: number; paymentReserved: number; refundReserved: number }>(
    "SELECT COALESCE((SELECT SUM(amount) FROM payments WHERE tenant_id = $1 AND order_id = $2 AND status = 'succeeded'), 0)::float8 AS paid, " +
    "COALESCE((SELECT SUM(amount) FROM refunds WHERE tenant_id = $1 AND order_id = $2 AND status = 'succeeded'), 0)::float8 AS refunded, " +
    "COALESCE((SELECT SUM(amount) FROM payments WHERE tenant_id = $1 AND order_id = $2 AND status IN ('reported', 'pending', 'succeeded')), 0)::float8 AS \"paymentReserved\", " +
    "COALESCE((SELECT SUM(amount) FROM refunds WHERE tenant_id = $1 AND order_id = $2 AND status IN ('reported', 'pending', 'succeeded')), 0)::float8 AS \"refundReserved\"",
    [tenantId, orderId],
  );
  return result.rows[0]!;
}

function canonicalJson(value: unknown): string {
  if (Array.isArray(value)) return "[" + value.map(canonicalJson).join(",") + "]";
  if (value !== null && typeof value === "object") {
    const entries = Object.entries(value as Record<string, unknown>).sort(([a], [b]) => a.localeCompare(b));
    return "{" + entries.map(([key, item]) => JSON.stringify(key) + ":" + canonicalJson(item)).join(",") + "}";
  }
  return JSON.stringify(value) ?? "null";
}

function methodLabel(method: string): string {
  switch (method) {
    case "cash": return "Cash";
    case "bank_transfer": return "Transfer";
    case "ewallet": return "QRIS/E-Wallet";
    case "card": return "Card";
    default: return "Other";
  }
}

function idempotencyKey(request: { headers: Record<string, string | string[] | undefined> }): string | undefined {
  const raw = request.headers["idempotency-key"];
  const value = Array.isArray(raw) ? raw[0] : raw;
  return value && value.trim().length >= 8 && value.trim().length <= 200 ? value.trim() : undefined;
}

export const paymentRoutes: FastifyPluginAsync<PaymentRouteOptions> = async (app, options) => {
  const auth = async (request: FastifyRequest, reply: FastifyReply) => {
    try { await request.jwtVerify(); } catch { return reply.code(401).send({ error: "unauthorized" }); }
  };

  app.post("/payments", { preHandler: auth }, async (request, reply) => {
    const parsed = paymentInput.safeParse(request.body);
    const key = idempotencyKey(request);
    if (!parsed.success || !key) return reply.code(400).send({ error: "invalid_request", required: ["outletId", "orderId", "method", "amount", "idempotency-key"] });
    const input = parsed.data;
    const client = await options.pool.connect();
    try {
      await client.query("BEGIN");
      const role = await outletRole(client, request.user.sub, request.user.tenantId, input.outletId);
      if (!role || !["owner", "cashier"].includes(role)) {
        await client.query("ROLLBACK");
        return reply.code(403).send({ error: "outlet_forbidden" });
      }
      await idempotencyLock(client, request.user.tenantId, key);
      const existing = await client.query(
        "SELECT id::text AS id, outlet_id::text AS \"outletId\", order_id::text AS \"orderId\", method, amount::float8 AS amount, status, provider, provider_reference AS \"providerReference\", metadata, verified_at AS \"verifiedAt\", created_at AS \"createdAt\" " +
        "FROM payments WHERE tenant_id = $1 AND idempotency_key = $2 FOR UPDATE",
        [request.user.tenantId, key],
      );
      if (existing.rowCount) {
        const row = existing.rows[0] as Record<string, unknown>;
        const same = row.outletId === input.outletId && row.orderId === input.orderId && row.method === input.method &&
          Number(row.amount) === input.amount && (row.provider ?? null) === (input.provider ?? null) &&
          (row.providerReference ?? null) === (input.providerReference ?? null) &&
          canonicalJson(row.metadata ?? {}) === canonicalJson(input.metadata ?? {});
        await client.query("COMMIT");
        if (!same) return reply.code(409).send({ error: "idempotency_key_payload_mismatch" });
        return reply.code(200).send({ payment: { ...row, verified: row.status === "succeeded" }, replayed: true });
      }
      const order = await lockOrder(client, request.user.tenantId, input.outletId, input.orderId);
      if (!order) { await client.query("ROLLBACK"); return reply.code(404).send({ error: "order_not_found" }); }
      if (order.status === "cancelled" || order.payment_status === "refunded") {
        await client.query("ROLLBACK");
        return reply.code(409).send({ error: "order_not_payable" });
      }
      const total = await totals(client, request.user.tenantId, order.id);
      const remaining = Math.max(0, order.total - total.paymentReserved);
      if (input.amount > remaining + 0.000001) {
        await client.query("ROLLBACK");
        return reply.code(409).send({ error: "payment_exceeds_balance", remainingAmount: remaining });
      }
      const inserted = await client.query(
        "INSERT INTO payments (tenant_id, outlet_id, order_id, method, amount, status, provider, provider_reference, idempotency_key, actor_user_id, metadata) " +
        "VALUES ($1, $2, $3, $4, $5, 'reported', $6, $7, $8, $9, $10::jsonb) " +
        "RETURNING id::text AS id, outlet_id::text AS \"outletId\", order_id::text AS \"orderId\", method, amount::float8 AS amount, status, provider, provider_reference AS \"providerReference\", verified_at AS \"verifiedAt\", created_at AS \"createdAt\"",
        [request.user.tenantId, input.outletId, input.orderId, input.method, input.amount, input.provider ?? null,
         input.providerReference ?? null, key, request.user.sub, JSON.stringify(input.metadata ?? {})],
      );
      const payment = inserted.rows[0] as Record<string, unknown>;
      await event(client, { tenantId: request.user.tenantId, outletId: input.outletId, orderId: input.orderId, userId: request.user.sub,
        type: "payment.reported", status: "reported", amount: input.amount, method: input.method, paymentId: String(payment.id),
        details: { verified: false, provider: input.provider ?? null, providerReference: input.providerReference ?? null } });
      await audit(client, request.user.tenantId, input.outletId, request.user.sub, "payment.reported", "payment", String(payment.id),
        { orderId: input.orderId, amount: input.amount, method: input.method, status: "reported", verified: false });
      await client.query("COMMIT");
      return reply.code(201).send({ payment: { ...payment, verified: false }, replayed: false });
    } catch (error) {
      await client.query("ROLLBACK").catch(() => undefined);
      app.log.error({ err: error }, "Payment report failed");
      return reply.code(500).send({ error: "internal_error" });
    } finally { client.release(); }
  });

  app.post("/payments/bon", { preHandler: auth }, async (request, reply) => {
    const parsed = bonInput.safeParse(request.body);
    const key = idempotencyKey(request);
    if (!parsed.success || !key) return reply.code(400).send({ error: "invalid_request" });
    const input = parsed.data;
    const client = await options.pool.connect();
    try {
      await client.query("BEGIN");
      const role = await outletRole(client, request.user.sub, request.user.tenantId, input.outletId);
      if (!role || !["owner", "cashier"].includes(role)) { await client.query("ROLLBACK"); return reply.code(403).send({ error: "outlet_forbidden" }); }
      await idempotencyLock(client, request.user.tenantId, key);
      const replay = await client.query(
        "SELECT id::text AS id, order_id::text AS \"orderId\", outlet_id::text AS \"outletId\", customer_id AS \"customerId\", customer_name AS \"customerName\", original_amount::float8 AS \"originalAmount\", outstanding_amount::float8 AS \"outstandingAmount\", status FROM accounts_receivable WHERE tenant_id = $1 AND idempotency_key = $2 FOR UPDATE",
        [request.user.tenantId, key],
      );
      if (replay.rowCount) {
        const row = replay.rows[0] as Record<string, unknown>;
        await client.query("COMMIT");
        if (row.orderId !== input.orderId || row.outletId !== input.outletId || row.customerId !== (input.customerId ?? null) || row.customerName !== (input.customerName ?? null)) return reply.code(409).send({ error: "idempotency_key_payload_mismatch" });
        return reply.code(200).send({ receivable: row, replayed: true, verified: false });
      }
      const order = await lockOrder(client, request.user.tenantId, input.outletId, input.orderId);
      if (!order) { await client.query("ROLLBACK"); return reply.code(404).send({ error: "order_not_found" }); }
      if (order.status === "cancelled" || order.payment_status === "paid" || order.payment_status === "refunded") {
        await client.query("ROLLBACK"); return reply.code(409).send({ error: "order_not_eligible_for_bon" });
      }
      const activePayments = await client.query(
        "SELECT id FROM payments WHERE tenant_id = $1 AND order_id = $2 AND status IN ('reported', 'pending', 'succeeded') LIMIT 1 FOR UPDATE",
        [request.user.tenantId, input.orderId],
      );
      if (activePayments.rowCount) {
        await client.query("ROLLBACK");
        return reply.code(409).send({ error: "order_has_payment_reports" });
      }
      const prior = await client.query("SELECT id FROM accounts_receivable WHERE tenant_id = $1 AND order_id = $2 FOR UPDATE", [request.user.tenantId, input.orderId]);
      if (prior.rowCount) { await client.query("ROLLBACK"); return reply.code(409).send({ error: "bon_already_recorded" }); }
      const inserted = await client.query(
        "INSERT INTO accounts_receivable (tenant_id, outlet_id, order_id, customer_id, customer_name, original_amount, outstanding_amount, status, idempotency_key) " +
        "VALUES ($1, $2, $3, $4, $5, $6, $6, 'open', $7) " +
        "RETURNING id::text AS id, order_id::text AS \"orderId\", original_amount::float8 AS \"originalAmount\", outstanding_amount::float8 AS \"outstandingAmount\", status, created_at AS \"createdAt\"",
        [request.user.tenantId, input.outletId, input.orderId, input.customerId ?? null, input.customerName ?? null, order.total, key],
      );
      await client.query(
        "UPDATE orders SET snapshot = snapshot || $4::jsonb, payment_status = 'unpaid', updated_at = now() WHERE tenant_id = $1 AND outlet_id = $2 AND id = $3",
        [request.user.tenantId, input.outletId, input.orderId, JSON.stringify({ paymentMethod: "BON", paymentStatus: "unpaid", paidAt: null, customerId: input.customerId ?? null, customerName: input.customerName ?? null })],
      );
      await event(client, { tenantId: request.user.tenantId, outletId: input.outletId, orderId: input.orderId, userId: request.user.sub,
        type: "bon.reported", status: "open", amount: order.total, method: "BON", details: { verified: false, receivableId: inserted.rows[0]!.id } });
      await audit(client, request.user.tenantId, input.outletId, request.user.sub, "bon.reported", "accounts_receivable", String(inserted.rows[0]!.id),
        { orderId: input.orderId, amount: order.total, status: "open", verified: false });
      await client.query("COMMIT");
      return reply.code(201).send({ receivable: inserted.rows[0], replayed: false, verified: false });
    } catch (error) {
      await client.query("ROLLBACK").catch(() => undefined);
      app.log.error({ err: error }, "BON report failed");
      return reply.code(500).send({ error: "internal_error" });
    } finally { client.release(); }
  });

  app.post("/payments/:paymentId/verify", { preHandler: auth }, async (request, reply) => {
    const paymentId = uuid.safeParse((request.params as { paymentId?: string }).paymentId);
    const parsed = z.object({ outletId: uuid }).safeParse(request.body);
    if (!paymentId.success || !parsed.success) return reply.code(400).send({ error: "invalid_request" });
    const client = await options.pool.connect();
    try {
      await client.query("BEGIN");
      const role = await outletRole(client, request.user.sub, request.user.tenantId, parsed.data.outletId);
      if (role !== "owner") { await client.query("ROLLBACK"); return reply.code(403).send({ error: role ? "owner_required" : "outlet_forbidden" }); }
      const found = await client.query<{ order_id: string; amount: number; method: string; status: string; id: string; outlet_id: string }>(
        "SELECT id::text AS id, order_id::text AS order_id, outlet_id::text AS outlet_id, amount::float8 AS amount, method, status FROM payments WHERE tenant_id = $1 AND outlet_id = $2 AND id = $3 FOR UPDATE",
        [request.user.tenantId, parsed.data.outletId, paymentId.data],
      );
      const payment = found.rows[0];
      if (!payment) { await client.query("ROLLBACK"); return reply.code(404).send({ error: "payment_not_found" }); }
      const order = await lockOrder(client, request.user.tenantId, parsed.data.outletId, payment.order_id);
      if (!order) { await client.query("ROLLBACK"); return reply.code(404).send({ error: "order_not_found" }); }
      if (order.status === "cancelled") {
        await client.query("ROLLBACK");
        return reply.code(409).send({ error: "cancelled_order_payment_verification_forbidden" });
      }
      if (payment.status === "succeeded") {
        await client.query("COMMIT");
        return reply.code(200).send({ payment: { id: payment.id, status: "succeeded", verified: true }, replayed: true });
      }
      if (!["reported", "pending"].includes(payment.status)) { await client.query("ROLLBACK"); return reply.code(409).send({ error: "payment_not_verifiable" }); }
      const before = await totals(client, request.user.tenantId, order.id);
      if (payment.amount > Math.max(0, order.total - before.paid) + 0.000001) {
        await client.query("ROLLBACK"); return reply.code(409).send({ error: "payment_exceeds_balance" });
      }
      await client.query("UPDATE payments SET status = 'succeeded', verified_at = now(), verified_by = $2 WHERE tenant_id = $1 AND id = $3",
        [request.user.tenantId, request.user.sub, payment.id]);
      const after = await totals(client, request.user.tenantId, order.id);
      if (after.paid - after.refunded >= order.total) {
        const snapshot = { paymentStatus: "paid", paidAt: new Date().toISOString(), ...(order.snapshot.paymentMethod === "BON" ? { settlementMethod: methodLabel(payment.method) } : { paymentMethod: methodLabel(payment.method) }) };
        await client.query("UPDATE orders SET payment_status = 'paid', snapshot = snapshot || $4::jsonb, updated_at = now() WHERE tenant_id = $1 AND outlet_id = $2 AND id = $3",
          [request.user.tenantId, parsed.data.outletId, order.id, JSON.stringify(snapshot)]);
      }
      const receivable = await client.query("SELECT original_amount FROM accounts_receivable WHERE tenant_id = $1 AND order_id = $2 FOR UPDATE", [request.user.tenantId, order.id]);
      if (receivable.rowCount) {
        const paidForReceivable = Math.min(Number(receivable.rows[0]!.original_amount), after.paid);
        const outstanding = Math.max(0, Number(receivable.rows[0]!.original_amount) - paidForReceivable);
        await client.query("UPDATE accounts_receivable SET outstanding_amount = $3, status = $4, updated_at = now() WHERE tenant_id = $1 AND order_id = $2",
          [request.user.tenantId, order.id, outstanding, outstanding === 0 ? "paid" : paidForReceivable > 0 ? "partially_paid" : "open"]);
      }
      await event(client, { tenantId: request.user.tenantId, outletId: parsed.data.outletId, orderId: order.id, userId: request.user.sub,
        type: "payment.verified", status: "succeeded", amount: payment.amount, method: payment.method, paymentId: payment.id, details: { verified: true } });
      await audit(client, request.user.tenantId, parsed.data.outletId, request.user.sub, "payment.verified", "payment", payment.id,
        { orderId: order.id, amount: payment.amount, method: payment.method, status: "succeeded", verified: true });
      await client.query("COMMIT");
      return reply.code(200).send({ payment: { id: payment.id, status: "succeeded", verified: true, verifiedAt: new Date().toISOString() }, orderPaymentStatus: after.paid - after.refunded >= order.total ? "paid" : "unpaid" });
    } catch (error) {
      await client.query("ROLLBACK").catch(() => undefined);
      app.log.error({ err: error }, "Payment verification failed");
      return reply.code(500).send({ error: "internal_error" });
    } finally { client.release(); }
  });

  app.post("/payments/:paymentId/fail", { preHandler: auth }, async (request, reply) => {
    const paymentId = uuid.safeParse((request.params as { paymentId?: string }).paymentId);
    const parsed = z.object({ outletId: uuid, reason: z.string().trim().min(1).max(300) }).safeParse(request.body);
    if (!paymentId.success || !parsed.success) return reply.code(400).send({ error: "invalid_request" });
    const client = await options.pool.connect();
    try {
      await client.query("BEGIN");
      const role = await outletRole(client, request.user.sub, request.user.tenantId, parsed.data.outletId);
      if (role !== "owner") { await client.query("ROLLBACK"); return reply.code(403).send({ error: role ? "owner_required" : "outlet_forbidden" }); }
      const result = await client.query<{ id: string; order_id: string; amount: number; method: string; status: string }>(
        "SELECT id::text AS id, order_id::text AS order_id, amount::float8 AS amount, method, status FROM payments WHERE tenant_id = $1 AND outlet_id = $2 AND id = $3 FOR UPDATE",
        [request.user.tenantId, parsed.data.outletId, paymentId.data],
      );
      const payment = result.rows[0];
      if (!payment) { await client.query("ROLLBACK"); return reply.code(404).send({ error: "payment_not_found" }); }
      if (payment.status === "failed") { await client.query("COMMIT"); return reply.code(200).send({ payment: { id: payment.id, status: "failed", verified: false }, replayed: true }); }
      if (!["reported", "pending"].includes(payment.status)) { await client.query("ROLLBACK"); return reply.code(409).send({ error: "payment_not_failible" }); }
      await client.query("UPDATE payments SET status = 'failed', failure_reason = $3 WHERE tenant_id = $1 AND id = $2", [request.user.tenantId, payment.id, parsed.data.reason]);
      await event(client, { tenantId: request.user.tenantId, outletId: parsed.data.outletId, orderId: payment.order_id, userId: request.user.sub,
        type: "payment.failed", status: "failed", amount: payment.amount, method: payment.method, paymentId: payment.id, details: { reason: parsed.data.reason } });
      await audit(client, request.user.tenantId, parsed.data.outletId, request.user.sub, "payment.failed", "payment", payment.id,
        { orderId: payment.order_id, amount: payment.amount, method: payment.method, status: "failed", reason: parsed.data.reason });
      await client.query("COMMIT");
      return reply.code(200).send({ payment: { id: payment.id, status: "failed", verified: false } });
    } catch (error) {
      await client.query("ROLLBACK").catch(() => undefined);
      app.log.error({ err: error }, "Payment failure update failed");
      return reply.code(500).send({ error: "internal_error" });
    } finally { client.release(); }
  });

  app.post("/refunds", { preHandler: auth }, async (request, reply) => {
    const parsed = refundInput.safeParse(request.body);
    const key = idempotencyKey(request);
    if (!parsed.success || !key) return reply.code(400).send({ error: "invalid_request", required: ["outletId", "orderId", "amount", "method", "reason", "idempotency-key"] });
    const input = parsed.data;
    const client = await options.pool.connect();
    try {
      await client.query("BEGIN");
      const role = await outletRole(client, request.user.sub, request.user.tenantId, input.outletId);
      if (!role || !["owner", "cashier"].includes(role)) { await client.query("ROLLBACK"); return reply.code(403).send({ error: "outlet_forbidden" }); }
      await idempotencyLock(client, request.user.tenantId, key);
      const replay = await client.query(
        "SELECT id::text AS id, order_id::text AS \"orderId\", outlet_id::text AS \"outletId\", amount::float8 AS amount, method, reason, status, verified_at AS \"verifiedAt\" FROM refunds WHERE tenant_id = $1 AND idempotency_key = $2 FOR UPDATE",
        [request.user.tenantId, key],
      );
      if (replay.rowCount) {
        const row = replay.rows[0] as Record<string, unknown>;
        const same = row.orderId === input.orderId && row.outletId === input.outletId && Number(row.amount) === input.amount && row.method === input.method && row.reason === input.reason;
        await client.query("COMMIT");
        if (!same) return reply.code(409).send({ error: "idempotency_key_payload_mismatch" });
        return reply.code(200).send({ refund: { ...row, verified: row.status === "succeeded" }, replayed: true });
      }
      const order = await lockOrder(client, request.user.tenantId, input.outletId, input.orderId);
      if (!order) { await client.query("ROLLBACK"); return reply.code(404).send({ error: "order_not_found" }); }
      const balance = await totals(client, request.user.tenantId, order.id);
      const refundable = Math.max(0, balance.paid - balance.refundReserved);
      if (order.payment_status !== "paid" || input.amount > refundable + 0.000001) {
        await client.query("ROLLBACK"); return reply.code(409).send({ error: "refund_exceeds_verified_payment", refundableAmount: refundable });
      }
      const inserted = await client.query(
        "INSERT INTO refunds (tenant_id, outlet_id, order_id, amount, method, reason, status, idempotency_key, actor_user_id, created_at) " +
        "VALUES ($1, $2, $3, $4, $5, $6, 'reported', $7, $8, now()) " +
        "RETURNING id::text AS id, order_id::text AS \"orderId\", amount::float8 AS amount, method, reason, status, verified_at AS \"verifiedAt\", created_at AS \"createdAt\"",
        [request.user.tenantId, input.outletId, input.orderId, input.amount, input.method, input.reason, key, request.user.sub],
      );
      const refund = inserted.rows[0] as Record<string, unknown>;
      await event(client, { tenantId: request.user.tenantId, outletId: input.outletId, orderId: input.orderId, userId: request.user.sub,
        type: "refund.reported", status: "reported", amount: input.amount, method: input.method, refundId: String(refund.id), details: { reason: input.reason, verified: false } });
      await audit(client, request.user.tenantId, input.outletId, request.user.sub, "refund.reported", "refund", String(refund.id),
        { orderId: input.orderId, amount: input.amount, method: input.method, reason: input.reason, status: "reported", verified: false });
      await client.query("COMMIT");
      return reply.code(201).send({ refund: { ...refund, verified: false }, replayed: false });
    } catch (error) {
      await client.query("ROLLBACK").catch(() => undefined);
      app.log.error({ err: error }, "Refund report failed");
      return reply.code(500).send({ error: "internal_error" });
    } finally { client.release(); }
  });

  app.post("/refunds/:refundId/verify", { preHandler: auth }, async (request, reply) => {
    const refundId = uuid.safeParse((request.params as { refundId?: string }).refundId);
    const parsed = z.object({ outletId: uuid }).safeParse(request.body);
    if (!refundId.success || !parsed.success) return reply.code(400).send({ error: "invalid_request" });
    const client = await options.pool.connect();
    try {
      await client.query("BEGIN");
      const role = await outletRole(client, request.user.sub, request.user.tenantId, parsed.data.outletId);
      if (role !== "owner") { await client.query("ROLLBACK"); return reply.code(403).send({ error: role ? "owner_required" : "outlet_forbidden" }); }
      const result = await client.query<{ id: string; order_id: string; amount: number; method: string; reason: string; status: string }>(
        "SELECT id::text AS id, order_id::text AS order_id, amount::float8 AS amount, method, reason, status FROM refunds WHERE tenant_id = $1 AND outlet_id = $2 AND id = $3 FOR UPDATE",
        [request.user.tenantId, parsed.data.outletId, refundId.data],
      );
      const refund = result.rows[0];
      if (!refund) { await client.query("ROLLBACK"); return reply.code(404).send({ error: "refund_not_found" }); }
      const order = await lockOrder(client, request.user.tenantId, parsed.data.outletId, refund.order_id);
      if (!order) { await client.query("ROLLBACK"); return reply.code(404).send({ error: "order_not_found" }); }
      if (refund.status === "succeeded") { await client.query("COMMIT"); return reply.code(200).send({ refund: { id: refund.id, status: "succeeded", verified: true }, replayed: true }); }
      if (!["reported", "pending"].includes(refund.status)) { await client.query("ROLLBACK"); return reply.code(409).send({ error: "refund_not_verifiable" }); }
      const before = await totals(client, request.user.tenantId, order.id);
      if (refund.amount > Math.max(0, before.paid - before.refunded) + 0.000001) {
        await client.query("ROLLBACK"); return reply.code(409).send({ error: "refund_exceeds_verified_payment" });
      }
      await client.query("UPDATE refunds SET status = 'succeeded', verified_at = now(), verified_by = $2 WHERE tenant_id = $1 AND id = $3",
        [request.user.tenantId, request.user.sub, refund.id]);
      const after = await totals(client, request.user.tenantId, order.id);
      const snapshotRecords = Array.isArray(order.snapshot.refundRecords) ? [...order.snapshot.refundRecords] : [];
      const timestamp = new Date().toISOString();
      snapshotRecords.push({ amount: refund.amount, method: methodLabel(refund.method), reason: refund.reason, createdAt: timestamp });
      const fullyRefunded = after.refunded >= order.total;
      const cashRefundAmount = after.refunded > 0 ? await client.query<{ amount: number }>(
        "SELECT COALESCE(SUM(amount), 0)::float8 AS amount FROM refunds WHERE tenant_id = $1 AND order_id = $2 AND status = 'succeeded' AND method = 'cash'",
        [request.user.tenantId, order.id],
      ) : { rows: [{ amount: 0 }] } as { rows: { amount: number }[] };
      const snapshot = {
        refundAmount: after.refunded,
        cashRefundAmount: Number(cashRefundAmount.rows[0]!.amount),
        refundedAt: timestamp,
        refundMethod: methodLabel(refund.method),
        refundReason: refund.reason,
        refundRecords: snapshotRecords,
        paymentStatus: fullyRefunded ? "refunded" : "paid",
      };
      await client.query("UPDATE orders SET payment_status = $4, snapshot = snapshot || $5::jsonb, updated_at = now() WHERE tenant_id = $1 AND outlet_id = $2 AND id = $3",
        [request.user.tenantId, parsed.data.outletId, order.id, fullyRefunded ? "refunded" : "paid", JSON.stringify(snapshot)]);
      await event(client, { tenantId: request.user.tenantId, outletId: parsed.data.outletId, orderId: order.id, userId: request.user.sub,
        type: "refund.verified", status: "succeeded", amount: refund.amount, method: refund.method, refundId: refund.id, details: { reason: refund.reason, verified: true, cumulativeRefund: after.refunded } });
      await audit(client, request.user.tenantId, parsed.data.outletId, request.user.sub, "refund.verified", "refund", refund.id,
        { orderId: order.id, amount: refund.amount, method: refund.method, reason: refund.reason, status: "succeeded", verified: true, cumulativeRefund: after.refunded });
      await client.query("COMMIT");
      return reply.code(200).send({ refund: { id: refund.id, status: "succeeded", verified: true, verifiedAt: timestamp }, orderPaymentStatus: fullyRefunded ? "refunded" : "paid", refundedAmount: after.refunded, refundableAmount: Math.max(0, order.total - after.refunded) });
    } catch (error) {
      await client.query("ROLLBACK").catch(() => undefined);
      app.log.error({ err: error }, "Refund verification failed");
      return reply.code(500).send({ error: "internal_error" });
    } finally { client.release(); }
  });

  app.get("/payments/history", { preHandler: auth }, async (request, reply) => {
    const query = request.query as { outletId?: string; orderId?: string };
    const outletId = uuid.safeParse(query.outletId);
    const orderId = query.orderId === undefined ? undefined : uuid.safeParse(query.orderId);
    if (!outletId.success || (orderId && !orderId.success)) return reply.code(400).send({ error: "invalid_request" });
    const client = await options.pool.connect();
    try {
      const role = await outletRole(client, request.user.sub, request.user.tenantId, outletId.data);
      if (!role) return reply.code(403).send({ error: "outlet_forbidden" });
      const params: string[] = [request.user.tenantId, outletId.data];
      const orderFilter = orderId ? " AND order_id = $3" : "";
      if (orderId) params.push(orderId.data);
      const [payments, refunds, events, receivables] = await Promise.all([
        client.query(
          "SELECT id::text AS id, order_id::text AS \"orderId\", method, amount::float8 AS amount, status, provider, provider_reference AS \"providerReference\", verified_at AS \"verifiedAt\", created_at AS \"createdAt\", (status = 'succeeded') AS verified FROM payments WHERE tenant_id = $1 AND outlet_id = $2" + orderFilter + " ORDER BY created_at DESC",
          params,
        ),
        client.query(
          "SELECT id::text AS id, order_id::text AS \"orderId\", amount::float8 AS amount, method, reason, status, verified_at AS \"verifiedAt\", created_at AS \"createdAt\", (status = 'succeeded') AS verified FROM refunds WHERE tenant_id = $1 AND outlet_id = $2" + orderFilter + " ORDER BY created_at DESC",
          params,
        ),
        client.query(
          "SELECT id::text AS id, order_id::text AS \"orderId\", payment_id::text AS \"paymentId\", refund_id::text AS \"refundId\", event_type AS \"eventType\", status, amount::float8 AS amount, method, actor_user_id::text AS \"actorUserId\", details, created_at AS \"createdAt\" FROM payment_events WHERE tenant_id = $1 AND outlet_id = $2" + orderFilter + " ORDER BY created_at DESC",
          params,
        ),
        client.query(
          "SELECT id::text AS id, order_id::text AS \"orderId\", customer_id AS \"customerId\", customer_name AS \"customerName\", original_amount::float8 AS \"originalAmount\", outstanding_amount::float8 AS \"outstandingAmount\", status, created_at AS \"createdAt\", updated_at AS \"updatedAt\" FROM accounts_receivable WHERE tenant_id = $1 AND outlet_id = $2" + orderFilter + " ORDER BY created_at DESC",
          params,
        ),
      ]);
      return { payments: payments.rows, refunds: refunds.rows, events: events.rows, receivables: receivables.rows };
    } finally { client.release(); }
  });
};
