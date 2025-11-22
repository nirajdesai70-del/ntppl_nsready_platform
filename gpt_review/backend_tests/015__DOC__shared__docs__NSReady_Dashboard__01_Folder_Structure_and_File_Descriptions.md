# Module 1 – Folder Structure and File Descriptions

_NSReady Data Collection Platform_

*(Suggested path: `docs/01_Folder_Structure_and_File_Descriptions.md`)*

---

## 1. Introduction

This module explains the complete directory structure and file organization of the NSReady Data Collection Platform.

New engineers must understand:

- Where the ingestion code lives
- Where configuration scripts live
- Where database migrations live
- Where deployment files live
- Which folders are SAFE to modify
- Which folders should NOT be touched

This document serves as the navigation guidebook for your entire project.

---

## 2. High-Level Directory Map

```
ntppl_nsready_platform/
│
├── admin_tool/              → Admin configuration API
├── collector_service/       → Telemetry ingestion service
├── db/                      → Database schema and migrations
├── deploy/                  → Kubernetes deployments
├── scripts/                 → Operational tools and utilities
├── tests/                   → Automated testing suite
├── docs/                    → Documentation modules
├── reports/                 → Generated reports and exports
│
├── docker-compose.yml       → Local Docker development
├── Makefile                 → Build and test shortcuts
├── README.md                → Project overview
├── openapi_spec.yaml        → API specification
└── .gitignore               → Git ignore rules
```

We now describe each folder in detail.

---

## 3. Folder-by-Folder Explanation

### 📁 3.1 `admin_tool/`

**Purpose:**

Admin configuration API that manages registry & parameter templates, and provides CRUD operations for:

- Customers
- Projects
- Sites
- Devices
- Parameter templates
- Registry versions

**Important files inside:**

```
admin_tool/
│
├── app.py                     → Main FastAPI application
│
├── core/
│   └── db.py                  → DB connection (async SQLAlchemy)
│
├── api/
│   ├── customers.py           → Customer CRUD endpoints
│   ├── projects.py            → Project CRUD endpoints
│   ├── sites.py               → Site CRUD endpoints
│   ├── devices.py             → Device CRUD endpoints
│   ├── parameter_templates.py → Parameter template CRUD endpoints
│   ├── registry_versions.py   → Version publishing APIs
│   ├── deps.py                → Shared API dependencies
│   └── models.py              → SQLAlchemy ORM models
│
├── Dockerfile                 → Admin Tool container build
├── requirements.txt           → Python dependencies
└── README.md                  → Admin tool documentation
```

**Key Endpoints:**

- `GET /admin/customers` - List customers
- `POST /admin/customers` - Create customer
- `GET /admin/projects` - List projects
- `POST /admin/projects/{id}/versions/publish` - Publish config version

**Do not modify:**

- `api/models.py` - Core database models (unless adding features)
- Internal versioning logic in `registry_versions.py`

---

### 📁 3.2 `collector_service/`

**Purpose:**

Handles ingestion of telemetry from field devices or simulators.

**Core responsibilities:**

- `/v1/ingest` endpoint
- Validation of NormalizedEvent
- Queueing to NATS JetStream
- Worker pull-consumer pool
- DB insertion into `ingest_events`

**Important files inside:**

```
collector_service/
│
├── app.py                         → FastAPI app with health + startup logic
│
├── core/
│   ├── nats_client.py             → JetStream connection + queue_depth stats
│   ├── db.py                      → Async DB engine & session management
│   ├── worker.py                  → Worker pool (batch event consumer)
│   └── metrics.py                 → Prometheus metrics instruments
│
├── api/
│   ├── ingest.py                  → /v1/ingest endpoint handler
│   └── models.py                  → NormalizedEvent Pydantic schema
│
├── tests/
│   └── sample_event.json          → Example test event
│
├── Dockerfile                     → Collector service container build
├── requirements.txt               → Python dependencies
├── README.md                      → Collector service documentation
└── RESILIENCE_FIXES.md            → Resilience improvements notes
```

**Key Files:**

- `api/models.py` - Defines `NormalizedEvent` and `Metric` schemas
- `core/worker.py` - Batch processing with transaction safety
- `core/nats_client.py` - NATS JetStream integration

