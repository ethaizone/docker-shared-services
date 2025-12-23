# Shared Docker Development Services <!-- omit in toc -->

This repository contains the `docker-compose.yml` for our common development services (PostgreSQL, Redis, MongoDB, MySQL, RabbitMQ, etc.) that are designed to be shared across multiple application projects on a developer's local machine.

## Table of Contents <!-- omit in toc -->

- [1. Why Shared Services?](#1-why-shared-services)
- [2. Getting Started](#2-getting-started)
  - [Prerequisites](#prerequisites)
  - [Initial Setup](#initial-setup)
  - [Starting the Services](#starting-the-services)
  - [Stopping the Services](#stopping-the-services)
- [3. Connecting Your Application Projects](#3-connecting-your-application-projects)
  - [Network Configuration](#network-configuration)
  - [Example Application `docker-compose.yml`](#example-application-docker-composeyml)
- [4. Accessing Services from Your Host Machine (Optional)](#4-accessing-services-from-your-host-machine-optional)
- [5. Managing Data (Volumes)](#5-managing-data-volumes)
  - [Backup](#backup)
  - [Restore](#restore)
  - [Cleaning Up Data](#cleaning-up-data)
- [6. Configuration](#6-configuration)
- [7. Automated Backups](#7-automated-backups)
- [8. Troubleshooting](#8-troubleshooting)

## 1\. Why Shared Services?

To enhance development efficiency and reduce resource consumption on individual developer machines, we centralize core services like databases and caches. This approach provides:

- **Resource Efficiency:** One instance of Postgres/Redis/Mongo/MySQL/RabbitMQ instead of multiple per project.

- **Simplified Management:** Start/stop all common services with a single command.

- **Consistency:** All projects connect to the same version and configuration of these services.

- **Faster Project Spin-up:** No need to configure these services in every new project.

- **Security:** Services are primarily accessible internally within Docker networks, not publicly exposed.

## 2\. Getting Started

### Prerequisites

- **Docker Desktop:** Ensure Docker Desktop is installed and running on your Mac (or equivalent for Linux/Windows).

- **Git:** To clone this repository.

### Initial Setup

1.  Clone this repository:

    It's recommended to clone this repository to a consistent location, e.g., in your home directory:

    ```
    git clone git@github.com:ethaizone/docker-shared-services.git ~/docker-shared-services
    cd ~/docker-shared-services
    git submodule update --init --recursive
    ```

2.  Create your local .env file:

    Copy the sample environment file (.env.sample) to create your local configuration. This file is ignored by Git and should contain any sensitive or personalized settings.

    ```
    cp .env.sample .env
    ```

    Review and modify the `.env` file as needed (e.g., set your preferred database passwords, backup directory).

### Starting the Services

Navigate to the `~/docker-shared-services` directory and run:

```
docker compose up -d
```

This command will:

- Create the `shared_services_network` (if it doesn't exist).

- Start the `shared_postgres`, `shared_redis`, `shared_mongodb`, `shared_mysql`, `shared_rabbitmq` containers.

- Create named Docker volumes (`postgres_data`, `redis_data`, `mongodb_data`, `mysql_data`, `rabbitmq_data`) to persist your data.

You can verify the services are running:

```
docker ps --filter "name=shared_"
docker network inspect shared_services_network
# To check RabbitMQ management UI, open http://localhost:15672 in your browser.
```

### Stopping the Services

To stop and remove the containers (but keep the data volumes):

```
docker compose down
```

To stop and remove containers AND their associated data volumes (use with caution, this deletes data!):

```
docker compose down -v
```

## 3\. Connecting Your Application Projects

Your application's `docker-compose.yml` needs to connect to the shared `shared_services_network`.

### Network Configuration

In your application's `docker-compose.yml`, define the `shared_services_network` as an `external` network. This tells Docker Compose that the network already exists and should be used, rather than created by this specific project.

```
# In your application's docker-compose.yml
networks:
  shared_services_network:
    external: true
```

### Example Application `docker-compose.yml`

Here's how your application service would connect to the shared services:

```
# ~/my-application-project/docker-compose.yml
version: '3.8'

services:
  my_app:
    build: .
    ports:
      - "8000:8000" # Expose your application's port to your host
    environment:
      # Connect to shared services using their container names as hostnames.
      # These services are NOT exposed to the host network (unless you enable the
      # '_host_access' services in docker-shared-services/docker-compose.yml).
      DATABASE_URL_POSTGRES: postgres://${POSTGRES_USER:-user}:${POSTGRES_PASSWORD:-password}@shared_postgres:5432/${POSTGRES_DB_NAME:-mydatabase}
      DATABASE_URL_REDIS: redis://shared_redis:6379
      DATABASE_URL_MONGO: mongodb://${MONGO_INITDB_ROOT_USERNAME:-mongouser}:${MONGO_INITDB_ROOT_PASSWORD:-mongopassword}@shared_mongodb:27017/${MONGO_APP_DB:-appdb} # Assumes 'appdb' is your application's specific MongoDB database
      DATABASE_URL_MYSQL: mysql://${MYSQL_USER:-user}:${MYSQL_PASSWORD:-password}@shared_mysql:3306/${MYSQL_DATABASE_NAME:-mydatabase}
    volumes:
      - .:/app # Mount your application code for development
    networks:
      - my_app_internal_network # For internal app services if any
      - shared_services_network # IMPORTANT: Connect to the shared network

networks:
  my_app_internal_network: # Your application's default internal network
  shared_services_network:
    external: true # Reference the external shared network
```

## 4\. Accessing Services from Your Host Machine (Optional)

By default, `shared_postgres`, `shared_redis`, `shared_mongodb`, and `shared_mysql` are **not** exposed to your host machine's network. This is for security.

If you need to connect to these services from your host machine (e.g., using a GUI client), you can enable the `*_host_access` services in `docker-shared-services/docker-compose.yml`.

1.  **Uncomment** the desired `*_host_access` services in `~/docker-shared-services/docker-compose.yml`.

2.  **Restart** the shared services: `docker compose up -d` in `~/docker-shared-services`.

    - Postgres: `localhost:5432`

    - Redis: `localhost:6379`

    - MongoDB: `localhost:27017`

    - MySQL: `localhost:3306`

    - RabbitMQ: `localhost:5672`

    These ports are bound _only_ to `127.0.0.1` (localhost) for security, meaning only your machine can connect.

## 5\. Managing Data (Volumes)

Data for all services is stored in named Docker volumes (`postgres_data`, `redis_data`, `mongodb_data`, `mysql_data`). These volumes persist even if containers are stopped or removed.

### Backup

Backup scripts are located in the `scripts/` directory.

You can back up individual services or use the `backup_all_dbs.sh` script.

**To run a single service backup (e.g., Postgres):**

```
cd ~/docker-shared-services
./scripts/backup_postgres.sh
```

**To run a full backup of all configured databases:**

```
cd ~/docker-shared-services
./scripts/backup_all_dbs.sh
```

Backups will be saved to the directory specified by `BACKUP_DIR` in your `.env` file (defaults to `~/docker_shared_backups`).

### Restore

Restoring involves copying the backup file back into the container and executing the restore command. Refer to the specific `scripts/backup_*.sh` files for restore instructions within each script's comments.

### Cleaning Up Data

To remove the data volumes (effectively resetting your databases/caches to a clean state), first stop the services, then run `down -v`:

```
cd ~/docker-shared-services
docker compose down -v
```

**WARNING: This command permanently deletes all data in the associated Docker volumes.**

## 6\. Configuration

You can customize the service and backup configurations by editing the `.env` file in this directory. If a variable is not set in `.env`, the default value specified in `docker-compose.yml` or the backup scripts will be used.

## 7\. Automated Backups

You can set up automated daily backups using `cron` on your macOS.

1.  **Ensure scripts are executable:**

    ```
    chmod +x scripts/*.sh
    ```

2.  **Open your crontab for editing:**

    ```
    crontab -e
    ```

3.  Add the following line to the crontab file:

    This example runs the backup_all_dbs.sh script daily at 2:00 AM.

    ```
    0 2 * * * /bin/bash -c "source ~/docker-shared-services/.env && /usr/bin/bash ~/docker-shared-services/scripts/backup_all_dbs.sh >> ~/docker-shared-services/logs/backup.log 2>&1"
    ```

    - `0 2 * * *`: Runs at 02:00 every day.

    - `/bin/bash -c "..."`: Ensures the command runs in a bash shell.

    - `source ~/docker-shared-services/.env`: Loads your environment variables from the `.env` file into the cron job's environment. **This is crucial for the backup scripts to pick up your passwords and `BACKUP_DIR`!**

    - `/usr/bin/bash ~/docker-shared-services/scripts/backup_all_dbs.sh`: The path to your backup script.

    - `>> ~/docker-shared-services/logs/backup.log 2>&1`: Redirects both standard output and standard error to a log file. Create the `logs` directory: `mkdir -p ~/docker-shared-services/logs`.

4.  **Save and exit** the crontab editor.

## 8\. Troubleshooting

- **"Network `shared_services_network` not found":** Ensure you have run `docker compose up -d` in the `~/docker-shared-services` directory at least once to create the network.

- **"Container already exists":** If you manually created containers or had a previous setup, sometimes `docker compose down` might not fully clean up. Try `docker compose down --remove-orphans` or `docker system prune` (use with caution, this removes all unused Docker data).

- **Connection Refused (from app to shared service):**

  - Verify both your app and shared services are on the `shared_services_network`.

  - Check container names (`shared_postgres`, `shared_redis`, `shared_mongodb`, `shared_mysql`) match in your app's environment variables.

  - Ensure the shared services are actually running (`docker ps`).

- **Connection Refused (from host to shared service):**

  - Ensure the `*_host_access` services are uncommented and running in `docker-shared-services/docker-compose.yml`.

  - Verify you're connecting to the correct localhost port.

- **Backup Script Issues:**

  - Check `chmod +x scripts/*.sh` has been run.

  - Ensure `BACKUP_DIR` exists (`mkdir -p "$BACKUP_DIR"`).

  - Check the log file for cron jobs (`~/docker-shared-services/logs/backup.log`).

  - Verify database credentials in your `.env` file are correct and match `docker-compose.yml`.

  - Ensure the containers are running when the backup script executes.

- **MongoDB Authentication:** If you enable authentication for MongoDB (which is recommended for production, even dev if you test it), ensure `MONGO_INITDB_ROOT_USERNAME` and `MONGO_INITDB_ROOT_PASSWORD` are correctly set in your `.env` and used in your application's connection string.

## About openmemory

I added openmemory to submodule but I found I need to use this version or else it will failed. For now just clone and `docker compose up -d` only.
