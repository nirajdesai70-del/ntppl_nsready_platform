# NSReady Platform - Restore Runbook

This runbook provides step-by-step instructions for restoring the NSReady platform from backups.

## Prerequisites

- `kubectl` configured and connected to the cluster
- Access to the `nsready-tier2` namespace
- Backup files available in the backup PVC or accessible location

## 1. Database Restore

### 1.1 List Available Backups

```bash
# List PostgreSQL backups
kubectl run list-backups --rm -i --restart=Never \
  --image=postgres:15-alpine \
  --namespace=nsready-tier2 \
  -v backup-pvc:/backups \
  -- ls -lh /backups/pg_backup_*.sql.gz
```

### 1.2 Restore PostgreSQL Database

**Option A: Using Restore Job (Recommended)**

```bash
# Edit deploy/k8s/restore-job.yaml to set BACKUP_FILE (or leave empty for latest)
kubectl apply -f deploy/k8s/restore-job.yaml
kubectl logs -f job/postgres-restore -n nsready-tier2
```

**Option B: Manual Restore**

```bash
# Create temporary restore pod
kubectl run postgres-restore-manual --rm -it --restart=Never \
  --image=postgres:15-alpine \
  --namespace=nsready-tier2 \
  -v backup-pvc:/backups \
  --env="POSTGRES_HOST=nsready-db" \
  --env-from=secret:nsready-secrets \
  -- sh -c 'gunzip -c /backups/pg_backup_YYYYMMDD_HHMMSS.sql.gz | \
    PGPASSWORD="${POSTGRES_PASSWORD}" psql -h nsready-db -U "${POSTGRES_USER}" -d nsready'
```

### 1.3 Verify Database Restore

```bash
# Check table count
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "\dt+"

# Check row counts
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "SELECT COUNT(*) FROM ingest_events;"
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "SELECT COUNT(*) FROM measurements;"
```

### 1.4 Run Database Migrations (if needed)

```bash
# Apply all migrations
cat db/migrations/*.sql | kubectl exec -i nsready-db-0 -n nsready-tier2 -- \
  psql -U postgres -d nsready
```

### 1.5 Optimize Database

```bash
# Update statistics
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "ANALYZE;"

# Rebuild indexes
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "REINDEX DATABASE nsready;"
```

### 1.6 Configure TimescaleDB Policies (if using hypertables)

```bash
# Convert to hypertable (if not already)
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "SELECT create_hypertable('ingest_events', 'time', if_not_exists => true);"

# Enable compression
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "ALTER TABLE ingest_events SET (timescaledb.compress, timescaledb.compress_segmentby = 'device_id, parameter_key');"

# Add compression policy (compress after 7 days)
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "SELECT add_compression_policy('ingest_events', interval '7 days');"

# Add retention policy (delete after 90 days)
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "SELECT add_retention_policy('ingest_events', interval '90 days');"
```

## 2. NATS JetStream Restore

### 2.1 List Available JetStream Backups

```bash
# List JetStream backups
kubectl run nats-list --rm -i --restart=Never \
  --image=natsio/nats-box:latest \
  --namespace=nsready-tier2 \
  -v backup-pvc:/backups \
  -- ls -lh /backups/jetstream_*.tar.gz
```

### 2.2 Restore JetStream Stream

**Option A: Using Restore Job (Recommended)**

```bash
# Edit deploy/k8s/nats-restore-job.yaml to set BACKUP_FILE
kubectl apply -f deploy/k8s/nats-restore-job.yaml
kubectl logs -f job/nats-restore -n nsready-tier2
```

**Option B: Manual Restore**

```bash
kubectl run nats-restore-manual --rm -it --restart=Never \
  --image=natsio/nats-box:latest \
  --namespace=nsready-tier2 \
  --overrides='
{
  "spec": {
    "containers": [{
      "name": "nats-restore-manual",
      "image": "natsio/nats-box:latest",
      "command": ["/bin/sh", "-c"],
      "args": ["nats stream restore INGRESS /backups/jetstream_YYYYMMDD_HHMM.tar.gz"],
      "env": [{"name": "NATS_URL", "value": "nats://nsready-nats:4222"}],
      "volumeMounts": [{"name": "backup-storage", "mountPath": "/backups"}]
    }],
    "volumes": [{"name": "backup-storage", "persistentVolumeClaim": {"claimName": "backup-pvc"}}]
  }
}'
```

### 2.3 Verify JetStream Restore

```bash
# Check stream info
kubectl run nats-info --rm -i --restart=Never \
  --image=natsio/nats-box:latest \
  --namespace=nsready-tier2 \
  --env="NATS_URL=nats://nsready-nats:4222" \
  -- nats stream info INGRESS
```

## 3. Service Verification

### 3.1 Port-Forward Services

```bash
# Admin Tool
kubectl port-forward -n nsready-tier2 svc/admin-tool 8000:8000 >/dev/null 2>&1 &

# Collector Service
kubectl port-forward -n nsready-tier2 svc/collector-service 8001:8001 >/dev/null 2>&1 &

# Prometheus (optional)
kubectl port-forward -n nsready-tier2 svc/prometheus 9090:9090 >/dev/null 2>&1 &

# Grafana (optional)
kubectl port-forward -n nsready-tier2 svc/grafana 3000:3000 >/dev/null 2>&1 &
```

### 3.2 Health Checks

