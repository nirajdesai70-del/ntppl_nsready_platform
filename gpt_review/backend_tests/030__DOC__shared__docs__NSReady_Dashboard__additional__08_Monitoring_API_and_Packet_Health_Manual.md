# Module 8 – Monitoring API and Packet Health Manual

_NSReady Data Collection Platform_

*(Suggested path: `docs/08_Monitoring_API_and_Packet_Health_Manual.md`)*

---

## 1. Introduction

The Monitoring API provides real-time visibility into:

- Packet arrival behaviour
- Expected vs received packets
- Missing packets
- Late packets
- Error counts
- Last packet timestamps
- Queue depth
- Site-level health
- Device-level health

This module describes:

- API endpoints (current and planned)
- Packet health formulas
- API response formats
- Usage examples
- SCADA/dashboard integration
- Prometheus metrics integration

**Audience:**

Engineers, SCADA teams, reliability engineers, and NSWare integration team.

---

## 2. Monitoring Architecture Overview

```
Device → Collector → NATS → Worker → DB → Monitoring API → SCADA/Dashboard
```

The monitoring system pulls from:

- `ingest_events` - Telemetry data
- `missing_intervals` - Missing packet tracking (future feature)
- `error_logs` - Error logging
- JetStream consumer stats - Queue metrics
- Registry metadata - Device/site/project information
- Time-based calculations - Packet health metrics

---

## 3. Current Monitoring Endpoints

### 3.1 GET /v1/health

**Purpose:**

Returns service health, queue depth, and database connection status.

**Endpoint:**

```
GET http://localhost:8001/v1/health
GET http://localhost:32001/v1/health  (Kubernetes NodePort)
```

**Response Structure:**

```json
{
  "service": "ok",
  "queue_depth": 0,
  "db": "connected",
  "queue": {
    "consumer": "ingest_workers",
    "pending": 0,
    "ack_pending": 0,
    "redelivered": 0,
    "waiting_pulls": 0
  }
}
```

**Fields:**

- `service` - Service status ("ok" or "error")
- `queue_depth` - Total pending + ack_pending messages
- `db` - Database connection status ("connected" or "disconnected")
- `queue.pending` - Unprocessed messages in JetStream
- `queue.ack_pending` - Messages being processed (not yet ACKed)
- `queue.redelivered` - Messages that were redelivered
- `queue.waiting_pulls` - Number of waiting pull requests

**Usage:**

```bash
curl http://localhost:8001/v1/health | jq .
```

**Queue Health Interpretation:**

| queue_depth | Status | Action |
|-------------|--------|--------|
| 0–5 | Normal | No action needed |
| 6–20 | Warning | Monitor closely |
| 21–100 | Critical | Check worker logs, may need scaling |
| >100 | Overload | System may be overloaded |

---

### 3.2 GET /metrics

**Purpose:**

Prometheus-compatible metrics endpoint for monitoring and alerting.

**Endpoint:**

```
GET http://localhost:8001/metrics
GET http://localhost:32001/metrics  (Kubernetes NodePort)
```

**Response Format:**

Prometheus text format (text/plain)

**Available Metrics:**

| Metric | Type | Description |
|--------|------|-------------|
| `ingest_events_total{status="queued"}` | Counter | Total events queued |
| `ingest_events_total{status="success"}` | Counter | Total events successfully processed |
| `ingest_errors_total{error_type="..."}` | Counter | Total errors by type |
| `ingest_queue_depth` | Gauge | Current queue depth |
| `ingest_consumer_pending` | Gauge | JetStream pending messages |
| `ingest_consumer_ack_pending` | Gauge | JetStream ack_pending messages |
| `ingest_rate_per_second` | Gauge | Current ingestion rate |

**Example Response:**

```
# HELP ingest_events_total Total events ingested
# TYPE ingest_events_total counter
ingest_events_total{status="queued"} 1250
ingest_events_total{status="success"} 1245

# HELP ingest_errors_total Total errors
# TYPE ingest_errors_total counter
ingest_errors_total{error_type="integrity"} 2
ingest_errors_total{error_type="database"} 1

# HELP ingest_queue_depth Current queue depth
# TYPE ingest_queue_depth gauge
ingest_queue_depth 5

# HELP ingest_consumer_pending JetStream pending messages
# TYPE ingest_consumer_pending gauge
ingest_consumer_pending 3

# HELP ingest_consumer_ack_pending JetStream ack_pending messages
# TYPE ingest_consumer_ack_pending gauge
ingest_consumer_ack_pending 2
```

