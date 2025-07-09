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

echo "SKIP_TABLES: $SKIP_TABLES"

if [ "$REMOTE_DB_HOST" == "localhost" ] || [ "$REMOTE_DB_HOST" == "127.0.0.1" ]; then
  echo "[ERROR] Refusing to export from localhost as remote."
  exit 1
fi

mkdir -p "$DATA_DIR"

# List all tables
TABLES=$(PGPASSWORD="$REMOTE_DB_PASSWORD" psql -h "$REMOTE_DB_HOST" -p "$REMOTE_DB_PORT" -U "$REMOTE_DB_USER" -d "$REMOTE_DB_NAME" -Atc \
  "SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename;")

for table in $TABLES; do
  output_file="$DATA_DIR/${table}.sql"

  # Skip if file already exists
  if [ -f "$output_file" ]; then
    echo "Skipping $table (already exported)"
    continue
  fi

  # Check if table should be skipped (schema only)
  skip=false
  for skip_table in $SKIP_TABLES; do
    if [ "$table" == "$skip_table" ]; then
      skip=true
      break
    fi
  done

  if [ "$skip" = true ]; then
    echo "Exporting schema only for $table (in SKIP_TABLES)..."
    PGPASSWORD="$REMOTE_DB_PASSWORD" pg_dump -h "$REMOTE_DB_HOST" -p "$REMOTE_DB_PORT" -U "$REMOTE_DB_USER" \
      -d "$REMOTE_DB_NAME" --schema-only --table="$table" > "$output_file"
  else
    echo "Exporting schema and data for $table..."
    PGPASSWORD="$REMOTE_DB_PASSWORD" pg_dump -h "$REMOTE_DB_HOST" -p "$REMOTE_DB_PORT" -U "$REMOTE_DB_USER" \
      -d "$REMOTE_DB_NAME" --table="$table" > "$output_file"
  fi

  # Remove empty files (tables with no data)
  if [ ! -s "$output_file" ]; then
    rm -f "$output_file"
    echo "  No data found for $table, removed empty file"
  fi
done

echo "Export complete. Table dumps are in $DATA_DIR/"
