#!/usr/bin/env bash

# Source the .env file to load configuration variables
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

DB_CONTAINER_NAME="shared_mysql"
MYSQL_USER="${MYSQL_USER:-user}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-password}"
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-rootpassword}" # Used for administrative tasks like creating dumps
DB_NAME="${MYSQL_DATABASE_NAME:-mydatabase}" # Specific database to backup

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${DB_NAME}_mysql_backup_${TIMESTAMP}.sql"
COMPRESSED_BACKUP_FILE="${BACKUP_FILE}.gz"
CONTAINER_TEMP_PATH="/tmp/${BACKUP_FILE}"

echo "Backing up MySQL database: ${DB_NAME} from ${DB_CONTAINER_NAME}"

# 1. Generate SQL dump inside the container
# Use MYSQL_PWD environment variable for authentication within docker exec
docker exec -e MYSQL_PWD="${MYSQL_PASSWORD}" \
  "$DB_CONTAINER_NAME" mysqldump -u "$MYSQL_USER" "$DB_NAME" > "${BACKUP_DIR}/${BACKUP_FILE}"

if [ $? -eq 0 ]; then
    echo "MySQL dump created: ${BACKUP_DIR}/${BACKUP_FILE}"
else
    echo "ERROR: MySQL dump failed for ${DB_NAME}!"
    exit 1
fi

# 2. Compress the backup file on the host
gzip "${BACKUP_DIR}/${BACKUP_FILE}"

if [ $? -eq 0 ]; then
    echo "MySQL backup compressed: ${BACKUP_DIR}/${COMPRESSED_BACKUP_FILE}"
else
    echo "ERROR: MySQL compression failed!"
    exit 1
fi

echo "MySQL backup complete."

# --- Restore Instructions ---
# To restore a MySQL backup:
# 1. Copy the compressed backup file to a temp location on your host, then decompress it:
#    cp "${BACKUP_DIR}/${COMPRESSED_BACKUP_FILE}" /tmp/
#    gunzip "/tmp/${COMPRESSED_BACKUP_FILE}"
#    SQL_FILE="/tmp/${BACKUP_FILE}"
#
# 2. Copy the decompressed SQL file into the running container:
#    docker cp "$SQL_FILE" "${DB_CONTAINER_NAME}:/tmp/"
#
# 3. Execute mysql client inside the container to restore.
#    (Optional but recommended: Drop and recreate database for a clean restore)
#    docker exec -e MYSQL_PWD="${MYSQL_ROOT_PASSWORD}" "$DB_CONTAINER_NAME" mysql -u root -e "DROP DATABASE IF EXISTS ${DB_NAME};"
#    docker exec -e MYSQL_PWD="${MYSQL_ROOT_PASSWORD}" "$DB_CONTAINER_NAME" mysql -u root -e "CREATE DATABASE ${DB_NAME};"
#    docker exec -i -e MYSQL_PWD="${MYSQL_PASSWORD}" "$DB_CONTAINER_NAME" sh -c "mysql -u \"$MYSQL_USER\" \"$DB_NAME\" < /tmp/${BACKUP_FILE}"
#
# 4. Clean up temp file in container (optional)
#    docker exec "$DB_CONTAINER_NAME" rm "/tmp/${BACKUP_FILE}"
#
# 5. Clean up temp file on host (optional)
#    rm "$SQL_FILE"
