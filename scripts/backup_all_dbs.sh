#!/usr/bin/env bash

# Source the .env file to load configuration variables
# This assumes the script is run from the project root or .env is in a known location
if [ -f "$(dirname "$0")/../.env" ]; then
    source "$(dirname "$0")/../.env"
else
    echo "Error: .env file not found. Please ensure it's in the project root."
    exit 1
fi

# Ensure BACKUP_DIR is set and exists
if [ -z "$BACKUP_DIR" ]; then
    echo "Error: BACKUP_DIR is not set in .env. Please define it."
    exit 1
fi
mkdir -p "$BACKUP_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${BACKUP_DIR}/backup_log_${TIMESTAMP}.txt"

echo "--- Starting All Database Backups at $(date) ---" | tee -a "$LOG_FILE"
echo "Backup directory: $BACKUP_DIR" | tee -a "$LOG_FILE"

# --- Call individual backup scripts ---
echo "" | tee -a "$LOG_FILE"
echo "Backing up PostgreSQL..." | tee -a "$LOG_FILE"
"$(dirname "$0")/backup_postgres.sh" >> "$LOG_FILE" 2>&1 || echo "PostgreSQL backup FAILED!" | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "Backing up Redis..." | tee -a "$LOG_FILE"
"$(dirname "$0")/backup_redis.sh" >> "$LOG_FILE" 2>&1 || echo "Redis backup FAILED!" | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "Backing up MongoDB..." | tee -a "$LOG_FILE"
"$(dirname "$0")/backup_mongodb.sh" >> "$LOG_FILE" 2>&1 || echo "MongoDB backup FAILED!" | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "Backing up MySQL..." | tee -a "$LOG_FILE"
"$(dirname "$0")/backup_mysql.sh" >> "$LOG_FILE" 2>&1 || echo "MySQL backup FAILED!" | tee -a "$LOG_FILE"

# --- Clean up old local backups ---
if [ -n "$BACKUP_RETENTION_DAYS" ] && [ "$BACKUP_RETENTION_DAYS" -ge 0 ]; then
    echo "" | tee -a "$LOG_FILE"
    echo "Cleaning up old local backups (keeping ${BACKUP_RETENTION_DAYS} days)..." | tee -a "$LOG_FILE"
    find "$BACKUP_DIR" -type f -name "*.gz" -mtime +"$BACKUP_RETENTION_DAYS" -delete
    echo "Cleanup complete." | tee -a "$LOG_FILE"
else
    echo "BACKUP_RETENTION_DAYS not set or invalid. Skipping local backup cleanup." | tee -a "$LOG_FILE"
fi

echo "" | tee -a "$LOG_FILE"
echo "--- All Database Backups Finished at $(date) ---" | tee -a "$LOG_FILE"
