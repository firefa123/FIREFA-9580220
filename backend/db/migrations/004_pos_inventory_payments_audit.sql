CREATE TABLE menu_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  outlet_id uuid,
  name text NOT NULL CHECK (length(trim(name)) > 0),
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (outlet_id, tenant_id) REFERENCES outlets(id, tenant_id) ON DELETE RESTRICT,
  UNIQUE (id, tenant_id, outlet_id)
);

CREATE TABLE products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  outlet_id uuid,
  category_id uuid,
  sku text,
  name text NOT NULL CHECK (length(trim(name)) > 0),
  description text,
  unit_price numeric(14,2) NOT NULL CHECK (unit_price >= 0),
  tax_rate numeric(7,4) NOT NULL DEFAULT 0 CHECK (tax_rate BETWEEN 0 AND 100),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (outlet_id, tenant_id) REFERENCES outlets(id, tenant_id) ON DELETE RESTRICT,
  FOREIGN KEY (category_id, tenant_id, outlet_id)
    REFERENCES menu_categories(id, tenant_id, outlet_id) ON DELETE RESTRICT,
  UNIQUE (id, tenant_id, outlet_id)
);

CREATE UNIQUE INDEX products_tenant_outlet_sku_unique
  ON products (tenant_id, outlet_id, sku)
  WHERE sku IS NOT NULL;

CREATE INDEX products_tenant_active_idx ON products (tenant_id, is_active, name);

CREATE TABLE inventory_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  outlet_id uuid NOT NULL,
  sku text,
  name text NOT NULL CHECK (length(trim(name)) > 0),
  unit text NOT NULL DEFAULT 'unit',
  quantity_on_hand numeric(16,3) NOT NULL DEFAULT 0,
  reorder_level numeric(16,3) NOT NULL DEFAULT 0 CHECK (reorder_level >= 0),
  average_unit_cost numeric(14,2) NOT NULL DEFAULT 0 CHECK (average_unit_cost >= 0),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (outlet_id, tenant_id) REFERENCES outlets(id, tenant_id) ON DELETE RESTRICT,
  UNIQUE (id, tenant_id, outlet_id),
  UNIQUE (tenant_id, outlet_id, sku)
);

CREATE INDEX inventory_items_outlet_name_idx ON inventory_items (tenant_id, outlet_id, name);

CREATE TABLE inventory_movements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  outlet_id uuid NOT NULL,
  inventory_item_id uuid NOT NULL,
  movement_type text NOT NULL CHECK (movement_type IN ('receipt', 'sale', 'adjustment', 'waste', 'return', 'transfer_in', 'transfer_out')),
  quantity_delta numeric(16,3) NOT NULL CHECK (quantity_delta <> 0),
  unit_cost numeric(14,2) NOT NULL DEFAULT 0 CHECK (unit_cost >= 0),
  source_type text,
  source_id text,
  idempotency_key text NOT NULL,
  actor_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (outlet_id, tenant_id) REFERENCES outlets(id, tenant_id) ON DELETE RESTRICT,
  FOREIGN KEY (inventory_item_id, tenant_id, outlet_id)
    REFERENCES inventory_items(id, tenant_id, outlet_id) ON DELETE RESTRICT,
  UNIQUE (tenant_id, outlet_id, idempotency_key)
);

CREATE INDEX inventory_movements_item_created_idx
  ON inventory_movements (tenant_id, outlet_id, inventory_item_id, created_at DESC);

CREATE TABLE order_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  outlet_id uuid NOT NULL,
  order_id uuid NOT NULL,
  product_id uuid,
  product_name text NOT NULL CHECK (length(trim(product_name)) > 0),
  quantity integer NOT NULL CHECK (quantity > 0),
  unit_price numeric(14,2) NOT NULL CHECK (unit_price >= 0),
  line_total numeric(16,2) NOT NULL CHECK (line_total >= 0),
  details text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (order_id, tenant_id, outlet_id)
    REFERENCES orders(id, tenant_id, outlet_id) ON DELETE RESTRICT,
  FOREIGN KEY (product_id, tenant_id, outlet_id)
    REFERENCES products(id, tenant_id, outlet_id) ON DELETE RESTRICT
);

CREATE INDEX order_items_order_idx ON order_items (tenant_id, order_id);

CREATE TABLE payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  outlet_id uuid NOT NULL,
  order_id uuid NOT NULL,
  method text NOT NULL CHECK (method IN ('cash', 'card', 'bank_transfer', 'ewallet', 'other')),
  amount numeric(14,2) NOT NULL CHECK (amount > 0),
  status text NOT NULL DEFAULT 'reported' CHECK (status IN ('reported', 'pending', 'succeeded', 'failed', 'refunded')),
  provider text,
  provider_reference text,
  idempotency_key text NOT NULL,
  actor_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (order_id, tenant_id, outlet_id)
    REFERENCES orders(id, tenant_id, outlet_id) ON DELETE RESTRICT,
  UNIQUE (tenant_id, idempotency_key)
);

CREATE INDEX payments_order_created_idx ON payments (tenant_id, order_id, created_at DESC);

CREATE TABLE audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  outlet_id uuid,
  actor_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  action text NOT NULL CHECK (length(trim(action)) > 0),
  resource_type text NOT NULL CHECK (length(trim(resource_type)) > 0),
  resource_id text,
  request_id text,
  changes jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (outlet_id, tenant_id) REFERENCES outlets(id, tenant_id) ON DELETE RESTRICT
);

CREATE INDEX audit_logs_tenant_created_idx ON audit_logs (tenant_id, created_at DESC);
CREATE INDEX audit_logs_resource_idx ON audit_logs (tenant_id, resource_type, resource_id, created_at DESC);

CREATE TABLE sync_devices (
  id uuid PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  outlet_id uuid NOT NULL,
  user_id uuid NOT NULL,
  device_name text NOT NULL DEFAULT 'FIREFA device',
  last_seen_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (outlet_id, tenant_id) REFERENCES outlets(id, tenant_id) ON DELETE RESTRICT,
  FOREIGN KEY (tenant_id, user_id) REFERENCES tenant_memberships(tenant_id, user_id) ON DELETE CASCADE,
  UNIQUE (id, tenant_id, outlet_id)
);

CREATE INDEX sync_devices_membership_idx ON sync_devices (tenant_id, user_id, revoked_at);