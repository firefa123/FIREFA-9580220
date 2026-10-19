CREATE TABLE platform_admin_audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_user_id uuid REFERENCES platform_admins(user_id) ON DELETE SET NULL,
  action text NOT NULL,
  resource_type text NOT NULL,
  resource_id text,
  tenant_id uuid REFERENCES tenants(id) ON DELETE SET NULL,
  outlet_id uuid REFERENCES outlets(id) ON DELETE SET NULL,
  changes jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX platform_admin_audit_created_idx ON platform_admin_audit_logs(created_at DESC);
CREATE INDEX platform_admin_audit_tenant_created_idx ON platform_admin_audit_logs(tenant_id, created_at DESC);
