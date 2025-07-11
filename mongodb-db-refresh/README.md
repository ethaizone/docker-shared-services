# MongoDB DB Refresh

Scripts to clone a remote MongoDB database, export collections to files, and import into local MongoDB.

## Prerequisites

1. Ensure you have `mongosh` installed (required)
2. `mongodump` and `mongorestore` tools are recommended but not required (the scripts will fall back to using `mongosh` if they're not available)
2. Have access to both source and destination MongoDB servers
3. Sufficient disk space for the database dump

## Usage

1. Edit `.env.example` and copy to `.env` (update values as needed).

   - Set `SKIP_COLLECTIONS` to a space-separated list of collections to skip (e.g., large log/history collections)
   - Configure database connection parameters for both source and destination

2. Export data from remote database:

   ```bash
   ./export_remote_db.sh
   ```

   Note: The script will create a `data` directory in the current directory and store the exported BSON files there. It will skip if the files already exist.

3. **Important**: Before importing, you may want to drop your local database to avoid conflicts:

   ```bash
   # Connect to your local MongoDB
   mongosh --host localhost --port 27017 -u your_username -p your_password --authenticationDatabase admin
   
   # In the mongosh shell
   use your_database
   db.dropDatabase()
   exit
   ```

   Note: This is a safety measure to prevent accidental data loss.

4. Import data to local database:
   ```bash
   ./import_local_db.sh
   ```

## Notes

- Only works if LOCAL_DB_HOST is `localhost` or `127.0.0.1` (for safety).
- Data is split per collection.
- Skipped collections are defined in `.env` as `SKIP_COLLECTIONS`.
- Make sure to backup your local database before dropping any collections.
