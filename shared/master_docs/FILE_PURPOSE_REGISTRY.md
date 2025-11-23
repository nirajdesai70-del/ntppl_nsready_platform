# File Purpose Registry

**Date:** 2025-11-22  
**Purpose:** Complete registry of all files and folders with their purpose and location

---

## Repository Structure

```
ntppl_nsready_platform/
├── nsready_backend/          # NSReady backend services
├── nsware_frontend/          # NSWare frontend (future)
├── shared/                   # Shared resources
├── backups/                  # Local backups (gitignored)
├── .github/                  # GitHub configs
└── Root files               # Config files
```

---

## Root Level Files

| File | Purpose | Status | Location |
|------|---------|--------|----------|
| `README.md` | Main project documentation | ✅ Active | Root |
| `docker-compose.yml` | Local development environment | ✅ Active | Root |
| `Makefile` | Development commands | ✅ Active | Root |
| `openapi_spec.yaml` | OpenAPI API specification | ✅ Active | Root |

---

## nsready_backend/

### Purpose
NSReady backend services - active production platform for data collection and configuration management.

### Structure

#### admin_tool/
**Purpose:** Configuration management API (FastAPI, port 8000)

| File/Folder | Purpose | Status |
|------------|---------|--------|
| `api/` | API endpoints (customers, projects, sites, devices, param_templates) | ✅ Active |
| `core/db.py` | Database connection and utilities | ✅ Active |
| `app.py` | FastAPI application entry point | ✅ Active |
| `Dockerfile` | Container build configuration | ✅ Active |
| `requirements.txt` | Python dependencies | ✅ Active |
| `README.md` | Service documentation | ✅ Active |

#### collector_service/
**Purpose:** Telemetry ingestion service (FastAPI, port 8001)

| File/Folder | Purpose | Status |
|------------|---------|--------|
| `api/ingest.py` | Event ingestion endpoint | ✅ Active |
| `core/worker.py` | NATS worker for async processing | ✅ Active |
| `core/nats_client.py` | NATS JetStream client | ✅ Active |
| `core/metrics.py` | Prometheus metrics | ✅ Active |
| `app.py` | FastAPI application entry point | ✅ Active |
| `Dockerfile` | Container build configuration | ✅ Active |
| `requirements.txt` | Python dependencies | ✅ Active |
| `README.md` | Service documentation | ✅ Active |
| `RESILIENCE_FIXES.md` | Resilience improvements documentation | ✅ Active |
| `tests/` | Service-specific tests | ✅ Active |

#### db/
**Purpose:** Database layer (PostgreSQL 15 + TimescaleDB)

| File/Folder | Purpose | Status |
|------------|---------|--------|
| `migrations/` | Database schema migrations | ✅ Active |
| `migrations/100_core_registry.sql` | Core registry tables | ✅ Active |
| `migrations/110_telemetry.sql` | Telemetry tables | ✅ Active |
| `migrations/120_timescale_hypertables.sql` | TimescaleDB setup | ✅ Active |
| `migrations/130_views.sql` | Database views | ✅ Active |
| `migrations/140_registry_versions_enhancements.sql` | Registry versioning | ✅ Active |
| `migrations/150_customer_hierarchy.sql` | Tenant/customer hierarchy | ✅ Active |
| `init.sql` | Database initialization | ✅ Active |
| `seed_registry.sql` | Seed data | ✅ Active |
| `Dockerfile` | Container build configuration | ✅ Active |
| `README.md` | Database documentation | ✅ Active |

#### dashboard/
**Purpose:** NSReady internal operational dashboard

| File/Folder | Purpose | Status |
|------------|---------|--------|
| `node_modules/` | NPM dependencies (gitignored) | ✅ Active |

#### tests/
**Purpose:** Backend test suites

| File/Folder | Purpose | Status |
|------------|---------|--------|
| `regression/` | Regression test suite | ✅ Active |
| `resilience/` | Resilience test suite | ✅ Active |
| `utils/` | Test utilities | ✅ Active |
| `reports/` | Test execution reports | ✅ Active |
| `performance/` | Performance test files | ✅ Active |

---

## nsware_frontend/

### Purpose
NSWare frontend components - future SaaS platform UI.

### Structure