**Do not modify unless required:**

- `core/worker.py` - Ensures correct event handling and ACK logic
- `core/nats_client.py` - Very sensitive to performance
- `core/db.py` - Transaction safety critical

---

### 📁 3.3 `db/`

**Purpose:**

Database schema, migrations, and initialization scripts.

**Structure:**

```
db/
│
├── init.sql                       → Initial schema creation (if needed)
├── seed_registry.sql              → Optional seed data
│
├── migrations/
│   ├── 100_core_registry.sql      → Customers, projects, sites, devices
│   ├── 110_telemetry.sql          → ingest_events, error_logs tables
│   ├── 120_timescale_hypertables.sql → TimescaleDB hypertable setup
│   ├── 130_views.sql              → SCADA views (v_scada_latest, v_scada_history)
│   └── 140_registry_versions_enhancements.sql → Version tracking
│
├── Dockerfile                     → PostgreSQL with TimescaleDB
└── README.md                      → Database documentation
```

**Migration Naming:**

- `100_` - Core registry tables
- `110_` - Telemetry tables
- `120_` - TimescaleDB configuration
- `130_` - Database views
- `140_` - Additional features

**Important:**

- **Do not delete migration files** - They are versioned
- Future DB schema changes go here as new migration files
- Migrations are applied in order during deployment

---

### 📁 3.4 `deploy/`

**Purpose:**

Kubernetes deployments for production or testing.

**Structure:**

```
deploy/
│
├── k8s/
│   ├── namespace.yaml             → nsready-tier2 namespace
│   ├── admin_tool-deployment.yaml → Admin tool deployment
│   ├── collector_service-deployment.yaml → Collector service deployment
│   ├── postgres-statefulset.yaml  → PostgreSQL StatefulSet
│   ├── nats-statefulset.yaml      → NATS JetStream StatefulSet
│   ├── hpa.yaml                   → Horizontal Pod Autoscaler
│   ├── ingress.yaml               → Ingress controller config
│   ├── rbac.yaml                  → Role-Based Access Control
│   ├── secrets.yaml               → Secrets (passwords, tokens)
│   ├── configmap.yaml             → Configuration maps
│   ├── admin-tool-nodeport.yaml   → NodePort service for admin tool
│   ├── collector-nodeport.yaml    → NodePort service for collector
│   ├── backup-cronjob.yaml        → Automated backup jobs
│   ├── restore-job.yaml           → Restore job template
│   └── network-policies.yaml      → Network security policies
│
├── helm/
│   └── nsready/
│       ├── Chart.yaml             → Helm chart metadata
│       ├── values.yaml            → Default values
│       └── templates/             → Helm templates
│
├── monitoring/
│   ├── grafana-dashboards/
│   │    └── dashboard.json        → NSReady dashboard
│   ├── grafana.yaml               → Grafana deployment
│   ├── prometheus.yaml            → Prometheus deployment
│   ├── prometheus-config.yaml     → Prometheus configuration
│   └── alertmanager.yaml          → Alertmanager configuration
│
├── nats/
│   ├── jetstream.conf             → NATS JetStream configuration
│   └── jetstream/                 → JetStream data directory
│
└── traefik/
    ├── traefik.yml                → Traefik ingress configuration
    └── letsencrypt/               → SSL certificate storage
```

**Do not modify casually:**

- `postgres-statefulset.yaml` - Database persistence
- `nats-statefulset.yaml` - Message queue persistence
- `rbac.yaml` - Security permissions
- `secrets.yaml` - Contains sensitive data

---

### 📁 3.5 `scripts/`

**Purpose:**

Operational tools for configuration, export, SCADA integration, and testing.

**Structure:**

