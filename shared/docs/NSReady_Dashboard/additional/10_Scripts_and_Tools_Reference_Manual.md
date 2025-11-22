# Module 10 – Scripts and Tools Reference Manual

_NSReady Data Collection Platform_

*(Suggested path: `docs/10_Scripts_and_Tools_Reference_Manual.md`)*

---

## 1. Introduction

This module documents every shell script and CSV template provided with the NSReady Data Collection Platform. These scripts are used for:

- Configuration import
- Parameter template management
- Registry export
- SCADA export
- Database connectivity testing
- Engineer-level troubleshooting

All scripts are located in:

```
<project-root>/scripts/
```

### NSReady v1 Tenant Model (Customer = Tenant)

NSReady v1 is multi-tenant. Each tenant is represented by a customer record.

- `customer_id` is the tenant boundary.

- Everywhere in this system, "customer" and "tenant" are equivalent concepts.

- `parent_customer_id` (or group id) is used only for grouping multiple customers (for OEM or group views). It does not define a separate tenant boundary.

- For API calls made on behalf of customer users, the `X-Customer-ID` header represents the tenant id.

- For internal engineer/admin tools, `customer_id` may be optional to allow cross-tenant admin operations.

---

## 2. Summary Table of All Scripts

| Script Name | Purpose | Category |
|-------------|---------|----------|
| `import_registry.sh` | Import customers, projects, sites, devices | Configuration |
| `import_parameter_templates.sh` | Import parameter templates | Configuration |
| `export_registry_data.sh` | Export full registry (read-only) | Export |
| `export_parameter_template_csv.sh` | Export parameter templates | Export |
| `export_scada_data.sh` | Export SCADA-ready raw data | SCADA |
| `export_scada_data_readable.sh` | Export SCADA-readable data with names | SCADA |
| `list_customers_projects.sh` | List all customers and projects | Utilities |
| `test_scada_connection.sh` | Test SCADA DB connectivity | Testing |
| `test_drive.sh` | Comprehensive automated testing (Kubernetes) | Testing |
| `test_data_flow.sh` | Basic end-to-end data flow test | Testing |
| `test_batch_ingestion.sh` | Batch ingestion testing (sequential/parallel) | Testing |
| `test_stress_load.sh` | Stress/load testing with configurable RPS | Testing |
| `test_multi_customer_flow.sh` | Multi-customer data flow and tenant isolation | Testing |
| `test_negative_cases.sh` | Negative test cases (invalid data validation) | Testing |
| `setup_scada_readonly_user.sql` | Creates read-only SCADA DB user | SQL Script |
| `backup_pg.sh` | PostgreSQL backup script | Backup |
| `backup_jetstream.sh` | NATS JetStream backup script | Backup |
| `push-images.sh` | Push Docker images to registry | Deployment |

### Template Files

| File Name | Purpose |
|-----------|---------|
| `parameter_template_template.csv` | Template for parameter import |
| `example_parameters.csv` | Example parameter CSV |
| `registry_template.csv` | Template for registry import |
| `example_registry.csv` | Example registry CSV |

---

## 3. Detailed Script Documentation

Each script is documented below with:

- Purpose
- When to use
- Exact usage command
- Sample output
- File paths
- Notes

### 3.1 `import_registry.sh`

**Purpose**

Imports Customers → Projects → Sites → Devices from a CSV file.

**When to use**

- New customer (tenant) onboarding
- Setting up a new project
- Bulk creation for testing/demo environments
- After receiving project creation CSV from customer

**Tenant Isolation:** This script supports optional `--customer-id` parameter for tenant-restricted imports.

- `--customer-id` specifies the tenant (customer) for this import operation.
- Customer users must use their own tenant id (customer_id).
- Engineers can use it to limit the operation to a specific tenant (customer).

When provided, all CSV rows must belong to the specified customer.

**Usage (Copy & Paste)**

```bash
# Full import (engineers only - can create new customers)
./scripts/import_registry.sh my_registry.csv

# Tenant-restricted import (customer users - restricted to one tenant/customer)
./scripts/import_registry.sh my_registry.csv --customer-id <customer_id>
```

**Input File Required**

CSV structured like:
- `registry_template.csv`
- `example_registry.csv`

