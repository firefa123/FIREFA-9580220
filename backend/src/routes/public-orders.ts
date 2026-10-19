import { createHash } from "node:crypto";
import type { FastifyPluginAsync, FastifyReply } from "fastify";
import type { Pool } from "pg";
import { z } from "zod";

interface PublicOrderOptions { pool: Pool; }
const uuid = z.string().uuid();
const menuQuery = z.object({ outletId: uuid });
const orderInput = z.object({
  outletId: uuid,
  tableId: z.string().trim().min(1).max(128),
  tableName: z.string().trim().min(1).max(40),
  customerName: z.string().trim().max(100).optional().default(""),
  notes: z.string().trim().max(500).optional().default(""),
  paymentMethod: z.enum(["cash", "qris"]).optional().default("cash"),
  items: z.array(z.object({
    productId: uuid,
    quantity: z.number().int().min(1).max(99),
  })).min(1).max(50),
});

function invalid(reply: FastifyReply) {
  return reply.code(400).send({ error: "invalid_request" });
}

export const publicOrderRoutes: FastifyPluginAsync<PublicOrderOptions> = async (app, { pool }) => {
  app.get("/menu", async (request, reply) => {
    const parsed = menuQuery.safeParse(request.query);
    if (!parsed.success) return invalid(reply);
    const result = await pool.query(
      "SELECT p.id::text AS id, p.name, p.description, p.unit_price::float8 AS \"unitPrice\", " +
      "p.is_active AS \"isActive\" FROM products p JOIN outlets o ON o.id = $1 AND o.tenant_id = p.tenant_id " +
      "WHERE o.status = 'active' AND p.is_active = true AND (p.outlet_id = o.id OR p.outlet_id IS NULL) " +
      "ORDER BY p.name",
      [parsed.data.outletId],
    );
    return { products: result.rows };
  });

  app.post("/orders", async (request, reply) => {
    const parsed = orderInput.safeParse(request.body);
    if (!parsed.success) return invalid(reply);
    const key = request.headers["idempotency-key"];
    if (typeof key !== "string" || key.length < 8 || key.length > 128) {
      return reply.code(400).send({ error: "idempotency_key_required" });
    }
    const input = parsed.data;
    const client = await pool.connect();
    try {
      await client.query("BEGIN");
      const outlet = await client.query<{ tenantId: string }>(
        "SELECT tenant_id::text AS \"tenantId\" FROM outlets WHERE id = $1 AND status = 'active' FOR SHARE",
        [input.outletId],
      );
      if (!outlet.rowCount) {
        await client.query("ROLLBACK");
        return reply.code(404).send({ error: "outlet_not_found" });
      }
      const tenantId = outlet.rows[0]!.tenantId;
      const quantities = new Map<string, number>();
      for (const item of input.items) quantities.set(item.productId, (quantities.get(item.productId) ?? 0) + item.quantity);
      const productIds = [...quantities.keys()];
      const products = await client.query<{
        id: string; name: string; unitPrice: string; taxRate: string;
      }>(
        "SELECT id::text AS id, name, unit_price::text AS \"unitPrice\", tax_rate::text AS \"taxRate\" " +
        "FROM products WHERE tenant_id = $1 AND is_active = true AND (outlet_id = $2 OR outlet_id IS NULL) " +
        "AND id = ANY($3::uuid[]) FOR SHARE",
        [tenantId, input.outletId, productIds],
      );
      if (products.rowCount !== productIds.length) {
        await client.query("ROLLBACK");
        return reply.code(400).send({ error: "menu_item_unavailable" });
      }
      const productById = new Map(products.rows.map(p => [p.id, p]));
      const items = productIds.map(id => {
        const product = productById.get(id)!;
        const quantity = quantities.get(id)!;
        const unitPrice = Number(product.unitPrice);
        return { productId: id, productName: product.name, quantity, unitPrice, details: "" };
      });
      const subtotal = items.reduce((sum, item) => sum + item.quantity * item.unitPrice, 0);
      const keyUuid = createHash("sha256").update(key).digest("hex").slice(0, 32);
      const deviceId = keyUuid.slice(0, 8) + "-" + keyUuid.slice(8, 12) + "-4" + keyUuid.slice(13, 16) + "-a" + keyUuid.slice(17, 20) + "-" + keyUuid.slice(20, 32);
      const existing = await client.query<{ id: string }>(
        "SELECT id::text AS id FROM orders WHERE tenant_id = $1 AND device_id = $2 AND client_order_id = $3",
        [tenantId, deviceId, key],
      );
      if (existing.rowCount) {
        await client.query("COMMIT");
        return reply.send({ orderId: existing.rows[0]!.id, status: "draft", duplicate: true });
      }
      const snapshot = {
        source: "customer_qr", tableId: input.tableId, tableName: input.tableName,
        customerName: input.customerName, notes: input.notes, paymentMethod: input.paymentMethod, items,
      };
      const created = await client.query<{ id: string }>(
        "INSERT INTO orders (tenant_id, outlet_id, device_id, client_order_id, order_type, status, payment_status, subtotal, discount, tax, service_charge, total, snapshot) " +
        "VALUES ($1, $2, $3, $4, 'Dine In', 'draft', 'unpaid', $5, 0, 0, 0, $5, $6::jsonb) RETURNING id::text AS id",
        [tenantId, input.outletId, deviceId, key, subtotal, JSON.stringify(snapshot)],
      );
      const orderId = created.rows[0]!.id;
      for (const item of items) {
        await client.query(
          "INSERT INTO order_items (tenant_id, outlet_id, order_id, product_id, product_name, quantity, unit_price, line_total, details) " +
          "VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)",
          [tenantId, input.outletId, orderId, item.productId, item.productName, item.quantity,
            item.unitPrice, item.quantity * item.unitPrice, item.details],
        );
      }
      await client.query(
        "INSERT INTO order_events (tenant_id, outlet_id, order_id, event_id, event_type, payload) VALUES ($1, $2, $3, $4, 'order.created', $5::jsonb)",
        [tenantId, input.outletId, orderId, "qr:" + key, JSON.stringify({ source: "customer_qr", tableId: input.tableId, tableName: input.tableName, status: "draft", paymentStatus: "unpaid" })],
      );
      await client.query("COMMIT");
      return reply.code(201).send({ orderId, status: "draft", paymentStatus: "unpaid", paymentMethod: input.paymentMethod, paymentMessage: input.paymentMethod === "qris" ? "QRIS payment requires outlet-side QR display and verification; order is not marked paid." : "Pay at cashier." });
    } catch (error) {
      await client.query("ROLLBACK").catch(() => undefined);
      if ((error as { code?: string }).code === "23505") {
        const retry = await pool.query<{ id: string }>(
          "SELECT id::text AS id FROM orders WHERE client_order_id = $1 ORDER BY created_at DESC LIMIT 1", [key],
        );
        if (retry.rowCount) return reply.send({ orderId: retry.rows[0]!.id, status: "draft", duplicate: true });
      }
      app.log.error({ err: error }, "Public QR order failed");
      return reply.code(500).send({ error: "internal_error" });
    } finally { client.release(); }
  });
};
