# Module 9 – SCADA Integration Manual

_NSReady Data Collection Platform_

*(Suggested path: `docs/09_SCADA_Integration_Manual.md`)*

---

## 1. Introduction

This module explains how to connect SCADA systems (PLC SCADA, WinCC, Ignition, Wonderware, etc.) to the NSReady Data Collection Platform.

You will learn:

- How SCADA can access the NSReady database
- How to create a read-only SCADA DB user
- How to export SCADA-friendly files
- How to test the connection
- Recommended tables/views for SCADA
- Safety & performance rules

This module prepares NSReady for real field integration.

---

## 2. SCADA Integration Options Overview

The NSReady platform supports two integration modes:

- **Option 1 (Simple/Default)** – Export Files → SCADA Reads TXT/CSV
- **Option 2 (Direct DB Access)** – SCADA connects to PostgreSQL (Read-Only)

Both methods are supported.

**ASCII diagram:**

```
+--------------+         +-------------------+
| NSReady DB   | <--->   | SCADA (Direct SQL |
| (Timescale)  |         |  or FDW)          |
+--------------+         +-------------------+

OR

+--------------+         +-------------------+
| NSReady DB   | --->    |  SCADA File Import|
| Export Tools |         |  (TXT/CSV)        |
+--------------+         +-------------------+
```

---

## 3. Option 1 — File Export (Recommended for Phase-1 & Testing)

> **NOTE (NS-TENANT-SCADA-BOUNDARY):**  
> SCADA integrations must strictly respect **tenant boundaries**.  
>  
> NSReady defines:  
> - `tenant_id = customer_id`  
> - Every SCADA file export or direct DB query will always be filtered  
>   by the customer's UUID to ensure isolation.  
>  
> SCADA for Customer A will never see devices or parameters of Customer B.  
> This rule will remain stable for all future NSWare releases.

**For tenant model details, see:**
- **TENANT_MODEL_SUMMARY.md** – Quick reference for SCADA filtering rules
- **TENANT_MODEL_DIAGRAM.md** – Visual isolation boundary diagrams

This method does not require SCADA to connect directly to the NSReady DB.

You simply export:

- Latest values
- Historical values
- Human-readable device/parameter names

Then SCADA imports these files.

### 3.1 Files Used

| Script | Purpose |
|--------|---------|
| `export_scada_data.sh` | Export latest or historical raw values |
| `export_scada_data_readable.sh` | Export readable values with device names & parameter names |

**Note:** Scripts support both Kubernetes and Docker Compose environments. They auto-detect the environment.

### 3.2 Export Latest SCADA Values (TXT)

**For Kubernetes:**

```bash
./scripts/export_scada_data.sh --latest --format txt
```

**For Docker Compose:**

```bash
# Scripts need to be updated for Docker, or use port-forward first
USE_KUBECTL=false ./scripts/export_scada_data.sh --latest --format txt
```

**Produces a file like:**

```
reports/scada_latest_20251114_1201.txt
```

**Format:** Tab-delimited format.

**Example output:**

```
device_id	parameter_key	time	value	quality	source
bc2c5e47-...	voltage	2025-11-14 12:00:00	230.5	192	GPRS
bc2c5e47-...	current	2025-11-14 12:00:00	10.2	192	GPRS
```

### 3.3 Export Full History (CSV)

**For Kubernetes:**

```bash
./scripts/export_scada_data.sh --history --format csv
```

**For Docker Compose:**

```bash
USE_KUBECTL=false ./scripts/export_scada_data.sh --history --format csv
```

**Produces:**

```
reports/scada_history_20251114_1201.csv
```

**Format:** CSV with header row.

### 3.4 Human-Readable Export

Adds joins with devices + parameter_templates for easier SCADA integration.

**For Kubernetes:**

```bash
./scripts/export_scada_data_readable.sh --latest --format txt
```

**For Docker Compose:**

```bash
USE_KUBECTL=false ./scripts/export_scada_data_readable.sh --latest --format txt
```

