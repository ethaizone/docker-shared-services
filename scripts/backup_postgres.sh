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

DB_CONTAINER_NAME="shared_postgres"
DB_USER="${POSTGRES_USER:-user}"
DB_NAME="${POSTGRES_DB_NAME:-mydatabase}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${DB_NAME}_postgres_backup_${TIMESTAMP}.sql"
COMPRESSED_BACKUP_FILE="${BACKUP_FILE}.gz"
CONTAINER_TEMP_PATH="/tmp/${BACKUP_FILE}"

echo "Backing up PostgreSQL database: ${DB_NAME} from ${DB_CONTAINER_NAME}"

# 1. Generate SQL dump inside the container
# Use PGPASSWORD environment variable for authentication within docker exec
docker exec -e PGPASSWORD="${POSTGRES_PASSWORD:-password}" \
  "$DB_CONTAINER_NAME" pg_dump -U "$DB_USER" "$DB_NAME" > "${BACKUP_DIR}/${BACKUP_FILE}"

if [ $? -eq 0 ]; then
    echo "PostgreSQL dump created: ${BACKUP_DIR}/${BACKUP_FILE}"
else
    echo "ERROR: PostgreSQL dump failed for ${DB_NAME}!"
    exit 1
fi

# 2. Compress the backup file on the host
gzip "${BACKUP_DIR}/${BACKUP_FILE}"

if [ $? -eq 0 ]; then
    echo "PostgreSQL backup compressed: ${BACKUP_DIR}/${COMPRESSED_BACKUP_FILE}"
else
    echo "ERROR: PostgreSQL compression failed for ${DB_NAME}!"
    exit 1
fi

echo "PostgreSQL backup complete."

# --- Restore Instructions ---
# To restore a PostgreSQL backup:
# 1. Copy the compressed backup file to a temp location on your host, then decompress it:
#    cp "${BACKUP_DIR}/${COMPRESSED_BACKUP_FILE}" /tmp/
#    gunzip "/tmp/${COMPRESSED_BACKUP_FILE}"
#    SQL_FILE="/tmp/${BACKUP_FILE}"
#
# 2. Copy the decompressed SQL file into the running container:
#    docker cp "$SQL_FILE" "${DB_CONTAINER_NAME}:/tmp/"
#
# 3. Execute psql inside the container to restore.
#    (Optional but recommended: Drop and recreate database for a clean restore)
#    docker exec -e PGPASSWORD="${POSTGRES_PASSWORD:-password}" "$DB_CONTAINER_NAME" psql -U "$DB_USER" -c "DROP DATABASE IF EXISTS ${DB_NAME};"
#    docker exec -e PGPASSWORD="${POSTGRES_PASSWORD:-password}" "$DB_CONTAINER_NAME" psql -U "$DB_USER" -c "CREATE DATABASE ${DB_NAME};"
#    docker exec -i -e PGPASSWORD="${POSTGRES_PASSWORD:-password}" "$DB_CONTAINER_NAME" sh -c "psql -U \"$DB_USER\" \"$DB_NAME\" < /tmp/${BACKUP_FILE}"
#
# 4. Clean up temp file in container (optional)
#    docker exec "$DB_CONTAINER_NAME" rm "/tmp/${BACKUP_FILE}"
#
# 5. Clean up temp file on host (optional)
#    rm "$SQL_FILE"
