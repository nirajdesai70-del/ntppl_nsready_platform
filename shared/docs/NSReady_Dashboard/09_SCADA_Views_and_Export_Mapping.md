# Module 9 – SCADA Views & Export Mapping

_NSReady Data Collection Platform_

*(Suggested path: `docs/09_SCADA_Views_and_Export_Mapping.md`)*

---

## 1. Purpose of This Document

This module provides a comprehensive guide to SCADA integration with the NSReady Data Collection Platform. It covers:

- SCADA view architecture and structure
- View definitions and query patterns
- SCADA read-only user setup and security
- Export mapping procedures and formats
- SCADA tag mapping and integration
- Connection methods and best practices
- Troubleshooting common SCADA integration issues

This module is essential for:
- **SCADA Engineers** integrating NSReady with SCADA systems
- **Database Administrators** setting up read-only access
- **System Integrators** mapping NSReady data to SCADA tags
- **Operators** understanding data export and integration

**Prerequisites:**
- Module 0 – Introduction and Terminology
- Module 2 – System Architecture and Data Flow
- Module 3 – Environment and PostgreSQL Storage Manual
- Module 6 – Parameter Template Manual

---

## 2. SCADA Integration Architecture Overview

SCADA systems integrate with NSReady through **read-only database access** and **export files**. The architecture provides multiple integration paths:

```
┌─────────────────────────────────────────────────────────────┐
│ NSReady Database (PostgreSQL + TimescaleDB)                  │
│ - ingest_events (hypertable)                                 │
│ - parameter_templates                                        │
│ - devices, sites, projects, customers                        │
└──────────────────────┬──────────────────────────────────────┘
                       │
        ┌──────────────┼──────────────┐
        │              │              │
        v              v              v
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│ SCADA Views  │ │ Read-Only    │ │ Export Files │
│ (SQL Queries)│ │ User Access  │ │ (TXT/CSV)    │
└──────────────┘ └──────────────┘ └──────────────┘
        │              │              │
        └──────────────┼──────────────┘
                       │
                       v
            ┌──────────────────────┐
            │ SCADA System         │
            │ - Tag Mapping        │
            │ - Data Acquisition   │
            │ - Visualization      │
            └──────────────────────┘
```

**Integration Methods:**

1. **Direct SQL Access** - SCADA queries views via PostgreSQL connection
2. **Read-Only User** - Dedicated `scada_reader` user with SELECT privileges
3. **Export Files** - Scheduled exports in TXT/CSV format
4. **Materialized Views** - Pre-aggregated data for performance (optional)

---

## 3. SCADA Views

### 3.1 View Overview

NSReady provides two primary SCADA views:

| View Name | Purpose | Data Source | Update Frequency |
|-----------|---------|-------------|------------------|
| `v_scada_latest` | Latest value per device/parameter | `ingest_events` | Real-time (as data arrives) |
| `v_scada_history` | Full historical data | `ingest_events` | Real-time (as data arrives) |

**Key Characteristics:**

- **Real-time** - Views update automatically as new data arrives
- **Read-only** - Views are SELECT-only (no INSERT/UPDATE/DELETE)
- **Optimized** - Views use efficient queries with proper indexes
- **Parameter-aware** - Views include parameter_key for tag mapping

### 3.2 View: v_scada_latest

**Purpose:** Provides the most recent value for each device/parameter combination.

**Definition:**

```sql
CREATE OR REPLACE VIEW v_scada_latest AS
WITH ranked AS (
  SELECT
    device_id,
    parameter_key,
    time,
    value,
    quality,
    ROW_NUMBER() OVER (PARTITION BY device_id, parameter_key ORDER BY time DESC) AS rn
  FROM ingest_events
)
SELECT device_id, parameter_key, time, value, quality
FROM ranked
WHERE rn = 1;
```

**View Structure:**

| Column | Type | Description |
|--------|------|-------------|
| `device_id` | UUID | Device identifier (foreign key to `devices` table) |
| `parameter_key` | TEXT | Parameter identifier (foreign key to `parameter_templates` table) |
| `time` | TIMESTAMPTZ | Timestamp of the latest value |
| `value` | DOUBLE PRECISION | Latest metric value |
| `quality` | SMALLINT | Quality code (192 = good, others = flags) |

**How It Works:**

