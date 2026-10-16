ALTER TABLE payments
  ADD COLUMN IF NOT EXISTS verified_at timestamptz,
  ADD COLUMN IF NOT EXISTS verified_by uuid REFERENCES users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS failure_reason text;

ALTER TABLE refunds
  ADD COLUMN IF NOT EXISTS verified_at timestamptz,
  ADD COLUMN IF NOT EXISTS verified_by uuid REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE accounts_receivable
  ADD COLUMN IF NOT EXISTS idempotency_key text;

CREATE UNIQUE INDEX IF NOT EXISTS accounts_receivable_tenant_idempotency_unique
  ON accounts_receivable (tenant_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;

CREATE TABLE IF NOT EXISTS payment_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  outlet_id uuid NOT NULL,
  order_id uuid NOT NULL,
  payment_id uuid REFERENCES payments(id) ON DELETE RESTRICT,
  refund_id uuid REFERENCES refunds(id) ON DELETE RESTRICT,
  event_type text NOT NULL CHECK (event_type IN (
    'payment.reported', 'payment.verified', 'payment.failed',
    'bon.reported', 'refund.reported', 'refund.verified', 'refund.failed'
  )),
  status text NOT NULL CHECK (status IN ('reported', 'pending', 'succeeded', 'failed', 'open', 'partially_paid', 'paid', 'refunded')),
  amount numeric(14,2) NOT NULL CHECK (amount >= 0),
  method text,
  actor_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (outlet_id, tenant_id) REFERENCES outlets(id, tenant_id) ON DELETE RESTRICT,
  FOREIGN KEY (order_id, tenant_id, outlet_id)
    REFERENCES orders(id, tenant_id, outlet_id) ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS payment_events_order_created_idx
  ON payment_events (tenant_id, outlet_id, order_id, created_at DESC);

CREATE INDEX IF NOT EXISTS payment_events_tenant_created_idx
  ON payment_events (tenant_id, created_at DESC);
