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

DB_CONTAINER_NAME="shared_mongodb"
MONGO_USER="${MONGO_INITDB_ROOT_USERNAME:-mongouser}"
MONGO_PASSWORD="${MONGO_INITDB_ROOT_PASSWORD:-mongopassword}"
MONGO_ADMIN_DB="${MONGO_INITDB_DATABASE:-admin}" # Admin DB where root user is created

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR_NAME="mongodb_backup_${TIMESTAMP}"
FULL_BACKUP_PATH="${BACKUP_DIR}/${BACKUP_DIR_NAME}"
COMPRESSED_BACKUP_FILE="${FULL_BACKUP_PATH}.tar.gz"
CONTAINER_TEMP_PATH="/tmp/mongo_dump"

echo "Backing up MongoDB from container: ${DB_CONTAINER_NAME}"

# 1. Create a temporary dump directory inside the container
docker exec "$DB_CONTAINER_NAME" mkdir -p "$CONTAINER_TEMP_PATH"

# 2. Execute mongodump inside the container
# This dumps all databases. Use --db <dbname> to dump a specific database.
docker exec "$DB_CONTAINER_NAME" mongodump \
  --username "$MONGO_USER" \
  --password "$MONGO_PASSWORD" \
  --authenticationDatabase "$MONGO_ADMIN_DB" \
  --out "$CONTAINER_TEMP_PATH"

if [ $? -eq 0 ]; then
    echo "MongoDB dump created inside container at ${CONTAINER_TEMP_PATH}"
else
    echo "ERROR: MongoDB dump failed!"
    exit 1
fi

# 3. Copy the dump directory from the container to the host
docker cp "$DB_CONTAINER_NAME":"$CONTAINER_TEMP_PATH" "$FULL_BACKUP_PATH"

if [ $? -eq 0 ]; then
    echo "MongoDB dump copied to host: ${FULL_BACKUP_PATH}"
else
    echo "ERROR: MongoDB dump copy failed!"
    exit 1
fi

# 4. Remove the temporary dump directory inside the container
docker exec "$DB_CONTAINER_NAME" rm -rf "$CONTAINER_TEMP_PATH"

# 5. Compress the backup directory on the host
tar -czvf "$COMPRESSED_BACKUP_FILE" -C "${BACKUP_DIR}" "$BACKUP_DIR_NAME"

if [ $? -eq 0 ]; then
    echo "MongoDB backup compressed: ${COMPRESSED_BACKUP_FILE}"
else
    echo "ERROR: MongoDB compression failed!"
    exit 1
fi

# 6. Remove the uncompressed directory on the host after compression
rm -rf "$FULL_BACKUP_PATH"

echo "MongoDB backup complete."

# --- Restore Instructions ---
# To restore a MongoDB backup:
# WARNING: This will overwrite existing data in the target database.
# 1. Stop the MongoDB service if you need a clean restore point:
#    docker compose stop mongodb
#
# 2. Decompress the backup file on your host:
#    gunzip "${BACKUP_DIR}/your_mongodb_backup_file.tar.gz"
#    tar -xvf "${BACKUP_DIR}/your_mongodb_backup_file.tar" -C /tmp/
#    UNCOMPRESSED_DIR="/tmp/mongodb_backup_YYYYMMDD_HHMMSS" # Adjust this to the extracted folder name
#
# 3. Copy the decompressed dump directory into the running container:
#    docker cp "$UNCOMPRESSED_DIR" "${DB_CONTAINER_NAME}:/tmp/mongo_restore_temp"
#
# 4. Execute mongorestore inside the container.
#    You might want to drop existing collections/databases first, or use --drop.
#    docker exec "${DB_CONTAINER_NAME}" mongorestore \
#      --username "${MONGO_USER}" \
#      --password "${MONGO_PASSWORD}" \
#      --authenticationDatabase "${MONGO_ADMIN_DB}" \
#      --drop \
#      "/tmp/mongo_restore_temp"
#
# 5. Clean up temp directories (optional)
#    docker exec "${DB_CONTAINER_NAME}" rm -rf "/tmp/mongo_restore_temp"
#    rm -rf "$UNCOMPRESSED_DIR"
#
# 6. Start the MongoDB service if you stopped it:
#    docker compose start mongodb
