# Module 13 – Performance and Monitoring Manual

_NSReady Data Collection Platform_

*(Suggested path: `docs/13_Performance_and_Monitoring_Manual.md`)*

---

## 1. Introduction

NSReady is designed for high-performance industrial telemetry ingestion.

**This manual provides:**

- Performance benchmarks
- Required monitoring metrics
- Recommended Grafana dashboards
- NATS JetStream throughput tuning
- DB performance tuning (TimescaleDB)
- Scaling strategies
- Queue depth analysis
- Operations alerting
- Resource sizing guidelines

**This module is mandatory for production deployments.**

**Audience:**

DevOps engineers, operations teams, SCADA reliability engineers, NSWare backend team.

---

## 2. Performance Architecture Overview

The performance pipeline consists of:

```
Device → Collector → JetStream → Worker Pool → PostgreSQL/TimescaleDB → SCADA/Monitoring
```

**Each component affects performance:**

| Component | Key Impact |
|-----------|-----------|
| **Collector-Service** | API latency, queue input rate |
| **NATS JetStream** | Queue depth, throughput, buffering |
| **Worker Pool** | DB write throughput |
| **TimescaleDB** | Insert speed, compression, index load |
| **Kubernetes** | CPU/memory scheduling |
| **SCADA** | Query load |

**Performance Bottlenecks:**

1. **API Layer** - Request validation and NATS publish
2. **NATS Queue** - Message buffering and distribution
3. **Worker Processing** - Database write operations
4. **Database** - Insert performance and query load

---

## 3. Key Performance Metrics (Prometheus)

NSReady exposes performance-critical metrics through the `/metrics` endpoint.

### 3.1 Core Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `ingest_events_total{status="queued"}` | Counter | Total events queued |
| `ingest_events_total{status="success"}` | Counter | Total events successfully processed |
| `ingest_errors_total{error_type="..."}` | Counter | Count of ingestion pipeline errors |
| `ingest_queue_depth` | Gauge | JetStream queue depth (pending + ack_pending) |
| `ingest_consumer_pending` | Gauge | Pending messages in consumer |
| `ingest_consumer_ack_pending` | Gauge | Delivered but unacknowledged messages |
| `ingest_rate_per_second` | Gauge | Current ingestion rate (events per second) |
| `ingest_dlq_total{reason="..."}` | Counter | Total events sent to dead-letter queue |

**Note:** Additional metrics like `worker_db_commit_seconds` and `collector_request_latency_seconds` may be added in future versions.

### 3.2 Metric Access

**Endpoint:**

```
GET http://localhost:32001/metrics
GET http://localhost:8001/metrics  (Docker Compose)
```

**Example Output:**

```
# HELP ingest_events_total Total number of events ingested
# TYPE ingest_events_total counter
ingest_events_total{status="queued"} 1250
ingest_events_total{status="success"} 1245

# HELP ingest_errors_total Total number of ingestion errors
# TYPE ingest_errors_total counter
ingest_errors_total{error_type="integrity"} 2

# HELP ingest_queue_depth Current depth of the ingestion queue
# TYPE ingest_queue_depth gauge
ingest_queue_depth 5

# HELP ingest_consumer_pending Number of messages pending delivery for the ingest consumer
# TYPE ingest_consumer_pending gauge
ingest_consumer_pending 3

# HELP ingest_consumer_ack_pending Number of messages delivered but waiting for acknowledgment for the ingest consumer
# TYPE ingest_consumer_ack_pending gauge
ingest_consumer_ack_pending 2
```

---

## 4. Prometheus Setup

Prometheus is deployed under:

```
deploy/monitoring/prometheus.yaml
```

### 4.1 Scrape Targets

**Configured Targets:**

- `collector-service:8001/metrics`
- `admin-tool:8000/metrics`
- `prometheus:9090` (self-monitoring)

**Scrape Configuration:**

- **Scrape Interval:** 30 seconds
- **Evaluation Interval:** 30 seconds
- **Retention:** 30 days

### 4.2 Validate Prometheus is Running

**Check Service:**

```bash
kubectl get svc -n nsready-tier2 | grep prometheus
```

**Check Pods:**

```bash
kubectl get pods -n nsready-tier2 | grep prometheus
```

**Expected Output:**

```
prometheus-xxxxx   1/1     Running   0    5m
```

### 4.3 Access Prometheus UI

**Port-Forward:**

```bash
kubectl port-forward -n nsready-tier2 svc/prometheus 9090:9090
```

