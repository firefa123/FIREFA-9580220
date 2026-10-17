-- Operational tables required by authenticated POS sync and inventory APIs.
-- Applied transactionally by backend/src/db/migrate.ts.

ALTER TABLE refresh_tokens
  ADD COLUMN tenant_id uuid REFERENCES tenants(id) ON DELETE RESTRICT;

CREATE INDEX refresh_tokens_tenant_active_idx
  ON refresh_tokens (tenant_id, expires_at)
  WHERE revoked_at IS NULL;

CREATE TABLE menu_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  outlet_id uuid,
  name text NOT NULL CHECK (length(trim(name)) > 0),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (outlet_id, tenant_id) REFERENCES outlets(id, tenant_id) ON DELETE RESTRICT,
  UNIQUE (id, tenant_id),
  UNIQUE (id, tenant_id, outlet_id)
);

CREATE UNIQUE INDEX menu_categories_name_unique
  ON menu_categories (tenant_id, COALESCE(outlet_id, '00000000-0000-0000-0000-000000000000'::uuid), lower(name));

CREATE TABLE products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  outlet_id uuid,
  category_id uuid,
  sku text,
  name text NOT NULL CHECK (length(trim(name)) > 0),
  description text,
  unit_price numeric(14, 2) NOT NULL DEFAULT 0 CHECK (unit_price >= 0),
  tax_rate numeric(5, 2) NOT NULL DEFAULT 0 CHECK (tax_rate BETWEEN 0 AND 100),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (outlet_id, tenant_id) REFERENCES outlets(id, tenant_id) ON DELETE RESTRICT,
  FOREIGN KEY (category_id, tenant_id) REFERENCES menu_categories(id, tenant_id) ON DELETE RESTRICT,
  UNIQUE (id, tenant_id),
  UNIQUE (id, tenant_id, outlet_id)
);

CREATE UNIQUE INDEX products_outlet_sku_unique
  ON products (tenant_id, outlet_id, lower(sku))
  WHERE sku IS NOT NULL;

CREATE TABLE sync_devices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  outlet_id uuid NOT NULL,
  device_id uuid NOT NULL,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  device_name text NOT NULL DEFAULT 'FIREFA device',
  last_seen_at timestamptz NOT NULL DEFAULT now(),
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (outlet_id, tenant_id) REFERENCES outlets(id, tenant_id) ON DELETE RESTRICT,
  UNIQUE (tenant_id, device_id)
);

CREATE INDEX sync_devices_outlet_last_seen_idx
  ON sync_devices (tenant_id, outlet_id, last_seen_at DESC);

CREATE TABLE inventory_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  outlet_id uuid NOT NULL,
  product_id uuid,
  sku text,
  name text NOT NULL CHECK (length(trim(name)) > 0),
  unit text NOT NULL DEFAULT 'unit' CHECK (length(trim(unit)) > 0),
  quantity_on_hand numeric(14, 3) NOT NULL DEFAULT 0 CHECK (quantity_on_hand >= 0),
  reorder_level numeric(14, 3) NOT NULL DEFAULT 0 CHECK (reorder_level >= 0),
  average_unit_cost numeric(14, 2) NOT NULL DEFAULT 0 CHECK (average_unit_cost >= 0),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (outlet_id, tenant_id) REFERENCES outlets(id, tenant_id) ON DELETE RESTRICT,
  FOREIGN KEY (product_id, tenant_id) REFERENCES products(id, tenant_id) ON DELETE RESTRICT,
  UNIQUE (id, tenant_id, outlet_id)
);

CREATE UNIQUE INDEX inventory_items_outlet_sku_unique
  ON inventory_items (tenant_id, outlet_id, lower(sku))
  WHERE sku IS NOT NULL;

CREATE INDEX inventory_items_product_idx
  ON inventory_items (tenant_id, outlet_id, product_id)
  WHERE is_active = true;

CREATE TABLE inventory_movements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  outlet_id uuid NOT NULL,
  inventory_item_id uuid NOT NULL,
  movement_type text NOT NULL CHECK (movement_type IN ('receipt', 'sale', 'adjustment', 'waste', 'return', 'transfer_in', 'transfer_out')),
  quantity_delta numeric(14, 3) NOT NULL CHECK (quantity_delta <> 0),
  unit_cost numeric(14, 2) NOT NULL DEFAULT 0 CHECK (unit_cost >= 0),
  source_type text,
  source_id text,
  idempotency_key text NOT NULL CHECK (length(trim(idempotency_key)) >= 8),
  actor_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  note text,
  payload_hash text,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (outlet_id, tenant_id) REFERENCES outlets(id, tenant_id) ON DELETE RESTRICT,
  FOREIGN KEY (inventory_item_id, tenant_id, outlet_id)
    REFERENCES inventory_items(id, tenant_id, outlet_id) ON DELETE RESTRICT,
  UNIQUE (tenant_id, outlet_id, idempotency_key)
);

CREATE INDEX inventory_movements_item_created_idx
  ON inventory_movements (tenant_id, outlet_id, inventory_item_id, created_at);

CREATE INDEX inventory_movements_order_source_idx
  ON inventory_movements (tenant_id, outlet_id, source_type, source_id, inventory_item_id)
  WHERE source_id IS NOT NULL;

