import { createHash } from "node:crypto";
import type { FastifyPluginAsync, FastifyReply } from "fastify";
import type { Pool, PoolClient } from "pg";
import { z } from "zod";

interface CatalogRouteOptions { pool: Pool; }
const uuid = z.string().uuid();
const productInput = z.object({
  outletId: uuid,
  categoryId: uuid.nullable().optional(),
  sku: z.string().trim().max(80).nullable().optional(),
  name: z.string().trim().min(1).max(180),
  description: z.string().max(2000).nullable().optional(),
  unitPrice: z.number().finite().min(0).max(999999999999),
  taxRate: z.number().finite().min(0).max(100).default(0),
});
const productUpdate = z.object({
  outletId: uuid,
  name: z.string().trim().min(1).max(180).optional(),
  description: z.string().max(2000).nullable().optional(),
  unitPrice: z.number().finite().min(0).max(999999999999).optional(),
  taxRate: z.number().finite().min(0).max(100).optional(),
  isActive: z.boolean().optional(),
});
const inventoryInput = z.object({
  outletId: uuid,
  productId: uuid.nullable().optional(),
  sku: z.string().trim().max(80).nullable().optional(),
  name: z.string().trim().min(1).max(180),
  unit: z.string().trim().min(1).max(32).default("unit"),
  initialQuantity: z.number().finite().min(0).max(1_000_000_000).default(0),
  reorderLevel: z.number().finite().min(0).max(1_000_000_000).default(0),
  averageUnitCost: z.number().finite().min(0).max(999999999999).default(0),
});
const movementInput = z.object({
  outletId: uuid,
  inventoryItemId: uuid,
  movementType: z.enum(["receipt", "sale", "adjustment", "waste", "return", "transfer_in", "transfer_out"]),
  quantityDelta: z.number().finite().min(-1_000_000_000).max(1_000_000_000).refine((value) => value !== 0),
  unitCost: z.number().finite().min(0).max(999999999999).default(0),
  sourceType: z.string().trim().max(64).nullable().optional(),
  sourceId: z.string().trim().max(128).nullable().optional(),
  note: z.string().trim().max(1000).nullable().optional(),
});

function invalid(reply: FastifyReply) {
  return reply.code(400).send({ error: "invalid_request" });
}