**Example output columns:**

```
customer_name	project_name	site_name	device_name	device_code	device_type	parameter_name	parameter_key	parameter_unit	timestamp	value	quality
Acme Corp	Factory Monitoring	Main Factory	Sensor-001	SENSOR-001	sensor	Voltage	voltage	V	2025-11-14 12:00:00	230.5	192
```

**Perfect for SCADA** – all names are human-readable, no UUIDs to look up.

### 3.5 Export Both Latest and History

**For Kubernetes:**

```bash
# Export both (default behavior)
./scripts/export_scada_data.sh --format csv

# Or specify both explicitly
./scripts/export_scada_data.sh --latest --history --format csv
```

---

## 4. Option 2 — Direct SCADA → NSReady Database Connection

For production or real-time use, SCADA can connect directly to PostgreSQL.

**Important:** SCADA will **NOT write anything** — only read.

We use a read-only SCADA user.

### 4.1 Create SCADA Read-Only User

**For Kubernetes:**

```bash
# Copy SQL script to pod first
kubectl cp scripts/setup_scada_readonly_user.sql nsready-tier2/nsready-db-0:/tmp/

# Execute the script
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -f /tmp/setup_scada_readonly_user.sql

# Clean up
kubectl exec -n nsready-tier2 nsready-db-0 -- rm -f /tmp/setup_scada_readonly_user.sql
```

**For Docker Compose:**

```bash
# Copy SQL script to container
docker cp scripts/setup_scada_readonly_user.sql nsready_db:/tmp/

# Execute the script
docker exec nsready_db psql -U postgres -d nsready -f /tmp/setup_scada_readonly_user.sql

# Clean up
docker exec nsready_db rm -f /tmp/setup_scada_readonly_user.sql
```

**Or paste SQL directly:**

```bash
# For Kubernetes
kubectl exec -it -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready

# For Docker Compose
docker exec -it nsready_db psql -U postgres -d nsready
```

Then paste the SQL from `scripts/setup_scada_readonly_user.sql`.

**This creates:**

- User: `scada_reader`
- Privileges: SELECT only
- No write/delete rights
- Access to SCADA views: `v_scada_latest`, `v_scada_history`

**Important:** Change the password in the SQL script before running:

```sql
CREATE USER scada_reader WITH PASSWORD 'YOUR_STRONG_PASSWORD_HERE';
```

### 4.2 Connection String for SCADA

#### If using port-forward:

```bash
# Terminal 1: Start port-forward
kubectl port-forward -n nsready-tier2 pod/nsready-db-0 5432:5432
```

Then SCADA connects to:

```
postgresql://scada_reader:<password>@localhost:5432/nsready
```

#### If SCADA runs inside cluster:

```
postgresql://scada_reader:<password>@nsready-db.nsready-tier2.svc.cluster.local:5432/nsready
```

#### If using Docker Compose:

```
postgresql://scada_reader:<password>@localhost:5432/nsready
```

### 4.3 Recommended Views for SCADA

#### 4.3.1 Latest values (one row per parameter/device)

**Note:** SCADA must map using full `parameter_key`, not display names. Views `v_scada_latest` and `v_scada_history` always contain full `parameter_key` values.

> **NOTE (NS-TS-DASHBOARD-GUARDRAIL):**  
> For large time ranges (weeks/months), dashboards and SCADA should read from rollup views  
> or materialized views (e.g., hourly aggregates), not directly from the raw `ingest_events` table.  
> This avoids performance issues and keeps the system scalable as data grows.

**View:** `v_scada_latest`

**Columns:**
- `device_id` (UUID)
- `parameter_key` (TEXT)
- `time` (TIMESTAMPTZ)
- `value` (DOUBLE PRECISION)
- `quality` (INTEGER)
- `source` (TEXT) - protocol (GPRS, SMS, HTTP)

**Query example (with readable names):**

