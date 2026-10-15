CREATE TABLE refunds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  outlet_id uuid NOT NULL,
  order_id uuid NOT NULL,
  amount numeric(14,2) NOT NULL CHECK (amount > 0),
  method text NOT NULL CHECK (length(trim(method)) > 0),
  reason text NOT NULL CHECK (length(trim(reason)) > 0),
  status text NOT NULL DEFAULT 'reported' CHECK (status IN ('reported', 'pending', 'succeeded', 'failed')),
  idempotency_key text NOT NULL,
  actor_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL,
  FOREIGN KEY (order_id, tenant_id, outlet_id)
    REFERENCES orders(id, tenant_id, outlet_id) ON DELETE RESTRICT,
  UNIQUE (tenant_id, idempotency_key)
);

CREATE INDEX refunds_order_created_idx ON refunds (tenant_id, order_id, created_at DESC);

CREATE TABLE accounts_receivable (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  outlet_id uuid NOT NULL,
  order_id uuid NOT NULL,
  customer_id text,
  customer_name text,
  original_amount numeric(14,2) NOT NULL CHECK (original_amount > 0),
  outstanding_amount numeric(14,2) NOT NULL CHECK (outstanding_amount BETWEEN 0 AND original_amount),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'partially_paid', 'paid', 'written_off')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (order_id, tenant_id, outlet_id)
    REFERENCES orders(id, tenant_id, outlet_id) ON DELETE RESTRICT,
  UNIQUE (tenant_id, order_id)
);

CREATE INDEX accounts_receivable_outlet_status_idx
  ON accounts_receivable (tenant_id, outlet_id, status, created_at DESC);