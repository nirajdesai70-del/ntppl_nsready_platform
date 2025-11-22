# Data Flow Testing Guide - Dashboard → NSReady → Database → SCADA

**Date**: 2025-11-22  
**Purpose**: Comprehensive guide for testing the complete data flow pipeline

---

## Overview

This guide covers testing the **full data flow** from dashboard input through NSReady ingestion to SCADA export:

```
Dashboard Input → NSReady Ingestion → Database → SCADA Export
```

**This is different from tenant isolation tests** (which test security/access control).  
**This tests functionality** - does data flow correctly through the system?

---

## Data Flow Pipeline

```
┌─────────────┐
│  Dashboard  │  (Simulated device/field input)
│    Input    │
└──────┬──────┘
       │ POST /v1/ingest
       ▼
┌─────────────────┐
│ Collector-Service│  (Validates & queues event)
│   /v1/ingest     │
└──────┬──────────┘
       │ NATS JetStream (ingress.events)
       ▼
┌─────────────────┐
│  Worker Pool    │  (Consumes from NATS)
│  (Pull Consumer)│
└──────┬──────────┘
       │ INSERT INTO ingest_events
       ▼
┌─────────────────┐
│   PostgreSQL    │  (TimescaleDB hypertable)
│  ingest_events  │
└──────┬──────────┘
       │ SCADA Views
       ▼
┌─────────────────┐
│  SCADA Export   │  (v_scada_latest, v_scada_history)
│   (Views/CSV)    │
└─────────────────┘
```

---

## Quick Start - Automated Test

**Run the automated end-to-end test:**

```bash
./scripts/test_data_flow.sh
```

This script:
1. ✅ Simulates dashboard input (creates test event)
2. ✅ Sends to NSReady ingestion API
3. ✅ Verifies data in database
4. ✅ Verifies data in SCADA views
5. ✅ Exports SCADA data (optional)

---

## Manual Testing Steps

### Step 1: Prepare Test Data

**Option A: Use existing sample event**
```bash
# Use the sample event file
cat collector_service/tests/sample_event.json
```

**Option B: Create custom test event**
```json
{
  "project_id": "YOUR_PROJECT_UUID",
  "site_id": "YOUR_SITE_UUID",
  "device_id": "YOUR_DEVICE_UUID",
  "protocol": "GPRS",
  "source_timestamp": "2025-11-22T12:00:00Z",
  "metrics": [
    {
      "parameter_key": "project:YOUR_PROJECT_UUID:voltage",
      "value": 230.5,
      "quality": 192,
      "attributes": {
        "unit": "V"
      }
    }
  ],
  "config_version": "v1.0"
}
```

**Get valid UUIDs from database:**
```bash
# Kubernetes
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c \
  "SELECT d.id as device_id, s.id as site_id, p.id as project_id 
   FROM devices d 
   JOIN sites s ON d.site_id=s.id 
   JOIN projects p ON s.project_id=p.id 
   LIMIT 1;"

# Docker Compose
docker exec nsready_db psql -U postgres -d nsready -c \
  "SELECT d.id as device_id, s.id as site_id, p.id as project_id 
   FROM devices d 
   JOIN sites s ON d.site_id=s.id 
   JOIN projects p ON s.project_id=p.id 
   LIMIT 1;"
```

---

### Step 2: Send Dashboard Input (Simulate Device)

**Send event to ingestion API:**

```bash
# Kubernetes (with port-forward)
kubectl port-forward -n nsready-tier2 svc/collector-service 8001:8001

# In another terminal
curl -X POST http://localhost:8001/v1/ingest \
  -H "Content-Type: application/json" \
  -d @collector_service/tests/sample_event.json
```

**Expected Response:**
```json
{
  "status": "queued",
  "trace_id": "abc123..."
}
```

**Verify API accepted event:**
```bash
# Check health endpoint
curl http://localhost:8001/v1/health | jq

# Check metrics
curl http://localhost:8001/metrics | grep ingest_events_total
```

---

### Step 3: Verify NSReady Ingestion

**Check worker logs (Kubernetes):**
```bash
kubectl logs -n nsready-tier2 -l app=collector-service --tail=50 | \
  grep -E "(DB commit OK|inserted.*rows|queued)"
```

**Check worker logs (Docker Compose):**
```bash
docker logs collector_service --tail=50 | \
  grep -E "(DB commit OK|inserted.*rows|queued)"
```

**Expected:**
- ✅ "DB commit OK → acked X messages"
- ✅ "inserted X rows"
- ✅ No errors

**Check queue depth:**
```bash
curl http://localhost:8001/v1/health | jq .queue_depth
# Should be 0 or very low (< 5)
```

---

### Step 4: Verify Database Storage