**Open Browser:**

```
http://localhost:9090
```

**Verify Targets:**

1. Navigate to **Status → Targets**
2. Verify all targets are **UP**
3. Check scrape errors (should be none)

---

## 5. Grafana Dashboard Setup

Grafana dashboards are stored in:

```
deploy/monitoring/grafana-dashboards/dashboard.json
```

### 5.1 Start Grafana

**Port-Forward:**

```bash
kubectl port-forward -n nsready-tier2 svc/grafana 3000:3000
```

**Default Login:**

- Username: `admin`
- Password: `admin` (change on first login)

**Access:**

```
http://localhost:3000
```

### 5.2 Import Dashboard

**Method 1: Import from File**

1. Navigate to **Dashboards → Import**
2. Upload `deploy/monitoring/grafana-dashboards/dashboard.json`
3. Select Prometheus data source
4. Click **Import**

**Method 2: Import via API**

```bash
curl -X POST http://admin:admin@localhost:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d @deploy/monitoring/grafana-dashboards/dashboard.json
```

---

## 6. Recommended Grafana Panels

Below are the recommended panels for NSReady monitoring.

### 6.1 Ingestion Throughput (events/sec)

**Panel Type:** Graph

**PromQL:**

```promql
rate(ingest_events_total{status="success"}[5m])
```

**Description:**

- Shows events successfully processed per second
- 5-minute rolling average
- Critical for capacity planning

**Alert Threshold:**

- Warning: < 10 events/sec (underutilized)
- Critical: > 500 events/sec (may need scaling)

---

### 6.2 Error Rate

**Panel Type:** Graph

**PromQL:**

```promql
rate(ingest_errors_total[5m])
```

**Alternative (Error Percentage):**

```promql
rate(ingest_errors_total[5m]) / rate(ingest_events_total[5m]) * 100
```

**Description:**

- Shows error rate over time
- Critical for reliability monitoring

**Alert Threshold:**

- Warning: > 0.1 errors/sec
- Critical: > 1 error/sec OR error rate > 1%

---

### 6.3 JetStream Queue Depth

**Panel Type:** Graph with Color Rules

**PromQL:**

```promql
ingest_queue_depth
```

**Color Rules:**

- **Green:** 0–5 (Normal)
- **Yellow:** 6–20 (Warning)
- **Red:** 21–100 (Critical)
- **Critical:** >100 (Overload)

**Description:**

- Real-time queue depth monitoring
- Critical for detecting backpressure

**Alert Threshold:**

- Warning: > 20 for 5 minutes
- Critical: > 100 for 2 minutes

---

### 6.4 Consumer Pending (JetStream)

**Panel Type:** Graph

**PromQL:**

```promql
ingest_consumer_pending
```

**Description:**

- Messages waiting to be delivered to workers
- Should be near 0 under normal load

**Alert Threshold:**

- Warning: > 10 for 5 minutes
- Critical: > 50 for 2 minutes

---

### 6.5 Consumer Ack Pending

**Panel Type:** Graph

**PromQL:**

```promql
ingest_consumer_ack_pending
```

**Description:**

- Messages delivered but not yet acknowledged
- High values indicate slow worker processing

**Alert Threshold:**

- Warning: > 50 for 5 minutes
- Critical: > 200 for 2 minutes

---

### 6.6 Ingestion Rate (Gauge)

**Panel Type:** Stat

**PromQL:**

```promql
ingest_rate_per_second
```

**Description:**

- Current ingestion rate (events per second)
- Real-time throughput indicator

---

### 6.7 P95 Latency (ms)

**Panel Type:** Graph

**PromQL:**

```promql
histogram_quantile(0.95, rate(ingest_events_total[5m]))
```

**Note:** This metric requires histogram instrumentation (may be added in future).

**Alternative (Estimated):**

Monitor queue depth and worker processing time separately.

**Alert Threshold:**

- Warning: > 500 ms
- Critical: > 1000 ms

---

### 6.8 Error Rate Percentage

**Panel Type:** Graph

**PromQL:**

```promql
rate(ingest_errors_total[5m]) / rate(ingest_events_total[5m]) * 100
```

**Description:**

- Error rate as percentage of total events
- More intuitive than absolute error count

**Alert Threshold:**

- Warning: > 0.1%
- Critical: > 1%

---

### 6.9 Dead-Letter Queue Count

**Panel Type:** Stat

**PromQL:**

```promql
ingest_dlq_total
```

**Description:**

- Total events sent to dead-letter queue
- Should be 0 under normal operation

