# NSReady Platform - Production Hardening Guide

This guide covers essential production hardening steps for the NSReady platform deployment.

## 1. Secrets & Tokens

### 1.1 Replace Development Secrets

**Current State:** Development secrets are in use (e.g., `devtoken`, `CHANGE_ME_IN_PRODUCTION`)

**Production Actions:**

```bash
# Create production secrets
kubectl create secret generic nsready-secrets \
  --from-literal=POSTGRES_USER=nsready_prod_user \
  --from-literal=POSTGRES_PASSWORD='<strong-random-password>' \
  --from-literal=ADMIN_TOOL_TOKEN='<strong-api-token>' \
  --from-literal=NATS_TOKEN='<strong-nats-token>' \
  --namespace=nsready-tier2 \
  --dry-run=client -o yaml | kubectl apply -f -

# Update JWT secret
kubectl delete secret jwt-secret -n nsready-tier2
kubectl create secret generic jwt-secret \
  --from-literal=JWT_SECRET=$(openssl rand -hex 32) \
  -n nsready-tier2

# AWS credentials (if using S3 backups)
kubectl create secret generic aws-credentials \
  --from-literal=access-key-id='<aws-access-key>' \
  --from-literal=secret-access-key='<aws-secret-key>' \
  -n nsready-tier2
```

### 1.2 Secret Rotation Policy

**Rotation Schedule:** Quarterly (every 3 months)

**Documentation Template:**
```yaml
Secrets:
  - Name: nsready-secrets
    Owner: Platform Team
    Last Rotated: YYYY-MM-DD
    Next Rotation: YYYY-MM-DD
    Rotation Method: kubectl create secret (see above)
    
  - Name: jwt-secret
    Owner: Security Team
    Last Rotated: YYYY-MM-DD
    Next Rotation: YYYY-MM-DD
    Rotation Method: Generate new secret, update deployments
    
  - Name: aws-credentials
    Owner: DevOps Team
    Last Rotated: YYYY-MM-DD
    Next Rotation: YYYY-MM-DD
    Rotation Method: AWS IAM key rotation
```

**Rotation Checklist:**
- [ ] Generate new secret values
- [ ] Update Kubernetes secrets
- [ ] Restart affected deployments
- [ ] Verify services are healthy
- [ ] Update documentation with new rotation date
- [ ] Test backup/restore with new credentials

## 2. TLS & Ingress

### 2.1 Domain Configuration

```bash
# Point your domain to the ingress
# DNS Records:
#   admin.nsready.example.com → Ingress IP
#   collector.nsready.example.com → Ingress IP

# Get ingress IP
kubectl get ingress -n nsready-tier2 -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}'
```

### 2.2 Cert-Manager Configuration

```bash
# Verify cert-manager is installed
kubectl get pods -n cert-manager

# Check ClusterIssuer
kubectl get clusterissuer letsencrypt-prod

# If not exists, apply:
kubectl apply -f deploy/k8s/cert-manager-issuer.yaml

# Verify certificate issuance
kubectl get certificate -n nsready-tier2
kubectl describe certificate nsready-tls-secret -n nsready-tier2
```

### 2.3 HTTPS Verification

```bash
# Test HTTPS endpoints
curl -v https://admin.nsready.example.com/health
curl -v https://collector.nsready.example.com/v1/health

# Verify certificate
openssl s_client -connect admin.nsready.example.com:443 -servername admin.nsready.example.com
```

## 3. Autoscaling & Resources

### 3.1 Resource Requests & Limits

**Current Configuration:**
- Admin Tool: 100m CPU / 256Mi RAM (requests), 500m CPU / 512Mi RAM (limits)
- Collector Service: 250m CPU / 512Mi RAM (requests), 1000m CPU / 1Gi RAM (limits)

**Production Recommendations:**

```yaml
# Update deploy/k8s/admin_tool-deployment.yaml
resources:
  requests:
    cpu: "200m"
    memory: "512Mi"
  limits:
    cpu: "1000m"
    memory: "1Gi"

# Update deploy/k8s/collector_service-deployment.yaml
resources:
  requests:
    cpu: "500m"
    memory: "1Gi"
  limits:
    cpu: "2000m"
    memory: "2Gi"
```

### 3.2 HPA Validation

