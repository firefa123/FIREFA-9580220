CREATE TABLE staff_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  outlet_id uuid NOT NULL,
  staff_code text NOT NULL,
  display_name text NOT NULL CHECK (length(trim(display_name)) BETWEEN 2 AND 120),
  pin_hash text NOT NULL,
  pin_failed_attempts integer NOT NULL DEFAULT 0 CHECK (pin_failed_attempts BETWEEN 0 AND 5),
  pin_locked_until timestamptz,
  expected_start_time time,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (outlet_id, tenant_id) REFERENCES outlets(id, tenant_id) ON DELETE RESTRICT,
  UNIQUE (tenant_id, outlet_id, staff_code),
  UNIQUE (id, tenant_id, outlet_id)
);

CREATE INDEX staff_members_outlet_status_idx
  ON staff_members (tenant_id, outlet_id, status, display_name);

CREATE TABLE staff_attendance (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  outlet_id uuid NOT NULL,
  staff_id uuid NOT NULL,
  work_date date NOT NULL,
  check_in_at timestamptz NOT NULL DEFAULT now(),
  check_in_latitude numeric(10, 7) NOT NULL,
  check_in_longitude numeric(10, 7) NOT NULL,
  check_in_distance_m integer NOT NULL CHECK (check_in_distance_m >= 0),
  late_minutes integer CHECK (late_minutes IS NULL OR late_minutes >= 0),
  check_out_at timestamptz,
  check_out_latitude numeric(10, 7),
  check_out_longitude numeric(10, 7),
  check_out_distance_m integer CHECK (check_out_distance_m IS NULL OR check_out_distance_m >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (outlet_id, tenant_id) REFERENCES outlets(id, tenant_id) ON DELETE RESTRICT,
  FOREIGN KEY (staff_id, tenant_id, outlet_id)
    REFERENCES staff_members(id, tenant_id, outlet_id) ON DELETE RESTRICT,
  UNIQUE (tenant_id, outlet_id, staff_id, work_date),
  CHECK ((check_out_at IS NULL AND check_out_latitude IS NULL AND check_out_longitude IS NULL AND check_out_distance_m IS NULL)
      OR (check_out_at IS NOT NULL AND check_out_latitude IS NOT NULL AND check_out_longitude IS NOT NULL AND check_out_distance_m IS NOT NULL)),
  CHECK (check_out_at IS NULL OR check_out_at >= check_in_at)
);

CREATE INDEX staff_attendance_outlet_date_idx
  ON staff_attendance (tenant_id, outlet_id, work_date DESC);

CREATE INDEX staff_attendance_staff_date_idx
  ON staff_attendance (tenant_id, staff_id, work_date DESC);