**Usage:**

```bash
curl http://localhost:8001/metrics | grep ingest
```

**Prometheus Integration:**

Prometheus scrapes this endpoint automatically (configured in `deploy/monitoring/prometheus.yaml`).

---

## 4. Planned Monitoring API Endpoints (Future Implementation)

> ⚠️ **PLANNED FEATURE (MONITOR API)**  
> All `/monitor/*` endpoints described in this section are **PLANNED** and  
> **NOT implemented in the current release**.  
> The current production monitoring surface consists of `/v1/health` (JSON status)  
> and `/metrics` (Prometheus).  
> The `/monitor/*` API is reserved for future NSWare AI/observability enhancements.

**Note:** The following endpoints are planned for future implementation. They are documented here to guide development and SCADA integration planning.

### 4.1 GET /monitor/summary

**Status:** ⚠️ **PLANNED – Not implemented yet**

**Purpose:**

Returns packet health summary for all customers/projects/sites.

**Endpoint (Planned):**

```
GET http://localhost:8001/monitor/summary
```

**Response Structure:**

```json
{
  "timestamp": "2025-11-18T12:00:00Z",
  "customers": [
    {
      "customer_id": "uuid",
      "customer_name": "Customer 01",
      "sites_total": 4,
      "sites_ok": 3,
      "sites_warning": 1,
      "sites_critical": 0
    }
  ],
  "summary": {
    "total_sites": 4,
    "sites_ok": 3,
    "sites_warning": 1,
    "sites_critical": 0
  }
}
```

**Status Rules:**

| Status | Condition |
|--------|-----------|
| OK | `missing_packets <= 1` in last 60min |
| Warning | `missing_packets 2-5` OR `last_packet_time > 2× interval` |
| Critical | `missing_packets > 5` OR `last_packet_time > 3× interval` |

---

### 4.2 GET /monitor/site/{site_id}

**Status:** ⚠️ **PLANNED – Not implemented yet**

**Purpose:**

Device-level breakdown of packet behaviour for a specific site.

**Endpoint (Planned):**

```
GET http://localhost:8001/monitor/site/{site_id}
```

**Response Example:**

```json
{
  "site_id": "uuid",
  "site_name": "Main Factory",
  "project_id": "uuid",
  "project_name": "Factory Monitoring",
  "expected_packets_per_hour": 12,
  "received_packets_per_hour": 11,
  "missing_packets_per_hour": 1,
  "late_packets": 0,
  "last_packet_time": "2025-11-18T11:55:00Z",
  "status": "warning",
  "devices": [
    {
      "device_id": "uuid",
      "device_name": "Sensor-001",
      "device_code": "SEN001",
      "expected": 12,
      "received": 10,
      "missing": 2,
      "late": 0,
      "last_packet_time": "2025-11-18T11:55:00Z",
      "status": "warning"
    }
  ]
}
```

---

### 4.3 GET /monitor/device/{device_id}

**Status:** ⚠️ **PLANNED – Not implemented yet**

**Purpose:**

Shows complete packet behaviour for one device.

**Endpoint (Planned):**

```
GET http://localhost:8001/monitor/device/{device_id}
```

**Response Includes:**

- Packet interval (expected reporting interval)
- Expected timeline (when packets should arrive)
- Gaps (missing intervals)
- Late packets (packets received after expected time)
- Last timestamp (most recent packet)
- Error history (recent errors for this device)
- Rolling 1h / 24h metrics

**Response Example:**

```json
{
  "device_id": "uuid",
  "device_name": "Sensor-001",
  "device_code": "SEN001",
  "site_id": "uuid",
  "site_name": "Main Factory",
  "reporting_interval_seconds": 300,
  "expected_packets_per_hour": 12,
  "last_24h": {
    "expected": 288,
    "received": 285,
    "missing": 3,
    "late": 1
  },
  "last_1h": {
    "expected": 12,
    "received": 11,
    "missing": 1,
    "late": 0
  },
  "last_packet_time": "2025-11-18T11:55:00Z",
  "status": "warning",
  "gaps": [
    {
      "start_time": "2025-11-18T11:50:00Z",
      "end_time": "2025-11-18T11:55:00Z",
      "reason": "No packets received"
    }
  ],
  "errors": [
    {
      "time": "2025-11-18T10:00:00Z",
      "message": "Out of range value",
      "severity": "warning"
    }
  ]
}
```