```bash
# Check HPA status
kubectl get hpa collector-service-hpa -n nsready-tier2

# Test scale-out (generate load)
# Monitor with: kubectl get hpa -w -n nsready-tier2

# Test scale-in (reduce load)
# Verify pods scale down after cooldown period
```

**HPA Configuration:**
```yaml
minReplicas: 2
maxReplicas: 10
targetCPUUtilizationPercentage: 70
targetMemoryUtilizationPercentage: 80
```

### 3.3 Worker Configuration Tuning

**Based on Observed Metrics:**

```bash
# Check current P95 latency
curl -s http://localhost:9090/api/v1/query?query=histogram_quantile\(0.95,rate\(ingest_latency_seconds_bucket\[5m\]\)\)\)

# Check CPU utilization
kubectl top pods -n nsready-tier2 -l app=collector-service

# Adjust based on metrics:
# - If P95 > 2s: Increase WORKER_POOL_SIZE
# - If CPU < 50%: Can increase batch sizes
# - If CPU > 80%: Reduce batch sizes or increase replicas
```

**Recommended Settings:**
```yaml
WORKER_POOL_SIZE: "8"  # Increase if P95 latency high
WORKER_BATCH_SIZE: "100"  # Increase if CPU allows
WORKER_BATCH_TIMEOUT: "0.5"  # Adjust based on throughput
NATS_PULL_BATCH_SIZE: "200"  # Increase if queue depth grows
```

## 4. Observability

### 4.1 Grafana Dashboard

**Create "NSReady Ops" Dashboard:**

Key Panels:
1. **Ingest Rate** (events/sec)
   - Query: `rate(ingest_events_total[5m])`
   - Alert: > 1000 events/sec

2. **Queue Depth**
   - Query: `ingest_queue_depth`
   - Alert: > 200

3. **Error Rate**
   - Query: `rate(ingest_errors_total[5m]) / rate(ingest_events_total[5m])`
   - Alert: > 0.5%

4. **P95 Latency**
   - Query: `histogram_quantile(0.95, rate(ingest_latency_seconds_bucket[5m]))`
   - Alert: > 2s

5. **Database Latency**
   - Query: `db_latency_seconds`
   - Alert: > 1s

6. **System Uptime**
   - Query: `system_uptime_seconds`

**Dashboard Import:**
```bash
# Use deploy/monitoring/grafana-dashboards/dashboard.json
# Or create via Grafana UI at http://localhost:3000
```

### 4.2 Alert Rules

**Prometheus Alert Rules** (in `deploy/monitoring/prometheus.yaml`):

```yaml
groups:
  - name: nsready_alerts
    interval: 30s
    rules:
      - alert: HighErrorRate
        expr: rate(ingest_errors_total[5m]) / rate(ingest_events_total[5m]) > 0.005
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value | humanizePercentage }}"

      - alert: HighQueueDepth
        expr: ingest_queue_depth > 200
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Queue depth is high"
          description: "Queue depth is {{ $value }} events"

      - alert: DatabaseConnectionFailure
        expr: db_status{status="disconnected"} == 1
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Database connection failure"
          description: "Database connection is down"

      - alert: CronJobFailure
        expr: kube_job_status_failed{job_name=~"postgres-backup.*"} > 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Backup job failed"
          description: "Backup job {{ $labels.job_name }} has failed"
```

**Alertmanager Configuration:**
- Route to on-call team
- Configure notification channels (Slack, PagerDuty, email)
- Set up escalation policies

## 5. CI/CD

### 5.1 GitHub Repository Secrets

**Required Secrets:**
```
KUBECONFIG              # Base64 encoded kubeconfig
POSTGRES_PASSWORD       # Production database password
JWT_SECRET              # JWT signing secret
NATS_TOKEN              # NATS authentication token
GITHUB_TOKEN            # Auto-provided by GitHub Actions
```

**Setup:**
1. Go to GitHub repo → Settings → Secrets and variables → Actions
2. Add each secret with production values
3. Verify secrets are used in `.github/workflows/build-test-deploy.yml`

### 5.2 Branch Protection

**Protect `main` Branch:**
```yaml
Required Status Checks:
  - build-and-test (must pass)
  - make test (must pass)
  - make benchmark (must pass)

Required Reviews:
  - At least 1 approval
  - Dismiss stale reviews
  - Require review from code owners

Restrictions:
  - Do not allow force pushes
  - Do not allow deletions
```

