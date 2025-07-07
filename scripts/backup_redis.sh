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

REDIS_CONTAINER_NAME="shared_redis"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="redis_backup_${TIMESTAMP}.rdb"
COMPRESSED_BACKUP_FILE="${BACKUP_FILE}.gz"
CONTAINER_DATA_PATH="/data/dump.rdb" # Default Redis RDB file location

echo "Backing up Redis from container: ${REDIS_CONTAINER_NAME}"

# 1. Trigger a Redis BGSAVE (Background Save) to ensure data is flushed to disk
echo "Triggering Redis BGSAVE..."
docker exec "$REDIS_CONTAINER_NAME" redis-cli BGSAVE

# Give Redis a moment to complete the save operation
# In a real production scenario, you might want to poll for BGSAVE completion
sleep 5

# 2. Copy the .rdb file from the container to the host
docker cp "$REDIS_CONTAINER_NAME":"$CONTAINER_DATA_PATH" "${BACKUP_DIR}/${BACKUP_FILE}"

if [ $? -eq 0 ]; then
    echo "Redis RDB file copied: ${BACKUP_DIR}/${BACKUP_FILE}"
else
    echo "ERROR: Redis RDB copy failed!"
    exit 1
fi

# 3. Compress the backup file on the host
gzip "${BACKUP_DIR}/${BACKUP_FILE}"

if [ $? -eq 0 ]; then
    echo "Redis backup compressed: ${BACKUP_DIR}/${COMPRESSED_BACKUP_FILE}"
else
    echo "ERROR: Redis compression failed!"
    exit 1
fi

echo "Redis backup complete."

# --- Restore Instructions ---
# To restore a Redis backup:
# WARNING: This will overwrite current Redis data.
# 1. Stop the Redis service:
#    docker compose stop redis
#
# 2. Decompress the backup file on your host if it's compressed:
#    gunzip "${BACKUP_DIR}/your_redis_backup_file.rdb.gz"
#    UNCOMPRESSED_FILE="${BACKUP_DIR}/your_redis_backup_file.rdb"
#
# 3. Use a temporary container to copy the decompressed RDB file into the volume.
#    This is safer than directly manipulating the Docker volume's host path.
#    docker run --rm \
#      -v redis_data:/data \
#      -v "$(dirname "$UNCOMPRESSED_FILE")":/backup_src \
#      alpine \
#      cp /backup_src/"$(basename "$UNCOMPRESSED_FILE")" /data/dump.rdb
#
# 4. Start the Redis service:
#    docker compose start redis
#
# 5. Clean up the decompressed file on host (optional)
#    rm "$UNCOMPRESSED_FILE"