---

### 4.4 GET /monitor/queue-depth

**Status:** ⚠️ **PLANNED – Not implemented yet**

**Purpose:**

Reports JetStream consumer metrics (detailed queue information).

**Endpoint (Planned):**

```
GET http://localhost:8001/monitor/queue-depth
```

**Note:** This information is currently available via `/v1/health` endpoint under the `queue` object.

**Response Structure:**

```json
{
  "consumer": "ingest_workers",
  "pending": 0,
  "ack_pending": 0,
  "redelivered": 0,
  "waiting_pulls": 0,
  "last_sequence": 123,
  "delivered": 1250,
  "acknowledged": 1250
}
```

**Current Alternative:**

Use `/v1/health` endpoint:

```bash
curl http://localhost:8001/v1/health | jq '.queue'
```

---

### 4.5 GET /monitor/errors

**Status:** ⚠️ **PLANNED – Not implemented yet**

**Purpose:**

Returns pipeline errors from `error_logs` table.

**Endpoint (Planned):**

```
GET http://localhost:8001/monitor/errors
```

**Query Parameters (Planned):**

- `device_id` - Filter by device
- `since` - Filter by time (ISO 8601)
- `severity` - Filter by severity level
- `limit` - Limit number of results

**Response Structure:**

```json
{
  "errors": [
    {
      "time": "2025-11-18T10:00:00Z",
      "device_id": "uuid",
      "device_name": "Sensor-001",
      "description": "Out of range value",
      "metric": "voltage",
      "value": 999,
      "severity": "critical",
      "context": {
        "parameter_key": "project:...:voltage",
        "min_value": 0,
        "max_value": 240
      }
    }
  ],
  "total": 5,
  "since": "2025-11-18T00:00:00Z"
}
```

**Current Alternative:**

Query database directly:

**For Kubernetes:**

```bash
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "
SELECT * FROM error_logs 
ORDER BY time DESC 
LIMIT 10;"
```

**For Docker Compose:**

```bash
docker exec nsready_db psql -U postgres -d nsready -c "
SELECT * FROM error_logs 
ORDER BY time DESC 
LIMIT 10;"
```

---

## 5. Packet Behaviour Definitions (Core Logic)

This is the heart of the health engine. These formulas define how packet health is calculated.

### 5.1 Expected Packets Per Hour

**Formula:**

```
expected_packets_per_hour = 3600 / reporting_interval_secs
```

**Examples:**

| Reporting Interval | Expected Packets Per Hour |
|-------------------|---------------------------|
| 5 minutes (300s) | 12 |
| 10 minutes (600s) | 6 |
| 15 minutes (900s) | 4 |
| 30 minutes (1800s) | 2 |
| 1 hour (3600s) | 1 |
| 2 hours (7200s) | 0.5 |

**Note:** Reporting interval must be configured per device (stored in device metadata or configuration).

---

### 5.2 Received Packets Per Hour

**Formula:**

```
received_packets_per_hour = COUNT(events WHERE time >= NOW() - INTERVAL '1 hour')
```

**SQL Example:**

```sql
SELECT COUNT(*) 
FROM ingest_events 
WHERE device_id = '<device_uuid>'
  AND time >= NOW() - INTERVAL '1 hour';
```

**Note:** Counts distinct events (one event may contain multiple metrics).

---

### 5.3 Missing Packets

**Formula:**

```
missing_packets_per_hour = expected_packets_per_hour - received_packets_per_hour
```

**If result is negative → set to zero** (device sent more than expected).

**Example:**

- Expected: 12 packets/hour
- Received: 11 packets/hour
- Missing: 1 packet

**Calculation:**

```sql
SELECT 
  (3600 / 300) - COUNT(*) AS missing_packets
FROM ingest_events
WHERE device_id = '<device_uuid>'
  AND time >= NOW() - INTERVAL '1 hour';
```

---

