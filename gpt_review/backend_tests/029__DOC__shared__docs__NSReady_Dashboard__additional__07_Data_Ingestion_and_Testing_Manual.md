# Module 7 – Data Ingestion and Testing Manual

_NSReady Data Collection Platform_

*(Suggested path: `docs/07_Data_Ingestion_and_Testing_Manual.md`)*

---

## 1. Introduction

This module explains how to test end-to-end data ingestion in the NSReady Data Collection Platform.

It covers:

- NormalizedEvent JSON format
- How to simulate data from your Mac (acting as a device/logger)
- How the collector-service processes incoming data
- How NATS queues events
- How the worker stores data in PostgreSQL
- How SCADA sees the data
- How to monitor health, queue depth, and worker behaviour

This is the core functional test of NSReady.

---

## 2. End-to-End Data Flow

```
Simulated Data (Mac / JSON)
          |
          v
Collector-Service  (/v1/ingest)
          |
          v
       NATS JetStream
          |
          v
  Worker Pool (pull consumers)
          |
          v
PostgreSQL (TimescaleDB)
          |
          v
SCADA Views (v_scada_latest / history)
```

We validate every step.

---

## 3. The NormalizedEvent Format (Official)

Every ingestion message must follow the NSReady v1.0 schema:

```json
{
  "project_id": "UUID",
  "site_id": "UUID",
  "device_id": "UUID",
  "protocol": "GPRS",
  "source_timestamp": "2025-11-14T12:00:00Z",
  "metrics": [
    {
      "parameter_key": "project:8212caa2-b928-4213-b64e-9f5b86f4cad1:voltage",
      "value": 230.5,
      "quality": 192,
      "attributes": {
        "unit": "V"
      }
    },
    {
      "parameter_key": "project:8212caa2-b928-4213-b64e-9f5b86f4cad1:current",
      "value": 10.2,
      "quality": 192,
      "attributes": {
        "unit": "A"
      }
    }
  ],
  "config_version": "v1.0",
  "event_id": "optional-unique-id",
  "metadata": {}
}
```

### Required Fields

- `project_id` (UUID string)
- `site_id` (UUID string)
- `device_id` (UUID string)
- `protocol` (string: "SMS", "GPRS", "HTTP")
- `source_timestamp` (ISO 8601 datetime string with 'Z' suffix)
- `metrics[]` (array with at least one metric)

### Optional Fields

- `config_version` (string)
- `event_id` (string, for idempotency)
- `metadata` (object)

> ⚠️ **NOTE (DB & AI CONSISTENCY):**  
> All `parameter_key` values in real ingestion MUST use the full canonical format  
> `project:<project_uuid>:<parameter_name_lowercase_with_underscores>`.  
> Short-form keys like `"voltage"` or `"current"` were used in early drafts for readability,  
> but are **invalid** and will cause foreign-key errors in the database  
> and will break future AI/ML and analytics pipelines that rely on stable parameter identifiers.

> **NOTE (NS-AI-FEATURES-FUTURE):**  
> In this phase we validate ingestion and SCADA directly from `ingest_events` and SCADA views.  
> When NSWare AI modules are introduced, they will build additional feature tables on top of this data  
> without changing the ingestion contract or SCADA views.

> **NOTE (NS-TENANT-INGESTION):**  
> All ingestion requests implicitly belong to a **tenant**,  
> defined by the `customer_id` of the corresponding `project_id → site_id → device_id`.  
>  
> > **Tenant = Customer**  
> > (tenant_id = customer_id)  
>  
> This allows:  
> - per-tenant ingestion isolation  
> - per-tenant SCADA mapping  
> - per-tenant AI/ML feature routing  
> - zero schema changes in future NSWare versions  
>  
> Nothing additional is required from devices or loggers.

**For tenant model details, see:**
- **TENANT_MODEL_SUMMARY.md** – Quick reference for ingestion tenant rules
- **TENANT_MODEL_DIAGRAM.md** – Visual data flow diagrams

### Each Metric Requires

- `parameter_key` (string - exact key from `parameter_templates`)
- `value` (number, optional)
- `quality` (integer, 0-255, defaults to 0)
- `attributes` (object, optional - can contain `unit` and other metadata)

**Important Notes:**

- `parameter_key` must match exactly with keys in `parameter_templates` table
- `unit` is stored inside `attributes`, not as a top-level field
- `quality` code 192 means "good quality" (typical for production)
- `source_timestamp` must be ISO 8601 format: `YYYY-MM-DDTHH:MM:SSZ`

