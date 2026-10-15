ALTER TABLE outlet_memberships
  ADD COLUMN tenant_id uuid;

UPDATE outlet_memberships om
SET tenant_id = o.tenant_id
FROM outlets o
WHERE o.id = om.outlet_id;

ALTER TABLE outlet_memberships
  ALTER COLUMN tenant_id SET NOT NULL;

ALTER TABLE outlet_memberships
  ADD CONSTRAINT outlet_memberships_outlet_tenant_fk
  FOREIGN KEY (outlet_id, tenant_id)
  REFERENCES outlets(id, tenant_id) ON DELETE CASCADE;

ALTER TABLE outlet_memberships
  ADD CONSTRAINT outlet_memberships_tenant_user_fk
  FOREIGN KEY (tenant_id, user_id)
  REFERENCES tenant_memberships(tenant_id, user_id) ON DELETE CASCADE;

ALTER TABLE refresh_tokens
  ADD CONSTRAINT refresh_tokens_tenant_membership_fk
  FOREIGN KEY (tenant_id, user_id)
  REFERENCES tenant_memberships(tenant_id, user_id) ON DELETE CASCADE;

ALTER TABLE orders
  ADD CONSTRAINT orders_id_tenant_unique UNIQUE (id, tenant_id);

ALTER TABLE sync_receipts
  DROP CONSTRAINT sync_receipts_global_order_id_fkey;

ALTER TABLE sync_receipts
  ADD CONSTRAINT sync_receipts_order_tenant_fk
  FOREIGN KEY (global_order_id, tenant_id)
  REFERENCES orders(id, tenant_id) ON DELETE RESTRICT;

ALTER TABLE tenant_memberships
  DROP CONSTRAINT tenant_memberships_role_check;

ALTER TABLE tenant_memberships
  ADD CONSTRAINT tenant_memberships_role_check
  CHECK (role IN ('owner', 'cashier', 'staff'));