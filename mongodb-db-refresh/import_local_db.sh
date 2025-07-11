#!/bin/bash
set -e

echo "MongoDB Import Script Starting..."

# Load env vars
if [ -f .env ]; then
  set -a
  . ./.env
  set +a
else
  set -a
  . ./.env.example
  set +a
fi

DATA_DIR="data"
COLLECTIONS_DIR="$DATA_DIR/collections"

if [ "$LOCAL_DB_HOST" != "localhost" ] && [ "$LOCAL_DB_HOST" != "127.0.0.1" ]; then
  echo "[ERROR] Refusing to import unless LOCAL_DB_HOST is localhost or 127.0.0.1."
  exit 1
fi

# Build connection string
if [ -n "$LOCAL_DB_USER" ] && [ -n "$LOCAL_DB_PASSWORD" ]; then
  AUTH_PARAMS="--username $LOCAL_DB_USER --password $LOCAL_DB_PASSWORD --authenticationDatabase $LOCAL_DB_AUTH_SOURCE"
else
  AUTH_PARAMS=""
fi

# Function to process collections from MongoDB dump
process_collections() {
  # Check if collections directory exists
  if [ ! -d "$COLLECTIONS_DIR" ]; then
    echo "Collections directory not found at $COLLECTIONS_DIR"
    return 1
  fi

  # Debug: List the contents of the collections directory
  echo "Contents of $COLLECTIONS_DIR:"
  ls -la "$COLLECTIONS_DIR"

  # Get the database directory (usually the remote DB name)
  DB_DIR="$COLLECTIONS_DIR/$REMOTE_DB_NAME"

  if [ ! -d "$DB_DIR" ]; then
    echo "Database directory not found at $DB_DIR"
    return 1
  fi

  echo "Found database directory: $DB_DIR"
  echo "Contents of database directory:"
  ls -la "$DB_DIR"

  # Process each BSON file in the database directory
  for bson_file in "$DB_DIR"/*.bson; do
    if [ -f "$bson_file" ]; then
      # Extract collection name from filename (remove .bson extension)
      collection_name=$(basename "$bson_file" .bson)
      echo "Found collection: $collection_name"

      # Check if collection exists in the database
      # First, check if collection exists
      COLLECTION_EXISTS=$(mongosh --host "$LOCAL_DB_HOST" --port "$LOCAL_DB_PORT" $AUTH_PARAMS "$LOCAL_DB_NAME" --quiet --norc --eval "db.getCollectionNames().includes('$collection_name')" | grep -c "true")
      
      # If collection exists, drop it to ensure clean import
      if [ "$COLLECTION_EXISTS" -eq 1 ]; then
        echo "Dropping existing collection $collection_name for clean import..."
        mongosh --host "$LOCAL_DB_HOST" --port "$LOCAL_DB_PORT" $AUTH_PARAMS "$LOCAL_DB_NAME" --quiet --norc --eval "db['$collection_name'].drop()" > /dev/null 2>&1 || true
      fi

      # We've already handled dropping the collection if it exists, so we don't need to skip

      echo "Importing collection $collection_name..."

      # Check if mongorestore is available
      if command -v mongorestore &> /dev/null; then
        echo "Importing BSON file using mongorestore..."
        mongorestore --host "$LOCAL_DB_HOST" --port "$LOCAL_DB_PORT" $AUTH_PARAMS \
          --db "$LOCAL_DB_NAME" --collection "$collection_name" \
          "$bson_file"
      else
        echo "Error: mongorestore not found and required for BSON files"
        echo "Please install mongorestore to import BSON files"
        continue
      fi
    fi
  done
}

# Main execution
process_collections

echo "Import complete. All collections have been imported from $COLLECTIONS_DIR/"