**Alert Threshold:**

- Critical: > 0 (any DLQ events indicate serious issues)

---

## 7. Scaling Guidelines

Performance scales across four areas:

### 7.1 Collector-Service Scaling

**Collector is stateless** - can be scaled horizontally.

**Increase Replicas:**

```bash
kubectl scale deploy/collector-service --replicas=3 -n nsready-tier2
```

**Benefits:**

- Handle higher POST load
- Reduce ingest latency
- Better fault tolerance

**Recommended Replicas:**

- **Development:** 1 replica
- **Production (Low Load):** 2 replicas
- **Production (High Load):** 3-5 replicas

**Resource Requirements:**

- **CPU:** 250m request, 1000m limit per replica
- **Memory:** 512Mi request, 1Gi limit per replica

**Horizontal Pod Autoscaling (HPA):**

Configured in `deploy/k8s/hpa.yaml`:

- **Min Replicas:** 2
- **Max Replicas:** 10
- **Target CPU:** 70%
- **Target Memory:** 80%

---

### 7.2 Worker Pool Scaling

**Workers handle DB inserts** - scaling improves throughput.

**Method 1: Increase Deployment Replicas**

```bash
kubectl scale deploy/collector-service --replicas=5 -n nsready-tier2
```

**Note:** Each replica runs a worker pool (configured via `WORKER_POOL_SIZE`).

**Method 2: Configure Worker Pool Size**

**Via ConfigMap:**

```yaml
WORKER_POOL_SIZE: "4"
```

**Via Environment Variable:**

```bash
WORKER_POOL_SIZE=4
```

**Impact:**

- **Faster JetStream draining** - More workers process messages in parallel
- **Increased DB load** - More concurrent database writes
- **Better CPU utilization** - Utilizes multiple CPU cores

**Recommended Configuration:**

- **Development:** `WORKER_POOL_SIZE=1`
- **Production (Low Load):** `WORKER_POOL_SIZE=2-3`
- **Production (High Load):** `WORKER_POOL_SIZE=4-6`

**Trade-offs:**

- More workers = higher throughput but more database connections
- Monitor database connection pool size
- Ensure database can handle concurrent writes

---

### 7.3 NATS JetStream Scaling

**NATS is StatefulSet** - scaling requires careful configuration.

**Increase Resources:**

**Edit StatefulSet:**

```bash
kubectl edit statefulset nsready-nats -n nsready-tier2
```

**Increase CPU/Memory:**

```yaml
resources:
  requests:
    memory: "512Mi"
    cpu: "500m"
  limits:
    memory: "2Gi"
    cpu: "2000m"
```

**Increase Max Ack Pending:**

**Via NATS Configuration:**

```yaml
max_ack_pending: 2000  # Increase from default 1000
```

**Increase Storage Retention:**

**Via NATS Configuration:**

```yaml
max_age: 7d  # Increase retention period
```

**Storage Considerations:**

- **PVC Size:** Ensure sufficient storage for message retention
- **IOPS:** High-throughput requires high IOPS storage
- **Backup:** Consider backup strategy for JetStream data

---

### 7.4 Database Scaling

**TimescaleDB tuning** - critical for performance.

**Increase CPU:**

```bash
kubectl edit statefulset nsready-db -n nsready-tier2
```

**Increase Memory:**

```yaml
resources:
  requests:
    memory: "1Gi"
    cpu: "500m"
  limits:
    memory: "4Gi"
    cpu: "2000m"
```

**Enable Compression:**

See Section 9.1 for compression policy.

**Increase WAL Disk IOPS:**

- Use high-IOPS storage class
- Consider SSD storage for WAL

**Add Indexes Carefully:**

- Indexes improve query performance but slow inserts
- Only add indexes for frequently queried columns
- Monitor insert performance after adding indexes

**Connection Pooling:**

- Configure appropriate connection pool size
- Monitor active connections
- Avoid connection pool exhaustion

---

## 8. Worker Performance Tuning

### 8.1 Batch Size

**Configuration:**

```bash
WORKER_BATCH_SIZE=50
```

**Description:**

- Number of messages to batch before database insert
- Larger batch = faster throughput (fewer DB round-trips)

**Recommended Values:**

- **Development:** 10-20
- **Production (Low Load):** 50
- **Production (High Load):** 50-100

**Trade-offs:**

- **Larger batch:** Higher throughput, but higher latency for first message in batch
- **Smaller batch:** Lower latency, but more database round-trips

