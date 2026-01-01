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

if [ "$LOCAL_DB_HOST" != "localhost" ] && [ "$LOCAL_DB_HOST" != "127.0.0.1" ]; then
  echo "[ERROR] Refusing to import unless LOCAL_DB_HOST is localhost or 127.0.0.1."
  exit 1
fi

# Function to process SQL files
process_sql_files() {
  # Process each SQL file (compressed or uncompressed) in the data directory
  for sql_file in "$TABLES_DIR"/*.sql*; do
    [ -f "$sql_file" ] || continue  # Skip if no .sql files found

    filename=$(basename "$sql_file")
    # Determine if file is compressed and extract table name
    if [[ "$sql_file" == *.sql.gz ]]; then
      table_name="${filename%.*.*}"  # Remove .sql.gz extension to get table name
      is_compressed=true
    elif [[ "$sql_file" == *.sql ]]; then
      table_name="${filename%.*}"  # Remove .sql extension to get table name
      is_compressed=false
    else
      continue
    fi

    # Check if table exists in the database
    TABLE_EXISTS=$(PGPASSWORD="$LOCAL_DB_PASSWORD" psql -h "$LOCAL_DB_HOST" -p "$LOCAL_DB_PORT" -U "$LOCAL_DB_USER" -d "$LOCAL_DB_NAME" -tAc "SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = '$table_name';")
    if [ "$TABLE_EXISTS" = "1" ]; then
      echo "Skipping table $table_name (already exists in database)"
      continue
    fi

    echo "Importing $filename..."

    if [ "$is_compressed" = true ]; then
      # Decompress, clean, and import in one pipeline
      gzip -d -c "$sql_file" | grep -v -E 'OWNER TO|GRANT ' | PGPASSWORD="$LOCAL_DB_PASSWORD" psql -h "$LOCAL_DB_HOST" -p "$LOCAL_DB_PORT" -U "$LOCAL_DB_USER" -d "$LOCAL_DB_NAME"
    else
      # Clean the SQL file to remove owner and grant statements
      CLEANED_SQL="${sql_file}.cleaned"
      grep -v -E 'OWNER TO|GRANT ' "$sql_file" > "$CLEANED_SQL"

      # Import the SQL file
      PGPASSWORD="$LOCAL_DB_PASSWORD" psql -h "$LOCAL_DB_HOST" -p "$LOCAL_DB_PORT" -U "$LOCAL_DB_USER" -d "$LOCAL_DB_NAME" -f "$CLEANED_SQL"

      # Clean up
      rm -f "$CLEANED_SQL"
    fi
  done
}

# Main execution
process_sql_files

echo "Import complete. All tables have been imported from $TABLES_DIR/"

VIEWS_DIR="$DATA_DIR/views"

if [ -d "$VIEWS_DIR" ]; then
  for view_sql in "$VIEWS_DIR"/*.sql*; do
    [ -f "$view_sql" ] || continue
    view_filename=$(basename "$view_sql")

    # Determine if file is compressed and extract view name
    if [[ "$view_sql" == *.sql.gz ]]; then
      view_name="${view_filename%.*.*}"
      is_compressed=true
    elif [[ "$view_sql" == *.sql ]]; then
      view_name="${view_filename%.*}"
      is_compressed=false
    else
      continue
    fi

    # Check if view exists in the database
    VIEW_EXISTS=$(PGPASSWORD="$LOCAL_DB_PASSWORD" psql -h "$LOCAL_DB_HOST" -p "$LOCAL_DB_PORT" -U "$LOCAL_DB_USER" -d "$LOCAL_DB_NAME" -tAc "SELECT 1 FROM information_schema.views WHERE table_schema = 'public' AND table_name = '$view_name';")
    if [ "$VIEW_EXISTS" = "1" ]; then
      echo "Skipping view $view_name (already exists in database)"
      continue
    fi

    echo "Importing view $view_filename..."

    if [ "$is_compressed" = true ]; then
      # Decompress, clean, and import in one pipeline
      gzip -d -c "$view_sql" | grep -v -E 'OWNER TO|GRANT ' | PGPASSWORD="$LOCAL_DB_PASSWORD" psql -h "$LOCAL_DB_HOST" -p "$LOCAL_DB_PORT" -U "$LOCAL_DB_USER" -d "$LOCAL_DB_NAME"
    else
      CLEANED_VIEW_SQL="${view_sql}.cleaned"
      grep -v -E 'OWNER TO|GRANT ' "$view_sql" > "$CLEANED_VIEW_SQL"
      PGPASSWORD="$LOCAL_DB_PASSWORD" psql -h "$LOCAL_DB_HOST" -p "$LOCAL_DB_PORT" -U "$LOCAL_DB_USER" -d "$LOCAL_DB_NAME" -f "$CLEANED_VIEW_SQL"
      rm -f "$CLEANED_VIEW_SQL"
    fi
  done
  echo "Import complete. All views have been imported from $VIEWS_DIR/"
else
  echo "No views directory found at $VIEWS_DIR, skipping view import."
fi
