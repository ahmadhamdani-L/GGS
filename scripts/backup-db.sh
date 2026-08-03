#!/bin/bash
# GGS Werewolf — Database Backup Script
# Run via cron: 0 2 * * * /path/to/backup-db.sh
#
# Prerequisites: pg_dump, gzip, AWS CLI (for S3 upload) or rclone
# Environment: DB_HOST, DB_USER, DB_NAME, DB_PASSWORD, BACKUP_DIR, S3_BUCKET

set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/backups/ggs}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5433}"
DB_USER="${DB_USER:-postgres}"
DB_NAME="${DB_NAME:-ggs_werewolf}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
FILENAME="ggs_${DB_NAME}_${TIMESTAMP}.sql.gz"

mkdir -p "$BACKUP_DIR"

echo "[$(date)] Starting backup: $FILENAME"

# Dump and compress
PGPASSWORD="$DB_PASSWORD" pg_dump \
  -h "$DB_HOST" \
  -p "$DB_PORT" \
  -U "$DB_USER" \
  -d "$DB_NAME" \
  --format=plain \
  --no-owner \
  --no-acl \
  | gzip > "$BACKUP_DIR/$FILENAME"

FILESIZE=$(du -h "$BACKUP_DIR/$FILENAME" | cut -f1)
echo "[$(date)] Backup complete: $FILENAME ($FILESIZE)"

# Upload to S3 (if configured)
if [ -n "${S3_BUCKET:-}" ]; then
  aws s3 cp "$BACKUP_DIR/$FILENAME" "s3://$S3_BUCKET/backups/$FILENAME"
  echo "[$(date)] Uploaded to S3: s3://$S3_BUCKET/backups/$FILENAME"
fi

# Cleanup old local backups
find "$BACKUP_DIR" -name "ggs_*.sql.gz" -mtime +$RETENTION_DAYS -delete
echo "[$(date)] Cleaned backups older than $RETENTION_DAYS days"

echo "[$(date)] Done!"
