-- Stage 5: connect sellable catalog products to outlet stock and retain
-- a stable payload fingerprint for safe retries after network interruptions.
ALTER TABLE inventory_items
  ADD COLUMN product_id uuid;

ALTER TABLE inventory_items
  ADD CONSTRAINT inventory_items_product_tenant_fk
  FOREIGN KEY (product_id, tenant_id)
  REFERENCES products(id, tenant_id)
  ON DELETE RESTRICT;

CREATE UNIQUE INDEX inventory_items_product_outlet_unique
  ON inventory_items (tenant_id, outlet_id, product_id)
  WHERE product_id IS NOT NULL;

ALTER TABLE inventory_movements
  ADD COLUMN payload_hash text;

CREATE INDEX inventory_movements_reconcile_idx
  ON inventory_movements (tenant_id, outlet_id, inventory_item_id, created_at DESC, id);
