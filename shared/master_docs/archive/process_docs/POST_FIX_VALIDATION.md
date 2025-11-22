# Post-Fix Validation Guide

This document provides a quick 5-step verification process to confirm the NS-Ready Platform ingestion pipeline is working correctly after fixes.

> **Quick Test:** For automated end-to-end testing, use `scripts/test_drive.sh` which auto-detects registry data and runs comprehensive tests.

## Prerequisites

- Kubernetes cluster with `nsready-tier2` namespace
- Port-forwarding active:
  - `kubectl port-forward -n nsready-tier2 svc/collector-service 8001:8001`
  - `kubectl port-forward -n nsready-tier2 svc/grafana 3000:3000`
  - `kubectl port-forward -n nsready-tier2 svc/prometheus 9090:9090`
- Sample event file: `collector_service/tests/sample_event.json`

---

## Step 1: Verify Worker Logs Show Commit Success

**Expected Output:**
- `DB target: db=nsready, schema=public, user=postgres`
- `DB commit OK → acked X messages`
- `post-commit count = X` (debug logging)

**Command:**
```bash
kubectl logs -n nsready-tier2 -l app=collector-service --tail=200 | \
  grep -E "(DB target|DB commit OK|post-commit count|inserted.*rows)" | tail -20
```

**Success Criteria:**
- ✅ See "DB commit OK → acked" messages
- ✅ Post-commit count increases with each batch
- ✅ No "batch insert failed" errors

---

## Step 2: Confirm Database Rows Are Landing

**Expected Output:**
- Row count increases with each ingest
- Latest rows show recent `created_at` timestamps

**Commands:**
```bash
# A) Fast truth - total count
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c \
  "SELECT COUNT(*) as total_rows FROM public.ingest_events;"

# B) Latest arrival window
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c \
  "SELECT device_id, time as source_timestamp, created_at as received_timestamp, source as protocol \
   FROM public.ingest_events ORDER BY created_at DESC LIMIT 10;"
```

**Success Criteria:**
- ✅ `COUNT(*)` > 0 and increases with new ingests
- ✅ Latest rows have recent `received_timestamp` values
- ✅ `device_id`, `source_timestamp`, `protocol` are populated

---

## Step 3: Verify Metrics Reflect Committed Success

**Expected Output:**
- `ingest_events_total{status="success"}` matches DB row count (approximately)
- `ingest_queue_depth` ≈ 0 after processing
- `ingest_errors_total` = 0 (or minimal)

**Command:**
```bash
curl -s http://localhost:8001/metrics | \
  grep -E "ingest_events_total|ingest_errors_total|ingest_queue_depth" | head -10
```

**Success Criteria:**
- ✅ `ingest_events_total{status="success"}` increments with each successful commit
- ✅ `ingest_queue_depth` decreases to ≈ 0 after processing
- ✅ `ingest_errors_total` = 0 (or only historical errors)

**Note:** Success counter may be slightly higher than DB count if events are still processing, but should converge.

---

## Step 4: Check NATS Consumer State

**Expected Output:**
- Unprocessed Messages: 0
- Outstanding Acks: 0
- Redelivered Messages: 0
- Delivered Seq matches Stream Last Sequence (after processing)

**Command:**
```bash
kubectl run nats-consumer-check --rm -i --restart=Never \
  --image=natsio/nats-box:latest \
  --namespace=nsready-tier2 \
  --env="NATS_URL=nats://nsready-nats:4222" \
  -- sh -c '
    echo "=== Stream Info ===" && \
    nats stream info INGRESS | grep -E "(Messages|Last Sequence)" && \
    echo "" && \
    echo "=== Consumer Info ===" && \
    nats consumer info INGRESS ingest_workers | \
      grep -E "(Unprocessed|Outstanding|Redelivered|Delivered|Num.*Pending)"
  '
```

**Success Criteria:**
- ✅ Unprocessed Messages: 0
- ✅ Outstanding Acks: 0
- ✅ Redelivered Messages: 0
- ✅ Consumer is bound to `ingress.events` subject

---

## Step 5: End-to-End Test

**Expected Output:**
- Event queued successfully
- Worker processes within 1-2 seconds
- Database count increases by expected number of metrics
- Queue depth returns to ≈ 0

**Commands:**
```bash
# Send test event
curl -s -X POST http://localhost:8001/v1/ingest \
  -H "Content-Type: application/json" \
  -d @collector_service/tests/sample_event.json | jq '.'

# Check queue depth
curl -s http://localhost:8001/v1/health | jq '.queue_depth'

# Wait 3-5 seconds, then check DB count
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c \
  "SELECT COUNT(*) FROM public.ingest_events;"

# Check worker logs
kubectl logs -n nsready-tier2 -l app=collector-service --tail=50 | \
  grep -E "(DB commit OK|post-commit count)" | tail -3
```

**Success Criteria:**
- ✅ Event returns `{"status":"queued","trace_id":"..."}`
- ✅ Queue depth increases briefly, then returns to ≈ 0
- ✅ Database count increases by number of metrics in event
- ✅ Worker logs show "DB commit OK → acked"

---

## Quick Triage Guide

### Issue: DB count doesn't move, but logs say "Inserted → Acked"