1. **Window Function** - `ROW_NUMBER()` partitions by `(device_id, parameter_key)`
2. **Ordering** - Orders by `time DESC` (newest first)
3. **Filtering** - Selects only `rn = 1` (most recent row per partition)
4. **Result** - One row per device/parameter with latest value

**Example Query:**

```sql
-- Get latest values for a specific device
SELECT 
    d.name AS device_name,
    pt.parameter_name,
    pt.unit,
    v.time,
    v.value,
    v.quality
FROM v_scada_latest v
JOIN devices d ON d.id = v.device_id
JOIN parameter_templates pt ON pt.key = v.parameter_key
WHERE v.device_id = '550e8400-e29b-41d4-a716-446655440002'
ORDER BY pt.parameter_name;
```

**Output:**

```
device_name | parameter_name | unit | time                  | value | quality
------------|----------------|------|-----------------------|-------|--------
Sensor-001  | Voltage        | V    | 2025-11-22 12:00:00Z | 230.5 | 192
Sensor-001  | Current        | A    | 2025-11-22 12:00:00Z | 10.2  | 192
Sensor-001  | Power          | kW   | 2025-11-22 12:00:00Z | 2.35  | 192
```

### 3.3 View: v_scada_history

**Purpose:** Provides full historical data for all devices and parameters.

**Definition:**

```sql
CREATE OR REPLACE VIEW v_scada_history AS
SELECT
  time, device_id, parameter_key, value, quality, source
FROM ingest_events;
```

**View Structure:**

| Column | Type | Description |
|--------|------|-------------|
| `time` | TIMESTAMPTZ | Timestamp of the measurement |
| `device_id` | UUID | Device identifier |
| `parameter_key` | TEXT | Parameter identifier |
| `value` | DOUBLE PRECISION | Metric value |
| `quality` | SMALLINT | Quality code |
| `source` | TEXT | Protocol source (e.g., "GPRS", "SMS", "MQTT") |

**How It Works:**

- **Direct Projection** - Simple SELECT from `ingest_events` table
- **No Aggregation** - Returns all historical rows
- **Time-Series Data** - Optimized for time-range queries

**Example Query:**

```sql
-- Get historical data for a device/parameter over time range
SELECT 
    v.time,
    v.value,
    v.quality,
    v.source
FROM v_scada_history v
WHERE v.device_id = '550e8400-e29b-41d4-a716-446655440002'
  AND v.parameter_key = 'voltage'
  AND v.time >= NOW() - INTERVAL '24 hours'
ORDER BY v.time DESC;
```

**Output:**

```
time                  | value | quality | source
----------------------|-------|---------|-------
2025-11-22 12:00:00Z  | 230.5 | 192     | GPRS
2025-11-22 11:55:00Z  | 230.3 | 192     | GPRS
2025-11-22 11:50:00Z  | 230.7 | 192     | GPRS
...
```

### 3.4 View Performance

**Indexes Supporting Views:**

```sql
-- Primary index for latest value queries
CREATE INDEX idx_ingest_events_device_param_time_desc
  ON ingest_events (device_id, parameter_key, time DESC);

-- TimescaleDB hypertable partitioning
-- Automatic partitioning by time (daily chunks)
```

**Query Optimization:**

1. **Latest Value Queries** - Use `v_scada_latest` (pre-filtered)
2. **Time-Range Queries** - Use `v_scada_history` with time filters
3. **Device-Specific** - Always filter by `device_id` for performance
4. **Parameter-Specific** - Filter by `parameter_key` when possible

**Performance Tips:**

- **Use Latest View** - For current values, use `v_scada_latest` (faster)
- **Time Filters** - Always include time range for historical queries
- **Limit Results** - Use `LIMIT` for large result sets
- **Join Efficiently** - Join with `devices` and `parameter_templates` only when needed

---

## 4. SCADA Read-Only User Setup

### 4.1 Purpose

The `scada_reader` user provides **secure, read-only access** to SCADA views and related tables. This user:

- **Cannot modify data** - SELECT privileges only
- **Cannot access sensitive tables** - Limited to SCADA views and related tables
- **Auditable** - All queries logged for security
- **Isolated** - Separate from admin and application users

### 4.2 User Creation

**SQL Script:**