**Count rows in ingest_events:**

```bash
# Kubernetes
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c \
  "SELECT COUNT(*) as total_rows FROM public.ingest_events;"

# Docker Compose
docker exec nsready_db psql -U postgres -d nsready -c \
  "SELECT COUNT(*) as total_rows FROM public.ingest_events;"
```

**Verify latest data:**
```bash
# Kubernetes
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c \
  "SELECT device_id, parameter_key, time, value, quality, created_at 
   FROM public.ingest_events 
   ORDER BY created_at DESC 
   LIMIT 5;"

# Docker Compose
docker exec nsready_db psql -U postgres -d nsready -c \
  "SELECT device_id, parameter_key, time, value, quality, created_at 
   FROM public.ingest_events 
   ORDER BY created_at DESC 
   LIMIT 5;"
```

**Success Criteria:**
- ✅ Row count increases after ingestion
- ✅ Latest rows have recent `created_at` timestamps
- ✅ Data matches what you sent (device_id, parameter_key, value)

---

### Step 5: Verify SCADA Views

**Check v_scada_latest (latest values per device/parameter):**

```bash
# Kubernetes
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c \
  "SELECT device_id, parameter_key, time, value, quality 
   FROM v_scada_latest 
   ORDER BY time DESC 
   LIMIT 5;"

# Docker Compose
docker exec nsready_db psql -U postgres -d nsready -c \
  "SELECT device_id, parameter_key, time, value, quality 
   FROM v_scada_latest 
   ORDER BY time DESC 
   LIMIT 5;"
```

**Check v_scada_history (full history):**

```bash
# Kubernetes
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c \
  "SELECT COUNT(*) as history_rows FROM v_scada_history;"

# Docker Compose
docker exec nsready_db psql -U postgres -d nsready -c \
  "SELECT COUNT(*) as history_rows FROM v_scada_history;"
```

**Success Criteria:**
- ✅ `v_scada_latest` shows your device/parameter with latest value
- ✅ `v_scada_history` contains historical data
- ✅ Values match what you sent

---

### Step 6: Verify SCADA Export

**Option A: Query SCADA views directly (for SCADA systems)**

```bash
# Test SCADA connection
./scripts/test_scada_connection.sh
```

**Option B: Export SCADA data to file**

The export script automatically detects your environment (Kubernetes or Docker Compose):

```bash
# Export latest SCADA values (TXT format) - auto-detects environment
./scripts/export_scada_data.sh --latest --format txt

# Export latest SCADA values (CSV format)
./scripts/export_scada_data.sh --latest --format csv

# Export to specific file (useful for testing)
./scripts/export_scada_data.sh --latest --format txt --output my_export.txt

# Export full history
./scripts/export_scada_data.sh --history --format txt

# Export both latest and history
./scripts/export_scada_data.sh --latest --history --format csv

# Docker Compose: specify container name if needed
DB_CONTAINER=nsready_db ./scripts/export_scada_data.sh --latest --format txt

# Kubernetes: specify namespace and pod if needed
NS=nsready-tier2 DB_POD=nsready-db-0 ./scripts/export_scada_data.sh --latest --format txt
```

**Verify export file:**
```bash
# Check exported file
cat scada_latest_*.txt
# or if using --output
cat my_export.txt

# Should contain:
# - device_id
# - parameter_key
# - value
# - timestamp
# - quality
```

**Success Criteria:**
- ✅ Export file created
- ✅ Export file contains your test data
- ✅ Values match what you sent
- ✅ File is not empty

---

## Automated Test Scripts

### Basic Data Flow Test

**Full end-to-end test:**

```bash
./scripts/test_data_flow.sh
```

**What it does:**
1. ✅ Auto-detects environment (Kubernetes or Docker Compose)
2. ✅ Auto-detects registry (device, site, project, parameters)
3. ✅ Creates test event with valid UUIDs
4. ✅ Sends to `/v1/ingest` API
5. ✅ Waits for queue to drain
6. ✅ Verifies data in `ingest_events` table
7. ✅ Verifies data in `v_scada_latest` view
8. ✅ Verifies data in `v_scada_history` view
9. ✅ Exports SCADA data (now working with both environments)
10. ✅ Generates test report

**Note:** For Docker Compose, you may need to specify the container name:
```bash
DB_CONTAINER=nsready_db ./scripts/test_data_flow.sh
```

**Output:**
- Test report in `tests/reports/DATA_FLOW_TEST_*.md`
- Pass/fail status for each step
- Detailed logs

---

### Batch Ingestion Test

**Test sending multiple events in batches:**

