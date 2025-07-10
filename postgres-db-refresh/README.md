# Postgres DB Refresh

Scripts to clone a remote Postgres database, split data into files, and import into local Postgres.

## Prerequisites

1. Ensure you have `psql` client installed
2. Have access to both source and destination PostgreSQL servers
3. Sufficient disk space for the database dump

## Usage

1. Edit `.env.example` and copy to `.env` (update values as needed).

   - Set `SKIP_TABLES` to a space-separated list of tables to skip (e.g., large log/history tables)
   - Configure database connection parameters for both source and destination

2. Export data from remote database:

   ```bash
   ./export_remote_db.sh
   ```

   Note: The script will create a `data` directory in the current directory and store the split SQL files there. It will skip if the sql files already exist.

3. **Important**: Before importing, manually drop all existing tables in your local database to avoid conflicts:

   ```bash
   # Connect to your local database
   PGPASSWORD=your_password psql -h localhost -U your_username -d your_database -c "
     DROP SCHEMA public CASCADE;
     CREATE SCHEMA public;
     GRANT ALL ON SCHEMA public TO your_username;
     GRANT ALL ON SCHEMA public TO public;
   "
   ```

   Note: This is a safety measure to prevent accidental data loss.

4. Import data to local database:
   ```bash
   ./import_local_db.sh
   ```

## Notes

- Only works if LOCAL_DB_HOST is `localhost` or `127.0.0.1` (for safety).
- Data is split per table.
- Skipped tables are defined in `.env` as `SKIP_TABLES`.
- The import script will fail if tables already exist in the target database.
- Make sure to backup your local database before dropping any tables.
