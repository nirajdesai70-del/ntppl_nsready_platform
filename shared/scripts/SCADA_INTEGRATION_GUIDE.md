# SCADA Database Integration Guide

This guide explains two approaches for integrating NSREADY platform data with your SCADA SQL database:

1. **File Export** - Export data to text/CSV files for import into SCADA
2. **Direct Database Connection** - Connect SCADA database directly to NSREADY PostgreSQL

---

## Option 1: File Export (Recommended for One-Time or Scheduled Imports)

### Quick Start

Export latest SCADA values to text file:
```bash
./shared/scripts/export_scada_data.sh --latest --format txt
```

Export full history to CSV:
```bash
./shared/scripts/export_scada_data.sh --history --format csv
```

### Available Views for Export

1. **`v_scada_latest`** - Latest value per device/parameter
   - Columns: `device_id`, `parameter_key`, `time`, `value`, `quality`
   - Best for: Real-time monitoring, current state

2. **`v_scada_history`** - Full historical data
   - Columns: `time`, `device_id`, `parameter_key`, `value`, `quality`, `source`
   - Best for: Historical analysis, trending

### Export Formats

- **TXT** (tab-delimited): `--format txt`
  - Pipe or tab-delimited text file
  - Suitable for most SCADA import tools
  
- **CSV** (comma-separated): `--format csv`
  - Standard CSV with headers
  - Excel-compatible

### Enhanced Export with Device/Parameter Names

For more readable exports with device names and parameter names instead of IDs:

```bash
./shared/scripts/export_scada_data_readable.sh --latest --format txt
```

This script joins with device and parameter template tables to provide human-readable names.

---

## Option 2: Direct Database Connection

### PostgreSQL Connection Details

**Connection String Format:**
```
postgresql://[user]:[password]@[host]:[port]/[database]
```

**Default Values:**
- Host: `db` (internal) or `localhost` (external, if port-forwarded)
- Port: `5432`
- Database: `nsready` (or `nsready_db` depending on environment)
- User: `postgres` (check your secrets/config)
- Password: (check your secrets)

### Method A: Direct PostgreSQL Connection (If SCADA Supports PostgreSQL)

Most modern SCADA systems support PostgreSQL connections. Configure your SCADA system to connect directly using:

1. **Connection Parameters:**
   - Host: Your NSREADY database host
   - Port: 5432
   - Database: `nsready`
   - Username/Password: From your Kubernetes secrets

2. **Recommended Views/Tables:**
   - `v_scada_latest` - For real-time data
   - `v_scada_history` - For historical queries
   - `ingest_events` - Raw telemetry data (if needed)

3. **Query Example:**
   ```sql
   SELECT 
       d.name AS device_name,
       pt.name AS parameter_name,
       v.time,
       v.value,
       v.quality
   FROM v_scada_latest v
   JOIN devices d ON d.id = v.device_id
   JOIN parameter_templates pt ON pt.key = v.parameter_key
   ORDER BY v.time DESC;
   ```

### Method B: PostgreSQL Foreign Data Wrapper (FDW)

If your SCADA database is also PostgreSQL, you can use Foreign Data Wrapper to create a seamless connection:

#### Setup on NSREADY Database (Source)

```sql
-- Enable postgres_fdw extension (if not already enabled)
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- Create foreign server (pointing to SCADA database)
CREATE SERVER scada_db
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS (
    host 'scada-db-host',
    port '5432',
    dbname 'scada_db'
);

-- Create user mapping
CREATE USER MAPPING FOR postgres
SERVER scada_db
OPTIONS (
    user 'scada_user',
    password 'scada_password'
);

-- Create foreign table (optional - if you want to write back to SCADA)
CREATE FOREIGN TABLE scada_measurements (
    device_name TEXT,
    parameter_name TEXT,
    timestamp TIMESTAMPTZ,
    value DOUBLE PRECISION,
    quality INTEGER
)
SERVER scada_db
OPTIONS (
    schema_name 'public',
    table_name 'measurements'
);
```

#### Setup on SCADA Database (Target)

```sql
-- Enable postgres_fdw extension
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- Create foreign server (pointing to NSREADY database)
CREATE SERVER nsready_db
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS (
    host 'nsready-db-host',
    port '5432',
    dbname 'nsready'
);

-- Create user mapping
CREATE USER MAPPING FOR scada_user
SERVER nsready_db
OPTIONS (
    user 'postgres',
    password 'nsready_password'
);

-- Create foreign table to access NSREADY data
CREATE FOREIGN TABLE nsready_latest (
    device_id UUID,
    parameter_key TEXT,
    time TIMESTAMPTZ,
    value DOUBLE PRECISION,
    quality SMALLINT
)
SERVER nsready_db
OPTIONS (
    schema_name 'public',
    table_name 'v_scada_latest'
);

-- Now you can query NSREADY data from SCADA database:
SELECT * FROM nsready_latest;
```

### Method C: Materialized Views with Refresh