**Check:**
1. Verify you're reading the same DB/schema the worker logs at startup:
   ```bash
   kubectl logs -n nsready-tier2 -l app=collector-service | grep "DB target"
   ```
2. Compare with your query:
   ```bash
   kubectl exec -n nsready-tier2 nsready-db-0 -- \
     psql -U postgres -d nsready -c \
     "SELECT current_database(), current_schema();"
   ```
3. Try a manual insert to verify DB is writable:
   ```bash
   kubectl exec -n nsready-tier2 nsready-db-0 -- \
     psql -U postgres -d nsready -c \
     "INSERT INTO public.ingest_events (time, device_id, parameter_key, value, quality, source, event_id, attributes) \
      VALUES (NOW(), 'bc2c5e47-f17e-46f0-b5e7-76b214f4f6ad', 'test', 1.0, 192, 'TEST', 'manual-test', '{}'::jsonb);"
   ```

### Issue: Queue doesn't drain

**Check:**
1. Verify worker is pulling from the current durable consumer:
   ```bash
   kubectl logs -n nsready-tier2 -l app=collector-service | grep "subscribed to"
   ```
2. Restart worker pods to rebind:
   ```bash
   kubectl delete pod -n nsready-tier2 -l app=collector-service
   ```
3. Check NATS stream/consumer state (Step 4 above)

### Issue: Metrics show success > DB rows

**Check:**
1. Verify success counter is only incremented after commit (already fixed)
2. Check for transaction rollbacks:
   ```bash
   kubectl logs -n nsready-tier2 -l app=collector-service | grep -E "(integrity error|batch insert failed)"
   ```
3. Verify foreign key constraints are satisfied (device_id, parameter_key exist)

---

## Acceptance Checklist

- [ ] Worker logs: "DB commit OK → acked" for new events
- [ ] `COUNT(*)` on `public.ingest_events` increases with each ingest
- [ ] NATS consumer: pending=0, redeliveries=0
- [ ] `/metrics`: success ≈ committed inserts; queue_depth≈0, errors=0
- [ ] Grafana shows ingest rate > 0, error rate = 0

---

## Optional: Performance Tuning

Once the pipeline is stable, you can tune for higher throughput:

1. **Increase Worker Pool Size:**
   ```bash
   kubectl set env deployment/collector-service -n nsready-tier2 \
     WORKER_POOL_SIZE=8
   ```

2. **Increase Batch Size:**
   ```bash
   kubectl set env deployment/collector-service -n nsready-tier2 \
     WORKER_BATCH_SIZE=50
   ```

3. **Monitor Impact:**
   - Check Grafana dashboard for throughput trends
   - Monitor queue depth (should stay near 0)
   - Watch for increased latency

---

## Reference: Pipeline Flow

```
Device → Listener (POST /v1/ingest) → NATS JetStream (ingress.events) 
  → Worker (pull consumer) → Database (public.ingest_events) → Metrics
```

**Key Components:**
- **Collector Service**: FastAPI endpoint at `:8001/v1/ingest`
- **NATS JetStream**: Stream `INGRESS`, subject `ingress.events`
- **Worker**: Durable consumer `ingest_workers`, pulls in batches
- **Database**: TimescaleDB hypertable `ingest_events` on `time` column
- **Metrics**: Prometheus metrics at `:8001/metrics`

---

---

## Automated Test Scripts

### Basic Data Flow Test

For end-to-end data flow validation, use:

```bash
# Docker Compose
DB_CONTAINER=nsready_db ./scripts/test_data_flow.sh

# Kubernetes
./scripts/test_drive.sh
```

**What it does:**
1. Auto-detects registry data (devices, sites, projects, parameters) from the database
2. Builds a valid NormalizedEvent payload automatically
3. Tests golden path (ingest → queue → DB)
4. Verifies SCADA views
5. Tests SCADA export
6. Generates a pass/fail report in `tests/reports/DATA_FLOW_TEST_*.md`

### Additional Test Scripts

**Batch Ingestion Test:**
```bash
./scripts/test_batch_ingestion.sh --count 100
```
Tests sequential and parallel batch ingestion with throughput measurement.

**Stress/Load Test:**
```bash
./scripts/test_stress_load.sh --events 1000 --rate 50
```
Tests system under sustained high load with queue depth monitoring.

**Multi-Customer Test:**
```bash
./scripts/test_multi_customer_flow.sh --customers 5
```
Tests data flow with multiple customers and verifies tenant isolation.

**Negative Test Cases:**
```bash
./scripts/test_negative_cases.sh
```
Tests system behavior with invalid data (missing fields, wrong formats, etc.).

**Requirements:**
- Services running (Docker Compose or Kubernetes)
- `jq` (optional, for better JSON handling)
- Port-forwarding will be set up automatically (Kubernetes)
- Registry must be seeded (customers, projects, sites, devices, parameter_templates)

**See Also:**
- `scripts/TEST_SCRIPTS_README.md` - Complete test scripts documentation
- `master_docs/DATA_FLOW_TESTING_GUIDE.md` - Comprehensive testing guide

**Last Updated:** 2025-11-22  
**Version:** 2.0