---

## 4. Get the Required IDs Before Testing

### 4.1 Get project/site/device IDs

**For Kubernetes:**

```bash
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "
SELECT 
  c.name AS customer, 
  p.name AS project, 
  p.id AS project_id,
  s.name AS site, 
  s.id AS site_id,
  d.name AS device, 
  d.id AS device_id,
  d.external_id AS device_code
FROM devices d
JOIN sites s ON s.id = d.site_id
JOIN projects p ON p.id = s.project_id
JOIN customers c ON c.id = p.customer_id
ORDER BY c.name, p.name, s.name, d.name
LIMIT 20;"
```

**For Docker Compose:**

```bash
docker exec nsready_db psql -U postgres -d nsready -c "
SELECT 
  c.name AS customer, 
  p.name AS project, 
  p.id AS project_id,
  s.name AS site, 
  s.id AS site_id,
  d.name AS device, 
  d.id AS device_id,
  d.external_id AS device_code
FROM devices d
JOIN sites s ON s.id = d.site_id
JOIN projects p ON p.id = s.project_id
JOIN customers c ON c.id = p.customer_id
ORDER BY c.name, p.name, s.name, d.name
LIMIT 20;"
```

### 4.2 Get parameter keys

**For Kubernetes:**

```bash
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "
SELECT key, name, unit 
FROM parameter_templates 
WHERE metadata->>'project_id' = '<PROJECT_ID_HERE>'
ORDER BY name;"
```

**For Docker Compose:**

```bash
docker exec nsready_db psql -U postgres -d nsready -c "
SELECT key, name, unit 
FROM parameter_templates 
WHERE metadata->>'project_id' = '<PROJECT_ID_HERE>'
ORDER BY name;"
```

### 4.3 Capture Required IDs

- `project_id` (UUID)
- `site_id` (UUID)
- `device_id` (UUID)
- `parameter_key` values (strings, e.g., "voltage", "current", "power")

These must be used in your JSON test input.

---

## 5. Create Your Test JSON File (on Mac)

Create a file: `test_event.json`

**Example:**

```json
{
  "project_id": "8212caa2-b928-4213-b64e-9f5b86f4cad1",
  "site_id": "89a66770-bdcc-4c95-ac97-e1829cb7a960",
  "device_id": "bc2c5e47-f17e-46f0-b5e7-76b214f4f6ad",
  "protocol": "GPRS",
  "source_timestamp": "2025-11-14T12:00:00Z",
  "metrics": [
    {
      "parameter_key": "project:8212caa2-b928-4213-b64e-9f5b86f4cad1:voltage",
      "value": 230.5,
      "quality": 192,
      "attributes": {
        "unit": "V"
      }
    },
    {
      "parameter_key": "project:8212caa2-b928-4213-b64e-9f5b86f4cad1:current",
      "value": 10.2,
      "quality": 192,
      "attributes": {
        "unit": "A"
      }
    },
    {
      "parameter_key": "project:8212caa2-b928-4213-b64e-9f5b86f4cad1:power",
      "value": 2455.8,
      "quality": 192,
      "attributes": {
        "unit": "W"
      }
    }
  ],
  "config_version": "v1.0",
  "event_id": "test-001-20251114-120000",
  "metadata": {}
}
```

**Or use the sample file:**

```bash
cp collector_service/tests/sample_event.json test_event.json
# Then edit the IDs in test_event.json
```

**Or use the generated test file:**

```bash
cp test_nsready_event.json test_event.json
```

Replace the IDs accordingly.

---

## 6. Send the JSON to the Collector (Copy–Paste Command)

### 6.1 For Kubernetes (NodePort)

**If you have NodePort configured (port 32001):**

```bash
curl -X POST http://localhost:32001/v1/ingest \
  -H "Content-Type: application/json" \
  -d @test_event.json
```

### 6.2 For Kubernetes (Port-Forward)

**Set up port-forward first:**

```bash
# Terminal 1: Start port-forward (leave running)
kubectl port-forward -n nsready-tier2 svc/collector-service 8001:8001

# Terminal 2: Send event
curl -X POST http://localhost:8001/v1/ingest \
  -H "Content-Type: application/json" \
  -d @test_event.json
```

### 6.3 For Docker Compose

```bash
curl -X POST http://localhost:8001/v1/ingest \
  -H "Content-Type: application/json" \
  -d @test_event.json
```

