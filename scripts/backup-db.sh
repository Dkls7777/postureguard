#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/dossa/projects/postureguard"
BACKUP_DIR="$PROJECT_DIR/backups"
KEEP=7

mkdir -p "$BACKUP_DIR"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
OUTFILE="$BACKUP_DIR/postureguard-$TIMESTAMP.sql.gz"

# Dump the database from the running Postgres container, then gzip it
docker compose -f "$PROJECT_DIR/docker-compose.yml" exec -T db \
  pg_dump -U postureguard postureguard | gzip > "$OUTFILE"

echo "Backup written: $OUTFILE"

# Rotation: keep only the most recent $KEEP backups, delete the rest
ls -1t "$BACKUP_DIR"/postureguard-*.sql.gz | tail -n +$((KEEP+1)) | xargs -r rm -f
echo "Rotation done, keeping last $KEEP backups"