### 5.4 Late Packets

**Definition:**

A packet is **late** if:

```
source_timestamp < NOW() - (2 × reporting_interval)
```

**Example:**

- Reporting interval: 5 minutes (300s)
- Current time: 12:00:00
- Packet timestamp: 11:50:00 (10 minutes ago)
- Expected latest: 11:55:00 (5 minutes ago)
- **Result:** Late (10 minutes > 2 × 5 minutes)

**SQL Example:**

```sql
SELECT COUNT(*) AS late_packets
FROM ingest_events
WHERE device_id = '<device_uuid>'
  AND time >= NOW() - INTERVAL '1 hour'
  AND source_timestamp < NOW() - INTERVAL '10 minutes';  -- 2 × 5min interval
```

**Note:** Late packets are counted separately from missing packets.

---

### 5.5 Device Status Logic

**Status Calculation:**

| Status | Condition |
|--------|-----------|
| **OK** | `missing ≤ 1` AND `last_packet_time < 2× interval` |
| **Warning** | `missing 2-5` OR `last_packet_time 2-3× interval` |
| **Critical** | `missing > 5` OR `last_packet_time > 3× interval` |

**Example:**

- Reporting interval: 5 minutes
- Missing packets: 2
- Last packet: 8 minutes ago

**Calculation:**

- Missing: 2 → Warning threshold
- Last packet: 8 minutes > 2×5 = 10 minutes? No (8 < 10)
- **Status:** Warning (due to missing packets)

**SQL Example:**

```sql
WITH device_stats AS (
  SELECT 
    device_id,
    COUNT(*) AS received,
    MAX(time) AS last_packet_time,
    NOW() - MAX(time) AS time_since_last
  FROM ingest_events
  WHERE device_id = '<device_uuid>'
    AND time >= NOW() - INTERVAL '1 hour'
  GROUP BY device_id
)
SELECT 
  device_id,
  received,
  last_packet_time,
  CASE
    WHEN (12 - received) <= 1 AND time_since_last < INTERVAL '10 minutes' THEN 'OK'
    WHEN (12 - received) BETWEEN 2 AND 5 OR time_since_last BETWEEN INTERVAL '10 minutes' AND INTERVAL '15 minutes' THEN 'warning'
    WHEN (12 - received) > 5 OR time_since_last > INTERVAL '15 minutes' THEN 'critical'
    ELSE 'unknown'
  END AS status
FROM device_stats;
```

---

### 5.6 Site Status Logic

**Calculation:**

A site is:

- **OK** if ≥ 80% devices are OK
- **Warning** if ≥ 1 device is Warning (but no Critical)
- **Critical** if ≥ 1 device is Critical

**Example:**

- Site has 10 devices
- 8 devices: OK
- 2 devices: Warning
- 0 devices: Critical

**Calculation:**

- OK devices: 8/10 = 80% → Site status: **OK** (80% threshold met)
- But 2 devices Warning → Site status: **Warning** (any Warning triggers Warning)

**Final Status:** **Warning**

---

### 5.7 Customer Status Logic

**Calculation:**

- **OK** if all sites are OK
- **Warning** if any site is Warning (but no Critical)
- **Critical** if any site is Critical

**Example:**

- Customer has 3 sites
- Site 1: OK
- Site 2: Warning
- Site 3: OK

**Final Status:** **Warning** (any Warning site triggers Warning)

---

### 5.8 Queue Health

**Status Rules:**

| queue_depth | Status | Action |
|-------------|--------|--------|
| 0–5 | OK | Normal operation |
| 6–20 | Warning | Monitor closely |
| 21–100 | Critical | Check worker logs, may need scaling |
| >100 | Overload | System may be overloaded |

**Current Implementation:**

Available via `/v1/health` endpoint:

```bash
curl http://localhost:8001/v1/health | jq .queue_depth
```

**Monitoring:**

```bash
watch -n 5 'curl -s http://localhost:8001/v1/health | jq .queue_depth'
```

---

### 5.9 Error Score

**Formula:**

```
error_score = (critical_errors × 3) + (warning_errors × 1)
```

**Status Rules:**

| Score | Status |
|-------|--------|
| 0 | OK |
| 1-4 | Warning |
| ≥ 5 | Critical |

**Example:**