**Expected Response:**

```json
{"status":"queued","trace_id":"abc123-def456-..."}
```

If you see `"queued"` → collector validated your data.

> **NOTE (NS-AI-TRACEABILITY):**  
> The `trace_id` returned by `/v1/ingest` and logged by workers is intended to support  
> future AI/ML experiment tracking and debugging.  
> It allows linking an external request, the stored events, and future model scores.

**Error Responses:**

```json
{"detail":"device_id must be a valid UUID: invalid-id"}
```

```json
{"detail":"metrics array must contain at least one metric"}
```

---

## 7. Validate Collector-Service Health

**For Kubernetes (NodePort):**

```bash
curl http://localhost:32001/v1/health
```

**For Kubernetes (Port-Forward) or Docker Compose:**

```bash
curl http://localhost:8001/v1/health
```

**Expected Response:**

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

**Interpretation:**

- `service: "ok"` → Collector service is running
- `queue_depth: 0` → No messages waiting (or processing complete)
- `db: "connected"` → Database connection is healthy
- `pending: 0` → No unprocessed messages
- `ack_pending: 0` → No messages being processed

**If `queue_depth > 0`:**

- Worker is still processing messages
- Wait a few seconds and check again
- Check worker logs if it stays high

---

## 8. Validate NATS JetStream Queue

### 8.1 Check NATS consumer (Kubernetes)

**Using NATS CLI (if installed):**

```bash
kubectl exec -n nsready-tier2 nsready-nats-0 -- \
  nats consumer info INGRESS ingest_workers
```

**Expected output:**

```
Outstanding Acks: 0
Unprocessed Messages: 0
```

**Using kubectl exec:**

```bash
kubectl exec -n nsready-tier2 nsready-nats-0 -- \
  sh -c "nats consumer info INGRESS ingest_workers || echo 'NATS CLI not available'"
```

**Check via health endpoint:**

```bash
curl http://localhost:8001/v1/health | jq '.queue'
```

### 8.2 If messages pending

If `pending > 0` or `ack_pending > 0`:

- Worker is still processing
- Check worker logs
- Wait a few seconds and check again

**If messages stay pending:**

- Worker may be stuck
- Check worker logs for errors
- Restart worker if needed

---

## 9. Validate Worker Processing

### 9.1 Follow worker logs

**For Kubernetes:**

```bash
kubectl logs -n nsready-tier2 -l app=collector-service -f | grep -E "(DB commit|Worker|inserted)"
```

**For Docker Compose:**

```bash
docker logs -f collector_service | grep -E "(DB commit|Worker|inserted)"
```

**Expected log lines:**

```
[Worker-0] DB commit OK → acked 3 messages
[Worker-1] inserting 5 events into database
[Worker-2] DB commit OK → acked 2 messages
```

**This confirms:**

- Message pulled from NATS
- Event parsed successfully
- Data inserted into database
- Transaction committed
- NATS ack sent

### 9.2 Check for errors

**For Kubernetes:**

```bash
kubectl logs -n nsready-tier2 -l app=collector-service --tail=100 | grep -i error
```

**For Docker Compose:**

```bash
docker logs collector_service --tail=100 | grep -i error
```

**Common errors:**

- `batch insert failed` → Database issue
- `invalid parameter_key` → Parameter template missing
- `device_id not found` → Device doesn't exist in registry

---

## 10. Validate Database Storage

### 10.1 Count events

**For Kubernetes:**

```bash
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "SELECT COUNT(*) FROM ingest_events;"
```

**For Docker Compose:**

```bash
docker exec nsready_db psql -U postgres -d nsready -c "SELECT COUNT(*) FROM ingest_events;"
```

**Expected:** Count increases after each test ingestion.

### 10.2 Check latest data

**For Kubernetes:**

```bash
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "
SELECT 
  device_id, 
  parameter_key,
  time AS source_timestamp, 
  created_at AS received_timestamp,
  value,
  quality,
  source AS protocol
FROM ingest_events
ORDER BY created_at DESC
LIMIT 10;"
```

**For Docker Compose:**

```bash
docker exec nsready_db psql -U postgres -d nsready -c "
SELECT 
  device_id, 
  parameter_key,
  time AS source_timestamp, 
  created_at AS received_timestamp,
  value,
  quality,
  source AS protocol
FROM ingest_events
ORDER BY created_at DESC
LIMIT 10;"
```