```sql
SELECT 
  c.name AS customer_name,
  p.name AS project_name,
  s.name AS site_name,
  d.name AS device_name,
  d.external_id AS device_code,
  pt.name AS parameter_name,
  pt.unit AS parameter_unit,
  v.time,
  v.value,
  v.quality,
  v.source
FROM v_scada_latest v
JOIN devices d ON d.id = v.device_id
JOIN parameter_templates pt ON pt.key = v.parameter_key
JOIN sites s ON s.id = d.site_id
JOIN projects p ON p.id = s.project_id
JOIN customers c ON c.id = p.customer_id
ORDER BY v.time DESC
LIMIT 100;
```

#### 4.3.2 Historical values

**View:** `v_scada_history`

**Columns:**
- `device_id` (UUID)
- `parameter_key` (TEXT)
- `time` (TIMESTAMPTZ)
- `value` (DOUBLE PRECISION)
- `quality` (INTEGER)
- `source` (TEXT)
- `event_id` (TEXT)
- `attributes` (JSONB)

**Query example:**

```sql
SELECT *
FROM v_scada_history
WHERE device_id = '<uuid-here>'
  AND time > now() - interval '1 day'
ORDER BY time DESC;
```

**Filtered by date range (recommended):**

```sql
SELECT 
  d.name AS device_name,
  pt.name AS parameter_name,
  v.time,
  v.value,
  v.quality
FROM v_scada_history v
JOIN devices d ON d.id = v.device_id
JOIN parameter_templates pt ON pt.key = v.parameter_key
WHERE v.time > now() - interval '1 hour'
ORDER BY v.time DESC;
```

---

## 5. Test the SCADA Connection (Copy–Paste)

Use your existing script:

**For Kubernetes:**

```bash
./scripts/test_scada_connection.sh
```

**For Docker Compose:**

```bash
USE_KUBECTL=false ./scripts/test_scada_connection.sh
```

**With external connection:**

```bash
./scripts/test_scada_connection.sh \
  --host localhost \
  --port 5432 \
  --user scada_reader \
  --password YOUR_PASSWORD
```

**Expected output:**

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
✓ v_scada_latest contains 15 rows

Test 4: Testing v_scada_history view...
✓ v_scada_history contains 1250 rows

Test 5: Sample data from v_scada_latest (first 3 rows)...
...

==========================================
Connection test completed!
==========================================
```

---

## 6. SCADA Integration via FDW (Advanced)

If SCADA uses a PostgreSQL backend, you can create a Foreign Data Wrapper (FDW) link:

```
SCADA DB <----> NSReady DB
```

This allows SCADA to directly query NSReady tables as if they were local.

**Not required now**, but this will be used in industry deployments.

### 5. SCADA Profiles per Customer (NS-MULTI-SCADA-FUTURE)

For deployments with multiple customers and SCADA systems, each customer will be assigned a **SCADA profile**:

- **SCADA type** (WinCC, Ignition, Wonderware, etc.)
- **Integration mode**: `file_export` or `db_readonly`
- **Data format specifics** (column order, encoding, etc.)
- **Filtering rules** (`customer_id` / `project_id` / `site_id`)

NSReady/NSWare engineers will define one SCADA profile per customer.  
Exports, views, and DB permissions for that customer MUST follow that profile,  
so that customer-specific outputs are clearly defined and reproducible.

**Example:**
- **Allidhra Group** (tenant) → Group-level SCADA profile (aggregates all 6 companies)
- **Allidhra Textool** (customer) → Individual SCADA profile (Textool-specific format)
- **Allidhra Texpin** (customer) → Individual SCADA profile (Texpin-specific format)

---

### 6. SCADA Integration via FDW (Advanced)

### 6.1 Example for SCADA DB

**On SCADA database:**

```sql
-- Enable FDW extension
CREATE EXTENSION postgres_fdw;

-- Create server link to NSReady
CREATE SERVER nsready_server
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS (host 'nsready-db.nsready-tier2.svc.cluster.local', dbname 'nsready', port '5432');

-- Create user mapping
CREATE USER MAPPING FOR scada_user
SERVER nsready_server
OPTIONS (user 'scada_reader', password '<password>');