```
scripts/
│
├── Configuration Import
│   ├── import_registry.sh                    → Import customers/projects/sites/devices
│   ├── import_parameter_templates.sh         → Import parameter templates
│   ├── registry_template.csv                 → Registry CSV template
│   ├── example_registry.csv                  → Example registry data
│   ├── parameter_template_template.csv       → Parameter CSV template
│   └── example_parameters.csv                → Example parameter data
│
├── Export Tools
│   ├── export_registry_data.sh               → Export full registry
│   ├── export_parameter_template_csv.sh      → Export parameter templates
│   ├── export_scada_data.sh                  → Export SCADA raw data
│   └── export_scada_data_readable.sh         → Export SCADA readable data
│
├── Utilities
│   ├── list_customers_projects.sh            → List customers and projects
│   └── test_scada_connection.sh              → Test SCADA DB connection
│
├── SQL Scripts
│   └── setup_scada_readonly_user.sql         → Create SCADA read-only user
│
├── Testing
│   └── test_drive.sh                         → Comprehensive automated test
│
├── Backups
│   ├── backup_pg.sh                          → PostgreSQL backup script
│   └── backup_jetstream.sh                   → NATS JetStream backup script
│
└── Deployment
    └── push-images.sh                        → Push Docker images to registry
```

**Documentation:**

- Scripts are documented in **Module 10** - Scripts and Tools Reference Manual
- Some scripts have additional documentation files (`.md` files in `scripts/`)

**Usage:**

These scripts are used across:
- **Module 5** - Configuration Import Manual
- **Module 9** - SCADA Integration Manual
- **Module 10** - Scripts and Tools Reference Manual
- **Module 11** - Troubleshooting and Diagnostics Manual

---

### 📁 3.6 `tests/`

**Purpose:**

Automated regression, integration, performance, and resilience testing.

**Structure:**

```
tests/
│
├── regression/
│   ├── test_api_endpoints.py     → API endpoint tests
│   └── ...                       → Other regression tests
│
├── performance/
│   ├── locustfile.py             → Locust load test configuration
│   └── tests/                    → Performance test scripts
│
├── resilience/
│   └── test_recovery.py          → Restart & recovery tests
│
├── utils/
│   ├── reporting.py              → Test reporting utilities
│   └── ...                       → Test helper functions
│
├── reports/                      → Generated test reports
│   ├── *.md                      → Test result reports
│   ├── *.csv                     → Test statistics
│   └── *.html                    → Test dashboards
│
├── run_all_tests.py              → Main test runner
├── pytest.ini                    → Pytest configuration
├── requirements.txt              → Test dependencies
└── README.md                     → Testing documentation
```

**Note:**

Engineers should run these tests before deploying to real field devices.

---

### 📁 3.7 `docs/`

**Purpose:**

Complete documentation set for the NSReady platform.

**Structure:**

```
docs/
│
├── 00_Introduction_and_Terminology.md
├── 01_Folder_Structure_and_File_Descriptions.md  → This document
├── 02_System_Architecture_and_DataFlow.md
├── 03_Environment_and_PostgreSQL_Storage_Manual.md
├── 04_Deployment_and_Startup_Manual.md
├── 05_Configuration_Import_Manual.md
├── 06_Parameter_Template_Manual.md
├── 07_Data_Ingestion_and_Testing_Manual.md
├── 08_Monitoring_API_and_Packet_Health_Manual.md
├── 09_SCADA_Integration_Manual.md
├── 10_Scripts_and_Tools_Reference_Manual.md
├── 11_Troubleshooting_and_Diagnostics_Manual.md
├── 12_API_Developer_Manual.md
├── 13_Performance_and_Monitoring_Manual.md
├── Master_Operation_Manual.md
├── DOCUMENTATION_TRACKING.md     → Documentation status tracking
└── README.md                     → Documentation index
```

**Documentation Modules:**

See **Module 0** - Introduction and Terminology for the complete module list.

---

### 📁 3.8 `reports/`

**Purpose:**

Generated reports and exports from scripts.

**Contents:**

```
reports/
│
├── registry_export_*.csv         → Registry exports
├── parameter_templates_export_*.csv → Parameter template exports
├── scada_latest_*.txt            → SCADA latest value exports
├── scada_history_*.csv           → SCADA historical exports
├── scada_*_readable_*.txt        → SCADA readable format exports
└── locust_*.html                 → Performance test reports
```

**Note:**

This directory is typically not committed to version control (see `.gitignore`).

Files are generated by:
- Export scripts in `scripts/`
- Test scripts in `tests/`

---

