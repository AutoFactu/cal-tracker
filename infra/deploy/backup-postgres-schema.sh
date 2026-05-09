#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:?Usage: backup-postgres-schema.sh <dev|pro>}"

case "$ENVIRONMENT" in
  dev) SCHEMA="cal_tracker_dev" ;;
  pro) SCHEMA="cal_tracker_pro" ;;
  *) echo "Unknown environment: $ENVIRONMENT" >&2; exit 2 ;;
esac

BACKUP_DIR="/srv/cal-tracker/backups"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"

install -d -m 0750 "$BACKUP_DIR"
docker exec cal-tracker-postgres pg_dump -U cal_tracker -d cal_tracker --schema="$SCHEMA" --format=custom > "$BACKUP_DIR/${SCHEMA}_${TIMESTAMP}.dump"
echo "$BACKUP_DIR/${SCHEMA}_${TIMESTAMP}.dump"