-- Create foreign table
CREATE FOREIGN TABLE nsready_latest (
    device_id uuid,
    parameter_key text,
    time timestamptz,
    value double precision,
    quality integer,
    source text
)
SERVER nsready_server
OPTIONS (schema_name 'public', table_name 'v_scada_latest');

-- Now query as if it's a local table
SELECT * FROM nsready_latest LIMIT 10;
```

---

## 7. Performance Guidelines for SCADA Connections

### 7.1 Use the SCADA read-only user

**Never use `postgres` for SCADA** — always use `scada_reader`.

### 7.2 For history, always filter date range

**Good:**

```sql
SELECT * FROM v_scada_history
WHERE time > now() - interval '1 day'
ORDER BY time DESC;
```

**Bad:**

```sql
SELECT * FROM v_scada_history;
```

This would try to return all historical data, which could be millions of rows!

### 7.3 Index suggestions (already implemented)

The database already has indexes on:

- `ingest_events(device_id, parameter_key, time DESC)` - for fast queries
- `ingest_events(event_id)` - for idempotency
- Supporting indexes on foreign keys

### 7.4 Materialized views (optional)

For faster SCADA dashboards, you can create materialized views:

```sql
CREATE MATERIALIZED VIEW mv_scada_latest_readable AS
SELECT 
    c.name AS customer_name,
    p.name AS project_name,
    s.name AS site_name,
    d.name AS device_name,
    d.external_id AS device_code,
    pt.name AS parameter_name,
    pt.unit AS parameter_unit,
    v.time AS timestamp,
    v.value,
    v.quality
FROM v_scada_latest v
JOIN devices d ON d.id = v.device_id
JOIN parameter_templates pt ON pt.key = v.parameter_key
JOIN sites s ON s.id = d.site_id
JOIN projects p ON p.id = s.project_id
JOIN customers c ON c.id = p.customer_id;

-- Create indexes
CREATE INDEX idx_mv_scada_latest_time ON mv_scada_latest_readable(timestamp DESC);
CREATE INDEX idx_mv_scada_latest_device ON mv_scada_latest_readable(device_name);

-- Grant access to SCADA user
GRANT SELECT ON mv_scada_latest_readable TO scada_reader;

-- Refresh periodically (set up cron job)
REFRESH MATERIALIZED VIEW mv_scada_latest_readable;
```

**Note:** Materialized views need to be refreshed manually or via cron. Use regular views for real-time data.

---

## 8. SCADA Security Rules

- ✅ **No write permissions** — SCADA user is read-only
- ✅ **Only allow SELECT** — Cannot modify data
- ✅ **Use TLS when connecting externally** — For production deployments
- ✅ **Restrict allowed IPs** — Use firewall/ingress rules
- ✅ **Rotate passwords periodically** — Every 90 days recommended
- ✅ **Monitor connection logs** — Track SCADA access
- ✅ **Use connection pooling** — Limit concurrent connections

**Production recommendations:**

- Set up PostgreSQL SSL/TLS certificates
- Use network policies to restrict database access
- Implement connection rate limiting
- Monitor database performance metrics

---

## 9. Troubleshooting SCADA Integration

| Symptom | Possible Cause | Fix |
|---------|---------------|-----|
| SCADA cannot connect | Port closed / service not accessible | Use port-forward, NodePort, or check service configuration |
| Authentication error | Wrong username/password | Reset SCADA user password in database |
| Slow queries | SCADA reading large history without date filter | Always filter by date range in queries |
| Missing data | Tags not defined / parameter templates missing | Check parameter templates exist for device |
| Wrong mapping | Device_code mismatch | Export registry data and verify device codes match |
| Connection timeout | Network issues / firewall blocking | Check network connectivity and firewall rules |
| "Permission denied" | SCADA user lacks SELECT privileges | Re-run `setup_scada_readonly_user.sql` |

### 9.1 Check SCADA user permissions

```sql
-- For Kubernetes
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "
SELECT 
    grantee, 
    table_schema, 
    table_name, 
    privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'scada_reader'
