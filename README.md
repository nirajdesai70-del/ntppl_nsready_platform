# NSReady / NSWare Platform

This repository contains the **NSReady** (active) and **NSWare** (future) platform components for data collection, configuration management, and operational dashboards.

## Overview

**NSReady** is the current production platform providing:
- Data collection and telemetry ingestion
- Configuration management (customers, projects, sites, devices)
- Registry and parameter template management
- TimescaleDB-based time-series data storage

**NSWare** is the future platform expansion that will include:
- Enhanced operational dashboards
- Advanced analytics and reporting
- Extended configuration capabilities

Both platforms share the same infrastructure foundation (PostgreSQL, NATS, Docker) but serve different use cases.

---

## Repository Structure

```
ntppl_nsready_platform/
├── admin_tool/              # NSReady: Configuration management API (FastAPI, port 8000)
├── collector_service/          # NSReady: Telemetry ingestion service (FastAPI, port 8001)
├── db/                       # Database schema, migrations, and TimescaleDB setup
├── frontend_dashboard/       # NSWare: React/TypeScript dashboard (future)
├── deploy/                  # Deployment configs (K8s, Helm, Docker Compose)
├── scripts/                 # Utility scripts (backup, import/export, testing)
├── backups/                 # Local file-level backups (excluded from git)
├── tests/                   # Test suites (regression, performance, resilience)
├── docs/                    # User-facing documentation (includes contracts/)
├── master_docs/             # Master documentation and design specs
├── docker-compose.yml       # Local development environment
├── Makefile                 # Development commands
└── README.md                # This file
```

### Backend Organization (NSReady)

The NSReady backend is split across three main services:

- **`admin_tool/`** - Configuration management API
  - Customer, project, site, device management
  - Parameter template management
  - Registry versioning and publishing
  - **Note:** NSReady has a small internal operational dashboard (UI/templates) under `admin_tool/` for engineers and administrators. This is separate from NSWare's full SaaS dashboard.
  
- **`collector_service/`** - Telemetry ingestion service
  - REST API for event ingestion
  - NATS message queuing
  - Asynchronous database writes to TimescaleDB
  
- **`db/`** - Database layer
  - PostgreSQL 15 with TimescaleDB extension
  - Schema migrations
  - Views and stored procedures

### Documentation Layout

- **`docs/`** - User-facing documentation (manuals, guides, tutorials)
- **`master_docs/`** - Master documentation (design docs, architecture, policies)

**Note:** Future reorganization may consolidate documentation, but current structure is maintained for clarity.

### Backup Policy

This project follows a **three-layer backup model** per `master_docs/PROJECT_BACKUP_AND_VERSIONING_POLICY.md`:

1. **File-level backup** in `backups/` folder
2. **Git backup branch** (`backup/YYYY-MM-DD-CHANGE_NAME`)
3. **Git tag** (optional, recommended for major changes)

Use `scripts/backup_before_change.sh` to automate backup creation before significant changes.

---

## NSReady Platform

**Status:** ✅ Active / Production

NSReady provides data collection and configuration management for Tier-1 local deployments.

### Components

- **admin_tool** (FastAPI, port 8000) - Configuration management API
- **collector_service** (FastAPI, port 8001) - Telemetry ingestion service
- **PostgreSQL 15 with TimescaleDB** - Time-series data storage
- **NATS** message queue - Async event processing

### NSReady v1 Tenant Model (Customer = Tenant)

NSReady v1 is multi-tenant. Each tenant is represented by a customer record.

- `customer_id` is the tenant boundary.
- Everywhere in this system, "customer" and "tenant" are equivalent concepts.
- `parent_customer_id` (or group id) is used only for grouping multiple customers (for OEM or group views). It does not define a separate tenant boundary.

---

## NSWare Platform

**Status:** 🚧 Future / Planned

NSWare will provide enhanced operational dashboards and analytics capabilities.

### Planned Components

