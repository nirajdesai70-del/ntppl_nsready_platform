# Module 11 – Troubleshooting and Diagnostics Manual

_NSReady Data Collection Platform_

*(Suggested path: `docs/11_Troubleshooting_and_Diagnostics_Manual.md`)*

---

## 1. Introduction

This manual helps engineers diagnose and resolve issues in the NSReady Data Collection Platform.

It covers:

- Registry & parameter CSV errors
- Ingestion errors
- Processing (worker/NATS) problems
- SCADA connectivity failures
- Database issues (Kubernetes & Docker)
- Health checks
- Queue depth issues
- Validation steps

This is the go-to reference when something does not work.

---

## 2. System Health Overview

NSReady's ingestion pipeline:

```
 Device / Simulator (JSON)
            |
            v
      Collector-Service
            |
            v
        NATS JetStream
            |
            v
     Worker Pool (consumers)
            |
            v
     PostgreSQL / TimescaleDB
            |
            v
    SCADA / Monitoring / Export
```

When diagnosing, identify which block is failing.

---

## 3. Quick Diagnostic Checklist (Copy & Paste)

### 3.1 Collector Health

**For Kubernetes (NodePort 32001):**

```bash
curl http://localhost:32001/v1/health | jq .
```

**For Kubernetes (Port-Forward) or Docker Compose (port 8001):**

```bash
curl http://localhost:8001/v1/health | jq .
```

**Expected:**

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
- `queue_depth: 0` → No messages waiting
- `db: "connected"` → Database connection healthy
- `pending: 0` → No unprocessed messages
- `ack_pending: 0` → No messages being processed
- `redelivered: 0` → No retry attempts

---

### 3.2 Worker Logs

**For Kubernetes:**

```bash
kubectl logs -n nsready-tier2 -l app=collector-service -f | grep -E "(DB commit|Worker|inserted|error)"
```

**For Docker Compose:**

```bash
docker logs -f collector_service | grep -E "(DB commit|Worker|inserted|error)"
```

**Expected log lines:**

```
[Worker-0] DB commit OK → acked 3 messages
[Worker-1] inserting 5 events into database
[Worker-2] inserted 5 rows from 5 events, DB count now: 1250
```

**Red flags:**

- `batch insert failed` → Database issue
- `integrity error` → Foreign key constraint violation
- `timeout` → NATS or database timeout
- `connection refused` → Database or NATS not reachable

---

### 3.3 NATS Consumer Status

**For Kubernetes:**

```bash
kubectl exec -n nsready-tier2 nsready-nats-0 -- \
  nats consumer info INGRESS ingest_workers
```

**Expected:**

```
Outstanding Acks: 0
Unprocessed Messages: 0
Redelivered Messages: 0
```

**If NATS CLI not available, check via health endpoint:**

```bash
curl http://localhost:8001/v1/health | jq '.queue'
```

**Interpretation:**

- `Outstanding Acks: 0` → All messages acknowledged
- `Unprocessed Messages: 0` → No backlog
- `Redelivered Messages: 0` → No retry attempts

---

### 3.4 Database Status

**For Kubernetes:**

```bash
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "SELECT now();"
```

**For Docker Compose:**

```bash
docker exec nsready_db psql -U postgres -d nsready -c "SELECT now();"
```

**Expected:**

```
              now              
-------------------------------
 2025-11-14 15:30:12.123456+00
(1 row)
```

**If fails:**

- Check pod/container status
- Check database logs
- Verify network connectivity

---

### 3.5 Event Count

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

**Before/After Test:**

```bash
# Before
BEFORE=$(kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -t -c "SELECT COUNT(*) FROM ingest_events;")

# Send test event
curl -X POST http://localhost:8001/v1/ingest \
  -H "Content-Type: application/json" \
  -d @test_event.json

# Wait 5 seconds
sleep 5

# After
AFTER=$(kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -t -c "SELECT COUNT(*) FROM ingest_events;")

echo "Before: $BEFORE, After: $AFTER"
```

---

### 3.6 SCADA Test

```bash
./scripts/test_scada_connection.sh
```

**Expected:**

```
✓ Internal connection successful
✓ Both SCADA views exist
✓ v_scada_latest contains X rows
✓ v_scada_history contains Y rows
```

---