```sql
-- Create read-only user
CREATE USER scada_reader WITH PASSWORD 'secure_password_here';

-- Grant connect privilege
GRANT CONNECT ON DATABASE nsready TO scada_reader;

-- Grant usage on schema
GRANT USAGE ON SCHEMA public TO scada_reader;

-- Grant SELECT on views
GRANT SELECT ON v_scada_latest TO scada_reader;
GRANT SELECT ON v_scada_history TO scada_reader;

-- Grant SELECT on related tables (for joins)
GRANT SELECT ON devices TO scada_reader;
GRANT SELECT ON parameter_templates TO scada_reader;
GRANT SELECT ON sites TO scada_reader;
GRANT SELECT ON projects TO scada_reader;
GRANT SELECT ON customers TO scada_reader;

-- Optional: Grant SELECT on ingest_events (if direct access needed)
-- GRANT SELECT ON ingest_events TO scada_reader;
```

**Setup Script Location:**

- `shared/scripts/setup_scada_readonly_user.sql` (if exists)
- Or create manually using SQL above

### 4.3 Connection String

**Format:**

```
postgresql://scada_reader:password@host:port/database
```

**Examples:**

```bash
# Local Docker
postgresql://scada_reader:password@localhost:5432/nsready

# Kubernetes (port-forward)
postgresql://scada_reader:password@localhost:5432/nsready

# Direct Kubernetes (cluster IP)
postgresql://scada_reader:password@nsready-db-0.nsready-tier2.svc.cluster.local:5432/nsready
```

### 4.4 Security Considerations

**Password Management:**

- **Strong Passwords** - Use complex, randomly generated passwords
- **Password Rotation** - Rotate passwords regularly
- **Secret Management** - Store passwords in Kubernetes secrets or vault
- **No Hardcoding** - Never hardcode passwords in code or configs

**Access Control:**

- **Network Isolation** - Restrict access to SCADA network only
- **IP Whitelisting** - Limit connections from specific IPs (if supported)
- **Audit Logging** - Enable PostgreSQL audit logging for SCADA user
- **Regular Review** - Review access logs periodically

**Privilege Principle:**

- **Minimum Privileges** - Grant only SELECT on required objects
- **No Write Access** - Never grant INSERT/UPDATE/DELETE
- **No Schema Changes** - Never grant CREATE/ALTER/DROP
- **No Admin Access** - Never grant superuser privileges

---

## 5. SCADA Integration Methods

### 5.1 Method 1: Direct SQL Connection

**Description:** SCADA system connects directly to PostgreSQL and queries views.

**Advantages:**

- **Real-time** - Data available immediately after ingestion
- **Flexible** - Custom queries for specific needs
- **Efficient** - Direct database access, no file I/O
- **Standard** - Uses standard PostgreSQL protocol

**Disadvantages:**

- **Network Dependency** - Requires stable network connection
- **Database Load** - Queries add load to database
- **Security** - Requires network access to database

**Configuration:**

```yaml
# SCADA System Configuration
Database Type: PostgreSQL
Host: nsready-db-0.nsready-tier2.svc.cluster.local
Port: 5432
Database: nsready
Username: scada_reader
Password: <secure_password>
Query: SELECT * FROM v_scada_latest WHERE device_id = ?
Poll Interval: 5 seconds
```

**Query Pattern:**

```sql
-- SCADA polls this query every N seconds
SELECT 
    device_id,
    parameter_key,
    time,
    value,
    quality
FROM v_scada_latest
WHERE device_id IN (?, ?, ?)  -- List of monitored devices
ORDER BY device_id, parameter_key;
```

### 5.2 Method 2: Export Files

**Description:** Scheduled scripts export data to TXT/CSV files, SCADA reads files.

**Advantages:**

- **Network Isolation** - No direct database connection needed
- **File-Based** - Works with file-based SCADA systems
- **Scheduled** - Exports run on schedule (e.g., every minute)
- **Backup** - Files can be archived for historical analysis

**Disadvantages:**

- **Latency** - Data not real-time (depends on export frequency)
- **File Management** - Requires file cleanup and management
- **Format Dependency** - SCADA must support file format

**Export Scripts:**

```bash
# Export latest values (TXT format)
./scripts/export_scada_data.sh --latest --format txt

# Export latest values (CSV format)
./scripts/export_scada_data.sh --latest --format csv

# Export historical data (time range)
./scripts/export_scada_data.sh --history --start "2025-11-22 00:00:00" --end "2025-11-22 23:59:59"

# Export readable format (with parameter names)
./scripts/export_scada_data_readable.sh --latest --format txt
```

