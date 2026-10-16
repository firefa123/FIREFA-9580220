-- Operational tenant memberships are limited to Owner and Cashier.
-- Fail closed if legacy memberships need an explicit owner-reviewed migration;
-- never silently promote an unsupported role to a more privileged role.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM tenant_memberships
    WHERE role NOT IN ('owner', 'cashier')
  ) THEN
    RAISE EXCEPTION
      'Unsupported tenant membership roles exist; review and remap them explicitly before applying migration 006';
  END IF;
END
$$;

ALTER TABLE tenant_memberships
  DROP CONSTRAINT IF EXISTS tenant_memberships_role_check;

ALTER TABLE tenant_memberships
  ADD CONSTRAINT tenant_memberships_role_check
  CHECK (role IN ('owner', 'cashier'));