### 3.7 Metrics Endpoint

**For Kubernetes (NodePort) or Port-Forward/Docker:**

```bash
curl http://localhost:8001/metrics | grep ingest
```

**Key metrics:**

- `ingest_events_total{status="queued"}` → Successful queuing
- `ingest_errors_total{error_type="..."}` → Error counts
- `ingest_queue_depth` → Current queue depth

**Expected:**

- `ingest_events_total` increasing
- `ingest_errors_total` = 0 (or low)
- `ingest_queue_depth` ≈ 0

---

**If all the above pass → system operational.**

**If something fails → use the sections below.**

---

## 4. Troubleshooting by Category

### 4.1 CSV Import Errors (Registry / Parameters)

#### ❗ Error: "Customer not found"

**Cause:** Wrong spelling or extra spaces in CSV

**Fix:**

```bash
# Get exact customer name
./scripts/list_customers_projects.sh

# Copy the exact name into the CSV
# Ensure case matches exactly (case-sensitive)
```

**Example:**

CSV has: `"Acme Corp Inc"`  
Database has: `"Acme Corp"`  
→ **Fix:** Change CSV to match exactly

---

#### ❗ Error: "Project not found"

**Cause:** Project name does not belong to customer OR wrong customer/project pairing

**Fix:**

```bash
# List all customer/project pairs
./scripts/list_customers_projects.sh

# Ensure customer/project combination exists
# Example: Project "Factory A" might belong to "Customer 01", not "Customer 02"
```

**Verify:**

**For Kubernetes:**

```bash
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "
SELECT c.name AS customer, p.name AS project
FROM customers c
JOIN projects p ON p.customer_id = c.id
WHERE c.name = 'Customer Name From CSV'
  AND p.name = 'Project Name From CSV';"
```

---

#### ❗ Error: "Parameter template already exists"

**Cause:** Parameter duplication - a parameter with the same key already exists

**Behavior:** Script skips that row (does not overwrite)

**Fix:**

**Option 1: Use a different parameter name**

```csv
customer_name,project_name,parameter_name,...
Customer 01,Project 01,Voltage_v2,...
```

**Option 2: Delete existing parameter**

**For Kubernetes:**

```bash
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "
DELETE FROM parameter_templates
WHERE key = 'project:PROJECT_ID:voltage';"
```

**Option 3: Update existing parameter**

Use Admin API or direct SQL to update instead of importing.

---

#### ❗ Error: "Invalid CSV format"

**Cause:** Wrong number of columns per row

**Fix - Validate CSV column count:**

**Registry CSV (should have 9 columns):**

```bash
awk -F',' 'NR==1 {print "Header columns: " NF} NR>1 {if (NF != 9) print "Row " NR " has " NF " columns (expected 9)"}' registry.csv
```

**Parameter CSV (should have 9 columns):**

```bash
awk -F',' 'NR==1 {print "Header columns: " NF} NR>1 {if (NF != 9) print "Row " NR " has " NF " columns (expected 9)"}' parameters.csv
```

**Expected:**

- Registry CSV = 9 columns
- Parameters CSV = 9 columns

**Common issues:**

- Missing commas in CSV
- Commas inside quoted fields (should be handled correctly)
- Trailing commas
- Empty rows with different column counts

---

### 4.2 Collector-Service Errors

#### ❗ Error: `{"status":"error"}` or `400 Bad Request` during ingest

**Causes:**

- Missing required metric fields
- Wrong `parameter_key`
- Wrong `device_id`/`project_id`/`site_id`
- JSON structure invalid
- Invalid UUID format

**Test ingest endpoint alone:**

```bash
curl -X POST http://localhost:8001/v1/ingest \
  -H "Content-Type: application/json" \
  -d @test_event.json -v
```

**Common error responses:**

```json
{"detail":"device_id must be a valid UUID: invalid-id"}
```

```json
{"detail":"metrics array must contain at least one metric"}
```

```json
{"detail":"parameter_key is required"}
```

**Fix:**

1. **Validate JSON structure** - Use online JSON validator
2. **Check UUIDs** - Ensure valid UUID format
3. **Verify device exists:**

```bash
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "SELECT id, name FROM devices WHERE id = '<DEVICE_ID>';"
```

4. **Verify parameter_key exists:**