**Make sure:**

- Timestamps correct (source_timestamp matches your JSON, created_at is recent)
- `device_id` matches your test JSON
- `parameter_key` matches your metrics
- `value` matches your test data
- `quality` = 192 (if you used 192 in JSON)

### 10.3 Verify specific device/parameter

**For Kubernetes:**

```bash
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "
SELECT 
  d.name AS device_name,
  pt.name AS parameter_name,
  e.time,
  e.value,
  e.quality
FROM ingest_events e
JOIN devices d ON d.id = e.device_id
JOIN parameter_templates pt ON pt.key = e.parameter_key
WHERE e.device_id = '<YOUR_DEVICE_ID>'
ORDER BY e.time DESC
LIMIT 10;"
```

---

## 11. Validate SCADA Visibility

### 11.1 If SCADA uses file import

**Export latest values:**

```bash
# For Kubernetes
./scripts/export_scada_data_readable.sh --latest --format txt

# For Docker Compose (if script supports it)
USE_KUBECTL=false ./scripts/export_scada_data_readable.sh --latest --format txt
```

**Check file under:**

```
reports/scada_latest_readable_*.txt
```

**Verify your test data appears:**

```bash
grep -i "voltage\|current\|power" reports/scada_latest_readable_*.txt
```

### 11.2 If SCADA uses DB read-only

**Query latest values:**

**For Kubernetes:**

```bash
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U scada_reader -d nsready -c "
SELECT 
  d.name AS device_name,
  pt.name AS parameter_name,
  v.time,
  v.value,
  v.quality
FROM v_scada_latest v
JOIN devices d ON d.id = v.device_id
JOIN parameter_templates pt ON pt.key = v.parameter_key
ORDER BY v.time DESC
LIMIT 10;"
```

**Expected:**

- Latest values for each parameter
- Quality field = 192 (if you used 192)
- Recent timestamps
- Correct device/parameter names

---

## 12. Bulk Simulation Testing

To simulate multiple packets like a real modem:

### 12.1 Create bulk events file (JSON Lines format)

Create `bulk_events.jsonl`:

```jsonl
{"project_id":"8212caa2-b928-4213-b64e-9f5b86f4cad1","site_id":"89a66770-bdcc-4c95-ac97-e1829cb7a960","device_id":"bc2c5e47-f17e-46f0-b5e7-76b214f4f6ad","protocol":"GPRS","source_timestamp":"2025-11-14T12:00:00Z","metrics":[{"parameter_key":"project:8212caa2-b928-4213-b64e-9f5b86f4cad1:voltage","value":230.5,"quality":192,"attributes":{"unit":"V"}}]}
{"project_id":"8212caa2-b928-4213-b64e-9f5b86f4cad1","site_id":"89a66770-bdcc-4c95-ac97-e1829cb7a960","device_id":"bc2c5e47-f17e-46f0-b5e7-76b214f4f6ad","protocol":"GPRS","source_timestamp":"2025-11-14T12:01:00Z","metrics":[{"parameter_key":"project:8212caa2-b928-4213-b64e-9f5b86f4cad1:voltage","value":231.0,"quality":192,"attributes":{"unit":"V"}}]}
{"project_id":"8212caa2-b928-4213-b64e-9f5b86f4cad1","site_id":"89a66770-bdcc-4c95-ac97-e1829cb7a960","device_id":"bc2c5e47-f17e-46f0-b5e7-76b214f4f6ad","protocol":"GPRS","source_timestamp":"2025-11-14T12:02:00Z","metrics":[{"parameter_key":"project:8212caa2-b928-4213-b64e-9f5b86f4cad1:voltage","value":229.8,"quality":192,"attributes":{"unit":"V"}}]}
```

### 12.2 Replay using loop

**For Kubernetes (NodePort 32001):**

```bash
cat bulk_events.jsonl | while read line; do
  curl -X POST http://localhost:32001/v1/ingest \
    -H "Content-Type: application/json" \
    -d "$line"
  sleep 0.1  # Small delay between requests
done
```

**For Kubernetes (Port-Forward) or Docker Compose (port 8001):**

```bash
cat bulk_events.jsonl | while read line; do
  curl -X POST http://localhost:8001/v1/ingest \
    -H "Content-Type: application/json" \
    -d "$line"
  sleep 0.1
done
```

### 12.3 Monitor processing

While sending bulk events:

**Watch queue depth:**