- 1 critical error → Score: 3 → Status: Warning
- 2 warning errors → Score: 2 → Status: Warning
- 2 critical errors → Score: 6 → Status: Critical

**SQL Example:**

```sql
SELECT 
  SUM(CASE WHEN level = 'critical' THEN 3 ELSE 1 END) AS error_score
FROM error_logs
WHERE time >= NOW() - INTERVAL '1 hour';
```

---

## 6. Database Tables Used for Monitoring

### 6.1 Tables

**ingest_events**

- Primary source for packet counts
- Time-series data with `time`, `device_id`, `parameter_key`
- Used to calculate received packets, last packet time

**devices**

- Device metadata (name, code, status)
- Links to sites and projects

**sites**

- Site metadata (name, location)
- Links to projects

**projects**

- Project metadata (name, description)
- Links to customers

**customers**

- Customer metadata (name)

**missing_intervals**

- Tracks missing packet intervals (future feature)
- Fields: `device_id`, `parameter_key`, `start_time`, `end_time`, `reason`

**error_logs**

- Error tracking
- Fields: `time`, `source`, `level`, `message`, `context`

---

### 6.2 Views

**v_scada_latest**

- Latest value per device/parameter
- Used for SCADA integration
- Can be used to determine last packet time

**v_scada_history**

- Full historical data
- Used for historical analysis

---

### 6.3 JetStream Stats

**Consumer Statistics:**

- `pending` - Unprocessed messages
- `ack_pending` - Messages being processed
- `redelivered` - Failed messages retried
- `waiting_pulls` - Waiting pull requests

**Access:**

- Via `/v1/health` endpoint (current)
- Via NATS monitoring API (port 8222)
- Via Prometheus metrics

---

## 7. Monitoring Window (Engineer UI Layout)

Below is the recommended dashboard layout for an NSReady/SCADA monitoring window.

### 7.1 Customer-Level Summary

**Columns:**

| Column | Description |
|--------|-------------|
| customer_name | Customer identifier |
| sites_total | Total number of sites |
| sites_ok | Number of sites with OK status |
| sites_warning | Number of sites with Warning status |
| sites_critical | Number of sites with Critical status |
| timestamp | Last update time |

**Example:**

```
customer_name    sites_total    sites_ok    sites_warning    sites_critical    timestamp
Customer 01      4              3           1                0                 2025-11-18T12:00:00Z
Customer 02      2              2           0                0                 2025-11-18T12:00:00Z
```

---

### 7.2 Site-Level Health

**Columns:**

| Column | Description |
|--------|-------------|
| site_name | Site identifier |
| expected_per_hour | Expected packets per hour |
| received_per_hour | Received packets per hour |
| missing | Missing packets |
| late | Late packets |
| last_packet_time | Most recent packet timestamp |
| status | OK / Warning / Critical |

**Example:**

```
site_name        expected    received    missing    late    last_packet_time        status
Main Factory     12          11          1          0       2025-11-18T11:55:00Z    warning
Boiler House     12          12          0          0       2025-11-18T11:58:00Z    ok
```

---

### 7.3 Device-Level Health Table

**Columns:**

| Column | Description |
|--------|-------------|
| device_name | Device identifier |
| device_code | External device code |
| parameter_count | Number of parameters |
| expected_per_hour | Expected packets per hour |
| received | Received packets (last hour) |
| missing | Missing packets |
| last_packet | Most recent packet timestamp |
| status | OK / Warning / Critical |

**Example:**

```
device_name    device_code    parameters    expected    received    missing    last_packet            status
Sensor-001     SEN001         3             12          10          2          2025-11-18T11:55:00Z   warning
Sensor-002     SEN002         3             12          12          0          2025-11-18T11:58:00Z   ok
```

---

### 7.4 Error Logs Panel

**Shows:**

- Last 20 errors
- Grouping by device
- Quick filters (severity, time range)

**Columns:**

| Column | Description |
|--------|-------------|
| time | Error timestamp |
| device_name | Device identifier |
| level | Error severity (critical/warning/info) |
| message | Error description |
| context | Additional error context (JSON) |

---

## 8. SCADA Integration for Monitoring

SCADA can integrate with monitoring in several ways:

### 8.1 Option 1 — Read Monitoring API Directly