### 📁 3.9 Root Files (Very Important)

#### `docker-compose.yml`

**Purpose:**

Local Docker-based development environment.

**Services:**

- `nsready_db` - PostgreSQL with TimescaleDB
- `collector_service` - Collector service
- `admin_tool` - Admin tool
- `nsready_nats` - NATS JetStream server

**Usage:**

```bash
docker-compose up -d      # Start all services
docker-compose down       # Stop all services
```

**Note:**

- Used **only** for local Docker-based simulation
- **NOT** used in Kubernetes mode

---

#### `Makefile`

**Purpose:**

Provides shortcuts for common operations.

**Common Commands:**

```bash
make up              # Start Docker Compose services
make down            # Stop Docker Compose services
make test            # Run test suite
make benchmark       # Run performance benchmarks
```

**Check the Makefile for all available commands.**

---

#### `README.md`

**Purpose:**

Top-level documentation entry point.

**Contains:**

- Project overview
- Quick start guide
- Architecture summary
- Links to detailed documentation

---

#### `openapi_spec.yaml`

**Purpose:**

OpenAPI 3.0 specification for all API endpoints.

**Covers:**

- Admin Tool APIs (`/admin/*`)
- Collector Service APIs (`/v1/*`)
- Health endpoints
- Metrics endpoints

**Usage:**

- Generate API client code
- View in Swagger UI
- API documentation reference

---

#### `.gitignore`

**Purpose:**

Git ignore rules for files that should not be committed.

**Common patterns:**

- `__pycache__/` - Python cache
- `*.pyc` - Compiled Python files
- `reports/` - Generated reports
- `*.log` - Log files
- `.env` - Environment variables
- `.venv/` - Virtual environments

---

#### `DOCUMENTATION_TRACKING.md`

**Purpose:**

Master tracking file for documentation integrity.

**Contains:**

- File mappings (old → new)
- Module status tracking
- Content mapping
- Consistency checks

**Location:** `docs/DOCUMENTATION_TRACKING.md`

---

## 4. Engineering Workflow Map

The folder structure supports this typical workflow:

1. **Deployment** (Module 04)
   - Use `deploy/k8s/` for Kubernetes
   - Use `docker-compose.yml` for local development

2. **Configuration Import** (Module 05)
   - Use `scripts/import_registry.sh`
   - Use `scripts/import_parameter_templates.sh`

3. **Parameter Templates** (Module 06)
   - Use `scripts/parameter_template_template.csv`
   - Reference `db/migrations/020_parameter_templates.sql`

4. **Data Ingestion Tests** (Module 07)
   - Use `tests/regression/` for API tests
   - Use `collector_service/tests/sample_event.json` for examples

5. **Monitoring & Packet Health** (Module 08)
   - Use `deploy/monitoring/` for Grafana/Prometheus
   - Reference `collector_service/core/metrics.py`

6. **SCADA Integration** (Module 09)
   - Use `scripts/export_scada_data*.sh`
   - Use `scripts/setup_scada_readonly_user.sql`
   - Reference `db/migrations/130_views.sql`

7. **Scripts** (Module 10)
   - All scripts in `scripts/` are documented

8. **Troubleshooting** (Module 11)
   - Reference logs in container/pod logs
   - Use diagnostic scripts in `scripts/`

---

## 5. File Type Icons (Symbol Glossary)

For quick visual identification in documentation:

- 📁 **folder** - Directory
- 📄 **file** - Generic file
- 🧩 **Python file** - `.py` files
- ⚙️ **Configuration** - `.yaml`, `.yml`, `.toml`, `.conf`
- 🐳 **Dockerfile** - Container configuration
- ⇄ **API/Network** - API endpoint files, network configs
- 🗃 **SQL** - Database schema, migrations
- 📝 **Markdown** - Documentation (`.md`)
- 📊 **CSV** - Data templates, exports
- 🧪 **Test file** - Test scripts, test data
- 🔐 **Secrets** - Security-related files

---

## 6. "Do Not Touch" Zones

These files should **not be modified** unless absolutely necessary:

### Database

- `db/migrations/*.sql` - Migration files are versioned and immutable
- `db/init.sql` - Initial schema (if critical)