```bash
watch -n 1 'curl -s http://localhost:8001/v1/health | jq .queue_depth'
```

**Watch worker logs:**

```bash
kubectl logs -n nsready-tier2 -l app=collector-service -f | grep "DB commit"
```

**Watch database count:**

```bash
watch -n 1 'kubectl exec -n nsready-tier2 nsready-db-0 -- psql -U postgres -d nsready -t -c "SELECT COUNT(*) FROM ingest_events;"'
```

---

## 13. Expected Behaviour Summary

| Component | Expected Output |
|-----------|----------------|
| Collector | Returns `{"status":"queued","trace_id":"..."}` |
| Health | `queue_depth: 0` after processing |
| NATS | `pending: 0`, `ack_pending: 0` |
| Worker | Logs `"DB commit OK → acked X messages"` |
| DB | New rows in `ingest_events` table |
| SCADA | Updated values appear in `v_scada_latest` |

**Timeline:**

1. **0s** - Event sent to `/v1/ingest`
2. **<1s** - Collector validates and queues to NATS
3. **1-2s** - Worker pulls from NATS
4. **2-3s** - Worker inserts into database
5. **3-4s** - Database committed, NATS acked
6. **Immediate** - SCADA views reflect new data

---

## 14. Troubleshooting (Copy–Paste Fixes)

### ❗ Problem: `"error": "device_id must be a valid UUID"`

**Cause:** Wrong `device_id` format

**Fix:**

```bash
# Get correct device IDs
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "SELECT id, name FROM devices LIMIT 10;"
```

**Update your JSON with correct UUID.**

### ❗ Problem: `"error": "parameter_key not found"`

**Cause:** Parameter template doesn't exist

**Fix:**

```bash
# Check parameter keys for your project
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "
SELECT key, name 
FROM parameter_templates 
WHERE metadata->>'project_id' = '<PROJECT_ID>';"
```

**Update your JSON with correct parameter_key values.**

### ❗ Problem: `queue_depth` stuck > 0

**Cause:**

- Worker is down
- Worker is stuck processing
- NATS consumer corrupted

**Fix:**

```bash
# Check worker status
kubectl get pods -n nsready-tier2 -l app=collector-service

# Check worker logs
kubectl logs -n nsready-tier2 -l app=collector-service --tail=50

# Restart workers
kubectl rollout restart deployment/collector-service -n nsready-tier2

# Wait for rollout
kubectl rollout status deployment/collector-service -n nsready-tier2
```

### ❗ Problem: Event not in database

**Check worker logs:**

**For Kubernetes:**

```bash
kubectl logs -n nsready-tier2 -l app=collector-service --tail=100 | grep -i error
```

**For Docker Compose:**

```bash
docker logs collector_service --tail=100 | grep -i error
```

**Check DB errors:**

**For Kubernetes:**

```bash
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "
SELECT * FROM error_logs 
ORDER BY time DESC 
LIMIT 5;"
```

**For Docker Compose:**

```bash
docker exec nsready_db psql -U postgres -d nsready -c "
SELECT * FROM error_logs 
ORDER BY time DESC 
LIMIT 5;"
```

**Common causes:**