**Impact:**

- **50 messages/batch** = 50x fewer database round-trips
- Significant performance improvement

---

### 8.2 Batch Timeout

**Configuration:**

```bash
WORKER_BATCH_TIMEOUT=0.5
```

**Description:**

- Maximum wait time (seconds) for batch to fill before processing
- Lower timeout = lower latency

**Recommended Values:**

- **Development:** 0.2-0.5 seconds
- **Production (Low Load):** 0.5 seconds
- **Production (High Load):** 0.2-0.3 seconds

**Trade-offs:**

- **Lower timeout:** Lower latency, but smaller batches (more DB round-trips)
- **Higher timeout:** Larger batches (fewer DB round-trips), but higher latency

**Impact:**

- Batch processes when either:
  - Batch size is reached (`WORKER_BATCH_SIZE`)
  - Batch timeout expires (`WORKER_BATCH_TIMEOUT`)
  - Service is shutting down

---

### 8.3 Consumer Pull Batch

**Configuration:**

```bash
NATS_PULL_BATCH_SIZE=100
```

**Description:**

- Number of messages to pull from NATS per batch
- Larger batch = fewer NATS round-trips

**Recommended Values:**

- **Development:** 50-100
- **Production (Low Load):** 100
- **Production (High Load):** 100-200

**Trade-offs:**

- **Larger batch:** Fewer NATS round-trips, but more memory usage
- **Smaller batch:** More NATS round-trips, but lower memory usage

**Impact:**

- **100 messages/batch** = 100x fewer NATS round-trips
- Significant performance improvement

---

### 8.4 Worker Pool Size

**Configuration:**

```bash
WORKER_POOL_SIZE=4
```

**Description:**

- Number of parallel workers per collector-service pod
- More workers = higher throughput

**Recommended Values:**

- **Development:** 1-2
- **Production (Low Load):** 2-3
- **Production (High Load):** 4-6

**Trade-offs:**

- **More workers:** Higher throughput, but more database connections
- **Fewer workers:** Lower database load, but lower throughput

**Impact:**

- **4 workers** = 3-5x throughput improvement
- Better CPU utilization across cores

---

## 9. Database Performance Tuning

### 9.1 TimescaleDB Compression

**Purpose:**

- Reduce storage size for historical data
- Improve query performance on compressed data

**Enable Compression:**

```sql
-- Add compression policy (compress data older than 7 days)
SELECT add_compression_policy('ingest_events', INTERVAL '7 days');
```

**Verify Compression:**

```sql
-- Check compression status
SELECT 
  hypertable_name,
  compression_status,
  uncompressed_total_bytes,
  compressed_total_bytes
FROM timescaledb_information.hypertables
WHERE hypertable_name = 'ingest_events';
```

**Compression Settings:**

Configured in `db/migrations/120_timescale_hypertables.sql`:

```sql
ALTER TABLE ingest_events SET (
  timescaledb.compress,
  timescaledb.compress_segmentby = 'device_id,parameter_key'
);
```

**Benefits:**

- **Storage Reduction:** 70-90% reduction in storage size
- **Query Performance:** Faster queries on compressed data
- **Cost Savings:** Lower storage costs

---

### 9.2 Retention Policy

**Purpose:**

- Automatically remove old data
- Prevent unbounded storage growth

**Add Retention Policy:**

```sql
-- Remove data older than 90 days
SELECT add_retention_policy('ingest_events', INTERVAL '90 days');
```

**Verify Retention:**

```sql
-- Check retention policies
SELECT * FROM timescaledb_information.jobs
WHERE proc_name = 'policy_retention';
```

**Recommended Retention:**

- **Development:** 30 days
- **Production (Low Volume):** 90 days
- **Production (High Volume):** 30-60 days (adjust based on storage)

**Considerations:**

- Ensure SCADA systems have exported data before retention
- Consider archiving before deletion
- Monitor storage usage

---

### 9.3 Indexing

**Critical Indexes:**

Already created in `db/migrations/110_telemetry.sql`:

```sql
-- Device/parameter/time index (most important)
CREATE INDEX idx_ingest_events_device_param_time_desc
  ON ingest_events (device_id, parameter_key, time DESC);

-- Event ID index (for idempotency)
CREATE UNIQUE INDEX uq_ingest_event_id
  ON ingest_events (device_id, event_id)
  WHERE event_id IS NOT NULL;
```

**Additional Indexes (if needed):**