async function outletRole(
  client: PoolClient,
  userId: string,
  tenantId: string,
  outletId: string,
): Promise<string | undefined> {
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

async function audit(
  client: PoolClient,
  tenantId: string,
  outletId: string,
  userId: string,
  action: string,
  resourceType: string,
  resourceId: string | null,
  changes: Record<string, unknown>,
): Promise<void> {
  await client.query(
    "INSERT INTO audit_logs (tenant_id, outlet_id, actor_user_id, action, resource_type, resource_id, changes) " +
      "VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb)",
    [tenantId, outletId, userId, action, resourceType, resourceId, JSON.stringify(changes)],
  );
}

export const catalogRoutes: FastifyPluginAsync<CatalogRouteOptions> = async (app, options) => {
  app.get("/products", {
    preHandler: async (request, reply) => {
      try { await request.jwtVerify(); } catch { return reply.code(401).send({ error: "unauthorized" }); }
    },
  }, async (request, reply) => {
    const parsedOutlet = uuid.safeParse((request.query as { outletId?: string }).outletId);
    if (!parsedOutlet.success) return invalid(reply);
    const client = await options.pool.connect();
    try {
      const role = await outletRole(client, request.user.sub, request.user.tenantId, parsedOutlet.data);
      if (!role) return reply.code(403).send({ error: "outlet_forbidden" });
      const products = await client.query(
        "SELECT id::text AS id, outlet_id::text AS \"outletId\", category_id::text AS \"categoryId\", " +
          "sku, name, description, unit_price::float8 AS \"unitPrice\", tax_rate::float8 AS \"taxRate\", " +
          "is_active AS \"isActive\", updated_at AS \"updatedAt\" FROM products " +
          "WHERE tenant_id = $1 AND (outlet_id = $2 OR outlet_id IS NULL) ORDER BY name",
        [request.user.tenantId, parsedOutlet.data],
      );
      return { products: products.rows };
    } finally { client.release(); }
  });

  app.post("/products", {
    preHandler: async (request, reply) => {
      try { await request.jwtVerify(); } catch { return reply.code(401).send({ error: "unauthorized" }); }
    },
  }, async (request, reply) => {
    const parsed = productInput.safeParse(request.body);
    if (!parsed.success) return invalid(reply);
    const input = parsed.data;
    const client = await options.pool.connect();
    try {
      await client.query("BEGIN");
      const role = await outletRole(client, request.user.sub, request.user.tenantId, input.outletId);
      if (role !== "owner") {
        await client.query("ROLLBACK");
        return reply.code(role ? 403 : 403).send({ error: role ? "owner_required" : "outlet_forbidden" });
      }
      const result = await client.query<{ id: string }>(
        "INSERT INTO products (tenant_id, outlet_id, category_id, sku, name, description, unit_price, tax_rate) " +
          "VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING id::text AS id",
        [request.user.tenantId, input.outletId, input.categoryId ?? null, input.sku ?? null,
         input.name, input.description ?? null, input.unitPrice, input.taxRate],
      );
      const id = result.rows[0]!.id;
      await audit(client, request.user.tenantId, input.outletId, request.user.sub, "product.created", "product", id, {
        name: input.name, unitPrice: input.unitPrice, sku: input.sku ?? null,
      });
      await client.query("COMMIT");
      return reply.code(201).send({ id });
    } catch (error) {
      await client.query("ROLLBACK").catch(() => undefined);
      if ((error as { code?: string }).code === "23505") return reply.code(409).send({ error: "duplicate_product_sku" });
      app.log.error({ err: error }, "Product create failed");
      return reply.code(500).send({ error: "internal_error" });
    } finally { client.release(); }
  });

  app.patch("/products/:id", {
    preHandler: async (request, reply) => {
      try { await request.jwtVerify(); } catch { return reply.code(401).send({ error: "unauthorized" }); }
    },
  }, async (request, reply) => {
    const id = (request.params as { id?: string }).id;
    const parsedId = uuid.safeParse(id);
    const parsed = productUpdate.safeParse(request.body);
    if (!parsedId.success || !parsed.success) return invalid(reply);
    const input = parsed.data;
    const client = await options.pool.connect();
    try {
      await client.query("BEGIN");
      const role = await outletRole(client, request.user.sub, request.user.tenantId, input.outletId);
      if (role !== "owner") {
        await client.query("ROLLBACK");
        return reply.code(403).send({ error: role ? "owner_required" : "outlet_forbidden" });
      }
      const updated = await client.query(
        "UPDATE products SET name = COALESCE($1, name), description = COALESCE($2, description), " +
          "unit_price = COALESCE($3, unit_price), tax_rate = COALESCE($4, tax_rate), " +
          "is_active = COALESCE($5, is_active), updated_at = now() " +
          "WHERE id = $6 AND tenant_id = $7 AND outlet_id = $8 RETURNING id::text AS id",
        [input.name ?? null, input.description ?? null, input.unitPrice ?? null, input.taxRate ?? null,
         input.isActive ?? null, parsedId.data, request.user.tenantId, input.outletId],
      );
      if (!updated.rowCount) {
        await client.query("ROLLBACK");
        return reply.code(404).send({ error: "product_not_found" });
      }
      await audit(client, request.user.tenantId, input.outletId, request.user.sub, "product.updated", "product", parsedId.data, input);
      await client.query("COMMIT");
      return { id: parsedId.data };
    } catch (error) {
      await client.query("ROLLBACK").catch(() => undefined);
      app.log.error({ err: error }, "Product update failed");
      return reply.code(500).send({ error: "internal_error" });
    } finally { client.release(); }
  });

  app.get("/inventory/items", {
    preHandler: async (request, reply) => {
      try { await request.jwtVerify(); } catch { return reply.code(401).send({ error: "unauthorized" }); }
    },
  }, async (request, reply) => {
    const parsedOutlet = uuid.safeParse((request.query as { outletId?: string }).outletId);
    if (!parsedOutlet.success) return invalid(reply);
    const client = await options.pool.connect();
    try {
      const role = await outletRole(client, request.user.sub, request.user.tenantId, parsedOutlet.data);
      if (!role) return reply.code(403).send({ error: "outlet_forbidden" });
      if (role !== "owner") return reply.code(403).send({ error: "owner_required" });
      const result = await client.query(
        "SELECT id::text AS id, outlet_id::text AS \"outletId\", sku, name, unit, " +
          "quantity_on_hand::float8 AS \"quantityOnHand\", reorder_level::float8 AS \"reorderLevel\", " +
          "average_unit_cost::float8 AS \"averageUnitCost\", is_active AS \"isActive\", updated_at AS \"updatedAt\" " +
          "FROM inventory_items WHERE tenant_id = $1 AND outlet_id = $2 ORDER BY name",
        [request.user.tenantId, parsedOutlet.data],
      );
      return { items: result.rows };
    } finally { client.release(); }
  });

  app.post("/inventory/items", {
    preHandler: async (request, reply) => {
      try { await request.jwtVerify(); } catch { return reply.code(401).send({ error: "unauthorized" }); }
    },
  }, async (request, reply) => {
    const parsed = inventoryInput.safeParse(request.body);
    if (!parsed.success) return invalid(reply);
    const input = parsed.data;
    const client = await options.pool.connect();
    try {
      await client.query("BEGIN");
      const role = await outletRole(client, request.user.sub, request.user.tenantId, input.outletId);
      if (role !== "owner") {
        await client.query("ROLLBACK");
        return reply.code(403).send({ error: role ? "owner_required" : "outlet_forbidden" });
      }
      if (input.productId) {
        const linkedProduct = await client.query(
          "SELECT 1 FROM products WHERE id = $1 AND tenant_id = $2 AND is_active = true " +
            "AND (outlet_id = $3 OR outlet_id IS NULL) FOR SHARE",
          [input.productId, request.user.tenantId, input.outletId],
        );
        if (!linkedProduct.rowCount) {
          await client.query("ROLLBACK");
          return reply.code(422).send({ error: "product_not_available_for_outlet" });
        }
      }
      const inserted = await client.query<{ id: string }>(
        "INSERT INTO inventory_items (tenant_id, outlet_id, product_id, sku, name, unit, quantity_on_hand, reorder_level, average_unit_cost) " +
          "VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING id::text AS id",
        [request.user.tenantId, input.outletId, input.productId ?? null, input.sku ?? null, input.name, input.unit,
         input.initialQuantity, input.reorderLevel, input.averageUnitCost],
      );
      const id = inserted.rows[0]!.id;
      if (input.initialQuantity > 0) {
        await client.query(
          "INSERT INTO inventory_movements (tenant_id, outlet_id, inventory_item_id, movement_type, quantity_delta, unit_cost, idempotency_key, actor_user_id, note) " +
            "VALUES ($1, $2, $3, 'receipt', $4, $5, $6, $7, 'Initial stock')",
          [request.user.tenantId, input.outletId, id, input.initialQuantity, input.averageUnitCost,
           "initial:" + id, request.user.sub],
        );
      }
      await audit(client, request.user.tenantId, input.outletId, request.user.sub, "inventory_item.created", "inventory_item", id, {
        name: input.name, initialQuantity: input.initialQuantity,
      });
      await client.query("COMMIT");
      return reply.code(201).send({ id });
    } catch (error) {
      await client.query("ROLLBACK").catch(() => undefined);
      if ((error as { code?: string }).code === "23505") return reply.code(409).send({ error: "duplicate_inventory_sku" });
      app.log.error({ err: error }, "Inventory item create failed");
      return reply.code(500).send({ error: "internal_error" });
    } finally { client.release(); }
  });

  app.get("/inventory/reconcile", {
    preHandler: async (request, reply) => {
      try { await request.jwtVerify(); } catch { return reply.code(401).send({ error: "unauthorized" }); }
    },
  }, async (request, reply) => {
    const parsedOutlet = uuid.safeParse((request.query as { outletId?: string }).outletId);
    if (!parsedOutlet.success) return invalid(reply);
    const client = await options.pool.connect();
    try {
      const role = await outletRole(client, request.user.sub, request.user.tenantId, parsedOutlet.data);
      if (!role) return reply.code(403).send({ error: "outlet_forbidden" });
      if (role !== "owner") return reply.code(403).send({ error: "owner_required" });
      const result = await client.query(
        "SELECT i.id::text AS id, i.product_id::text AS \"productId\", i.name, i.unit, " +
          "i.quantity_on_hand::float8 AS \"quantityOnHand\", i.updated_at AS \"updatedAt\", " +
          "COALESCE(SUM(m.quantity_delta), 0)::float8 AS \"movementTotal\", " +
          "COUNT(m.id)::int AS \"movementCount\", MAX(m.created_at) AS \"lastMovementAt\", " +
          "(i.quantity_on_hand = COALESCE(SUM(m.quantity_delta), 0)) AS \"ledgerMatches\", " +
          "i.quantity_on_hand - COALESCE(SUM(m.quantity_delta), 0) AS \"unexplainedDelta\" " +
          "FROM inventory_items i LEFT JOIN inventory_movements m " +
          "ON m.inventory_item_id = i.id AND m.tenant_id = i.tenant_id AND m.outlet_id = i.outlet_id " +
          "WHERE i.tenant_id = $1 AND i.outlet_id = $2 GROUP BY i.id ORDER BY i.name",
        [request.user.tenantId, parsedOutlet.data],
      );
      return { outletId: parsedOutlet.data, items: result.rows };
    } finally { client.release(); }
  });

  app.post("/inventory/movements", {
    preHandler: async (request, reply) => {
      try { await request.jwtVerify(); } catch { return reply.code(401).send({ error: "unauthorized" }); }
    },
  }, async (request, reply) => {
    const parsed = movementInput.safeParse(request.body);
    if (!parsed.success) return invalid(reply);
    const input = parsed.data;
    const idempotencyKey = request.headers["idempotency-key"];
    if (typeof idempotencyKey !== "string" || idempotencyKey.trim().length < 8 || idempotencyKey.length > 128) {
      return reply.code(400).send({ error: "idempotency_key_required" });
    }
    if (["receipt", "return", "transfer_in"].includes(input.movementType) && input.quantityDelta < 0) return invalid(reply);
    if (["sale", "waste", "transfer_out"].includes(input.movementType) && input.quantityDelta > 0) return invalid(reply);

    const client = await options.pool.connect();
    try {
      await client.query("BEGIN");
      const role = await outletRole(client, request.user.sub, request.user.tenantId, input.outletId);
      if (role !== "owner") {
        await client.query("ROLLBACK");
        return reply.code(403).send({ error: role ? "owner_required" : "outlet_forbidden" });
      }
      await client.query("SELECT pg_advisory_xact_lock(hashtextextended($1, 0))", [
        request.user.tenantId + ":" + input.outletId + ":" + idempotencyKey,
      ]);
      const payloadHash = createHash("sha256").update(JSON.stringify({
        outletId: input.outletId,
        inventoryItemId: input.inventoryItemId,
        movementType: input.movementType,
        quantityDelta: input.quantityDelta,
        unitCost: input.unitCost,
        sourceType: input.sourceType ?? null,
        sourceId: input.sourceId ?? null,
        note: input.note ?? null,
      })).digest("hex");
      const prior = await client.query<{
        id: string; inventory_item_id: string; quantity_delta: string; movement_type: string;
        unit_cost: string; source_type: string | null; source_id: string | null; note: string | null;
        payload_hash: string | null;
      }>(
        "SELECT id::text AS id, inventory_item_id::text AS inventory_item_id, quantity_delta::text, movement_type, " +
          "unit_cost::text, source_type, source_id, note, payload_hash " +
          "FROM inventory_movements WHERE tenant_id = $1 AND outlet_id = $2 AND idempotency_key = $3",
        [request.user.tenantId, input.outletId, idempotencyKey],
      );
      if (prior.rows[0]) {
        const old = prior.rows[0];
        await client.query("ROLLBACK");
        const samePayload = old.payload_hash
          ? old.payload_hash === payloadHash
          : old.inventory_item_id === input.inventoryItemId &&
            Number(old.quantity_delta) === input.quantityDelta &&
            old.movement_type === input.movementType &&
            Number(old.unit_cost) === input.unitCost &&
            old.source_type === (input.sourceType ?? null) &&
            old.source_id === (input.sourceId ?? null) &&
            old.note === (input.note ?? null);
        if (!samePayload) return reply.code(409).send({ error: "idempotency_key_payload_mismatch" });
        const current = await options.pool.query<{ quantity_on_hand: string }>(
          "SELECT quantity_on_hand::text FROM inventory_items WHERE id = $1 AND tenant_id = $2 AND outlet_id = $3",
          [input.inventoryItemId, request.user.tenantId, input.outletId],
        );
        return reply.code(200).send({
          id: old.id, replayed: true,
          quantityOnHand: current.rows[0] ? Number(current.rows[0].quantity_on_hand) : null,
        });
      }
      const updated = await client.query<{ id: string; quantity_on_hand: string }>(
        "UPDATE inventory_items SET quantity_on_hand = quantity_on_hand + $1, updated_at = now() " +
          "WHERE id = $2 AND tenant_id = $3 AND outlet_id = $4 AND is_active = true " +
          "AND quantity_on_hand + $1 >= 0 RETURNING id::text AS id, quantity_on_hand::text",
        [input.quantityDelta, input.inventoryItemId, request.user.tenantId, input.outletId],
      );
      if (!updated.rowCount) {
        await client.query("ROLLBACK");
        const exists = await client.query(
          "SELECT 1 FROM inventory_items WHERE id = $1 AND tenant_id = $2 AND outlet_id = $3",
          [input.inventoryItemId, request.user.tenantId, input.outletId],
        );
        return exists.rowCount
          ? reply.code(409).send({ error: "insufficient_stock" })
          : reply.code(404).send({ error: "inventory_item_not_found" });
      }
      const movement = await client.query<{ id: string }>(
        "INSERT INTO inventory_movements (tenant_id, outlet_id, inventory_item_id, movement_type, quantity_delta, unit_cost, source_type, source_id, idempotency_key, actor_user_id, note, payload_hash) " +
          "VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12) RETURNING id::text AS id",
        [request.user.tenantId, input.outletId, input.inventoryItemId, input.movementType,
         input.quantityDelta, input.unitCost, input.sourceType ?? null, input.sourceId ?? null,
         idempotencyKey, request.user.sub, input.note ?? null, payloadHash],
      );
      await audit(client, request.user.tenantId, input.outletId, request.user.sub, "inventory.movement", "inventory_item", input.inventoryItemId, {
        movementId: movement.rows[0]!.id, movementType: input.movementType,
        quantityDelta: input.quantityDelta, quantityOnHand: Number(updated.rows[0]!.quantity_on_hand),
      });
      await client.query("COMMIT");
      return reply.code(201).send({
        id: movement.rows[0]!.id,
        quantityOnHand: Number(updated.rows[0]!.quantity_on_hand),
      });
    } catch (error) {
      await client.query("ROLLBACK").catch(() => undefined);
      app.log.error({ err: error }, "Inventory movement failed");
      return reply.code(500).send({ error: "internal_error" });
    } finally { client.release(); }
  });
};