- Enhanced dashboard UI (React/TypeScript)
- Advanced analytics and reporting
- Extended configuration management
- Real-time monitoring and alerting

### Important: NSReady UI vs NSWare Dashboard

**Critical Distinction:**

- **NSReady Operational Dashboard** (Current, Internal)
  - Location: `admin_tool/ui/` (or `admin_tool/templates/`) - under NSReady backend
  - Purpose: Lightweight internal UI for engineers/administrators
  - Technology: Simple HTML/JavaScript, served by FastAPI
  - Authentication: Bearer token (simple)
  - Status: Current / In design

- **NSWare Dashboard** (Future, Full SaaS Platform)
  - Location: `frontend_dashboard/` (future: `nsware_frontend/frontend_dashboard/`)
  - Purpose: Full industrial platform UI for multi-tenant SaaS operations
  - Technology: React/TypeScript, separate service
  - Authentication: Full stack (JWT, RBAC, MFA)
  - Status: Future / Planned

**See `master_docs/NSREADY_VS_NSWARE_DASHBOARD_CLARIFICATION.md` for full details.**

**Note:** NSWare components are in development. See `master_docs/NSWARE_DASHBOARD_MASTER.md` for current status.

---

## Prerequisites

- Docker Desktop for macOS
- `docker-compose` CLI available (Docker Desktop provides this)

---

## Environment Variables

Copy the example file and adjust as needed:
```bash
cp .env.example .env
```

`.env.example` contains:
```bash
APP_ENV=development
POSTGRES_DB=nsready_db
POSTGRES_USER=nsready_user
POSTGRES_PASSWORD=nsready_password
POSTGRES_HOST=db
POSTGRES_PORT=5432
NATS_URL=nats://nats:4222
```

---

## Build and Run

Using Makefile:
```bash
make up
```

Or directly:
```bash
docker-compose up --build
```

This will start:
- `admin_tool` on `http://localhost:8000`
- `collector_service` on `http://localhost:8001`
- `Postgres` on `localhost:5432` (TimescaleDB extension enabled)
- `NATS` on `nats://localhost:4222` with monitoring on `http://localhost:8222`

---

## Health Checks

Test the services:
```bash
curl http://localhost:8000/health
curl http://localhost:8001/health
```

Expected response:
```json
{ "service": "ok" }
```

---

## Tear Down

```bash
make down
```

Or:
```bash
docker-compose down
```

---

## How to Work with This Repository

### For Developers

1. **Before making changes:** Create backups using `scripts/backup_before_change.sh`
2. **Work in feature branches:** Use `feature/`, `chore/`, or `fix/` prefixes
3. **Follow backup policy:** See `master_docs/PROJECT_BACKUP_AND_VERSIONING_POLICY.md`
4. **Test changes:** Run test suites in `tests/`
5. **Update documentation:** Keep `docs/` and `master_docs/` in sync

### For AI Tools (Cursor, GitHub Copilot, etc.)

- **Repository structure:** Use the "Repository Structure" section above for accurate folder references
- **Documentation:** Check `docs/` for user guides, `master_docs/` for design docs
- **Backend services:** Understand the split between `admin_tool/`, `collector_service/`, and `db/`
- **NSReady vs NSWare:** Distinguish between active (NSReady) and future (NSWare) components

---

## Notes

- Database data persists in the named volume `nsready_db_data`.
- Both apps are built with Python 3.11 and served by Uvicorn.
- `collector_service` uses `NATS_URL` and both services can use the DB env vars.
- For security documentation, see the security documentation in master_docs (currently being developed).

---

## Additional Resources

- **API Documentation:** See `docs/12_API_Developer_Manual.md`
- **Deployment Guide:** See `DEPLOYMENT_GUIDE.md`
- **Backup Policy:** See `master_docs/PROJECT_BACKUP_AND_VERSIONING_POLICY.md`
- **Testing Guide:** See `tests/README.md`
