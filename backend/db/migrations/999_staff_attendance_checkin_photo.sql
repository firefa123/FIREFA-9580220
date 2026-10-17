-- Store a compressed camera image with each new staff check-in.
-- Historical attendance records remain valid and have no photo.
ALTER TABLE staff_attendance
  ADD COLUMN IF NOT EXISTS check_in_photo bytea;

ALTER TABLE staff_attendance
  ADD COLUMN IF NOT EXISTS check_in_photo_mime_type text;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'staff_attendance_photo_mime_type_check'
  ) THEN
    ALTER TABLE staff_attendance
      ADD CONSTRAINT staff_attendance_photo_mime_type_check
      CHECK (check_in_photo_mime_type IS NULL OR check_in_photo_mime_type IN ('image/jpeg', 'image/png'));
  END IF;
END
$$;