```bash
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "SELECT key, name FROM parameter_templates WHERE key = '<PARAMETER_KEY>';"
```

---

#### ❗ Error: `500 Internal Server Error`

**Causes:**

- NATS connection failure
- Database connection failure
- Worker startup failure

**Check logs:**

**For Kubernetes:**

```bash
kubectl logs -n nsready-tier2 -l app=collector-service --tail=100 | grep -i error
```

**For Docker Compose:**

```bash
docker logs collector_service --tail=100 | grep -i error
```

**Common errors:**

- `Failed to connect to NATS` → NATS pod/container down
- `Database healthcheck failed` → Database pod/container down
- `Failed to start workers` → Worker initialization error

---

### 4.3 Worker Problems

#### ❗ Symptom: `queue_depth` increases and stays > 0

**Cause:** Worker not consuming messages OR worker stuck processing

**Diagnostic:**

```bash
# Check worker status
kubectl get pods -n nsready-tier2 -l app=collector-service

# Check worker logs
kubectl logs -n nsready-tier2 -l app=collector-service --tail=100

# Check queue depth over time
watch -n 2 'curl -s http://localhost:8001/v1/health | jq .queue_depth'
```

**Fix:**

**Option 1: Restart workers**

```bash
kubectl rollout restart deployment/collector-service -n nsready-tier2

# Wait for rollout
kubectl rollout status deployment/collector-service -n nsready-tier2
```

**Option 2: Delete pods (forces recreation)**

```bash
kubectl delete pod -n nsready-tier2 -l app=collector-service

# Pods will be recreated automatically
```

**Option 3: Check for stuck messages**

```bash
# Check NATS consumer stats
kubectl exec -n nsready-tier2 nsready-nats-0 -- \
  nats consumer info INGRESS ingest_workers

# If many redelivered messages, consumer may be corrupted
```

**Verify:**

```bash
curl http://localhost:8001/v1/health | jq .queue_depth
# Should return to 0 within 30 seconds
```

---

#### ❗ Symptom: DB commit errors in worker logs

**Check logs:**

**For Kubernetes:**

```bash
kubectl logs -n nsready-tier2 -l app=collector-service --tail=200 | grep -i "error\|failed\|rollback"
```

**For Docker Compose:**

```bash
docker logs collector_service --tail=200 | grep -i "error\|failed\|rollback"
```

**Expected log lines (errors):**

```
[Worker-0] batch insert failed: ...
[Worker-0] integrity error in batch insert: ...
[Worker-0] error in bulk insert: ...
```

**Possible causes:**

- **Wrong foreign keys** (device/parameter mismatch)
- **Invalid data types** (non-numeric value where number expected)
- **DB unavailable** (connection lost during transaction)
- **Constraint violation** (duplicate primary key, foreign key constraint)

**Fix:**

**1. Check for integrity errors:**

```bash
# Get first event in failed batch (from logs)
# Then verify device_id and parameter_key exist
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "
SELECT id FROM devices WHERE id = '<DEVICE_ID_FROM_LOG>';

SELECT key FROM parameter_templates WHERE key = '<PARAMETER_KEY_FROM_LOG>';"
```

**2. Check error_logs table:**

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

**3. Verify database is accessible:**

```bash
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "SELECT now();"
```

---

#### ❗ Symptom: Worker says "Inserted X rows" but DB has 0

**Causes:**