```bash
# Sequential batch (default: 50 events)
./scripts/test_batch_ingestion.sh --count 100 --sequential

# Parallel batch
./scripts/test_batch_ingestion.sh --count 100 --parallel

# Both sequential and parallel
./scripts/test_batch_ingestion.sh --count 50
```

**What it tests:**
- ✅ Sequential ingestion (one event at a time)
- ✅ Parallel ingestion (multiple events concurrently)
- ✅ Throughput measurement (events/second)
- ✅ Queue handling under batch load
- ✅ Database insertion verification

**Output:**
- Test report in `tests/reports/BATCH_INGESTION_TEST_*.md`
- Ingestion rates for both modes
- Success/failure counts

---

### Stress/Load Test

**Test system under high load:**

```bash
# Default: 1000 events over 60 seconds at 50 RPS
./scripts/test_stress_load.sh

# Custom: 5000 events over 120 seconds at 100 RPS
./scripts/test_stress_load.sh --events 5000 --duration 120 --rate 100
```

**What it tests:**
- ✅ Sustained high-volume ingestion
- ✅ Queue depth monitoring over time
- ✅ System stability under load
- ✅ Throughput measurement
- ✅ Error rate tracking
- ✅ Database performance

**Output:**
- Test report in `tests/reports/STRESS_LOAD_TEST_*.md`
- Queue depth over time graph
- Success rate and throughput metrics
- Recommendations for scaling

---

### Multi-Customer Data Flow Test

**Test data flow with multiple customers:**

```bash
# Test with 5 customers (default)
./scripts/test_multi_customer_flow.sh

# Test with 10 customers
./scripts/test_multi_customer_flow.sh --customers 10
```

**What it tests:**
- ✅ Data ingestion for multiple customers
- ✅ Tenant isolation verification
- ✅ Per-customer data separation
- ✅ Database integrity across customers

**Output:**
- Test report in `tests/reports/MULTI_CUSTOMER_FLOW_TEST_*.md`
- Per-customer results
- Tenant isolation verification
- Data separation confirmation

---

### Negative Test Cases

**Test system behavior with invalid data:**

```bash
./scripts/test_negative_cases.sh
```

**What it tests:**
- ✅ Missing required fields (project_id, site_id, device_id, etc.)
- ✅ Invalid UUID formats
- ✅ Non-existent parameter keys
- ✅ Invalid data types (strings instead of numbers)
- ✅ Malformed JSON
- ✅ Empty requests
- ✅ Non-existent device references

**Expected behavior:**
- All invalid requests should be rejected with appropriate HTTP status codes (400, 422)
- No invalid data should be inserted into the database
- Error messages should be clear and helpful

**Output:**
- Test report in `tests/reports/NEGATIVE_TEST_*.md`
- Detailed results for each test case
- Data integrity verification (should be 0 rows inserted)

---

## Testing Checklist

### Pre-Test Setup
- [ ] Services running (collector-service, database, NATS)
- [ ] Port-forwarding active (if using Kubernetes)
- [ ] Registry seeded (customers, projects, sites, devices, parameters)
- [ ] Valid UUIDs available for test event

### Basic Data Flow Test
- [ ] **Step 1**: Dashboard input sent to `/v1/ingest` ✅
- [ ] **Step 2**: API returns `{"status": "queued"}` ✅
- [ ] **Step 3**: Worker logs show "DB commit OK" ✅
- [ ] **Step 4**: Database row count increases ✅
- [ ] **Step 5**: Data visible in `ingest_events` table ✅
- [ ] **Step 6**: Data visible in `v_scada_latest` view ✅
- [ ] **Step 7**: Data visible in `v_scada_history` view ✅
- [ ] **Step 8**: SCADA export contains test data ✅

### Batch Ingestion Test
- [ ] Sequential batch test passes
- [ ] Parallel batch test passes
- [ ] Throughput rates measured
- [ ] Queue drains successfully

### Stress/Load Test
- [ ] System handles target RPS
- [ ] Queue depth remains stable
- [ ] Success rate > 95%
- [ ] No system errors or crashes

### Multi-Customer Test
- [ ] All customers' data ingested successfully
- [ ] Tenant isolation verified
- [ ] No cross-customer data leakage

### Negative Test Cases
- [ ] All invalid requests rejected
- [ ] Appropriate HTTP status codes returned
- [ ] No invalid data inserted (0 rows)

### Post-Test Verification
- [ ] Queue depth = 0 (all events processed)
- [ ] No errors in worker logs
- [ ] Metrics show success (not errors)
- [ ] SCADA views updated with latest values

---

## Troubleshooting

### Issue: API returns 400 Bad Request

**Check:**
1. Event JSON format is valid
2. Required fields present (project_id, site_id, device_id, metrics)
3. UUIDs are valid and exist in database
4. Parameter keys match parameter_templates table