**Format:**

```csv
customer_name,project_name,project_description,site_name,site_location,device_name,device_type,device_code,device_status
```

**Expected Output**

```
Importing registry data from: my_registry.csv
Environment: Kubernetes (or Docker Compose)

NOTICE:  Import completed:
NOTICE:    Rows processed: 5
NOTICE:    Customers created: 1
NOTICE:    Projects created: 1
NOTICE:    Sites created: 3
NOTICE:    Devices created: 5
NOTICE:    Rows skipped: 0

Import completed!
```

**Notes**

- **Tenant Isolation**: When `--customer-id` is provided:
  - All CSV rows must match the specified customer
  - Rows for other customers are skipped with error messages
  - Cannot create new customers (must exist first)
- **Full Import Mode** (no `--customer-id`, engineers only):
  - Can create new customers
  - Can import data for any customer
  - Use only by engineers/admins
- Supports both Kubernetes and Docker Compose (auto-detects)
- Ensures no duplicates
- Device identity is based on `device_code` (preferred) or `device_name`
- `site_location` must be valid JSON (`{}` allowed for empty)
- Creates hierarchy: Customer → Project → Site → Device

**Environment Variables:**

- `NAMESPACE` (default: `nsready-tier2`) - Kubernetes namespace
- `DB_POD` (default: `nsready-db-0`) - Database pod name
- `USE_KUBECTL` (default: `auto`) - Set to `true`/`false` to override auto-detection

**Tenant Isolation Error Messages:**

- `Row X: customer_name "..." does not match restricted customer "..."` - CSV row for wrong customer
- `Error: Customer ID <id> not found in database.` - Customer ID invalid or missing

---

### 3.2 `list_customers_projects.sh`

**Purpose**

Lists all customers and their projects from the database.

**When to use**

- Before creating parameter CSV
- Before validating registry import
- When you need exact customer/project names

**Usage**

```bash
./scripts/list_customers_projects.sh
```

**Expected Output**

```
=== Customers and Projects in Database ===
Environment: Kubernetes (or Docker Compose)

Use these EXACT names in your CSV file:

customer_name,project_name
Customer 01,Project 01_Customer_01
Customer 02,Project 01_Customer_02
Demo Customer,Demo Project

=== CSV Template Format ===
customer_name,project_name,parameter_name,unit,dtype,min_value,max_value,required,description
...
```

**Notes**

- Supports both Kubernetes and Docker Compose (auto-detects)
- Output format is CSV-compatible
- Shows exact names to use in CSV files (case-sensitive)

**Environment Variables:**

- `NAMESPACE` (default: `nsready-tier2`)
- `DB_POD` (default: `nsready-db-0`)
- `USE_KUBECTL` (default: `auto`)

---

### 3.3 `import_parameter_templates.sh`

**Purpose**

Imports engineering parameters (Voltage, Current, Temperature, etc.) into the platform.

**When to use**

- After registry import
- Before ingestion testing
- Whenever adding new parameters

**Tenant Isolation:** This script supports optional `--customer-id` parameter for tenant-restricted imports.

- `--customer-id` specifies the tenant (customer) for this import operation.
- Customer users must use their own tenant id (customer_id).
- Engineers can use it to limit the operation to a specific tenant (customer).

When provided, all CSV rows must belong to the specified customer.

**Usage**

```bash
# Full import (engineers only - can import for any customer)
./scripts/import_parameter_templates.sh my_parameters.csv

# Tenant-restricted import (customer users - restricted to one tenant/customer)
./scripts/import_parameter_templates.sh my_parameters.csv --customer-id <customer_id>
```

**Input File Required**

- `parameter_template_template.csv`
- or `example_parameters.csv`

**Format:**

```csv
customer_name,project_name,parameter_name,unit,dtype,min_value,max_value,required,description
```

**Expected Output**

```
Importing parameter templates from: my_parameters.csv

NOTICE:  Import completed:
NOTICE:    Rows processed: 5
NOTICE:    Templates created: 5
NOTICE:    Rows skipped: 0

Import completed!
```

**Notes**

