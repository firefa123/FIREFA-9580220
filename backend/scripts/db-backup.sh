#!/usr/bin/env sh
set -eu
: "${DATABASE_URL:?DATABASE_URL is required}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"
mkdir -p "$BACKUP_DIR"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
FILE="$BACKUP_DIR/firefa-$STAMP.dump"
pg_dump --format=custom --no-owner --no-acl "$DATABASE_URL" --file "$FILE"
printf 'Backup created: %s\n' "$FILE"