CREATE TABLE order_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  outlet_id uuid NOT NULL,
  order_id uuid NOT NULL,
  product_id uuid,
  product_name text NOT NULL CHECK (length(trim(product_name)) > 0),
  quantity integer NOT NULL CHECK (quantity > 0),
  unit_price numeric(14, 2) NOT NULL CHECK (unit_price >= 0),
  line_total numeric(14, 2) NOT NULL CHECK (line_total >= 0),
  details text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (outlet_id, tenant_id) REFERENCES outlets(id, tenant_id) ON DELETE RESTRICT,
  FOREIGN KEY (order_id, tenant_id, outlet_id)
    REFERENCES orders(id, tenant_id, outlet_id) ON DELETE RESTRICT,
  FOREIGN KEY (product_id, tenant_id)
    REFERENCES products(id, tenant_id) ON DELETE RESTRICT
);

CREATE INDEX order_items_order_idx ON order_items (tenant_id, order_id);

CREATE TABLE audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  outlet_id uuid NOT NULL,
  actor_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  action text NOT NULL CHECK (length(trim(action)) > 0),
  resource_type text NOT NULL CHECK (length(trim(resource_type)) > 0),
  resource_id text,
  changes jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (outlet_id, tenant_id) REFERENCES outlets(id, tenant_id) ON DELETE RESTRICT
);

CREATE INDEX audit_logs_outlet_created_idx ON audit_logs (tenant_id, outlet_id, created_at DESC);

CREATE TABLE payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  outlet_id uuid NOT NULL,
  order_id uuid NOT NULL,
  method text NOT NULL CHECK (length(trim(method)) > 0),
  amount numeric(14, 2) NOT NULL CHECK (amount >= 0),
  status text NOT NULL DEFAULT 'reported',
  provider text,
  provider_reference text,
  idempotency_key text NOT NULL CHECK (length(trim(idempotency_key)) >= 8),
  actor_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  verified_by uuid REFERENCES users(id) ON DELETE SET NULL,
  verified_at timestamptz,
  reference text,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (outlet_id, tenant_id) REFERENCES outlets(id, tenant_id) ON DELETE RESTRICT,
  FOREIGN KEY (order_id, tenant_id, outlet_id)
    REFERENCES orders(id, tenant_id, outlet_id) ON DELETE RESTRICT,
  UNIQUE (tenant_id, idempotency_key)
);

CREATE INDEX payments_order_status_idx ON payments (tenant_id, order_id, status);

CREATE TABLE refunds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  outlet_id uuid NOT NULL,
  order_id uuid NOT NULL,
  amount numeric(14, 2) NOT NULL CHECK (amount > 0),
  method text NOT NULL,
  reason text NOT NULL CHECK (length(trim(reason)) > 0),
  status text NOT NULL DEFAULT 'reported',
  idempotency_key text NOT NULL CHECK (length(trim(idempotency_key)) >= 8),
  actor_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  verified_by uuid REFERENCES users(id) ON DELETE SET NULL,
  verified_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (outlet_id, tenant_id) REFERENCES outlets(id, tenant_id) ON DELETE RESTRICT,
  FOREIGN KEY (order_id, tenant_id, outlet_id)
    REFERENCES orders(id, tenant_id, outlet_id) ON DELETE RESTRICT,
  UNIQUE (tenant_id, idempotency_key)
);

CREATE INDEX refunds_order_status_idx ON refunds (tenant_id, order_id, status);

CREATE TABLE payment_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  outlet_id uuid NOT NULL,
  order_id uuid NOT NULL,
  payment_id uuid REFERENCES payments(id) ON DELETE RESTRICT,
  refund_id uuid REFERENCES refunds(id) ON DELETE RESTRICT,
  event_type text NOT NULL,
  status text NOT NULL,
  amount numeric(14, 2) NOT NULL CHECK (amount >= 0),
  method text NOT NULL,
  actor_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (outlet_id, tenant_id) REFERENCES outlets(id, tenant_id) ON DELETE RESTRICT,
  FOREIGN KEY (order_id, tenant_id, outlet_id)
    REFERENCES orders(id, tenant_id, outlet_id) ON DELETE RESTRICT
);

CREATE INDEX payment_events_order_created_idx ON payment_events (tenant_id, order_id, created_at);

CREATE TABLE accounts_receivable (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  outlet_id uuid NOT NULL,
  order_id uuid NOT NULL,
  customer_id text,
  customer_name text,
  original_amount numeric(14, 2) NOT NULL CHECK (original_amount >= 0),
  outstanding_amount numeric(14, 2) NOT NULL CHECK (outstanding_amount >= 0),
  idempotency_key text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'partially_paid', 'paid', 'cancelled')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (outlet_id, tenant_id) REFERENCES outlets(id, tenant_id) ON DELETE RESTRICT,
  FOREIGN KEY (order_id, tenant_id, outlet_id)
    REFERENCES orders(id, tenant_id, outlet_id) ON DELETE RESTRICT,
  UNIQUE (tenant_id, order_id)
);

CREATE INDEX accounts_receivable_outlet_status_idx
  ON accounts_receivable (tenant_id, outlet_id, status);

CREATE UNIQUE INDEX accounts_receivable_idempotency_unique
  ON accounts_receivable (tenant_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;
