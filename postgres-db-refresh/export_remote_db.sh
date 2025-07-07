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

# Export schema only
PGPASSWORD="$REMOTE_DB_PASSWORD" pg_dump -h "$REMOTE_DB_HOST" -p "$REMOTE_DB_PORT" -U "$REMOTE_DB_USER" -d "$REMOTE_DB_NAME" --schema-only > "$DATA_DIR/schema.sql"

# List all tables
TABLES=$(PGPASSWORD="$REMOTE_DB_PASSWORD" psql -h "$REMOTE_DB_HOST" -p "$REMOTE_DB_PORT" -U "$REMOTE_DB_USER" -d "$REMOTE_DB_NAME" -Atc \
  "SELECT tablename FROM pg_tables WHERE schemaname='public';")

for table in $TABLES; do
  skip=false
  for skip_table in $SKIP_TABLES; do
    if [ "$table" == "$skip_table" ]; then
      skip=true
      break
    fi
  done
  if [ "$skip" = true ]; then
    echo "Skipping table $table (in SKIP_TABLES)"
    continue
  fi
  if [ -f "$DATA_DIR/$table.csv" ]; then
    echo "Skipping table $table (already exported)"
    continue
  fi
  echo "Exporting data for $table..."
  PGPASSWORD="$REMOTE_DB_PASSWORD" psql -h "$REMOTE_DB_HOST" -p "$REMOTE_DB_PORT" -U "$REMOTE_DB_USER" -d "$REMOTE_DB_NAME" -c \
    "\COPY \"$table\" TO '$DATA_DIR/$table.csv' CSV"
done

echo "Export complete. Schema and table data are in $DATA_DIR/"