**Using planned `/monitor/site/{id}` endpoint:**

```bash
curl http://localhost:32001/monitor/site/<site_uuid>
```

**Benefits:**

- Pre-calculated health metrics
- Standardized status values
- Easy integration

**Limitations:**

- Requires API endpoint implementation
- Network dependency

---

### 8.2 Option 2 — Read Pre-computed Database Tables

**Query `missing_intervals` table:**

```sql
SELECT 
  device_id,
  parameter_key,
  start_time,
  end_time,
  reason
FROM missing_intervals
WHERE device_id = '<device_uuid>'
ORDER BY start_time DESC;
```

**Query last event per device:**

```sql
SELECT 
  device_id,
  MAX(time) AS last_packet_time,
  COUNT(*) AS packets_last_hour
FROM ingest_events
WHERE device_id = '<device_uuid>'
  AND time >= NOW() - INTERVAL '1 hour'
GROUP BY device_id;
```

**Benefits:**

- Direct database access
- Full control over queries
- No API dependency

---

### 8.3 Option 3 — Read Latest Values + Timestamp from `v_scada_latest`

**Calculate health inside SCADA HMI:**

```sql
SELECT 
  d.name AS device_name,
  pt.name AS parameter_name,
  v.time AS last_packet_time,
  v.value,
  v.quality,
  NOW() - v.time AS time_since_last
FROM v_scada_latest v
JOIN devices d ON d.id = v.device_id
JOIN parameter_templates pt ON pt.key = v.parameter_key
WHERE d.site_id = '<site_uuid>'
ORDER BY v.time DESC;
```

**SCADA calculates:**

- Missing packets based on expected interval
- Late packets based on timestamp
- Device status based on rules

**Benefits:**

- Uses existing SCADA views
- No additional API needed
- SCADA has full control

---

## 9. Prometheus Metrics (Current Implementation)

### 9.1 Available Metrics

Monitoring endpoints integrate with Prometheus:

| Metric | Type | Description |
|--------|------|-------------|
| `ingest_queue_depth` | Gauge | Pending messages in JetStream |
| `ingest_consumer_pending` | Gauge | JetStream pending messages |
| `ingest_consumer_ack_pending` | Gauge | Messages delivered but not acked |
| `ingest_events_total{status="queued"}` | Counter | Total events queued |
| `ingest_events_total{status="success"}` | Counter | Total events successfully processed |
| `ingest_errors_total{error_type="..."}` | Counter | Pipeline errors by type |

**Access:**

```bash
curl http://localhost:8001/metrics | grep ingest
```

---

### 9.2 Prometheus Configuration

**Scrape Configuration:**

Defined in `deploy/monitoring/prometheus.yaml`:

```yaml
scrape_configs:
  - job_name: 'collector-service'
    kubernetes_sd_configs:
      - role: pod
        namespaces:
          names:
            - nsready-tier2
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_label_app]
        action: keep
        regex: collector-service
      - source_labels: [__meta_kubernetes_pod_ip]
        action: replace
        target_label: __address__
        replacement: $1:8001
    metrics_path: '/metrics'
```

---

### 9.3 Grafana Dashboard

**Dashboard Location:**

`deploy/monitoring/grafana-dashboards/dashboard.json`

**Panels:**

1. **Ingest Rate (events/sec)**
   - Query: `rate(ingest_events_total[5m])`
   - Shows ingestion throughput

2. **Queue Depth**
   - Query: `ingest_queue_depth`
   - Shows current queue backlog

3. **Error Rate**
   - Query: `rate(ingest_errors_total[5m]) / rate(ingest_events_total[5m])`
   - Shows error percentage

4. **P95 Latency**
   - Query: `histogram_quantile(0.95, rate(ingest_events_total[5m]))`
   - Shows 95th percentile latency

5. **Database Latency**
   - Query: `db_latency_seconds`
   - Shows database operation latency

6. **System Uptime**
   - Query: `system_uptime_seconds`
   - Shows service uptime

**Access:**

- Grafana URL: `http://localhost:3000` (port-forward)
- Grafana NodePort: `http://localhost:32000` (if configured)

---

## 10. Example Monitoring API Calls (Copy/Paste)

### 10.1 Current Endpoints

**Get health and queue depth:**

```bash
curl http://localhost:8001/v1/health | jq .
```

