#!/bin/bash
set -e

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

COMPRESS_EXPORTS="${COMPRESS_EXPORTS:-true}"

echo "SKIP_COLLECTIONS: $SKIP_COLLECTIONS"
echo "COMPRESS_EXPORTS: $COMPRESS_EXPORTS"

if [ "$REMOTE_DB_HOST" == "localhost" ] || [ "$REMOTE_DB_HOST" == "127.0.0.1" ]; then
  echo "[ERROR] Refusing to export from localhost as remote."
  exit 1
fi

mkdir -p "$COLLECTIONS_DIR"

# Build connection string
if [ -n "$REMOTE_DB_USER" ] && [ -n "$REMOTE_DB_PASSWORD" ]; then
  AUTH_PARAMS="--username $REMOTE_DB_USER --password $REMOTE_DB_PASSWORD --authenticationDatabase $REMOTE_DB_AUTH_SOURCE"
else
  AUTH_PARAMS=""
fi

# List all collections
COLLECTIONS=$(mongosh --host "$REMOTE_DB_HOST" --port "$REMOTE_DB_PORT" $AUTH_PARAMS "$REMOTE_DB_NAME" --quiet --eval "db.getCollectionNames().join(' ')" --norc)

for collection in $COLLECTIONS; do
  output_dir="$COLLECTIONS_DIR/$collection"
  
  # Skip if directory already exists
  if [ -d "$output_dir" ]; then
    echo "Skipping $collection (already exported)"
    continue
  fi

  # Check if collection should be skipped
  skip=false
  for skip_collection in $SKIP_COLLECTIONS; do
    if [ "$collection" == "$skip_collection" ]; then
      skip=true
      break
    fi
  done

  if [ "$skip" = true ]; then
    echo "Skipping collection $collection (in SKIP_COLLECTIONS)..."
    continue
  else
    echo "Exporting collection $collection..."
    # Check if mongodump is available
    if command -v mongodump &> /dev/null; then
      mongodump --host "$REMOTE_DB_HOST" --port "$REMOTE_DB_PORT" $AUTH_PARAMS \
        --db "$REMOTE_DB_NAME" --collection "$collection" \
        --out "$COLLECTIONS_DIR"

      if [ "$COMPRESS_EXPORTS" = true ]; then
        bson_file="$COLLECTIONS_DIR/$REMOTE_DB_NAME/$collection.bson"
        if [ -f "$bson_file" ]; then
          echo "  Compressing $collection.bson..."
          gzip "$bson_file"
        fi
      fi
    else
      # Fallback to mongosh if mongodump is not available
      echo "mongodump not found, using mongosh to export data..."
      mkdir -p "$COLLECTIONS_DIR/$REMOTE_DB_NAME"
      json_file="$COLLECTIONS_DIR/$REMOTE_DB_NAME/$collection.json"
      mongosh --host "$REMOTE_DB_HOST" --port "$REMOTE_DB_PORT" $AUTH_PARAMS \
        "$REMOTE_DB_NAME" --quiet --norc \
        --eval "db.${collection}.find().forEach(doc => printjson(doc))" > "$json_file"

      if [ "$COMPRESS_EXPORTS" = true ] && [ -f "$json_file" ]; then
        echo "  Compressing $collection.json..."
        gzip "$json_file"
      fi
    fi
  fi

  # Check if the export was successful
  if [ "$COMPRESS_EXPORTS" = true ]; then
    if [ ! -f "$COLLECTIONS_DIR/$REMOTE_DB_NAME/$collection.bson.gz" ] && [ ! -f "$COLLECTIONS_DIR/$REMOTE_DB_NAME/$collection.json.gz" ]; then
      echo "  Warning: Export may have failed for $collection"
    fi
  else
    if [ ! -f "$COLLECTIONS_DIR/$REMOTE_DB_NAME/$collection.bson" ]; then
      echo "  Warning: Export may have failed for $collection"
    fi
  fi
done

echo "Export complete. Collection dumps are in $COLLECTIONS_DIR/"
