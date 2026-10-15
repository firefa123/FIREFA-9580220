CREATE TABLE tenants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL CHECK (length(trim(name)) > 0),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE outlets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  code text NOT NULL,
  name text NOT NULL CHECK (length(trim(name)) > 0),
  address text,
  latitude numeric(10, 7),
  longitude numeric(10, 7),
  geofence_radius_m integer NOT NULL DEFAULT 100 CHECK (geofence_radius_m BETWEEN 25 AND 2000),
  timezone text NOT NULL DEFAULT 'Asia/Jakarta',
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, code),
  UNIQUE (id, tenant_id),
  CHECK ((latitude IS NULL AND longitude IS NULL) OR
         (latitude BETWEEN -90 AND 90 AND longitude BETWEEN -180 AND 180))
);

CREATE TABLE users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL UNIQUE,
  password_hash text NOT NULL,
  display_name text NOT NULL CHECK (length(trim(display_name)) > 0),
  avatar_url text,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'disabled', 'locked')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE tenant_memberships (
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  role text NOT NULL CHECK (role IN ('owner', 'cashier', 'staff', 'super_admin')),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'revoked')),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, user_id)
);

CREATE TABLE outlet_memberships (
  outlet_id uuid NOT NULL REFERENCES outlets(id) ON DELETE RESTRICT,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (outlet_id, user_id)
);

CREATE TABLE refresh_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash text NOT NULL UNIQUE,
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (expires_at > created_at)
);

CREATE INDEX refresh_tokens_user_active_idx
  ON refresh_tokens (user_id, expires_at)
  WHERE revoked_at IS NULL;

CREATE TABLE orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  outlet_id uuid NOT NULL,
  device_id uuid NOT NULL,
  client_order_id text NOT NULL,
  version integer NOT NULL DEFAULT 1 CHECK (version > 0),
  order_type text NOT NULL,
  status text NOT NULL,
  payment_status text NOT NULL DEFAULT 'unpaid',
  subtotal numeric(14, 2) NOT NULL DEFAULT 0 CHECK (subtotal >= 0),
  discount numeric(14, 2) NOT NULL DEFAULT 0 CHECK (discount >= 0),
  tax numeric(14, 2) NOT NULL DEFAULT 0 CHECK (tax >= 0),
  service_charge numeric(14, 2) NOT NULL DEFAULT 0 CHECK (service_charge >= 0),
  total numeric(14, 2) NOT NULL DEFAULT 0 CHECK (total >= 0),
  snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (outlet_id, tenant_id) REFERENCES outlets(id, tenant_id) ON DELETE RESTRICT,
  UNIQUE (tenant_id, device_id, client_order_id),
  UNIQUE (id, tenant_id, outlet_id)
);

CREATE INDEX orders_outlet_created_idx ON orders (outlet_id, created_at DESC);

CREATE TABLE sync_receipts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  event_id text NOT NULL,
  payload_hash text NOT NULL,
  server_reference uuid NOT NULL DEFAULT gen_random_uuid(),
  global_order_id uuid REFERENCES orders(id) ON DELETE RESTRICT,
  response_body jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, event_id)
);

CREATE TABLE order_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  outlet_id uuid NOT NULL,
  order_id uuid NOT NULL,
  event_id text NOT NULL,
  event_type text NOT NULL,
  actor_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  payload jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (outlet_id, tenant_id) REFERENCES outlets(id, tenant_id) ON DELETE RESTRICT,
  FOREIGN KEY (order_id, tenant_id, outlet_id) REFERENCES orders(id, tenant_id, outlet_id) ON DELETE RESTRICT,
  UNIQUE (tenant_id, event_id)
);

CREATE INDEX order_events_order_created_idx ON order_events (order_id, created_at);