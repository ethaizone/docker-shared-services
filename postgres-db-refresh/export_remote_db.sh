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
TABLES_DIR="$DATA_DIR/tables"

COMPRESS_EXPORTS="${COMPRESS_EXPORTS:-true}"

echo "SKIP_TABLES: $SKIP_TABLES"
echo "COMPRESS_EXPORTS: $COMPRESS_EXPORTS"

if [ "$REMOTE_DB_HOST" == "localhost" ] || [ "$REMOTE_DB_HOST" == "127.0.0.1" ]; then
  echo "[ERROR] Refusing to export from localhost as remote."
  exit 1
fi

mkdir -p "$TABLES_DIR"

# List all tables
TABLES=$(PGPASSWORD="$REMOTE_DB_PASSWORD" psql -h "$REMOTE_DB_HOST" -p "$REMOTE_DB_PORT" -U "$REMOTE_DB_USER" -d "$REMOTE_DB_NAME" -Atc \
  "SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename;")

for table in $TABLES; do
  output_file="$TABLES_DIR/${table}.sql"

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
    if [ "$COMPRESS_EXPORTS" = true ]; then
      output_file="$TABLES_DIR/${table}.sql.gz"
      PGPASSWORD="$REMOTE_DB_PASSWORD" pg_dump -h "$REMOTE_DB_HOST" -p "$REMOTE_DB_PORT" -U "$REMOTE_DB_USER" \
        -d "$REMOTE_DB_NAME" --schema-only --table="$table" | gzip > "$output_file"
    else
      output_file="$TABLES_DIR/${table}.sql"
      PGPASSWORD="$REMOTE_DB_PASSWORD" pg_dump -h "$REMOTE_DB_HOST" -p "$REMOTE_DB_PORT" -U "$REMOTE_DB_USER" \
        -d "$REMOTE_DB_NAME" --schema-only --table="$table" > "$output_file"
    fi
  else
    echo "Exporting schema and data for $table..."
    if [ "$COMPRESS_EXPORTS" = true ]; then
      output_file="$TABLES_DIR/${table}.sql.gz"
      PGPASSWORD="$REMOTE_DB_PASSWORD" pg_dump -h "$REMOTE_DB_HOST" -p "$REMOTE_DB_PORT" -U "$REMOTE_DB_USER" \
        -d "$REMOTE_DB_NAME" --table="$table" | gzip > "$output_file"
    else
      output_file="$TABLES_DIR/${table}.sql"
      PGPASSWORD="$REMOTE_DB_PASSWORD" pg_dump -h "$REMOTE_DB_HOST" -p "$REMOTE_DB_PORT" -U "$REMOTE_DB_USER" \
        -d "$REMOTE_DB_NAME" --table="$table" > "$output_file"
    fi
  fi

  # Remove empty files (tables with no data)
  if [ ! -s "$output_file" ]; then
    rm -f "$output_file"
    echo "  No data found for $table, removed empty file"
  fi
done

echo "Export complete. Table dumps are in $TABLES_DIR/"

# --- Export views ---
VIEWS_DIR="$DATA_DIR/views"
mkdir -p "$VIEWS_DIR"

# Get all view names in public schema
VIEWS=$(PGPASSWORD="$REMOTE_DB_PASSWORD" psql -h "$REMOTE_DB_HOST" -p "$REMOTE_DB_PORT" -U "$REMOTE_DB_USER" -d "$REMOTE_DB_NAME" -Atc \
  "SELECT table_name FROM information_schema.views WHERE table_schema = 'public' ORDER BY table_name;")

for view in $VIEWS; do
  if [ "$COMPRESS_EXPORTS" = true ]; then
    view_file="$VIEWS_DIR/${view}.sql.gz"
  else
    view_file="$VIEWS_DIR/${view}.sql"
  fi

  # Skip if file already exists
  if [ -f "$view_file" ]; then
    echo "Skipping view $view (already exported)"
    continue
  fi

  echo "Exporting definition for view $view..."
  # Dump only the view definition
  if [ "$COMPRESS_EXPORTS" = true ]; then
    PGPASSWORD="$REMOTE_DB_PASSWORD" pg_dump -h "$REMOTE_DB_HOST" -p "$REMOTE_DB_PORT" -U "$REMOTE_DB_USER" \
      -d "$REMOTE_DB_NAME" --schema-only --table="$view" | gzip > "$view_file"
  else
    PGPASSWORD="$REMOTE_DB_PASSWORD" pg_dump -h "$REMOTE_DB_HOST" -p "$REMOTE_DB_PORT" -U "$REMOTE_DB_USER" \
      -d "$REMOTE_DB_NAME" --schema-only --table="$view" > "$view_file"
  fi

  # Remove empty files (shouldn't happen for views)
  if [ ! -s "$view_file" ]; then
    rm -f "$view_file"
    echo "  No definition found for view $view, removed empty file"
  fi
done

echo "View export complete. View definitions are in $VIEWS_DIR/"