**Export File Format (TXT):**

```
device_id,parameter_key,time,value,quality
550e8400-e29b-41d4-a716-446655440002,voltage,2025-11-22T12:00:00Z,230.5,192
550e8400-e29b-41d4-a716-446655440002,current,2025-11-22T12:00:00Z,10.2,192
```

**Export File Format (Readable TXT):**

```
device_name,device_code,parameter_name,unit,value,quality,timestamp
Sensor-001,SEN001,Voltage,V,230.5,192,2025-11-22T12:00:00Z
Sensor-001,SEN001,Current,A,10.2,192,2025-11-22T12:00:00Z
```

**Scheduled Export (Cron):**

```bash
# Export latest values every minute
*/1 * * * * /path/to/scripts/export_scada_data.sh --latest --format txt --output /scada/import/latest.txt
```

### 5.3 Method 3: Materialized Views (Optional)

**Description:** Pre-aggregated materialized views for faster queries.

**Use Case:** When SCADA needs aggregated data (hourly averages, daily summaries).

**Example:**

```sql
-- Create materialized view for hourly averages
CREATE MATERIALIZED VIEW mv_scada_hourly_avg AS
SELECT
    time_bucket('1 hour', time) AS hour,
    device_id,
    parameter_key,
    AVG(value) AS avg_value,
    MIN(value) AS min_value,
    MAX(value) AS max_value,
    COUNT(*) AS sample_count
FROM ingest_events
GROUP BY time_bucket('1 hour', time), device_id, parameter_key;

-- Create index for fast queries
CREATE INDEX idx_mv_scada_hourly_avg_hour_device_param
  ON mv_scada_hourly_avg (hour DESC, device_id, parameter_key);

-- Refresh materialized view (run periodically)
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_scada_hourly_avg;
```

**Refresh Strategy:**

- **Scheduled Refresh** - Refresh every hour via cron or scheduler
- **Concurrent Refresh** - Use `CONCURRENTLY` to avoid blocking queries
- **Incremental Refresh** - Refresh only new data (advanced)

---

## 6. SCADA Tag Mapping

### 6.1 Tag Mapping Overview

SCADA systems use **tag names** to identify data points. NSReady uses **parameter_key** for the same purpose. Tag mapping connects SCADA tags to NSReady parameters.

**Mapping Process:**

```
SCADA Tag Name          →  NSReady parameter_key  →  Parameter Template
─────────────────          ─────────────────────      ──────────────────
Pump01_Voltage         →  project:...:voltage     →  Voltage (V)
Pump01_Current         →  project:...:current     →  Current (A)
Pump01_Status          →  project:...:status      →  Status
```

### 6.2 Mapping Table Structure

**Recommended Mapping Table:**

| SCADA Tag | Device Name | parameter_key | parameter_name | unit | device_id |
|-----------|-------------|--------------|-----------------|------|-----------|
| `Pump01_Voltage` | Pump-001 | `project:...:voltage` | Voltage | V | `550e8400-...` |
| `Pump01_Current` | Pump-001 | `project:...:current` | Current | A | `550e8400-...` |
| `Pump01_Power` | Pump-001 | `project:...:power` | Power | kW | `550e8400-...` |

**Mapping Query:**

```sql
-- Get mapping for SCADA tag configuration
SELECT 
    d.name AS device_name,
    d.device_code,
    pt.key AS parameter_key,
    pt.parameter_name,
    pt.unit,
    d.id AS device_id
FROM devices d
JOIN parameter_templates pt ON 1=1  -- All combinations
WHERE d.site_id = '550e8400-e29b-41d4-a716-446655440001'
ORDER BY d.name, pt.parameter_name;
```

### 6.3 Tag Mapping Best Practices

**1. Use parameter_key, Not parameter_name**

- **parameter_key** is stable and unique (immutable)
- **parameter_name** can change (for display only)
- **Mapping should use key** for reliability

**2. Document Mapping**

- **Maintain mapping table** - Keep SCADA tag → parameter_key mapping
- **Version control** - Track mapping changes over time
- **Export regularly** - Export mapping for backup

**3. Consistent Naming**

- **Standardize tag names** - Use consistent naming convention
- **Include device identifier** - Tag names should include device info
- **Avoid special characters** - Use alphanumeric and underscores only

**4. Validate Mapping**