- **Tenant Isolation**: When `--customer-id` is provided:
  - All CSV rows must match the specified customer
  - Rows for other customers are skipped with error messages
  - Cannot create new customers (must exist first)
- **Full Import Mode** (no `--customer-id`, engineers only):
  - Can import parameters for any existing customer
  - Use only by engineers/admins
- Supports both Kubernetes and Docker Compose (auto-detects)
- Customer/project names must match exactly (case-sensitive)
- Parameters unique within project (based on generated key)
- Existing parameters are skipped (not overwritten)
- Validates that customers and projects exist

**Environment Variables:**

- `NAMESPACE` (default: `nsready-tier2`)
- `DB_POD` (default: `nsready-db-0`)
- `USE_KUBECTL` (default: `auto`)

**Tenant Isolation Error Messages:**

- `Row X: customer_name "..." does not match restricted customer "..."` - CSV row for wrong customer
- `Error: Customer ID <id> not found in database.` - Customer ID invalid or missing

---

### 3.4 `export_parameter_template_csv.sh`

**Purpose**

Exports parameter templates from the database into a CSV file.

**When to use**

- For engineering audit
- For duplicating or modifying parameters
- For debugging parameter mapping
- To review existing parameters

**⚠️ BREAKING CHANGE (Tenant Isolation):** This script now **REQUIRES** `--customer-id` parameter for tenant isolation.

- `--customer-id` specifies the tenant (customer) for this export operation.
- Customer users must use their own tenant id (customer_id).
- Engineers can use it to limit the operation to a specific tenant (customer).

Exports are restricted to a single customer's data.

**Usage**

```bash
# Export parameter templates for specific tenant (customer) (REQUIRED)
./scripts/export_parameter_template_csv.sh --customer-id <customer_id>

# With custom output file
./scripts/export_parameter_template_csv.sh --customer-id <customer_id> my_export.csv
```

**Finding Customer ID:**

```bash
# List all customers to get their IDs
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "SELECT id::text, name FROM customers;"
```

**Output**

Creates a file in `reports/`:

```
reports/<customer_name>_parameter_templates_export_YYYYMMDD_HHMMSS.csv
```

**Expected Output**

```
Exporting parameter templates for customer: Customer 01 (8212caa2-b928-4213-b64e-9f5b86f4cad1)
Output file: reports/customer_01_parameter_templates_export_20251114_1201.csv

Export completed successfully!
File saved to: reports/customer_01_parameter_templates_export_20251114_1201.csv

Row count: 25 rows (excluding header)

Note: Export is tenant-isolated to customer: Customer 01 (8212caa2-b928-4213-b64e-9f5b86f4cad1)
```

**Format:**

```csv
customer_name,project_name,parameter_name,unit,dtype,min_value,max_value,required,description
```

**Notes**

- **Tenant Isolation**: Export is restricted to specified customer only
- Supports both Kubernetes and Docker Compose (auto-detects)
- Includes customer and project names for reference
- Can be re-imported after editing (ensures no duplicates)
- Customer ID must be a valid UUID format

**Environment Variables:**

- `NAMESPACE` (default: `nsready-tier2`)
- `DB_POD` (default: `nsready-db-0`)

**Error Messages:**

- `Error: --customer-id is REQUIRED for tenant isolation` - You must provide a customer ID
- `Error: Invalid customer_id format. Expected UUID format.` - Customer ID must be a valid UUID
- `Error: Customer ID <id> not found in database.` - Customer does not exist

---

### 3.5 `export_registry_data.sh`

**Purpose**

Exports registry data (customers, projects, sites, devices, parameters) in a single CSV.

**When to use**

- For customer (tenant) registry backup/review
- For SCADA mapping reference
- For documentation purposes
- For debugging registry structure

**⚠️ BREAKING CHANGE (Tenant Isolation):** This script now **REQUIRES** `--customer-id` parameter for tenant isolation.

- `--customer-id` specifies the tenant (customer) for this export operation.
- Customer users must use their own tenant id (customer_id).
- Engineers can use it to limit the operation to a specific tenant (customer).

Exports are restricted to a single customer's data.

**Usage**