ORDER BY table_name, privilege_type;"

-- For Docker Compose
docker exec nsready_db psql -U postgres -d nsready -c "
SELECT 
    grantee, 
    table_schema, 
    table_name, 
    privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'scada_reader'
ORDER BY table_name, privilege_type;"
```

### 9.2 Verify SCADA views exist

```sql
SELECT table_name, view_definition
FROM information_schema.views
WHERE table_name IN ('v_scada_latest', 'v_scada_history');
```

### 9.3 Test SCADA user connection

```bash
# For Kubernetes
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U scada_reader -d nsready -c "SELECT COUNT(*) FROM v_scada_latest;"

# For Docker Compose
docker exec nsready_db psql -U scada_reader -d nsready -c "SELECT COUNT(*) FROM v_scada_latest;"
```

---

## 10. SCADA Checklist (Copy–Paste for Engineers)

### Configuration

- [ ] Registry imported (customers, projects, sites, devices)
- [ ] Parameter templates imported
- [ ] Device codes matched to SCADA tags
- [ ] Parameter names matched to SCADA tag names

### Connection

- [ ] SCADA read-only user created (`scada_reader`)
- [ ] SCADA user password changed from default
- [ ] SCADA can connect to DB (tested with `test_scada_connection.sh`)
- [ ] SCADA can read `v_scada_latest`
- [ ] SCADA can read `v_scada_history`
- [ ] File export works correctly (`export_scada_data_readable.sh`)

### Data

- [ ] Latest values visible on SCADA
- [ ] Historical values visible
- [ ] Unit/quality fields correct
- [ ] No missing device mappings
- [ ] Timestamps are correct timezone
- [ ] Data updates in real-time (for direct DB connection)

### Performance

- [ ] Queries use date range filters
- [ ] No full table scans on large tables
- [ ] Connection pooling configured (if applicable)
- [ ] Materialized views created (if needed for dashboards)

### Security

- [ ] SCADA user has read-only access only
- [ ] Password is strong and rotated periodically
- [ ] Network access restricted (firewall/ingress rules)
- [ ] TLS enabled (for production)

---

## 11. Quick Reference

### Export Commands

```bash
# Latest values (readable)
./scripts/export_scada_data_readable.sh --latest --format txt

# History (readable, CSV)
./scripts/export_scada_data_readable.sh --history --format csv

# Both (raw data)
./scripts/export_scada_data.sh --format csv
```

### Test Connection

```bash
./scripts/test_scada_connection.sh
```

### Create SCADA User

```bash
# Kubernetes
kubectl cp scripts/setup_scada_readonly_user.sql nsready-tier2/nsready-db-0:/tmp/
kubectl exec -n nsready-tier2 nsready-db-0 -- psql -U postgres -d nsready -f /tmp/setup_scada_readonly_user.sql

# Docker Compose
docker cp scripts/setup_scada_readonly_user.sql nsready_db:/tmp/
docker exec nsready_db psql -U postgres -d nsready -f /tmp/setup_scada_readonly_user.sql
```

### Port Forward (for local SCADA tools)

```bash
kubectl port-forward -n nsready-tier2 pod/nsready-db-0 5432:5432
```

---

## 12. Summary

After completing this module, you can:

- Export SCADA data in various formats (TXT, CSV, readable)
- Create read-only SCADA database users
- Connect SCADA systems to NSReady database
- Query SCADA views (`v_scada_latest`, `v_scada_history`)
- Test SCADA connections
- Troubleshoot SCADA integration issues

This prepares NSReady for production field integration with SCADA systems.

---

**End of Module 9 – SCADA Integration Manual**

**Related Modules:**

- Module 3 – Environment and PostgreSQL Storage Manual
- Module 5 – Configuration Import Manual
- Module 7 – Data Ingestion and Testing Manual
- Module 10 – Scripts and Tools Reference Manual