**Fix:**
```bash
# Validate JSON
cat collector_service/tests/sample_event.json | jq .

# Check UUIDs exist
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c \
  "SELECT id FROM devices WHERE id = 'YOUR_DEVICE_ID';"
```

---

### Issue: Data not appearing in database

**Check:**
1. Worker is running
2. NATS connection is working
3. Queue depth is draining
4. No database errors in logs

**Fix:**
```bash
# Check worker logs
kubectl logs -n nsready-tier2 -l app=collector-service --tail=100

# Check queue depth
curl http://localhost:8001/v1/health | jq .queue_depth

# Check NATS
kubectl logs -n nsready-tier2 -l app=collector-service | grep -i nats
```

---

### Issue: SCADA views empty

**Check:**
1. Data exists in `ingest_events` table
2. Views are created correctly
3. Views are queryable

**Fix:**
```bash
# Check if views exist
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c \
  "SELECT table_name FROM information_schema.views 
   WHERE table_name IN ('v_scada_latest', 'v_scada_history');"

# Refresh views (if needed)
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c \
  "REFRESH MATERIALIZED VIEW v_scada_latest;"  # If materialized
```

---

### Issue: SCADA export empty or fails

**Check:**
1. SCADA views contain data
2. Export script has execute permissions
3. Export script can access database
4. Correct container name for Docker Compose

**Fix:**
```bash
# Make script executable
chmod +x scripts/export_scada_data.sh

# Test export (Docker Compose)
DB_CONTAINER=nsready_db ./scripts/export_scada_data.sh --latest --format txt --output test.txt

# Test export (Kubernetes)
NS=nsready-tier2 DB_POD=nsready-db-0 ./scripts/export_scada_data.sh --latest --format txt --output test.txt

# Verify export file
cat test.txt
```

---

## Performance Testing

**Test with multiple events:**

```bash
# Send 10 events
for i in {1..10}; do
  curl -X POST http://localhost:8001/v1/ingest \
    -H "Content-Type: application/json" \
    -d @collector_service/tests/sample_event.json
  sleep 0.5
done

# Verify all processed
curl http://localhost:8001/v1/health | jq .queue_depth
# Should be 0 after a few seconds
```

**Monitor metrics:**
```bash
# Watch metrics
watch -n 1 'curl -s http://localhost:8001/metrics | grep ingest_events_total'
```

---

## Integration with CI/CD

**Add to CI/CD pipeline:**

```yaml
# .github/workflows/build-test-deploy.yml
- name: Test data flow
  run: |
    docker compose up -d
    sleep 10
    ./scripts/test_data_flow.sh || exit 1
```

---

## Summary

**Data Flow Testing** verifies:
- ✅ Dashboard input → NSReady ingestion works
- ✅ Data stored in database correctly
- ✅ SCADA views updated
- ✅ SCADA export works

**When to Run:**
- ✅ When testing new device integrations
- ✅ When verifying SCADA export works
- ✅ When debugging data flow issues
- ✅ During end-to-end integration testing
- ✅ After code changes to ingestion pipeline

**This is separate from tenant isolation tests** (which test security/access control).

---

**Current Status**: ✅ **Data flow testing guide complete**

**Recent Updates** (2025-11-22):
- ✅ SCADA export script now supports both Kubernetes and Docker Compose
- ✅ Export script auto-detects environment
- ✅ Added `--output` parameter for single file export
- ✅ Step 5 (SCADA export) now passes successfully in automated test
- ✅ Updated container names to match actual Docker Compose setup
- ✅ **NEW**: Added batch ingestion test script
- ✅ **NEW**: Added stress/load test script
- ✅ **NEW**: Added multi-customer data flow test script
- ✅ **NEW**: Added negative test cases script

**Available Test Scripts**:
1. `test_data_flow.sh` - Basic end-to-end data flow test
2. `test_batch_ingestion.sh` - Batch ingestion (sequential/parallel)
3. `test_stress_load.sh` - Stress/load testing
4. `test_multi_customer_flow.sh` - Multi-customer tenant isolation
5. `test_negative_cases.sh` - Invalid data validation

**Next Steps**:
1. Run `./scripts/test_data_flow.sh` to test your setup (use `DB_CONTAINER=nsready_db` for Docker Compose)
2. Run batch ingestion test: `./scripts/test_batch_ingestion.sh --count 100`
3. Run stress test: `./scripts/test_stress_load.sh --events 1000 --rate 50`
4. Run multi-customer test: `./scripts/test_multi_customer_flow.sh --customers 5`
5. Run negative tests: `./scripts/test_negative_cases.sh`
6. Use manual steps for detailed debugging
7. Add to CI/CD for automated validation