```bash
# Export registry data for specific tenant (customer) (REQUIRED)
./scripts/export_registry_data.sh --customer-id <customer_id>

# Export test subset (first 5 sites) for tenant (customer)
./scripts/export_registry_data.sh --customer-id <customer_id> --test

# Export limited number of sites for tenant (customer)
./scripts/export_registry_data.sh --customer-id <customer_id> --limit 10
```

**Finding Customer ID:**

```bash
# List all customers to get their IDs
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "SELECT id::text, name FROM customers;"
```

**Output**

Creates file:

```
reports/<customer_name>_registry_export_YYYYMMDD_HHMMSS.csv
# or
reports/<customer_name>_registry_export_test_YYYYMMDD_HHMMSS.csv
```

**Expected Output**

```
Exporting registry data for customer: Customer 01 (8212caa2-b928-4213-b64e-9f5b86f4cad1)
Output file: reports/customer_01_registry_export_20251114_1201.csv

Export completed successfully!
File saved to: reports/customer_01_registry_export_20251114_1201.csv

Row count: 150 rows (excluding header)

Note: Export is tenant-isolated to customer: Customer 01 (8212caa2-b928-4213-b64e-9f5b86f4cad1)
```

**Format:**

```csv
customer_id,customer_name,project_id,project_name,site_id,site_name,site_location,device_id,device_name,device_type,device_code,device_status,parameter_template_id,parameter_key,parameter_name,parameter_unit,parameter_metadata
```

**Notes**

- **Tenant Isolation**: Export is restricted to specified customer only
- This is **read-only export**
- Cannot be used to import registry (use `import_registry.sh` for that)
- Useful for review / SCADA mapping
- Includes all relationships in a flattened format
- One row per device/parameter combination
- Customer ID must be a valid UUID format

**Environment Variables:**

- `NAMESPACE` (default: `nsready-tier2`)
- `DB_POD` (default: `nsready-db-0`)

**Error Messages:**

- `Error: --customer-id is REQUIRED for tenant isolation` - You must provide a customer ID
- `Error: Invalid customer_id format. Expected UUID format.` - Customer ID must be a valid UUID
- `Error: Customer ID <id> not found in database.` - Customer does not exist

---

### 3.6 `export_scada_data.sh`

**Purpose**

Exports SCADA-ready values (raw, optimized for import into SCADA systems).

**When to use**

- To validate SCADA mapping
- For intermediate SCADA file-based integration
- For testing SCADA import workflows

**Usage**

**Latest Only:**

```bash
./scripts/export_scada_data.sh --latest --format txt

# Or CSV format
./scripts/export_scada_data.sh --latest --format csv
```

**Full History:**

```bash
./scripts/export_scada_data.sh --history --format csv
```

**Both:**

```bash
# Export both (default)
./scripts/export_scada_data.sh --format txt
```

**Output**

Files like:

```
reports/scada_latest_YYYYMMDD_HHMMSS.txt
reports/scada_history_YYYYMMDD_HHMMSS.csv
```

**Format (TXT):**

Tab-delimited text file with raw data.

**Format (CSV):**

CSV with header row.

**Columns:**

- `device_id`, `parameter_key`, `time`, `value`, `quality`, `source`

**Expected Output**

```
Exporting v_scada_latest to reports/scada_latest_20251114_1201.txt...
✓ Exported v_scada_latest
  File: reports/scada_latest_20251114_1201.txt
  Row count: 45 rows

Exporting v_scada_history to reports/scada_history_20251114_1201.txt...
✓ Exported v_scada_history
  File: reports/scada_history_20251114_1201.txt
  Row count: 1250 rows

Export completed successfully!
Files saved to: reports/
```

**Notes**

- Supports both Kubernetes and Docker Compose (auto-detects)
- Raw format (UUIDs, not human-readable names)
- For human-readable exports, use `export_scada_data_readable.sh`
- Best for SCADA systems that map IDs themselves

**Environment Variables:**

- `NAMESPACE` (default: `nsready-tier2`)
- `DB_POD` (default: `nsready-db-0`)

---

### 3.7 `export_scada_data_readable.sh`

**Purpose**

Exports SCADA data with human-readable names:
- `device_name` (instead of UUID)
- `parameter_name` (instead of key)
- `unit`, `customer_name`, `project_name`, `site_name`

**When to use**