- **Test queries** - Verify tags map to correct parameters
- **Check data quality** - Ensure mapped parameters have data
- **Monitor for changes** - Alert on parameter_key changes

---

## 7. Export Procedures

### 7.1 Export Latest Values

**Purpose:** Export current values for all devices/parameters.

**Command:**

```bash
# Export latest values (TXT format)
./scripts/export_scada_data.sh --latest --format txt

# Export latest values (CSV format)
./scripts/export_scada_data.sh --latest --format csv

# Export to specific file
./scripts/export_scada_data.sh --latest --format txt --output /path/to/export.txt
```

**Output Format (TXT):**

```
device_id,parameter_key,time,value,quality
550e8400-e29b-41d4-a716-446655440002,voltage,2025-11-22T12:00:00Z,230.5,192
550e8400-e29b-41d4-a716-446655440002,current,2025-11-22T12:00:00Z,10.2,192
```

**Output Format (CSV):**

```csv
device_id,parameter_key,time,value,quality
550e8400-e29b-41d4-a716-446655440002,voltage,2025-11-22T12:00:00Z,230.5,192
550e8400-e29b-41d4-a716-446655440002,current,2025-11-22T12:00:00Z,10.2,192
```

### 7.2 Export Historical Data

**Purpose:** Export historical data for time range analysis.

**Command:**

```bash
# Export last 24 hours
./scripts/export_scada_data.sh --history --hours 24

# Export specific time range
./scripts/export_scada_data.sh --history \
  --start "2025-11-22 00:00:00" \
  --end "2025-11-22 23:59:59"

# Export for specific device
./scripts/export_scada_data.sh --history \
  --device-id "550e8400-e29b-41d4-a716-446655440002" \
  --hours 24
```

**Output:** Same format as latest values, but includes all rows in time range.

### 7.3 Export Readable Format

**Purpose:** Export with human-readable parameter names and units.

**Command:**

```bash
# Export latest values (readable)
./scripts/export_scada_data_readable.sh --latest --format txt

# Export historical (readable)
./scripts/export_scada_data_readable.sh --history --hours 24 --format txt
```

**Output Format:**

```
device_name,device_code,parameter_name,unit,value,quality,timestamp
Sensor-001,SEN001,Voltage,V,230.5,192,2025-11-22T12:00:00Z
Sensor-001,SEN001,Current,A,10.2,192,2025-11-22T12:00:00Z
Sensor-001,SEN001,Power,kW,2.35,192,2025-11-22T12:00:00Z
```

**Benefits:**

- **Human-readable** - Parameter names instead of keys
- **Units included** - Engineering units for display
- **Device names** - Device names instead of UUIDs
- **SCADA-friendly** - Easy to import into SCADA systems

### 7.4 Scheduled Exports

**Purpose:** Automate regular exports for SCADA file-based integration.

**Cron Example:**

```bash
# Export latest values every minute
*/1 * * * * /path/to/scripts/export_scada_data.sh --latest --format txt --output /scada/import/latest.txt

# Export hourly summary every hour
0 * * * * /path/to/scripts/export_scada_data_readable.sh --history --hours 1 --format csv --output /scada/import/hourly_$(date +\%Y\%m\%d_\%H).csv

# Export daily summary at midnight
0 0 * * * /path/to/scripts/export_scada_data_readable.sh --history --hours 24 --format csv --output /scada/import/daily_$(date +\%Y\%m\%d).csv
```

**File Management:**

- **Rotate files** - Archive old exports
- **Cleanup** - Remove files older than N days
- **Monitor disk space** - Ensure sufficient storage

---

## 8. SCADA Connection Examples

### 8.1 PostgreSQL ODBC Connection

**ODBC Configuration (Windows):**

```
[NSReady_SCADA]
Driver=PostgreSQL Unicode
Server=nsready-db-0.nsready-tier2.svc.cluster.local
Port=5432
Database=nsready
Username=scada_reader
Password=<secure_password>
SSLMode=prefer
```

**Connection String:**

```
DRIVER={PostgreSQL Unicode};SERVER=nsready-db-0.nsready-tier2.svc.cluster.local;PORT=5432;DATABASE=nsready;UID=scada_reader;PWD=<secure_password>
```

### 8.2 Python Connection Example