**Get Prometheus metrics:**

```bash
curl http://localhost:8001/metrics | grep ingest
```

**Get queue depth only:**

```bash
curl -s http://localhost:8001/v1/health | jq .queue_depth
```

**Get detailed queue stats:**

```bash
curl -s http://localhost:8001/v1/health | jq .queue
```

---

### 10.2 Planned Endpoints (Future)

**Get global summary:**

```bash
curl http://localhost:32001/monitor/summary
```

**Get site health:**

```bash
curl http://localhost:32001/monitor/site/<site_uuid>
```

**Get device health:**

```bash
curl http://localhost:32001/monitor/device/<device_uuid>
```

**Get queue stats:**

```bash
curl http://localhost:32001/monitor/queue-depth
```

**Get errors:**

```bash
curl http://localhost:32001/monitor/errors?since=2025-11-18T00:00:00Z&limit=20
```

---

### 10.3 Database Queries (Current Alternative)

**Get last packet time per device:**

**For Kubernetes:**

```bash
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "
SELECT 
  d.name AS device_name,
  MAX(e.time) AS last_packet_time,
  COUNT(*) AS packets_last_hour
FROM ingest_events e
JOIN devices d ON d.id = e.device_id
WHERE e.time >= NOW() - INTERVAL '1 hour'
GROUP BY d.name
ORDER BY last_packet_time DESC;"
```

**For Docker Compose:**

```bash
docker exec nsready_db psql -U postgres -d nsready -c "
SELECT 
  d.name AS device_name,
  MAX(e.time) AS last_packet_time,
  COUNT(*) AS packets_last_hour
FROM ingest_events e
JOIN devices d ON d.id = e.device_id
WHERE e.time >= NOW() - INTERVAL '1 hour'
GROUP BY d.name
ORDER BY last_packet_time DESC;"
```

**Get missing intervals:**

```bash
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "
SELECT * FROM missing_intervals 
WHERE device_id = '<device_uuid>'
ORDER BY start_time DESC
LIMIT 10;"
```

**Get recent errors:**

```bash
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "
SELECT * FROM error_logs 
ORDER BY time DESC 
LIMIT 20;"
```

---

## 11. Troubleshooting Monitoring Issues

### ❗ Status Always "OK"

**Possible causes:**

- `missing_intervals` table empty (not populated yet)
- Reporting interval not configured
- Status calculation not implemented

**Check:**

```bash
# Check if missing_intervals table has data
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "SELECT COUNT(*) FROM missing_intervals;"
```

**Fix:**

- Implement missing interval detection
- Configure reporting intervals per device
- Implement status calculation logic

---

### ❗ Missing Packets Always Zero

**Possible causes:**

- Reporting interval not configured
- Timestamps from device incorrect
- Calculation window too short

**Check:**

```bash
# Check device reporting interval (stored in metadata)
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "
SELECT 
  d.name,
  d.metadata->>'reporting_interval_seconds' AS interval
FROM devices d
LIMIT 10;"
```

**Fix:**

- Configure reporting interval in device metadata
- Verify device timestamps are correct
- Adjust calculation window if needed

---

### ❗ Queue Depth Always Same

**Possible causes:**

- NATS consumer name mismatch
- Consumer stats not updating
- Queue actually stable

**Check:**

```bash
# Verify consumer name
curl -s http://localhost:8001/v1/health | jq .queue.consumer

# Check NATS consumer directly
kubectl exec -n nsready-tier2 nsready-nats-0 -- \
  nats consumer info INGRESS ingest_workers
```

**Fix:**

- Verify consumer name is "ingest_workers"
- Check NATS connection
- Verify worker is pulling messages

---

### ❗ Late Packets Not Counted

**Possible causes:**

- `source_timestamp` format incorrect
- Late packet calculation not implemented
- Timestamp comparison logic error

**Check:**

```bash
# Check source_timestamp format
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "
SELECT 
  device_id,
  time AS source_timestamp,
  created_at AS received_timestamp,
  NOW() - time AS age
FROM ingest_events
ORDER BY time DESC
LIMIT 10;"
```

**Fix:**

- Verify `source_timestamp` is ISO 8601 format
- Implement late packet detection logic
- Check timestamp comparison in queries

---