- SCADA import
- Debugging data mapping
- Training new engineers
- Manual review of data

**Usage**

```bash
# Latest values (readable)
./scripts/export_scada_data_readable.sh --latest --format txt

# History (readable, CSV)
./scripts/export_scada_data_readable.sh --history --format csv

# Both
./scripts/export_scada_data_readable.sh --format txt
```

**Output**

Files like:

```
reports/scada_latest_readable_YYYYMMDD_HHMMSS.txt
reports/scada_history_readable_YYYYMMDD_HHMMSS.csv
```

**Format:**

Includes readable columns:
- `customer_name`, `project_name`, `site_name`
- `device_name`, `device_code`, `device_type`
- `parameter_name`, `parameter_key`, `parameter_unit`
- `timestamp`, `value`, `quality`, `source`

**Expected Output**

```
Exporting latest SCADA values (readable format) to reports/scada_latest_readable_20251114_1201.txt...
✓ Exported latest values (readable)
  File: reports/scada_latest_readable_20251114_1201.txt
  Row count: 45 rows

Export completed successfully!
Files saved to: reports/
```

**Notes**

- Supports both Kubernetes and Docker Compose (auto-detects)
- **Best for SCADA integration** - all names are human-readable
- No UUID lookups needed
- Perfect for import into SCADA systems

**Environment Variables:**

- `NAMESPACE` (default: `nsready-tier2`)
- `DB_POD` (default: `nsready-db-0`)

---

### 3.8 `test_scada_connection.sh`

**Purpose**

Tests SCADA read-only user connectivity to NSReady DB.

**When to use**

- After creating SCADA user
- Before configuring SCADA system
- Troubleshooting SCADA connection issues
- Validating database access

**Usage**

**Basic test (internal connection):**

```bash
./scripts/test_scada_connection.sh
```

**External connection test:**

```bash
./scripts/test_scada_connection.sh \
  --host localhost \
  --port 5432 \
  --user scada_reader \
  --password YOUR_PASSWORD
```

**Expected Output**

```
==========================================
SCADA Database Connection Test
==========================================

Test 1: Testing database connection...
✓ Internal connection successful (via kubectl)
  Pod: nsready-db-0
  Namespace: nsready-tier2
  Database: nsready
  User: postgres

Test 2: Checking SCADA views...
✓ Both SCADA views exist
  - v_scada_latest
  - v_scada_history

Test 3: Testing v_scada_latest view...
✓ v_scada_latest contains 45 rows

Test 4: Testing v_scada_history view...
✓ v_scada_history contains 1250 rows

Test 5: Sample data from v_scada_latest (first 3 rows)...
...

Test 6: Connection information...
...

==========================================
Connection test completed!
==========================================
```

**Notes**

- Supports both Kubernetes and Docker Compose (auto-detects)
- Can test internal (via kubectl/docker) or external connections
- Validates SCADA views exist
- Shows sample data for verification

**Environment Variables:**

- `NAMESPACE` (default: `nsready-tier2`)
- `DB_POD` (default: `nsready-db-0`)
- `DB_USER` (default: `postgres`)
- `DB_NAME` (default: `nsready`)

---

### 3.9 `test_drive.sh`

**Purpose**

Comprehensive automated testing script that:
- Auto-detects registry data
- Generates test events
- Tests ingestion pipeline
- Validates database storage
- Generates test report

**When to use**

- After platform setup
- Before production deployment
- After making configuration changes
- For comprehensive validation

**Usage**

```bash
./scripts/test_drive.sh
```

**What it does:**

1. Discovers existing registry (devices, projects, sites)
2. Discovers parameter templates
3. Generates test event JSON automatically
4. Sends to ingest endpoint
5. Validates queue drains
6. Verifies database rows
7. Generates test report

**Output**

Creates report:

```
tests/reports/FINAL_TEST_DRIVE_YYYYMMDD_HHMMSS.md
```

**Notes**

- Requires Kubernetes environment
- Auto-discovers test data from database
- Comprehensive end-to-end test
- See `POST_FIX_VALIDATION.md` for details

**Environment Variables:**

- `NS` (default: `nsready-tier2`)
- `ADMIN_URL` (default: `http://localhost:8000`)
- `COLLECT_URL` (default: `http://localhost:8001`)