### Core Services

- `collector_service/core/worker.py` - Logic sensitive, ACK behavior critical
- `collector_service/core/nats_client.py` - Queue logic, performance critical
- `collector_service/core/db.py` - Transaction safety critical
- `admin_tool/api/models.py` - Core database models

### Deployment

- `deploy/k8s/postgres-statefulset.yaml` - Database persistence
- `deploy/k8s/nats-statefulset.yaml` - Message queue persistence
- `deploy/k8s/rbac.yaml` - Security permissions
- `deploy/k8s/secrets.yaml` - Sensitive credentials
- `deploy/helm/nsready/templates/*` - Helm chart templates (unless upgrading)

### Configuration

- `.gitignore` - Version control rules
- `docker-compose.yml` - Service definitions (modify with caution)

---

## 7. Safe-to-Modify Areas (For New Features)

These areas are **safe to modify** when adding features:

### API Endpoints

- `admin_tool/api/*.py` - API endpoint handlers (except `models.py`)
- `collector_service/api/ingest.py` - Ingestion endpoint logic

### Scripts

- `scripts/*.sh` - Operational scripts
- `scripts/*.sql` - Utility SQL scripts (not migrations)

### Monitoring

- `deploy/monitoring/grafana-dashboards/dashboard.json` - Dashboard configuration
- `deploy/monitoring/prometheus-config.yaml` - Prometheus configuration

### Documentation

- `docs/*.md` - All documentation files
- `README.md` - Project documentation

### Tests

- `tests/regression/*.py` - Regression tests
- `tests/performance/locustfile.py` - Performance test configuration
- `tests/resilience/*.py` - Resilience tests

### Configuration Templates

- `scripts/registry_template.csv` - Registry import template
- `scripts/parameter_template_template.csv` - Parameter import template

---

## 8. Important File Locations Quick Reference

### Finding Code

| What You Need | Where to Look |
|---------------|---------------|
| Ingestion endpoint | `collector_service/api/ingest.py` |
| Admin API endpoints | `admin_tool/api/*.py` |
| Worker logic | `collector_service/core/worker.py` |
| Database models | `admin_tool/api/models.py` |
| Event schema | `collector_service/api/models.py` |

### Finding Configuration

| What You Need | Where to Look |
|---------------|---------------|
| Docker Compose | `docker-compose.yml` |
| Kubernetes deployments | `deploy/k8s/*.yaml` |
| Database migrations | `db/migrations/*.sql` |
| Environment variables | `deploy/k8s/configmap.yaml`, `deploy/k8s/secrets.yaml` |

### Finding Scripts

| What You Need | Where to Look |
|---------------|---------------|
| Import scripts | `scripts/import_*.sh` |
| Export scripts | `scripts/export_*.sh` |
| Test scripts | `scripts/test_*.sh` |
| Backup scripts | `scripts/backups/*.sh` |

### Finding Documentation

| What You Need | Where to Look |
|---------------|---------------|
| All documentation | `docs/*.md` |
| Documentation index | `docs/README.md` |
| Module tracking | `docs/DOCUMENTATION_TRACKING.md` |

---

## 9. Final Folder-Level Checklist

Before starting development work, ensure:

- [ ] Engineers understand purpose of each folder
- [ ] No core system files edited accidentally
- [ ] All scripts documented in Module 10
- [ ] Developers use correct Python folders for API changes
- [ ] Deployments updated only through Module 04 procedures
- [ ] Database migrations follow naming convention (`XXX_description.sql`)
- [ ] Test files are in appropriate `tests/` subdirectories
- [ ] Generated files go to `reports/` (not committed to Git)

---

## 10. Next Steps

After understanding the folder structure:

- **Module 02** – System Architecture and DataFlow
  - Understand how components interact
  - Visual data flow diagrams

- **Module 03** – Environment and PostgreSQL Storage Manual
  - Set up local development environment
  - Understand database structure

- **Module 05** – Configuration Import Manual
  - Use scripts in `scripts/` for configuration

---

**End of Module 1 – Folder Structure and File Descriptions**

**Last Updated:** 2025-11-18

_NSReady Data Collection Platform Documentation Team_

