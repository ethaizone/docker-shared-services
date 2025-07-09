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

if [ "$LOCAL_DB_HOST" != "localhost" ] && [ "$LOCAL_DB_HOST" != "127.0.0.1" ]; then
  echo "[ERROR] Refusing to import unless LOCAL_DB_HOST is localhost or 127.0.0.1."
  exit 1
fi

# Function to process SQL files
process_sql_files() {
  # Process each SQL file in the data directory
  for sql_file in "$DATA_DIR"/*.sql; do
    [ -f "$sql_file" ] || continue  # Skip if no .sql files found

    filename=$(basename "$sql_file")
    table_name="${filename%.*}"  # Remove .sql extension to get table name

    # Check if table is in skip list
    skip=false
    for skip_table in $SKIP_TABLES; do
      if [ "$table_name" == "$skip_table" ]; then
        skip=true
        break
      fi
    done

    if [ "$skip" = true ]; then
      echo "Skipping table $table_name (in SKIP_TABLES)"
      continue
    fi

    echo "Importing $filename..."

    # Clean the SQL file to remove owner and grant statements
    CLEANED_SQL="${sql_file}.cleaned"
    grep -v -E 'OWNER TO|GRANT ' "$sql_file" > "$CLEANED_SQL"

    # Import the SQL file
    PGPASSWORD="$LOCAL_DB_PASSWORD" psql -h "$LOCAL_DB_HOST" -p "$LOCAL_DB_PORT" -U "$LOCAL_DB_USER" -d "$LOCAL_DB_NAME" -f "$CLEANED_SQL"

    # Clean up
    rm -f "$CLEANED_SQL"
  done
}

# Main execution
process_sql_files

echo "Import complete. All tables have been imported from $DATA_DIR/"