---

### 3.10 `setup_scada_readonly_user.sql`

**Purpose**

Creates SCADA read-only database user with minimal privileges.

**When to use**

- Before setting up SCADA integration
- When configuring SCADA database access
- For production deployments

**Usage**

**For Kubernetes:**

```bash
# Copy SQL to pod
kubectl cp scripts/setup_scada_readonly_user.sql nsready-tier2/nsready-db-0:/tmp/

# Execute
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -f /tmp/setup_scada_readonly_user.sql

# Clean up
kubectl exec -n nsready-tier2 nsready-db-0 -- rm -f /tmp/setup_scada_readonly_user.sql
```

**For Docker Compose:**

```bash
# Copy SQL to container
docker cp scripts/setup_scada_readonly_user.sql nsready_db:/tmp/

# Execute
docker exec nsready_db psql -U postgres -d nsready -f /tmp/setup_scada_readonly_user.sql

# Clean up
docker exec nsready_db rm -f /tmp/setup_scada_readonly_user.sql
```

**What it creates:**

- User: `scada_reader`
- Password: `CHANGE_THIS_PASSWORD` (change before running!)
- Permissions: SELECT only on all tables and views
- Access to: `v_scada_latest`, `v_scada_history`

**Notes**

- **CRITICAL:** Change password before running in production
- User has read-only access (SELECT only)
- Cannot write, delete, or modify data
- Grants access to SCADA views explicitly

---

### 3.11 `backup_pg.sh`

**Purpose**

PostgreSQL backup script for scheduled or manual backups.

**Location:**

```
scripts/backups/backup_pg.sh
```

**When to use**

- Scheduled backups (via CronJob)
- Manual backup before major changes
- Database migration preparation

**Usage**

```bash
# Run inside container/pod with proper environment
./scripts/backups/backup_pg.sh
```

**Environment Variables:**

- `POSTGRES_HOST` (default: `nsready-db`)
- `POSTGRES_USER` (default: `postgres`)
- `POSTGRES_DB` (default: `nsready`)
- `BACKUP_DIR` (default: `/backups`)
- `RETENTION_DAYS` (default: `7`)
- `S3_BUCKET` (optional, for S3 upload)

**Notes**

- Used by Kubernetes CronJob for automated backups
- Creates compressed backups (`pg_backup_YYYYMMDD_HHMMSS.sql.gz`)
- Optional S3 upload support
- Automatic cleanup of old backups

---

### 3.12 `backup_jetstream.sh`

**Purpose**

NATS JetStream backup script.

**Location:**

```
scripts/backups/backup_jetstream.sh
```

**When to use**

- Scheduled NATS backups
- Before NATS maintenance
- For disaster recovery

**Usage**

```bash
./scripts/backups/backup_jetstream.sh
```

**Notes**

- Requires NATS CLI or API access
- Used by Kubernetes CronJob
- Optional S3 upload support

---

### 3.13 `push-images.sh`

**Purpose**

Push Docker images to container registry.

**When to use**

- After building images
- Before deployment
- For image distribution

**Usage**

```bash
./scripts/push-images.sh
```

**Notes**

- Pushes images for all services
- Requires registry authentication
- See script for registry configuration

---

## 4. Template Files Summary

### 4.1 `parameter_template_template.csv`

**Purpose**

Template CSV structure for defining engineering parameters. The `parameter_template_template.csv` generates full-form `parameter_key` values per **Module 6 – Parameter Template Manual**.

**Location:**

```
scripts/parameter_template_template.csv
```

**Format:**

```csv
customer_name,project_name,parameter_name,unit,dtype,min_value,max_value,required,description
Customer 01,Project 01_Customer_01,Voltage,V,float,0,240,true,AC voltage measurement
```

**Use:**

- Copy this file as starting point
- Fill in your customer/project names
- Add your parameters

---

### 4.2 `example_parameters.csv`

**Purpose**

Example parameter CSV with sample data.

**Location:**

```
scripts/example_parameters.csv
```

**Contains:**

- Sample customers (Customer 02, Customer 03, Customer 04)
- Sample projects
- Sample parameters (Voltage, Current, Power, Temperature, Humidity, Status, Count)