```sql
-- Time-only index (for time-range queries)
CREATE INDEX idx_ingest_events_time_desc
  ON ingest_events (time DESC);

-- Device-only index (for device queries)
CREATE INDEX idx_ingest_events_device_id
  ON ingest_events (device_id);
```

**Index Maintenance:**

```sql
-- Analyze tables regularly
ANALYZE ingest_events;

-- Vacuum if needed (PostgreSQL handles automatically)
VACUUM ANALYZE ingest_events;
```

**Trade-offs:**

- **More indexes:** Faster queries, but slower inserts
- **Fewer indexes:** Faster inserts, but slower queries
- **Monitor:** Check insert performance after adding indexes

---

### 9.4 Connection Pooling

**Configuration:**

Configured in `collector_service/core/db.py`:

```python
# Async connection pool settings
pool_size=10
max_overflow=20
```

**Monitor Connections:**

```sql
-- Check active connections
SELECT 
  count(*) as total_connections,
  state,
  application_name
FROM pg_stat_activity
WHERE datname = 'nsready'
GROUP BY state, application_name;
```

**Tuning:**

- **Increase pool_size** if seeing connection pool exhaustion
- **Monitor max_overflow** to detect connection spikes
- **Adjust based on worker pool size** (more workers = more connections)

---

## 10. Performance Benchmarks

Below are validated performance numbers from testing.

### 10.1 Collector Throughput

**Test Configuration:**

- **Concurrent Users:** 50 (Locust)
- **Duration:** 60 seconds
- **Ramp-up Rate:** 5 users/second

**Results:**

| Metric | Target | Achieved | Status |
|--------|--------|----------|--------|
| **Throughput** | 12-15 events/sec | **262.38 events/sec** | ✅ **67× target** |
| **Average Latency** | 4-6 seconds | **23.64 ms** | ✅ **169× better** |
| **P95 Latency** | 4-6 seconds | **220 ms** | ✅ **18× better** |
| **Error Rate** | 0% | **0.00%** | ✅ **Maintained** |
| **Queue Depth** | Near 0 | **0 (stable)** | ✅ **Achieved** |

**Endpoint-Specific Performance:**

**Single Metric Event:**

- Throughput: 61.24 req/s
- Average Latency: 28 ms
- P95 Latency: 220 ms
- P99 Latency: 320 ms

**Multiple Metrics Event:**

- Throughput: 19.69 req/s
- Average Latency: 29.79 ms
- P95 Latency: 220 ms
- P99 Latency: 350 ms

---

### 10.2 Worker Throughput

**Database Commit Latency:**

- **Average:** 8-30 ms
- **P95:** < 50 ms
- **P99:** < 100 ms

**End-to-End Latency:**

- **Average:** 23 ms
- **P95:** 220 ms
- **P99:** 350 ms

**Throughput:**

- **Sustained:** 262 events/sec
- **Peak:** 300+ events/sec

---

### 10.3 Queue Stability

**Queue Depth:**

- **Under Load:** 0-3 messages
- **Stable:** Consistently near 0
- **No Backlog:** Queue drains faster than ingestion rate

**Redelivery:**

- **Redelivered Messages:** 0
- **No Failures:** All messages processed successfully

**Consumer Stats:**

- **Pending:** 0 (stable)
- **Ack Pending:** 0-2 (minimal)
- **Waiting Pulls:** 0

---

### 10.4 Performance Optimization Impact

**Optimizations Applied:**

1. **Worker Pool (4 workers)** - 3-5x throughput improvement
2. **Batch DB Inserts (50 msg/batch)** - 50x fewer DB round-trips
3. **JetStream Pull Batching (100 msg/batch)** - 100x fewer NATS round-trips

**Combined Effect:**

- **67× target throughput** (262.38 vs 12-15 req/s)
- **169× better latency** (23.64 ms vs 4-6 seconds)
- **Perfect reliability** (0% error rate)

---

## 11. Alerting Rules (Recommended)

Below rules should be implemented via Alertmanager.

### 11.1 Queue Depth > 20

**Alert Rule:**

```yaml
- alert: HighQueueDepth
  expr: ingest_queue_depth > 20
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "High queue depth detected"
    description: "Queue depth is {{ $value }} messages (threshold: 20)"
```

**Severity:** Warning

**Action:** Monitor closely, check worker logs

---

### 11.2 Queue Depth > 100

**Alert Rule:**

```yaml
- alert: CriticalQueueDepth
  expr: ingest_queue_depth > 100
  for: 2m
  labels:
    severity: critical
  annotations:
    summary: "Critical queue depth - system overload"
    description: "Queue depth is {{ $value }} messages (threshold: 100). Scale workers immediately."
```

