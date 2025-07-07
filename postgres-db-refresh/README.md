# Postgres DB Refresh

Scripts to clone a remote Postgres database, split data into files, and import into local Postgres.

## Usage

1. Edit `.env.example` and copy to `.env` (update values as needed).
   - Set `SKIP_TABLES` to a space-separated list of tables to skip (e.g., large log/history tables)
   - Set `CHUNK_SIZE` for bulk insert size
2. Run `export_remote_db.sh` to export schema and data from remote.
3. Run `import_local_db.sh` to import into local Postgres.

## Notes
- Only works if LOCAL_DB_HOST is `localhost` (for safety).
- Data is split per table and imported in chunks.
- Skipped tables are defined in `.env` as `SKIP_TABLES`.
