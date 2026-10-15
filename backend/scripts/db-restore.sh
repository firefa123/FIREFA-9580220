#!/usr/bin/env sh
set -eu
: "${DATABASE_URL:?DATABASE_URL is required}"
: "${BACKUP_FILE:?BACKUP_FILE must point to a custom-format pg_dump file}"
if [ ! -f "$BACKUP_FILE" ]; then
  printf 'Backup file not found: %s\n' "$BACKUP_FILE" >&2
  exit 1
fi
if [ "${CONFIRM_RESTORE:-}" != "YES" ]; then
  printf 'Restore replaces objects/data in the target database. Set CONFIRM_RESTORE=YES to continue.\n' >&2
  exit 2
fi
pg_restore --clean --if-exists --no-owner --no-acl --dbname "$DATABASE_URL" "$BACKUP_FILE"
printf 'Restore completed from: %s\n' "$BACKUP_FILE"