**Severity:** Critical

**Action:** Scale workers immediately

---

### 11.3 Error Rate > 1/sec

**Alert Rule:**

```yaml
- alert: HighErrorRate
  expr: rate(ingest_errors_total[5m]) > 1
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "High error rate detected"
    description: "Error rate is {{ $value }} errors/sec (threshold: 1)"
```

**Severity:** Critical

**Action:** Check error logs, investigate root cause

---

### 11.4 Error Rate Percentage > 1%

**Alert Rule:**

```yaml
- alert: HighErrorPercentage
  expr: (rate(ingest_errors_total[5m]) / rate(ingest_events_total[5m])) * 100 > 1
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "High error percentage detected"
    description: "Error rate is {{ $value }}% of total events (threshold: 1%)"
```

**Severity:** Critical

**Action:** Check error logs, investigate root cause

---

### 11.5 Worker DB Latency > 0.5s

**Alert Rule:**

```yaml
- alert: HighWorkerLatency
  expr: worker_db_commit_seconds > 0.5
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "High worker DB latency"
    description: "Worker DB commit latency is {{ $value }}s (threshold: 0.5s)"
```

**Note:** This metric requires histogram instrumentation (may be added in future).

**Severity:** Warning

**Action:** Check database performance, consider scaling

---

### 11.6 Service Down

**Alert Rule:**

```yaml
- alert: ServiceDown
  expr: up{job=~"admin-tool|collector-service"} == 0
  for: 2m
  labels:
    severity: critical
  annotations:
    summary: "Service is down"
    description: "{{ $labels.job }} is down for more than 2 minutes"
```

**Severity:** Critical

**Action:** Check pod status, restart if needed

---

### 11.7 Database Connection Failure

**Alert Rule:**

```yaml
- alert: DatabaseConnectionFailure
  expr: db_status{status="disconnected"} == 1
  for: 1m
  labels:
    severity: critical
  annotations:
    summary: "Database connection failure"
    description: "Database connection is down"
```

**Note:** This metric requires database status metric (may be added in future).

**Severity:** Critical

**Action:** Check database pod, verify connectivity

---

### 11.8 No Packets from Site for > 1 hour

**Alert Rule:**

```yaml
- alert: NoPacketsFromSite
  expr: |
    (time() - last_packet_timestamp{site_id="<site_id>"}) > 3600
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "No packets from site"
    description: "Site {{ $labels.site_id }} has not sent packets for {{ $value }} seconds"
```

**Note:** This requires monitoring API implementation (Module 8).

**Severity:** Warning

**Action:** Check device connectivity, investigate site issues

---

## 12. SCADA Performance Considerations

### 12.1 Use Materialized Views for Large Datasets

**Materialized View for Latest Values:**

```sql
CREATE MATERIALIZED VIEW mv_scada_latest_readable AS
SELECT 
  d.name AS device_name,
  d.external_id AS device_code,
  pt.name AS parameter_name,
  pt.unit,
  v.time,
  v.value,
  v.quality
FROM v_scada_latest v
JOIN devices d ON d.id = v.device_id
JOIN parameter_templates pt ON pt.key = v.parameter_key;

-- Create index for fast queries
CREATE INDEX idx_mv_scada_latest_device ON mv_scada_latest_readable(device_code);

-- Refresh periodically (via cron or scheduled job)
REFRESH MATERIALIZED VIEW mv_scada_latest_readable;
```

**Benefits:**

- Faster queries (pre-computed joins)
- Reduced database load
- Better SCADA performance

**Refresh Strategy:**

- **Real-time:** Refresh every 1-5 minutes
- **Near real-time:** Refresh every 5-15 minutes
- **Batch:** Refresh hourly (if acceptable latency)

---

### 12.2 Limit Queries with Date Filters

**Always Filter by Time Range:**

```sql
-- Good: Filtered query
SELECT * FROM v_scada_history
WHERE device_id = '<device_uuid>'
  AND time > NOW() - INTERVAL '24 hours'
ORDER BY time DESC;

-- Bad: Full table scan
SELECT * FROM v_scada_history
WHERE device_id = '<device_uuid>'
ORDER BY time DESC;
```

**Benefits:**

- Faster queries (uses time index)
- Reduced database load
- Better SCADA performance

**Recommended Time Ranges:**