- **Transaction rollback** (integrity error, constraint violation)
- **Foreign key failed** (device_id or parameter_key doesn't exist)
- **Worker acked before commit** (fixed in current build - worker only acks after commit)

**Diagnostic SQL:**

**For Kubernetes:**

```bash
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "
SELECT * FROM error_logs 
ORDER BY time DESC 
LIMIT 5;"
```

**Check worker logs for rollback:**

```bash
kubectl logs -n nsready-tier2 -l app=collector-service --tail=200 | \
  grep -E "(rollback|integrity error|constraint|foreign key)"
```

**Fix:**

1. **Verify foreign keys exist:**
   - Device exists in `devices` table
   - Parameter template exists in `parameter_templates` table

2. **Check for constraint violations:**
   - Duplicate primary key (time, device_id, parameter_key)
   - Invalid event_id (if using idempotency)

3. **Verify data types:**
   - `value` should be numeric (or NULL)
   - `quality` should be integer 0-255
   - `time` should be valid timestamp

---

### 4.4 NATS JetStream Problems

#### ❗ Symptom: Consumer `pending > 0` or messages stuck

**Diagnostic:**

**For Kubernetes:**

```bash
kubectl exec -n nsready-tier2 nsready-nats-0 -- \
  nats consumer info INGRESS ingest_workers
```

**Or check via health endpoint:**

```bash
curl http://localhost:8001/v1/health | jq '.queue'
```

**Check values:**

- `Outstanding Acks` → Messages awaiting acknowledgment
- `Unprocessed Messages` → Messages not yet pulled
- `Redelivered Messages` → Messages that failed and were retried
- `Ack Pending` → Messages being processed

**Fix:**

**Option 1: Restart workers**

```bash
kubectl rollout restart deployment/collector-service -n nsready-tier2
```

**Option 2: Recreate consumer (if corrupted)**

**For Kubernetes:**

```bash
kubectl exec -n nsready-tier2 nsready-nats-0 -- \
  sh -c "nats consumer delete INGRESS ingest_workers && \
  nats consumer add INGRESS ingest_workers --pull --deliver=all --ack=explicit --max-deliver=3"
```

**Note:** Workers will recreate consumer on startup if it doesn't exist.

**Option 3: Check NATS pod status**

```bash
kubectl get pods -n nsready-tier2 | grep nats
kubectl logs -n nsready-tier2 nsready-nats-0 --tail=50
```

---

#### ❗ Symptom: NATS timeout errors

**Logs show:**

```
Worker 0 fetch error (timeout): ...
```

**Causes:**

- NATS pod/container not responding
- Network issues
- NATS overloaded

**Fix:**

**Check NATS status:**

```bash
# Kubernetes
kubectl get pods -n nsready-tier2 | grep nats
kubectl logs -n nsready-tier2 nsready-nats-0 --tail=50

# Docker
docker ps | grep nats
docker logs nsready_nats --tail=50
```

**Restart NATS if needed:**

```bash
# Kubernetes
kubectl delete pod -n nsready-tier2 nsready-nats-0

# Docker
docker restart nsready_nats
```

---

### 4.5 Database Issues

#### ❗ Error: "connection refused"

**Cause:** DB pod/container may be down OR network connectivity issue

**Check:**

**For Kubernetes:**

```bash
kubectl get pods -n nsready-tier2 | grep nsready-db
```

**For Docker Compose:**

```bash
docker ps | grep nsready_db
```

**If restarting repeatedly, check logs:**

**For Kubernetes:**

```bash
kubectl logs -n nsready-tier2 nsready-db-0 --tail=100
```

**For Docker Compose:**

```bash
docker logs nsready_db --tail=100
```

**Common causes:**

- **Disk full** → Check PVC or Docker volume space
- **Corrupted database** → Restore from backup
- **Memory limit** → Increase resource limits
- **Startup script failure** → Check init scripts

---

#### ❗ Error: "permission denied"

**Cause:** SCADA user is not created or not granted privileges

**Check permissions:**

**For Kubernetes:**

```bash
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "
SELECT grantee, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'scada_reader';"
```

**Fix - Re-run setup script:**

**For Kubernetes:**

```bash
kubectl cp scripts/setup_scada_readonly_user.sql nsready-tier2/nsready-db-0:/tmp/
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -f /tmp/setup_scada_readonly_user.sql
```

**For Docker Compose:**

```bash
docker cp scripts/setup_scada_readonly_user.sql nsready_db:/tmp/
docker exec nsready_db psql -U postgres -d nsready -f /tmp/setup_scada_readonly_user.sql
```

**Important:** Change password in SQL script before running!

---

#### ❗ Database size too big

**Check size:**

**For Kubernetes:**

```bash
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "
SELECT pg_size_pretty(pg_database_size('nsready'));"
```

**Check top tables:**

**For Kubernetes:**

```bash
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "
SELECT relname AS table_name,
       pg_size_pretty(pg_total_relation_size(relid)) AS total_size
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC
LIMIT 20;"
```

**Expected:** `ingest_events` is usually the largest table.

**If too large:**

1. **Check retention policy** (default: 90 days)
2. **Archive old data** (export before deletion)
3. **Compression** (enabled after 7 days for ingest_events)
4. **Increase PVC size** if needed

**Check retention policy:**

```bash
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "
SELECT * FROM timescaledb_information.job_stats;"
```

---

#### ❗ Error: "out of disk space"

**Symptoms:**

- Database operations fail
- "no space left on device" errors
- Pod keeps restarting

**Check:**

**For Kubernetes:**

```bash
# Check PVC usage
kubectl describe pvc postgres-pvc -n nsready-tier2

# Check pod disk usage
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  df -h
```

**For Docker Compose:**

```bash
# Check Docker disk usage
docker system df

# Check volume usage
docker exec nsready_db df -h
```

**Fix:**

1. **Clean up old data** (archive and delete old `ingest_events`)
2. **Increase PVC size** (Kubernetes)
3. **Increase Docker disk image size** (Docker Desktop)
4. **Check for log file bloat**

---

### 4.6 SCADA Issues

#### ❗ SCADA shows old values

**For materialized views:**

**Fix:**

```sql
REFRESH MATERIALIZED VIEW mv_scada_latest_readable;
```

**For regular views:**

Regular views (`v_scada_latest`, `v_scada_history`) are always current - no refresh needed.

**If using exports:**

**Regenerate exports:**

```bash
./scripts/export_scada_data_readable.sh --latest --format txt
```

**Check timestamp:**

```bash
ls -lh reports/scada_latest_readable_*.txt
# Check file modification time
```

---

#### ❗ SCADA cannot connect to DB

**Check NodePort:**

**For Kubernetes:**

```bash
kubectl get svc -n nsready-tier2 | grep nsready-db
```

**Check local port-forward:**

**For Kubernetes:**

```bash
# Terminal 1: Start port-forward
kubectl port-forward -n nsready-tier2 pod/nsready-db-0 5432:5432

# Terminal 2: Test connection
psql -h localhost -U scada_reader -d nsready -c "SELECT now();"
```

**For Docker Compose:**

```bash
# Test connection
docker exec nsready_db psql -U scada_reader -d nsready -c "SELECT now();"
```

**Or from host:**

```bash
psql -h localhost -p 5432 -U scada_reader -d nsready -c "SELECT now();"
```

**Common issues:**

- **Port not exposed** → Check service configuration
- **Firewall blocking** → Check firewall rules
- **Wrong password** → Reset SCADA user password
- **User doesn't exist** → Run `setup_scada_readonly_user.sql`

---

#### ❗ SCADA shows missing parameters

**Cause:** Parameter template not defined for the project

**Check:**

```bash
# List parameters for a project
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "
SELECT key, name, unit 
FROM parameter_templates 
WHERE metadata->>'project_id' = '<PROJECT_ID>';"
```

**Fix:**

Import missing parameter templates:

```bash
./scripts/import_parameter_templates.sh missing_parameters.csv
```

---

#### ❗ SCADA shows wrong device

**Cause:** Device code mismatch between NSReady and SCADA

**Check:**

```bash
# List devices with codes
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "
SELECT d.name, d.external_id AS device_code, s.name AS site
FROM devices d
JOIN sites s ON s.id = d.site_id
ORDER BY s.name, d.name;"
```

**Fix:**

1. **Export registry** to see exact device codes
2. **Update SCADA mapping** to match NSReady device codes
3. **Or update NSReady** to match SCADA codes (if preferred)

---

## 5. Full Deep-Dive Diagnostic Trees

### 5.1 If event is not showing in DB

```
Event sent?
   |
   +--> Yes → Collector response?
   |         |
   |         +--> "queued" → NATS queue depth?
   |         |              |
   |         |              +--> 0 → Worker logs?
   |         |              |          |
   |         |              |          +--> No DB commit → DB issue
   |         |              |          |                  Check error_logs
   |         |              |          |                  Check foreign keys
   |         |              |          |
   |         |              |          +--> DB commit OK → Check SELECT query
   |         |              |                            Verify device_id
   |         |              |                            Verify parameter_key
   |         |              |
   |         |              +--> >0 → Worker stuck / restart needed
   |         |                         Check worker logs
   |         |                         Restart deployment
   |         |
   |         +--> "error" → JSON invalid
   |                        Check validation errors
   |                        Verify JSON structure
   |
   +--> No → Connection issue
              Check collector service status
              Check network connectivity
              Verify port (8001 or 32001)
```

---

### 5.2 If SCADA values are wrong

```
Wrong values in SCADA?
      |
      +--> Export method?
      |       |
      |       +--> TXT → Check export_scada_data_readable.sh
      |       |           Verify file timestamp
      |       |           Check column order
      |       |
      |       +--> CSV → Check column order
      |                   Verify CSV parsing
      |
      +--> DB method?
              |
              +--> SCADA using v_scada_latest?
              |           |
              |           +--> Check view definition
              |           |   SELECT * FROM v_scada_latest LIMIT 1;
              |           |
              |           +--> Check device mapping (device_code)
              |           |   Verify device_code matches SCADA tags
              |
              +--> Check JOIN in SCADA query
                      Verify device_id → device mapping
                      Verify parameter_key → parameter mapping
```

---

### 5.3 If worker not processing

```
worker stuck?
   |
   +--> Check logs
   |       |
   |       +--> NATS timeout → Restart NATS
   |       |                   Check NATS pod status
   |       |
   |       +--> DB failure → Fix DB
   |       |                  Check DB connectivity
   |       |                  Check DB errors
   |       |
   |       +--> Integrity error → Fix foreign keys
   |                               Verify device_id exists
   |                               Verify parameter_key exists
   |
   +--> Check queue depth
           |
           +--> > 0 = backlog
           |        Restart workers
           |        Check for stuck messages
           |
           +--> 0 = normal
                   Check if events are being sent
                   Verify collector is working
```

---

## 6. Master Troubleshooting Table (Copy–Paste)

| Symptom | Cause | Fix |
|---------|-------|-----|
| `status:"error"` on ingest | JSON invalid / missing fields | Fix JSON structure, verify required fields |
| Queue depth increasing | Worker not consuming | Restart worker deployment |
| No events in DB | Wrong device_id or parameter_key | Check registry & parameter templates |
| Worker "DB commit OK" but no rows | Transaction rollback | Check error_logs, verify foreign keys |
| NATS timeout | NATS not ready / network issue | Restart NATS pod, check connectivity |
| SCADA cannot read DB | Wrong user/password / user doesn't exist | Recreate SCADA user |
| SCADA missing parameters | Parameter not defined | Import parameter template |
| SCADA shows wrong device | Wrong device_code | Fix registry & SCADA mapping |
| "Customer not found" | CSV mismatch | Use list script to get exact name |
| "Project not found" | Wrong customer/project pairing | Check registry export |
| DB connection refused | Pod down / network issue | Check db pod status & logs |
| `ingest_events` empty | Worker rollback / foreign key error | Check error_logs, verify registry |
| "Invalid UUID" error | Wrong UUID format | Verify UUIDs in JSON |
| Queue depth stuck > 0 | Worker crashed / stuck | Restart deployment, check logs |
| Health shows `db: "disconnected"` | Database connection lost | Check DB pod, verify network |
| "Parameter template already exists" | Duplicate parameter | Use different name or delete first |
| Worker logs "integrity error" | Foreign key constraint violation | Verify device_id and parameter_key exist. **Foreign key errors usually mean short-form parameter_key was used** - always use full format `project:<uuid>:<parameter>` (see **Module 6**). |

---

## 7. Verification Steps After Fix

> **NOTE (NS-AI-DEBUG-FUTURE):**  
> When diagnosing complex AI/ML behaviours in future phases, the `trace_id` will be used  
> to cross-reference telemetry, model scores, and SCADA behaviour.

After resolving an issue, always re-run:

**Step 1: Check Collector Health**

```bash
curl http://localhost:8001/v1/health | jq .
```

**Expected:** All values healthy (service: ok, db: connected, queue_depth: 0)

---

**Step 2: Check Worker Logs**

**For Kubernetes:**

```bash
kubectl logs -n nsready-tier2 -l app=collector-service --tail=50 | grep -E "(DB commit|error)"
```

**For Docker Compose:**

```bash
docker logs collector_service --tail=50 | grep -E "(DB commit|error)"
```

**Expected:** "DB commit OK → acked" messages, no errors

---

**Step 3: Verify Database**

**For Kubernetes:**

```bash
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "SELECT COUNT(*) FROM ingest_events;"
```

**For Docker Compose:**

```bash
docker exec nsready_db psql -U postgres -d nsready -c "SELECT COUNT(*) FROM ingest_events;"
```

**Expected:** Count > 0 and increasing with new events

---

**Step 4: Test SCADA Connection**

```bash
./scripts/test_scada_connection.sh
```

**Expected:** All tests pass

---

**Step 5: Send Test Event**

```bash
curl -X POST http://localhost:8001/v1/ingest \
  -H "Content-Type: application/json" \
  -d @test_event.json

# Wait 5 seconds
sleep 5

# Verify queue drained
curl http://localhost:8001/v1/health | jq .queue_depth
# Should be 0

# Verify DB count increased
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -t -c "SELECT COUNT(*) FROM ingest_events;"
```

---

## 8. Final Operational Checklist

### Configuration

- [ ] Registry correct (customers, projects, sites, devices exist)
- [ ] Parameters correct (parameter_templates imported)
- [ ] No CSV errors (imports completed successfully)
- [ ] Device codes match SCADA tags

### Ingestion

- [ ] JSON accepted (`{"status":"queued"}`)
- [ ] Worker commits (logs show "DB commit OK")
- [ ] Queue depth stays near 0 (check `/v1/health`)
- [ ] Events appear in database (verify with SELECT)

### Database

- [ ] `ingest_events` growing (count increases)
- [ ] `v_scada_latest` valid (latest values present)
- [ ] `v_scada_history` valid (historical data present)
- [ ] No errors in `error_logs` table

### SCADA

- [ ] SCADA reads latest values (from DB or file)
- [ ] File export correct (if using file import)
- [ ] Device codes/parameter names match
- [ ] Timestamps correct

### Monitoring

- [ ] Health endpoint accessible
- [ ] Metrics endpoint accessible (`/metrics`)
- [ ] No worker errors in logs
- [ ] NATS consumer healthy

---

## 9. Quick Command Reference

### Health Check

```bash
curl http://localhost:8001/v1/health | jq .
```

### Worker Logs

```bash
# Kubernetes
kubectl logs -n nsready-tier2 -l app=collector-service -f

# Docker Compose
docker logs -f collector_service
```

### Queue Depth

```bash
curl -s http://localhost:8001/v1/health | jq .queue_depth
```

### Database Count

```bash
# Kubernetes
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -t -c "SELECT COUNT(*) FROM ingest_events;"

# Docker Compose
docker exec nsready_db psql -U postgres -d nsready -t -c "SELECT COUNT(*) FROM ingest_events;"
```

### Restart Workers

```bash
# Kubernetes
kubectl rollout restart deployment/collector-service -n nsready-tier2

# Docker Compose
docker restart collector_service
```

### Check Errors

```bash
# Kubernetes
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "SELECT * FROM error_logs ORDER BY time DESC LIMIT 5;"
```

---

## 10. Summary

After reviewing this module, you can:

- Diagnose issues across all NSReady components
- Use diagnostic checklists to quickly identify problems
- Follow step-by-step troubleshooting procedures
- Verify fixes with validation steps
- Use the master troubleshooting table for quick reference

This manual serves as your primary reference for resolving issues in the NSReady platform.

---

**Related Modules:**

- **Module 6** – Parameter Template Manual
- **Module 7** – Data Ingestion & Testing Manual
- **Module 8** – Monitoring API & Packet Health Manual
- **Module 9** – SCADA Integration Manual
- **Module 12** – API Developer Manual

---

**End of Module 11 – Troubleshooting and Diagnostics Manual**

**Complete Documentation Set:**

- Module 0 – Introduction and Terminology
- Module 1 – Folder Structure and File Descriptions
- Module 2 – System Architecture and DataFlow
- Module 3 – Environment and PostgreSQL Storage Manual
- Module 4 – Deployment and Startup Manual
- Module 5 – Configuration Import Manual
- Module 6 – Parameter Template Manual
- Module 7 – Data Ingestion and Testing Manual
- Module 8 – Monitoring API and Packet Health Manual
- Module 9 – SCADA Integration Manual
- Module 10 – Scripts and Tools Reference Manual
- Module 11 – Troubleshooting and Diagnostics Manual
- Module 12 – API Developer Manual
- Module 13 – Performance and Monitoring Manual

