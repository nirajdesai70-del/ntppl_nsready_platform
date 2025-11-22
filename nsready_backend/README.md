# NSReady Backend

This folder contains all NSReady backend services and infrastructure.

## Components

- **`admin_tool/`** - Configuration management API (FastAPI, port 8000)
  - Customer, project, site, device management
  - Parameter template management
  - Registry versioning and publishing
  - **Note:** NSReady has a small internal operational dashboard (UI/templates) under `admin_tool/ui/` for engineers and administrators. This is separate from NSWare's full SaaS dashboard.

- **`collector_service/`** - Telemetry ingestion service (FastAPI, port 8001)
  - REST API for event ingestion
  - NATS message queuing
  - Asynchronous database writes to TimescaleDB

- **`db/`** - Database layer
  - PostgreSQL 15 with TimescaleDB extension
  - Schema migrations
  - Views and stored procedures

- **`tests/`** - Backend test suites
  - Regression tests
  - Performance tests
  - Resilience tests

## Running Services

See root `README.md` for instructions on running the full stack with docker-compose.

Individual services can be run from their respective directories.

## NSReady vs NSWare

**Important:** NSReady backend services are separate from NSWare frontend components.

- **NSReady** = Current production platform (this folder)
- **NSWare** = Future SaaS platform (see `../nsware_frontend/`)

For details on the distinction between NSReady UI and NSWare Dashboard, see `../shared/master_docs/NSREADY_VS_NSWARE_DASHBOARD_CLARIFICATION.md`.