```python
import psycopg2
from psycopg2.extras import RealDictCursor

# Connect to database
conn = psycopg2.connect(
    host="nsready-db-0.nsready-tier2.svc.cluster.local",
    port=5432,
    database="nsready",
    user="scada_reader",
    password="secure_password"
)

# Query latest values
cursor = conn.cursor(cursor_factory=RealDictCursor)
cursor.execute("""
    SELECT 
        d.name AS device_name,
        pt.parameter_name,
        pt.unit,
        v.time,
        v.value,
        v.quality
    FROM v_scada_latest v
    JOIN devices d ON d.id = v.device_id
    JOIN parameter_templates pt ON pt.key = v.parameter_key
    WHERE v.device_id = %s
    ORDER BY pt.parameter_name
""", (device_id,))

results = cursor.fetchall()
for row in results:
    print(f"{row['device_name']}: {row['parameter_name']} = {row['value']} {row['unit']}")

cursor.close()
conn.close()
```

### 8.3 Node.js Connection Example

```javascript
const { Client } = require('pg');

// Connect to database
const client = new Client({
  host: 'nsready-db-0.nsready-tier2.svc.cluster.local',
  port: 5432,
  database: 'nsready',
  user: 'scada_reader',
  password: 'secure_password'
});

await client.connect();

// Query latest values
const result = await client.query(`
  SELECT 
    d.name AS device_name,
    pt.parameter_name,
    pt.unit,
    v.time,
    v.value,
    v.quality
  FROM v_scada_latest v
  JOIN devices d ON d.id = v.device_id
  JOIN parameter_templates pt ON pt.key = v.parameter_key
  WHERE v.device_id = $1
  ORDER BY pt.parameter_name
`, [deviceId]);

result.rows.forEach(row => {
  console.log(`${row.device_name}: ${row.parameter_name} = ${row.value} ${row.unit}`);
});

await client.end();
```

---

## 9. Quality Codes

### 9.1 Quality Code Values

**Standard Quality Codes:**

| Quality Code | Meaning | Description |
|--------------|---------|-------------|
| 192 | Good | Data is valid and reliable |
| 0 | Bad | Data is invalid or unreliable |
| 1-191 | Various | Quality flags (implementation-specific) |

**Quality Code Usage:**

- **192 (Good)** - Normal operation, data is valid
- **0 (Bad)** - Data quality issue, do not use
- **Other values** - Custom quality flags (check documentation)

**Query with Quality Filter:**

```sql
-- Get only good quality data
SELECT * FROM v_scada_latest
WHERE quality = 192;

-- Get data with quality information
SELECT 
    device_id,
    parameter_key,
    value,
    CASE 
        WHEN quality = 192 THEN 'Good'
        WHEN quality = 0 THEN 'Bad'
        ELSE 'Unknown'
    END AS quality_status
FROM v_scada_latest;
```

---

## 10. Troubleshooting

### 10.1 View Returns No Data

**Symptoms:**
- `v_scada_latest` returns empty result set
- `v_scada_history` returns no rows

**Diagnosis:**

```sql
-- Check if ingest_events has data
SELECT COUNT(*) FROM ingest_events;

-- Check if devices exist
SELECT COUNT(*) FROM devices;

-- Check if parameter_templates exist
SELECT COUNT(*) FROM parameter_templates;

-- Check view definition
SELECT * FROM v_scada_latest LIMIT 10;
```

**Resolution:**

1. **Verify Data Ingestion** - Ensure data is being ingested (see Module 8)
2. **Check Device Registry** - Ensure devices are imported (see Module 5)
3. **Check Parameter Templates** - Ensure parameters are imported (see Module 6)
4. **Verify View Definition** - Check view is created correctly

### 10.2 SCADA Cannot Connect

**Symptoms:**
- Connection timeout
- Authentication failure
- Network unreachable

**Diagnosis:**

```bash
# Test database connectivity
psql -h nsready-db-0.nsready-tier2.svc.cluster.local \
     -p 5432 \
     -U scada_reader \
     -d nsready

# Test from SCADA network
telnet nsready-db-0.nsready-tier2.svc.cluster.local 5432

# Check firewall rules
# Check network routing
```

**Resolution:**

1. **Check Network** - Ensure SCADA network can reach database
2. **Check Firewall** - Ensure port 5432 is open
3. **Check Credentials** - Verify username and password
4. **Check User Permissions** - Verify scada_reader user exists and has permissions

### 10.3 Slow Query Performance

**Symptoms:**
- Queries take long time
- High database CPU usage
- Timeout errors

