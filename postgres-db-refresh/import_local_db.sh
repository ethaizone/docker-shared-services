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

chunk_size=${CHUNK_SIZE:-10000}

# Preprocess schema.sql to remove OWNER TO and GRANT lines
CLEANED_SCHEMA="$DATA_DIR/schema.cleaned.sql"
grep -v -E 'OWNER TO|GRANT ' "$DATA_DIR/schema.sql" > "$CLEANED_SCHEMA"

# Import cleaned schema
PGPASSWORD="$LOCAL_DB_PASSWORD" psql -h "$LOCAL_DB_HOST" -p "$LOCAL_DB_PORT" -U "$LOCAL_DB_USER" -d "$LOCAL_DB_NAME" -f "$CLEANED_SCHEMA"

# Import data for each table
for csv_file in $DATA_DIR/*.csv; do
  table=$(basename "$csv_file" .csv)
  skip=false
  for skip_table in $SKIP_TABLES; do
    if [ "$table" == "$skip_table" ]; then
      skip=true
      break
    fi
  done
  if [ "$skip" = true ]; then
    echo "Skipping table $table"
    continue
  fi
  echo "Dropping and recreating $table..."
  PGPASSWORD="$LOCAL_DB_PASSWORD" psql -h "$LOCAL_DB_HOST" -p "$LOCAL_DB_PORT" -U "$LOCAL_DB_USER" -d "$LOCAL_DB_NAME" -c "DROP TABLE IF EXISTS \"$table\" CASCADE;"
  # Recreate table from schema
  PGPASSWORD="$LOCAL_DB_PASSWORD" psql -h "$LOCAL_DB_HOST" -p "$LOCAL_DB_PORT" -U "$LOCAL_DB_USER" -d "$LOCAL_DB_NAME" -f <(awk "/CREATE TABLE .*${table}.*/{flag=1} /;/{if(flag){print;flag=0}} flag" "$DATA_DIR/schema.sql")
  echo "Importing data for $table in chunks..."
  total_lines=$(wc -l < "$csv_file")
  if [ "$total_lines" -le "$chunk_size" ]; then
    PGPASSWORD="$LOCAL_DB_PASSWORD" psql -h "$LOCAL_DB_HOST" -p "$LOCAL_DB_PORT" -U "$LOCAL_DB_USER" -d "$LOCAL_DB_NAME" -c "\COPY \"$table\" FROM '$csv_file' CSV"
  else
    split -l $chunk_size "$csv_file" "$csv_file.chunk."
    for chunk in "$csv_file".chunk.*; do
      PGPASSWORD="$LOCAL_DB_PASSWORD" psql -h "$LOCAL_DB_HOST" -p "$LOCAL_DB_PORT" -U "$LOCAL_DB_USER" -d "$LOCAL_DB_NAME" -c "\COPY \"$table\" FROM '$chunk' CSV"
      rm "$chunk"
    done
  fi
done

echo "Import complete."