#### frontend_dashboard/
**Purpose:** React/TypeScript dashboard (future)

| File/Folder | Purpose | Status |
|------------|---------|--------|
| `package.json` | NPM package configuration | 🚧 Future |
| `package-lock.json` | NPM lock file | 🚧 Future |
| `tsconfig.json` | TypeScript configuration | 🚧 Future |
| `tsconfig.node.json` | TypeScript node config | 🚧 Future |
| `README.md` | Frontend documentation | ✅ Active |

---

## shared/

### Purpose
Shared resources used across NSReady and NSWare platforms.

### Structure

#### contracts/
**Purpose:** Shared data contracts and API schemas

| File/Folder | Purpose | Status |
|------------|---------|--------|
| `nsready/ingest_events.yaml` | Ingest events contract | ✅ Active |
| `nsready/parameter_templates.yaml` | Parameter templates contract | ✅ Active |
| `nsready/v_scada_latest.yaml` | SCADA latest view contract | ✅ Active |
| `nsready/v_scada_history.yaml` | SCADA history view contract | ✅ Active |

#### docs/
**Purpose:** User-facing documentation

| File/Folder | Purpose | Status |
|------------|---------|--------|
| `NSReady_Dashboard/` | NSReady user documentation modules (00-13) | ✅ Active |
| `NSReady_Dashboard/additional/` | Additional documentation modules | ✅ Active |

#### master_docs/
**Purpose:** Master documentation, design specs, policies

| File/Folder | Purpose | Status |
|------------|---------|--------|
| `archive/` | Historical documentation | ✅ Active |
| `implementation/` | Implementation summaries | ✅ Active |
| `security/` | Security documentation | ✅ Active |
| `tenant_upgrade/` | Tenant upgrade documentation | ✅ Active |
| Active master docs | Current design and architecture docs | ✅ Active |

#### deploy/
**Purpose:** Deployment configurations

| File/Folder | Purpose | Status |
|------------|---------|--------|
| `k8s/` | Kubernetes configurations | ✅ Active |
| `helm/nsready/` | Helm charts for NSReady | ✅ Active |
| `monitoring/` | Monitoring configs (Prometheus, Grafana) | ✅ Active |
| `nats/` | NATS JetStream configurations | ✅ Active |
| `traefik/` | Traefik ingress configurations | ✅ Active |

#### scripts/
**Purpose:** Utility scripts

| File/Folder | Purpose | Status |
|------------|---------|--------|
| `backup_before_change.sh` | Backup automation script | ✅ Active |
| `import_registry.sh` | Registry import script | ✅ Active |
| `export_registry_data.sh` | Registry export script | ✅ Active |
| `import_parameter_templates.sh` | Parameter template import | ✅ Active |
| `export_parameter_template_csv.sh` | Parameter template export | ✅ Active |
| `export_scada_data.sh` | SCADA data export | ✅ Active |
| `export_scada_data_readable.sh` | SCADA readable export | ✅ Active |
| `test_*.sh` | Test scripts | ✅ Active |
| `tenant_testing/` | Tenant isolation test scripts | ✅ Active |
| `*.md` | Script guides and documentation | ✅ Active |
| `*.csv` | CSV templates | ✅ Active |
| `*.sql` | SQL setup scripts | ✅ Active |
| `*.json` | Test event files | ✅ Active |

---

## .github/

### Purpose
GitHub workflows and templates

| File/Folder | Purpose | Status |
|------------|---------|--------|
| `workflows/build-test-deploy.yml` | CI/CD workflow | ✅ Active |
| `pull_request_template.md` | PR template | ✅ Active |

---

## File Status Legend

- ✅ **Active** - Currently used, maintained
- 🚧 **Future** - Planned, not yet active
- 📦 **Archive** - Historical, kept for reference
- ❌ **Obsolete** - No longer used, can be deleted

---

## Cleanup Status

### ✅ Completed
- Removed empty unknown directories (operation, permitted, not)
- Removed empty old directories (admin_tool, deploy at root)
- Removed duplicate files (db 2.py, Dockerfile 2, migrations 2/)
- Moved test reports to correct location

### ⚠️ Pending Review
- Backup README files (README_BACKUP.md) - Compare with current and remove if redundant

---

**Last Updated:** 2025-11-22  
**Status:** Active Registry