- Foreign key constraint violation (device_id or parameter_key doesn't exist)
- Data type mismatch
- Transaction rollback

### ❗ Problem: SCADA shows old values

**For materialized views:**

```sql
REFRESH MATERIALIZED VIEW mv_scada_latest_readable;
```

**For regular views:**

- Views are always current (no refresh needed)
- Check if your test data actually reached the database
- Verify the device_id matches

**Re-export SCADA files:**

```bash
./scripts/export_scada_data_readable.sh --latest --format txt
```

---

## 15. Automated Testing Scripts

Multiple automated test scripts are available for comprehensive testing:

### 15.1 Basic Data Flow Test

**For Docker Compose:**
```bash
DB_CONTAINER=nsready_db ./scripts/test_data_flow.sh
```

**For Kubernetes:**
```bash
./scripts/test_drive.sh
```

**What it does:**
- Auto-detects registry data (device_id, site_id, project_id)
- Auto-detects parameter templates
- Generates test event JSON
- Sends to ingest endpoint
- Verifies data in database
- Verifies SCADA views
- Tests SCADA export
- Generates detailed test report

### 15.2 Batch Ingestion Test

Tests sending multiple events in sequential and parallel batches:

```bash
# Sequential batch
./scripts/test_batch_ingestion.sh --sequential --count 100

# Parallel batch
./scripts/test_batch_ingestion.sh --parallel --count 100

# Both modes
./scripts/test_batch_ingestion.sh --count 50
```

**What it tests:**
- Sequential ingestion throughput
- Parallel ingestion throughput
- Queue handling under batch load
- Database insertion performance

### 15.3 Stress/Load Test

Tests system under sustained high load:

```bash
# Default: 1000 events over 60s at 50 RPS
./scripts/test_stress_load.sh

# Custom: 5000 events over 120s at 100 RPS
./scripts/test_stress_load.sh --events 5000 --duration 120 --rate 100
```

**What it tests:**
- Sustained high-volume ingestion
- Queue depth stability over time
- System stability under load
- Error rates and throughput

### 15.4 Multi-Customer Data Flow Test

Tests data flow with multiple customers and verifies tenant isolation:

```bash
# Test with 5 customers (default)
./scripts/test_multi_customer_flow.sh

# Test with 10 customers
./scripts/test_multi_customer_flow.sh --customers 10
```

**What it tests:**
- Data ingestion for multiple customers
- Tenant isolation verification
- Per-customer data separation
- Database integrity across customers

### 15.5 Negative Test Cases

Tests system behavior with invalid data:

```bash
./scripts/test_negative_cases.sh
```

**What it tests:**
- Missing required fields
- Invalid UUID formats
- Non-existent parameter keys
- Invalid data types
- Malformed JSON
- Empty requests
- Non-existent references

**Expected:** All invalid requests should be rejected with appropriate HTTP status codes (400, 422) and no invalid data should be inserted.

### Test Reports

All test scripts generate detailed reports in `tests/reports/`:
- `DATA_FLOW_TEST_*.md`
- `BATCH_INGESTION_TEST_*.md`
- `STRESS_LOAD_TEST_*.md`
- `MULTI_CUSTOMER_FLOW_TEST_*.md`
- `NEGATIVE_TEST_*.md`

See `scripts/TEST_SCRIPTS_README.md` and `master_docs/DATA_FLOW_TESTING_GUIDE.md` for complete documentation.
- Validates queue drains
- Verifies database rows
- Generates report

---

## 16. Final Checklist (Copy–Paste)

### Configuration

- [ ] Registry imported (customers, projects, sites, devices)
- [ ] Parameter templates imported
- [ ] Device IDs correct (verified via SQL query)
- [ ] Parameter keys correct (verified via SQL query)

### Ingestion

- [ ] JSON event sent successfully
- [ ] Collector returned `{"status":"queued"}`
- [ ] Worker committed (see logs: "DB commit OK")
- [ ] Queue depth returned to 0 (check `/v1/health`)

### Database

- [ ] `ingest_events` row count increased (before/after comparison)
- [ ] Data stored correctly (verify with SELECT query)
- [ ] Timestamps correct (source_timestamp matches JSON, created_at is recent)
- [ ] Quality codes correct (192 for good quality)

### SCADA

- [ ] Latest values visible in `v_scada_latest`
- [ ] Historical values visible in `v_scada_history`
- [ ] Exported files contain test data (if using file export)

### Monitoring

- [ ] Health endpoint shows `"service": "ok"`
- [ ] Health endpoint shows `"db": "connected"`
- [ ] Metrics endpoint accessible (`/metrics`)
- [ ] No errors in worker logs
- [ ] No errors in error_logs table

---

## 17. Performance Testing

For load testing, see `tests/performance/locustfile.py`:

```bash
# Install locust
pip install locust

# Run load test
cd tests/performance
locust -f locustfile.py --host=http://localhost:8001
```

Open browser: `http://localhost:8089`

---

## 18. Summary

After completing this module, you can:

- Create valid NormalizedEvent JSON files
- Send test data to the collector service
- Monitor the entire ingestion pipeline
- Validate data storage in PostgreSQL
- Verify SCADA visibility
- Troubleshoot ingestion issues
- Perform bulk testing

This validates that the NSReady platform is functioning correctly end-to-end.

---

**End of Module 7 – Data Ingestion and Testing Manual**

**Related Modules:**

- Module 3 – Environment and PostgreSQL Storage Manual
- Module 5 – Configuration Import Manual
- Module 9 – SCADA Integration Manual
- Module 11 – Troubleshooting and Diagnostics Manual

**Recommended next:** Review all modules for complete understanding of the NSReady platform.