**Diagnosis:**

```sql
-- Check query execution plan
EXPLAIN ANALYZE
SELECT * FROM v_scada_latest
WHERE device_id = '550e8400-e29b-41d4-a716-446655440002';

-- Check index usage
SELECT * FROM pg_stat_user_indexes
WHERE schemaname = 'public' AND tablename = 'ingest_events';

-- Check table statistics
SELECT * FROM pg_stat_user_tables
WHERE schemaname = 'public' AND relname = 'ingest_events';
```

**Resolution:**

1. **Add Indexes** - Ensure proper indexes exist
2. **Optimize Queries** - Add filters (device_id, time range)
3. **Use Latest View** - Use `v_scada_latest` instead of `v_scada_history` for current values
4. **Limit Results** - Use LIMIT for large result sets
5. **Check Database Load** - Ensure database has sufficient resources

### 10.4 Export Files Not Updating

**Symptoms:**
- Export files show old data
- Export timestamps not changing

**Diagnosis:**

```bash
# Check export script execution
ps aux | grep export_scada_data

# Check cron job
crontab -l | grep export_scada_data

# Check file permissions
ls -la /path/to/export/files

# Check disk space
df -h
```

**Resolution:**

1. **Check Cron** - Verify cron job is running
2. **Check Script** - Verify export script executes successfully
3. **Check Permissions** - Ensure script can write to export directory
4. **Check Disk Space** - Ensure sufficient disk space
5. **Check Logs** - Review export script logs for errors

---

## 11. Best Practices

### 11.1 View Usage

1. **Use Latest View for Current Values** - `v_scada_latest` is optimized for current data
2. **Use History View for Time Ranges** - `v_scada_history` with time filters for historical data
3. **Always Filter by Device** - Include `device_id` filter for performance
4. **Use Time Ranges** - Always include time filters for historical queries
5. **Limit Result Sets** - Use LIMIT for large queries

### 11.2 Security

1. **Strong Passwords** - Use complex, randomly generated passwords
2. **Read-Only Access** - Never grant write privileges to SCADA user
3. **Network Isolation** - Restrict access to SCADA network
4. **Audit Logging** - Enable query logging for security
5. **Regular Review** - Review access logs periodically

### 11.3 Performance

1. **Index Optimization** - Ensure proper indexes exist
2. **Query Optimization** - Use efficient queries with filters
3. **Connection Pooling** - Reuse database connections
4. **Polling Frequency** - Balance real-time needs with database load
5. **Materialized Views** - Use for aggregated data if needed

### 11.4 Integration

1. **Tag Mapping** - Use `parameter_key` for mapping (not `parameter_name`)
2. **Documentation** - Maintain mapping table and documentation
3. **Testing** - Test integration before production deployment
4. **Monitoring** - Monitor query performance and errors
5. **Backup** - Export mapping tables regularly

---

## 12. Summary

### 12.1 Key Takeaways

1. **Two Primary Views** - `v_scada_latest` for current values, `v_scada_history` for historical data
2. **Read-Only Access** - Dedicated `scada_reader` user with SELECT privileges only
3. **Multiple Integration Methods** - Direct SQL, export files, materialized views
4. **Tag Mapping** - Map SCADA tags to `parameter_key` (stable identifier)
5. **Performance Optimized** - Views use efficient queries with proper indexes

### 12.2 Related Modules

- **Module 0** - Introduction and Terminology
- **Module 2** - System Architecture and Data Flow
- **Module 3** - Environment and PostgreSQL Storage Manual
- **Module 5** - Configuration Import Manual
- **Module 6** - Parameter Template Manual
- **Module 8** - Ingestion Worker & Queue Processing
- **Module 10** - NSReady Dashboard Architecture & UI (upcoming)
- **Module 13** - Operational Checklist & Runbook (upcoming)

### 12.3 Next Steps

After understanding SCADA views and export mapping:

1. **Set Up Read-Only User** - Create `scada_reader` user with proper permissions
2. **Configure SCADA Connection** - Set up SCADA system to connect to database
3. **Create Tag Mapping** - Map SCADA tags to NSReady parameters
4. **Test Integration** - Verify data flow from NSReady to SCADA
5. **Set Up Monitoring** - Monitor query performance and data quality

---

**Module Created:** 2025-11-22  
**Last Updated:** 2025-11-22  
**Status:** Complete