- **Latest Values:** No filter needed (use `v_scada_latest`)
- **Recent History:** `NOW() - INTERVAL '24 hours'`
- **Historical Analysis:** `NOW() - INTERVAL '7 days'` (or specific date range)

---

### 12.3 Optimize SCADA Query Patterns

**Pattern 1: Latest Values (Most Common)**

```sql
-- Use materialized view
SELECT * FROM mv_scada_latest_readable
WHERE device_code = 'DEV001';
```

**Pattern 2: Historical Data**

```sql
-- Use time-filtered query
SELECT * FROM v_scada_history
WHERE device_id = '<device_uuid>'
  AND parameter_key = 'project:...:voltage'
  AND time BETWEEN '2025-11-18T00:00:00Z' AND '2025-11-18T23:59:59Z'
ORDER BY time DESC;
```

**Pattern 3: Aggregated Data**

```sql
-- Use TimescaleDB continuous aggregates (future feature)
SELECT 
  time_bucket('1 hour', time) AS hour,
  AVG(value) AS avg_value,
  MIN(value) AS min_value,
  MAX(value) AS max_value
FROM ingest_events
WHERE device_id = '<device_uuid>'
  AND time > NOW() - INTERVAL '7 days'
GROUP BY hour
ORDER BY hour DESC;
```

---

## 13. Operator Checklists

### 13.1 Daily Checklist

**Performance Monitoring:**

- [ ] Queue depth < 5 (check Grafana dashboard)
- [ ] No critical errors (check error rate panel)
- [ ] Worker latency stable (check latency graphs)
- [ ] SCADA reading correct values (verify latest values)

**Health Checks:**

- [ ] All pods running (check `kubectl get pods`)
- [ ] Prometheus targets UP (check Prometheus UI)
- [ ] Database connections healthy (check connection pool)
- [ ] NATS JetStream healthy (check queue depth)

**Quick Commands:**

```bash
# Check queue depth
curl -s http://localhost:32001/v1/health | jq .queue_depth

# Check pod status
kubectl get pods -n nsready-tier2

# Check Prometheus targets
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.health=="up")'
```

---

### 13.2 Weekly Checklist

**Maintenance:**

- [ ] Vacuum/Analyze run (if needed, PostgreSQL handles automatically)
- [ ] Export registry (backup configuration)
- [ ] Check error logs (review `error_logs` table)
- [ ] Review performance metrics (check Grafana trends)

**Database:**

- [ ] Check database size (monitor storage usage)
- [ ] Verify compression working (check compression status)
- [ ] Review retention policy (ensure old data being removed)
- [ ] Check index usage (verify indexes are being used)

**Quick Commands:**

```bash
# Export registry
./scripts/export_registry_data.sh

# Check database size
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c \
  "SELECT pg_size_pretty(pg_database_size('nsready'));"

# Check error logs
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c \
  "SELECT COUNT(*) FROM error_logs WHERE time > NOW() - INTERVAL '7 days';"
```

---

### 13.3 Monthly Checklist

**Performance Review:**

- [ ] TimescaleDB compression reviewed (verify compression ratio)
- [ ] Storage usage within limits (check storage growth)
- [ ] Performance benchmarks run (compare with baseline)
- [ ] Scaling needs assessed (review capacity planning)

**Configuration Review:**

- [ ] Worker pool size optimized (adjust if needed)
- [ ] Batch sizes optimized (adjust if needed)
- [ ] Alert thresholds reviewed (adjust based on trends)
- [ ] Resource limits reviewed (adjust if needed)

**Documentation:**

- [ ] Performance metrics documented (update benchmarks)
- [ ] Scaling procedures documented (update runbooks)
- [ ] Incident reports reviewed (learn from issues)

**Quick Commands:**

```bash
# Check compression status
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c \
  "SELECT * FROM timescaledb_information.hypertables WHERE hypertable_name = 'ingest_events';"

# Check storage usage
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c \
  "SELECT pg_size_pretty(pg_total_relation_size('ingest_events'));"
```

---

## 14. Resource Sizing Guidelines

### 14.1 Development Environment

**Collector-Service:**

- **Replicas:** 1
- **CPU:** 250m request, 500m limit
- **Memory:** 256Mi request, 512Mi limit
- **Worker Pool:** 1-2 workers

**Database:**

- **CPU:** 250m request, 1000m limit
- **Memory:** 512Mi request, 2Gi limit
- **Storage:** 10Gi

**NATS:**

- **CPU:** 100m request, 500m limit
- **Memory:** 256Mi request, 1Gi limit
- **Storage:** 5Gi