**Use:**

- Reference for format
- Training/testing
- Example data

---

### 4.3 `registry_template.csv`

**Purpose**

Template CSV structure for registry import (customers, projects, sites, devices).

**Location:**

```
scripts/registry_template.csv
```

**Format:**

```csv
customer_name,project_name,project_description,site_name,site_location,device_name,device_type,device_code,device_status
```

**Use:**

- Copy this file as starting point
- Fill in your hierarchy
- Multiple rows allowed (one per device or site)

---

### 4.4 `example_registry.csv`

**Purpose**

Example registry CSV with sample data.

**Location:**

```
scripts/example_registry.csv
```

**Contains:**

- Sample customers (Acme Corp, Beta Industries)
- Sample projects
- Sample sites and devices
- Example device codes

**Use:**

- Reference for format
- Training/testing
- Example data

---

## 5. Directory Structure

All scripts and templates are organized like this:

```
scripts/
│
├── Configuration Import
│   ├── import_registry.sh
│   ├── import_parameter_templates.sh
│   ├── registry_template.csv
│   ├── example_registry.csv
│   ├── parameter_template_template.csv
│   └── example_parameters.csv
│
├── Export Tools
│   ├── export_registry_data.sh
│   ├── export_parameter_template_csv.sh
│   ├── export_scada_data.sh
│   └── export_scada_data_readable.sh
│
├── Utilities
│   ├── list_customers_projects.sh
│   └── test_scada_connection.sh
│
├── Testing
│   └── test_drive.sh
│
├── SQL Scripts
│   └── setup_scada_readonly_user.sql
│
├── Backups
│   ├── backup_pg.sh
│   └── backup_jetstream.sh
│
└── Deployment
    └── push-images.sh
```

**Output Directory:**

All export scripts save to:

```
reports/
├── registry_export_*.csv
├── parameter_templates_export_*.csv
├── scada_latest_*.txt
├── scada_history_*.csv
└── scada_*_readable_*.txt
```

---

## 6. Master Quick Reference (Copy–Paste)

### Configuration Import

```bash
# Registry import (customers, projects, sites, devices)
./scripts/import_registry.sh registry.csv

# Parameter import
./scripts/import_parameter_templates.sh params.csv

# List customers/projects (get exact names)
./scripts/list_customers_projects.sh
```

### Export

```bash
# Export registry for customer (REQUIRED: --customer-id)
./scripts/export_registry_data.sh --customer-id <customer_id>

# Export parameters for customer (REQUIRED: --customer-id)
./scripts/export_parameter_template_csv.sh --customer-id <customer_id>

# Export SCADA raw data
./scripts/export_scada_data.sh --latest --format txt

# Export SCADA readable data (recommended)
./scripts/export_scada_data_readable.sh --latest --format txt
```

### SCADA Setup

```bash
# Test SCADA DB connection
./scripts/test_scada_connection.sh

# Create SCADA read-only user
kubectl cp scripts/setup_scada_readonly_user.sql nsready-tier2/nsready-db-0:/tmp/
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -f /tmp/setup_scada_readonly_user.sql
```

### Testing

```bash
# Comprehensive automated test
./scripts/test_drive.sh
```

---

## 7. Common Workflows

### Workflow 1: New Customer Onboarding

```bash
# Step 1: Import registry
./scripts/import_registry.sh new_customer_registry.csv

# Step 2: Verify import
./scripts/list_customers_projects.sh

# Step 3: Import parameters
./scripts/import_parameter_templates.sh new_customer_parameters.csv

# Step 4: Verify parameters
./scripts/export_parameter_template_csv.sh
```

### Workflow 2: SCADA Integration Setup

```bash
# Step 1: Create SCADA user
kubectl cp scripts/setup_scada_readonly_user.sql nsready-tier2/nsready-db-0:/tmp/
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -f /tmp/setup_scada_readonly_user.sql

# Step 2: Test connection
./scripts/test_scada_connection.sh

# Step 3: Export test data
./scripts/export_scada_data_readable.sh --latest --format txt

# Step 4: Verify export
cat reports/scada_latest_readable_*.txt
```

