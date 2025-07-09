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

# Function to drop all objects in the public schema
drop_all_tables() {
  echo "Dropping all objects in the public schema..."

  # Disable triggers and constraints temporarily
  PGPASSWORD="$LOCAL_DB_PASSWORD" psql -h "$LOCAL_DB_HOST" -p "$LOCAL_DB_PORT" -U "$LOCAL_DB_USER" -d "$LOCAL_DB_NAME" -c "
    SET session_replication_role = 'replica';

    -- Drop all tables
    SELECT 'DROP TABLE IF EXISTS ' || tablename || ' CASCADE;'
    FROM pg_tables
    WHERE schemaname = 'public';

    -- Drop all views
    SELECT 'DROP VIEW IF EXISTS ' || table_name || ' CASCADE;'
    FROM information_schema.views
    WHERE table_schema = 'public';

    -- Drop all functions
    SELECT 'DROP FUNCTION IF EXISTS ' || routine_name || ' CASCADE;'
    FROM information_schema.routines
    WHERE routine_schema = 'public';

    -- Drop all sequences
    SELECT 'DROP SEQUENCE IF EXISTS ' || sequence_name || ' CASCADE;'
    FROM information_schema.sequences
    WHERE sequence_schema = 'public';
  " | grep '^DROP' | PGPASSWORD="$LOCAL_DB_PASSWORD" psql -h "$LOCAL_DB_HOST" -p "$LOCAL_DB_PORT" -U "$LOCAL_DB_USER" -d "$LOCAL_DB_NAME" -v ON_ERROR_STOP=0

  # Re-enable triggers and constraints
  PGPASSWORD="$LOCAL_DB_PASSWORD" psql -h "$LOCAL_DB_HOST" -p "$LOCAL_DB_PORT" -U "$LOCAL_DB_USER" -d "$LOCAL_DB_NAME" -c "
    SET session_replication_role = 'origin';
  "

  echo "All objects in public schema have been dropped."
}

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
# drop_all_tables
process_sql_files

echo "Import complete. All tables have been imported from $DATA_DIR/"