---

### 14.2 Production Environment (Low Load)

**Collector-Service:**

- **Replicas:** 2
- **CPU:** 250m request, 1000m limit per replica
- **Memory:** 512Mi request, 1Gi limit per replica
- **Worker Pool:** 2-3 workers per replica

**Database:**

- **CPU:** 500m request, 2000m limit
- **Memory:** 1Gi request, 4Gi limit
- **Storage:** 50Gi (with compression)

**NATS:**

- **CPU:** 250m request, 1000m limit
- **Memory:** 512Mi request, 2Gi limit
- **Storage:** 20Gi

---

### 14.3 Production Environment (High Load)

**Collector-Service:**

- **Replicas:** 3-5 (with HPA)
- **CPU:** 250m request, 1000m limit per replica
- **Memory:** 512Mi request, 1Gi limit per replica
- **Worker Pool:** 4-6 workers per replica

**Database:**

- **CPU:** 1000m request, 4000m limit
- **Memory:** 2Gi request, 8Gi limit
- **Storage:** 200Gi (with compression)

**NATS:**

- **CPU:** 500m request, 2000m limit
- **Memory:** 1Gi request, 4Gi limit
- **Storage:** 50Gi

---

## 15. Time-Series Modeling Strategy (NS-TS-GUARDRAIL)

NSReady uses a **narrow ingest model** via `ingest_events`  
(one row per `(time, device_id, parameter_key, value, quality, source, ...)`).

> **Decision:**  
> - We will **keep `ingest_events` narrow and append-only** for performance and retention.  
> - For read-heavy workloads (dashboards, SCADA, AI baselines), we will use  
>   continuous aggregates and/or materialized views built on top of `ingest_events`,  
>   such as per-site or per-project rollup views (1m/5m/hourly).

This hybrid approach lets us:

- Maintain high ingest performance,
- Optimize for key dashboard slices,
- Avoid schema churn or wide tables for every new metric.

### 15.1 Time-Series Rollup Plan (NS-TS-FUTURE)

NSReady uses `ingest_events` as the canonical narrow ingest table.  
For long-term performance and analytics/AI, we will introduce continuous aggregates and/or materialized views:

- **1-minute rollups** for short-term analysis (7–90 days)
- **5–15 minute rollups** for medium-term trends
- **Hourly rollups** for long-term dashboards and AI feature baselines

**Retention concept:**
- `ingest_events` raw: keep 7–30 days (depending on load)
- 1-minute aggregates: keep ~90 days
- Hourly aggregates: keep ~13 months or more
- Cold history: archive to Parquet (S3/MinIO) when needed

> **NOTE (NS-TS-AI-FRIENDLY):**  
> This layered model ensures we don't overload the raw table with long-term reads,  
> and that AI/ML features can use rollups efficiently without changing ingestion.

> **NOTE (NS-TS-DASHBOARD-GUARDRAIL):**  
> For long time ranges (weeks/months), dashboards should query rollup or materialized views,  
> not `ingest_events` directly. This avoids performance issues and keeps the system scalable.

### 15.2 Tenant Context for AI/Monitoring (NS-TENANT-03)

All AI feature stores, model registries, monitoring summaries, and alert rules  
are expected to operate per tenant.

- `tenant_id = customer_id`

This ensures SCADA, dashboards, and AI/ML behaviour can be reasoned about  
and debugged per customer, and prevents accidental cross-customer leakage  
in multi-customer deployments.

**For tenant model details, see:**
- **TENANT_MODEL_SUMMARY.md** – Quick reference for AI/monitoring tenant rules
- **TENANT_DECISION_RECORD.md** – Architecture Decision Record (ADR-003)

---

## 16. Next Steps

After understanding performance and monitoring:

- **Module 8** - Monitoring API and Packet Health Manual
  - Packet health calculations
  - Monitoring API endpoints

- **Module 11** - Troubleshooting and Diagnostics Manual
  - Performance troubleshooting
  - Diagnostic procedures

- **Module 12** - API Developer Manual
  - API performance considerations
  - Integration best practices

---

**End of Module 13 – Performance and Monitoring Manual**

**Related Modules:**

- Module 8 – Monitoring API and Packet Health Manual (monitoring endpoints)
- Module 11 – Troubleshooting and Diagnostics Manual (performance troubleshooting)
- Module 12 – API Developer Manual (API performance)

**Last Updated:** 2025-11-18

_NSReady Data Collection Platform Documentation Team_