```bash
# Admin Tool
curl -s http://localhost:8000/health

# Collector Service
curl -s http://localhost:8001/v1/health

# Expected output:
# {"service":"ok","queue_depth":0,"db":"connected"}
```

### 3.3 Test Data Ingestion

```bash
# Send test event
curl -s -X POST http://localhost:8001/v1/ingest \
  -H "Content-Type: application/json" \
  -d @collector_service/tests/sample_event.json

# Verify in database
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "SELECT COUNT(*) FROM ingest_events;"
```

## 4. Monitoring Verification

### 4.1 Grafana Dashboard

```bash
# Access Grafana (if port-forwarded)
# URL: http://localhost:3000
# Credentials: admin/admin

# Check metrics:
# - Ingest Rate (events/sec)
# - Queue Depth (should be near 0)
# - Error Rate (should be 0)
```

### 4.2 Prometheus Queries

```bash
# Ingest rate
curl -s "http://localhost:9090/api/v1/query?query=rate(ingest_events_total[5m])"

# Queue depth
curl -s "http://localhost:9090/api/v1/query?query=ingest_queue_depth"

# Error rate
curl -s "http://localhost:9090/api/v1/query?query=rate(ingest_errors_total[5m])"
```

### 4.3 Alertmanager

```bash
# Port-forward Alertmanager
kubectl port-forward -n nsready-tier2 svc/alertmanager 9093:9093 >/dev/null 2>&1 &

# Check active alerts
curl -s http://localhost:9093/api/v2/alerts | jq 'length'

# Should return: 0 (no active alerts)
```

## 5. Common Pitfalls & Quick Fixes

### 5.1 Collector Can't Reach Database

**Symptom:** Collector service shows `"db":"disconnected"` in health check

**Fix:**
```bash
# Verify DB_HOST in ConfigMap
kubectl get configmap nsready-config -n nsready-tier2 -o jsonpath='{.data.DB_HOST}'
# Should output: nsready-db

# If incorrect, update ConfigMap
kubectl edit configmap nsready-config -n nsready-tier2
# Set DB_HOST: nsready-db

# Restart collector service
kubectl rollout restart deployment/collector-service -n nsready-tier2
```

### 5.2 Foreign Key Errors on Ingest

**Symptom:** `ERROR: insert or update on table "ingest_events" violates foreign key constraint`

**Fix:**
```bash
# Verify required entities exist
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "
    SELECT COUNT(*) as devices FROM devices;
    SELECT COUNT(*) as projects FROM projects;
    SELECT COUNT(*) as sites FROM sites;
    SELECT COUNT(*) as parameters FROM parameter_templates;
  "

# If counts are 0, restore from a backup that includes registry data
# Or create test data via admin tool API
```

### 5.3 Slow Queries After Restore

**Symptom:** Queries are slow, especially on large tables

**Fix:**
```bash
# Run ANALYZE to update statistics
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "ANALYZE;"

# Rebuild indexes
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "REINDEX DATABASE nsready;"

# Verify indexes exist
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "\d+ ingest_events"
```

### 5.4 NATS Worker Timeout

**Symptom:** Events queued but not processed, worker logs show `nats: timeout`

**Fix:**
```bash
# Verify NATS pod is running
kubectl get pods -n nsready-tier2 -l app=nsready-nats

# Check NATS JetStream status
kubectl exec -n nsready-tier2 nsready-nats-0 -- \
  wget -q -O- http://localhost:8222/jsz | jq '.streams'

# Verify stream exists
kubectl run nats-check --rm -i --restart=Never \
  --image=natsio/nats-box:latest \
  --namespace=nsready-tier2 \
  --env="NATS_URL=nats://nsready-nats:4222" \
  -- nats stream list

# Restart collector service if needed
kubectl rollout restart deployment/collector-service -n nsready-tier2
```

### 5.5 Empty Database After Restore

**Symptom:** Database restored but no tables exist

**Fix:**
```bash
# Run migrations
cat db/migrations/*.sql | kubectl exec -i nsready-db-0 -n nsready-tier2 -- \
  psql -U postgres -d nsready

# Verify tables created
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "\dt+"
```

## 6. Post-Restore Checklist

- [ ] Database restore completed successfully
- [ ] All tables exist and have correct structure
- [ ] Database statistics updated (ANALYZE run)
- [ ] Indexes rebuilt (REINDEX run)
- [ ] TimescaleDB policies configured (if applicable)
- [ ] NATS JetStream stream restored (if applicable)
- [ ] All services healthy (health checks pass)
- [ ] Test ingestion successful
- [ ] Grafana metrics showing correct values
- [ ] No active alerts in Alertmanager
- [ ] Queue depth near zero
- [ ] Error rate is zero

## 7. Emergency Contacts

- **Database Issues:** Check `kubectl logs -n nsready-tier2 nsready-db-0`
- **Collector Issues:** Check `kubectl logs -n nsready-tier2 -l app=collector-service`
- **NATS Issues:** Check `kubectl logs -n nsready-tier2 nsready-nats-0`
- **Monitoring:** Access Grafana at http://localhost:3000 (after port-forward)

## 8. Backup File Naming Convention

- **PostgreSQL:** `pg_backup_YYYYMMDD_HHMMSS.sql.gz`
- **JetStream:** `jetstream_backup_YYYYMMDD_HHMM.tar.gz`

Example: `pg_backup_20251110_200428.sql.gz` = Backup from Nov 10, 2025 at 20:04:28

---

**Last Updated:** 2025-11-10  
**Version:** 1.0