### Workflow 3: Registry Audit

```bash
# Step 1: Get customer ID
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "SELECT id::text, name FROM customers;"

# Step 2: Export registry for customer (REQUIRED: --customer-id)
./scripts/export_registry_data.sh --customer-id <customer_id>

# Step 3: Export parameters for customer (REQUIRED: --customer-id)
./scripts/export_parameter_template_csv.sh --customer-id <customer_id>

# Step 4: Review exports
open reports/*_registry_export_*.csv
open reports/*_parameter_templates_export_*.csv
```

---

## 8. Environment Configuration

Most scripts support environment variables for customization:

### Kubernetes Environment

```bash
export NAMESPACE=nsready-tier2
export DB_POD=nsready-db-0
export DB_NAME=nsready
export DB_USER=postgres
export USE_KUBECTL=true  # or auto for auto-detection
```

### Docker Compose Environment

```bash
export USE_KUBECTL=false
# Scripts will use docker commands instead
```

### Auto-Detection

Most scripts auto-detect environment:

```bash
# Scripts will check kubectl first, then docker
# No configuration needed
./scripts/import_registry.sh registry.csv
```

---

## 9. Safety Notes

### ⚠️ Important Warnings

- **Do NOT edit scripts directly** unless you understand internal logic
- **Always test CSV files** with small batches first
- **Avoid running imports** while ingestion tests are running
- **Do NOT grant SCADA** more than read-only DB permissions
- **Backup database** before large imports
- **Verify CSV format** before importing (check headers match)

### ✅ Best Practices

- **Test imports on dev environment** first
- **Use template files** as starting point
- **Verify exports** after imports
- **Check logs** for any errors
- **Validate data** in database after import
- **Document any custom changes** to scripts

### 🔒 Security

- **Change SCADA password** before production use
- **Limit database access** to necessary IPs only
- **Use read-only users** for SCADA/exports
- **Rotate passwords** periodically
- **Review permissions** regularly

---

## 10. Troubleshooting Scripts

### Script not executable

```bash
chmod +x scripts/*.sh
```

### Script fails with "command not found"

```bash
# Check if bash is available
which bash

# Use full path if needed
/bin/bash scripts/import_registry.sh registry.csv
```

### CSV file not found

```bash
# Use full path
./scripts/import_registry.sh /full/path/to/registry.csv

# Or use relative path from project root
./scripts/import_registry.sh scripts/example_registry.csv
```

### Permission denied

```bash
# Check file permissions
ls -l scripts/import_registry.sh

# Make executable
chmod +x scripts/import_registry.sh
```

### Database connection error

- Check if database pod/container is running
- Verify namespace/pod name is correct
- Check database credentials
- Verify network connectivity

---

## 11. Script Dependencies

### Required Tools

- `bash` - Shell interpreter
- `kubectl` - Kubernetes CLI (for Kubernetes environments)
- `docker` - Docker CLI (for Docker Compose environments)
- `psql` - PostgreSQL client (usually in database container)
- `jq` - JSON processor (optional, for some scripts)

### Optional Tools

- `jq` - For JSON processing
- `awk` - For text processing
- `watch` - For monitoring

### Installing Dependencies

**On macOS:**

```bash
# Install jq
brew install jq

# kubectl (usually via Docker Desktop)
# docker (via Docker Desktop)
```

**On Linux:**

```bash
# Install jq
sudo apt-get install jq  # Debian/Ubuntu
# or
sudo yum install jq      # RHEL/CentOS

# kubectl
# See: https://kubernetes.io/docs/tasks/tools/
```

---

## 12. Summary

After reviewing this module, you can:

- Understand all available scripts and their purposes
- Use scripts correctly for configuration tasks
- Export data for SCADA integration
- Test database connections
- Troubleshoot script issues

This completes your understanding of the NSReady platform's script-based tooling.

---

**End of Module 10 – Scripts and Tools Reference Manual**

**Related Modules:**

- Module 3 – Environment and PostgreSQL Storage Manual
- Module 5 – Configuration Import Manual
- Module 7 – Data Ingestion and Testing Manual
- Module 9 – SCADA Integration Manual
- Module 11 – Troubleshooting and Diagnostics Manual