For better performance, create materialized views that refresh periodically:

```sql
-- On NSREADY database
CREATE MATERIALIZED VIEW mv_scada_latest_readable AS
SELECT 
    d.name AS device_name,
    d.external_id AS device_code,
    pt.name AS parameter_name,
    pt.unit,
    v.time,
    v.value,
    v.quality,
    s.name AS site_name,
    p.name AS project_name,
    c.name AS customer_name
FROM v_scada_latest v
JOIN devices d ON d.id = v.device_id
JOIN parameter_templates pt ON pt.key = v.parameter_key
JOIN sites s ON s.id = d.site_id
JOIN projects p ON p.id = s.project_id
JOIN customers c ON c.id = p.customer_id;

-- Create index for faster queries
CREATE INDEX idx_mv_scada_latest_time ON mv_scada_latest_readable(time DESC);

-- Refresh periodically (set up cron job or scheduled task)
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_scada_latest_readable;
```

### Method D: Replication (For High Availability)

For production environments requiring real-time synchronization:

1. **Logical Replication** (PostgreSQL 10+)
   - Replicate specific tables/views to SCADA database
   - Near real-time updates

2. **Streaming Replication** (Full database)
   - Complete database replica
   - Requires more resources

---

## Security Considerations

### Network Access

1. **Kubernetes Port Forwarding** (Development/Testing):
   ```bash
   kubectl port-forward -n nsready-tier2 svc/nsready-db 5432:5432
   ```

2. **NodePort Service** (Limited Production):
   - Expose database via NodePort
   - Restrict access with firewall rules

3. **LoadBalancer/Ingress** (Production):
   - Use secure ingress with TLS
   - Implement IP whitelisting

### Authentication

- Use dedicated database users with minimal privileges
- Create read-only users for SCADA access:
  ```sql
  CREATE USER scada_reader WITH PASSWORD 'secure_password';
  GRANT CONNECT ON DATABASE nsready TO scada_reader;
  GRANT USAGE ON SCHEMA public TO scada_reader;
  GRANT SELECT ON ALL TABLES IN SCHEMA public TO scada_reader;
  GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO scada_reader;
  ```

### Encryption

- Enable SSL/TLS for database connections
- Use encrypted connections in connection strings: `postgresql://...?sslmode=require`

---

## Performance Optimization

### For File Exports

- Use `--limit` option to export subsets of data
- Schedule exports during off-peak hours
- Compress large exports: `gzip output_file.txt`

### For Direct Connections

- Use materialized views for frequently accessed data
- Create indexes on commonly queried columns
- Use connection pooling
- Limit query time ranges for historical data

---

## Troubleshooting

### Connection Issues

1. **Check database accessibility:**
   ```bash
   kubectl exec -n nsready-tier2 nsready-db-0 -- psql -U postgres -d nsready -c "SELECT version();"
   ```

2. **Verify network connectivity:**
   ```bash
   telnet <db-host> 5432
   ```

3. **Check firewall rules:**
   - Ensure port 5432 is open
   - Verify Kubernetes network policies

### Performance Issues

1. **Monitor query performance:**
   ```sql
   EXPLAIN ANALYZE SELECT * FROM v_scada_latest;
   ```

2. **Check database load:**
   ```bash
   kubectl exec -n nsready-tier2 nsready-db-0 -- psql -U postgres -d nsready -c "SELECT * FROM pg_stat_activity;"
   ```

---

## Recommendations

**For Development/Testing:**
- Use file export method
- Simple, no network configuration needed

**For Production:**
- Use direct database connection with read-only user
- Implement materialized views for better performance
- Set up monitoring and alerting

**For High-Volume Real-Time:**
- Use logical replication
- Consider message queue integration (NATS) for event-driven updates

---

## Next Steps

1. **Test file export:**
   ```bash
   ./shared/scripts/export_scada_data.sh --latest --format txt
   ```

2. **Test direct connection:**
   - Get database credentials from Kubernetes secrets
   - Test connection from SCADA system

3. **Choose integration method** based on your SCADA system capabilities and requirements

---

### Backend Testing (Standard Process)

Backend test procedures are now maintained centrally in:

- `nsready_backend/tests/README_BACKEND_TESTS.md` (full SOP)
- `nsready_backend/tests/README_BACKEND_TESTS_QUICK.md` (operator quick view)

**Key commands (from repository root):**

```bash
cd /Users/nirajdesai/Documents/Projects/NTPPL_NSREADY_Platforms/ntppl_nsready_platform

./shared/scripts/test_data_flow.sh
./shared/scripts/test_batch_ingestion.sh --count 100
./shared/scripts/test_stress_load.sh
```

All reports are stored under:

```text
nsready_backend/tests/reports/
```

For detailed negative, roles, multi-customer, tenant, SCADA, and final-drive tests, see the Extended Test Suite section in:

- `nsready_backend/tests/README_BACKEND_TESTS.md`







