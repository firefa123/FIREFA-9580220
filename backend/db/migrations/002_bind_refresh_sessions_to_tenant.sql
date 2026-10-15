-- Refresh tokens are tenant-scoped so a token cannot silently switch tenant context.
-- No authenticated sessions existed before this migration; any legacy rows are invalidated.
DELETE FROM refresh_tokens;

ALTER TABLE refresh_tokens
  ADD COLUMN tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE;

ALTER TABLE refresh_tokens
  ALTER COLUMN tenant_id SET NOT NULL;

CREATE INDEX refresh_tokens_tenant_user_active_idx
  ON refresh_tokens (tenant_id, user_id, expires_at)
  WHERE revoked_at IS NULL;