**GitHub Settings:**
1. Repo → Settings → Branches → Add rule for `main`
2. Enable "Require status checks to pass before merging"
3. Select: `build-and-test`, `make test`, `make benchmark`
4. Enable "Require pull request reviews before merging"

### 5.3 CI/CD Workflow Verification

```bash
# Test locally before pushing
make test
make benchmark

# Verify workflow file syntax
# Check .github/workflows/build-test-deploy.yml

# Test deployment on a feature branch first
```

## 6. Operational SOPs

### 6.1 Weekly Maintenance

**ANALYZE Database:**
```bash
# Add to weekly cron or scheduled job
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "ANALYZE;"
```

**Index Bloat Check:**
```bash
# Check for bloated indexes
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "
    SELECT schemaname, tablename, indexname,
           pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
           n_dead_tup, n_live_tup,
           CASE WHEN n_live_tup > 0 
             THEN (n_dead_tup::float / n_live_tup * 100)::numeric(5,2)
             ELSE 0 
           END AS dead_tuple_pct
    FROM pg_stat_user_indexes
    WHERE n_dead_tup > 1000
    ORDER BY n_dead_tup DESC;
  "

# If dead_tuple_pct > 10%, run REINDEX
```

### 6.2 Monthly Restore Drill

**Procedure:**
1. Create test namespace: `kubectl create ns nsready-test`
2. Restore database to test namespace
3. Verify data integrity
4. Test ingestion flow
5. Document any issues
6. Clean up test namespace

**Commands:**
```bash
# See RUNBOOK_Restore.md for detailed steps
# Quick test:
kubectl apply -f deploy/k8s/restore-job.yaml
kubectl logs -f job/postgres-restore -n nsready-tier2
```

### 6.3 Incident Response Template

**Incident Capture Form:**

```markdown
## Incident Report

**Timestamp:** YYYY-MM-DD HH:MM:SS UTC
**Severity:** Critical / High / Medium / Low
**Affected Services:** [List services]

### Symptoms
- [ ] Service unavailable
- [ ] High error rate
- [ ] High queue depth
- [ ] Database connection issues
- [ ] Performance degradation

### Trace IDs
- [List relevant trace_ids from logs]

### Pod Logs
```bash
# Collector Service
kubectl logs -n nsready-tier2 -l app=collector-service --tail=100

# Admin Tool
kubectl logs -n nsready-tier2 -l app=admin-tool --tail=100

# Database
kubectl logs -n nsready-tier2 nsready-db-0 --tail=100

# NATS
kubectl logs -n nsready-tier2 nsready-nats-0 --tail=100
```

### Metrics at Time of Incident
- Ingest Rate: [value]
- Queue Depth: [value]
- Error Rate: [value]
- P95 Latency: [value]
- CPU Utilization: [value]
- Memory Utilization: [value]

### Root Cause
[Description of root cause]

### Resolution
[Steps taken to resolve]

### Prevention
[Actions to prevent recurrence]

### Follow-up
- [ ] Post-mortem scheduled
- [ ] Runbook updated
- [ ] Monitoring improved
- [ ] Alerts added/updated
```

## 7. Production Readiness Checklist

### Pre-Deployment
- [ ] All secrets rotated to production values
- [ ] TLS certificates configured and valid
- [ ] Domain DNS records configured
- [ ] Resource limits set appropriately
- [ ] HPA tested (scale-out and scale-in)
- [ ] Worker pool size tuned based on metrics

### Monitoring
- [ ] Grafana dashboard created and pinned
- [ ] Alert rules configured and tested
- [ ] Alertmanager routing configured
- [ ] Notification channels tested
- [ ] On-call rotation established

### CI/CD
- [ ] GitHub secrets configured
- [ ] Branch protection enabled
- [ ] Required status checks configured
- [ ] Deployment workflow tested

### Operations
- [ ] RUNBOOK_Restore.md reviewed
- [ ] Weekly ANALYZE scheduled
- [ ] Monthly restore drill scheduled
- [ ] Incident response template ready
- [ ] Team trained on runbooks

### Security
- [ ] All default passwords changed
- [ ] JWT secret rotated
- [ ] API tokens rotated
- [ ] AWS credentials rotated (if applicable)
- [ ] RBAC policies reviewed
- [ ] Network policies applied
- [ ] Security contexts configured (runAsNonRoot)

---

**Last Updated:** 2025-11-10  
**Version:** 1.0  
**Owner:** Platform Team