### ❗ Monitoring API Slow

**Possible causes:**

- Large time range queries
- Missing database indexes
- Too many devices/sites

**Fix:**

**Increase DB indexes:**

```sql
CREATE INDEX IF NOT EXISTS idx_ingest_events_device_time 
  ON ingest_events (device_id, time DESC);

CREATE INDEX IF NOT EXISTS idx_ingest_events_time 
  ON ingest_events (time DESC);
```

**Limit time range:**

- Use smaller time windows (1 hour instead of 24 hours)
- Add pagination to API responses
- Cache frequently accessed data

**Optimize queries:**

- Use materialized views for aggregated data
- Pre-calculate metrics in background jobs
- Use TimescaleDB continuous aggregates

---

## 12. Monitoring Checklist (Copy–Paste)

### Before Production

- [ ] Monitoring API endpoints active (or planned)
- [ ] DB views valid (`v_scada_latest`, `v_scada_history`)
- [ ] Queue depth metrics enabled (`/v1/health`, `/metrics`)
- [ ] Packet interval defined for every device (in metadata)
- [ ] SCADA mapping complete (device codes, parameter keys)
- [ ] Prometheus scraping configured
- [ ] Grafana dashboard deployed
- [ ] Alert rules configured (if using Alertmanager)

### During Operation

- [ ] Check queue depth hourly (`curl http://localhost:8001/v1/health | jq .queue_depth`)
- [ ] Verify missing packets (query database or use monitoring API)
- [ ] Monitor last packet times (query `v_scada_latest` or monitoring API)
- [ ] Review error logs (`SELECT * FROM error_logs ORDER BY time DESC LIMIT 20`)
- [ ] Export SCADA CSV daily (optional, using export scripts)
- [ ] Check Prometheus metrics (Grafana dashboard)
- [ ] Monitor worker logs for errors

---

## 13. Implementation Notes

### 13.1 Current Implementation Status

**✅ Implemented:**

- `/v1/health` endpoint with queue depth
- `/metrics` endpoint (Prometheus)
- Queue depth tracking
- Error logging to `error_logs` table
- Database views for SCADA

**⚠️ Planned (Future Implementation):**

- `/monitor/summary` endpoint
- `/monitor/site/{site_id}` endpoint
- `/monitor/device/{device_id}` endpoint
- `/monitor/queue-depth` endpoint (separate from health)
- `/monitor/errors` endpoint
- Missing interval detection and population
- Packet health calculation logic
- Status calculation (OK/Warning/Critical)

---

### 13.2 Database Schema Support

**Tables exist:**

- ✅ `ingest_events` - Telemetry data
- ✅ `missing_intervals` - Missing packet tracking (schema exists, needs population logic)
- ✅ `error_logs` - Error logging
- ✅ `devices`, `sites`, `projects`, `customers` - Registry metadata

**Views exist:**

- ✅ `v_scada_latest` - Latest values
- ✅ `v_scada_history` - Historical data

---

### 13.3 Future Enhancements

**Phase 1.1 (Planned):**

- Implement monitoring API endpoints
- Add missing interval detection
- Add packet health calculation
- Add status calculation logic
- Add reporting interval configuration

**Phase 1.2 (Future):**

- Real-time monitoring dashboard
- Alert rules and notifications
- Historical trend analysis
- Predictive packet health

---

## 14. Next Steps

After understanding monitoring:

- **Module 9** - SCADA Integration Manual
  - Use monitoring data for SCADA integration
  - Configure SCADA health displays

- **Module 13** - Performance and Monitoring Manual
  - Advanced Prometheus configuration
  - Grafana dashboard customization
  - Alerting rules

- **Module 11** - Troubleshooting and Diagnostics Manual
  - Use monitoring data for troubleshooting
  - Diagnose packet health issues

---

**End of Module 8 – Monitoring API and Packet Health Manual**

**Related Modules:**

- Module 2 – System Architecture and DataFlow (monitoring architecture)
- Module 7 – Data Ingestion and Testing Manual (testing with monitoring)
- Module 9 – SCADA Integration Manual (SCADA monitoring integration)
- Module 13 – Performance and Monitoring Manual (advanced monitoring)

**Last Updated:** 2025-11-18

_NSReady Data Collection Platform Documentation Team_

