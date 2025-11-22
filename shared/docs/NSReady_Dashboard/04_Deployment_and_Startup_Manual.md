# Module 4 – Deployment and Startup Manual

_NSReady Data Collection Platform_

*(Suggested path: `docs/04_Deployment_and_Startup_Manual.md`)*

---

## 1. Introduction

This module teaches you:

- How to deploy NSReady locally using Docker Compose
- How to deploy NSReady on Kubernetes using the prepared YAMLs
- How to start/stop/restart services
- How to check logs and health
- How to rebuild images after code updates
- How to verify successful startup
- How to expose services using NodePorts
- How to troubleshoot basic deployment issues

This is one of the most critical modules for day-to-day operation.

---

## 2. Deployment Modes

NSReady supports two deployment modes:

1. **Local Developer Mode** → Docker Compose (Mac/Linux)
2. **Cluster Mode** → Kubernetes (`nsready-tier2` namespace)

**When to use:**

- **Local Mode** → For rapid testing on your Mac, development, quick demos
- **Cluster Mode** → For realistic, scalable testing or staging
- **Production** → Always via Kubernetes

---

## 3. Local Deployment (Mac/Linux – Docker Compose)

### 3.1 Prerequisites

- **Docker Desktop** installed and running
- **Python / curl** (for tests)
- **Project folder** contains:
  - `docker-compose.yml`
  - `.env` file (or create from `.env.example`)

### 3.2 Create the `.env` File

**If `.env` file is missing:**

```bash
cp .env.example .env
```

**Or create manually:**

```bash
# .env file contents
APP_ENV=development
POSTGRES_DB=nsready
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_HOST=db
POSTGRES_PORT=5432
NATS_URL=nats://nats:4222
ADMIN_BEARER_TOKEN=devtoken
```

**Key Variables:**

- `POSTGRES_DB` - Database name (default: `nsready`)
- `POSTGRES_USER` - Database user (default: `postgres`)
- `POSTGRES_PASSWORD` - Database password (default: `postgres`)
- `POSTGRES_HOST` - Database host (default: `db` for Docker Compose)
- `POSTGRES_PORT` - Database port (default: `5432`)
- `NATS_URL` - NATS server URL (default: `nats://nats:4222`)
- `ADMIN_BEARER_TOKEN` - Admin tool authentication token (default: `devtoken`)

---

### 3.3 Start the Entire Stack

**Using Makefile (recommended):**

```bash
make up
```

**Or directly with Docker Compose:**

```bash
docker-compose up --build
```

**This starts:**

- PostgreSQL (TimescaleDB) on port `5432`
- NATS JetStream on ports `4222` (client) and `8222` (monitoring)
- Collector-Service on port `8001`
- Admin-Tool on port `8000`
- Traefik (reverse proxy) on ports `80`, `443`, `8080`

**To run in background (detached mode):**

```bash
docker-compose up -d --build
```

---

### 3.4 Verify Containers Are Running

```bash
docker-compose ps
```

**Expected output:**

```
NAME                  STATUS              PORTS
admin_tool            Up                  0.0.0.0:8000->8000/tcp
collector_service     Up                  0.0.0.0:8001->8001/tcp
nsready_db            Up                  0.0.0.0:5432->5432/tcp
nsready_nats          Up                  0.0.0.0:4222->4222/tcp, 0.0.0.0:8222->8222/tcp
nsready_traefik       Up                  0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp, 0.0.0.0:8080->8080/tcp
```

**All containers should show STATUS: "Up"**

---

### 3.5 Test Collector-Service (Local)

```bash
curl http://localhost:8001/v1/health
```

**Expected response:**

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

**Test Admin Tool:**

```bash
curl http://localhost:8000/health
```

**Expected response:**

```json
{
  "service": "ok"
}
```

---

### 3.6 View Logs (Local)

**All services:**

```bash
docker-compose logs -f
```

**Specific service:**

```bash
docker-compose logs -f collector_service
docker-compose logs -f admin_tool
docker-compose logs -f nsready_db
docker-compose logs -f nsready_nats
```

**Follow logs (real-time):**

```bash
docker-compose logs -f --tail=100 collector_service
```

---

### 3.7 Stop Everything

**Stop containers (keeps volumes):**

```bash
docker-compose down
```

**Or using Makefile:**

```bash
make down
```

**Stop and remove volumes (⚠️ WARNING: Deletes all data):**

```bash
docker-compose down -v
```

---

### 3.8 Reset Database (Local)

**To reset database (⚠️ WARNING: Deletes all data):**

```bash
# Stop and remove volumes
docker-compose down -v

# Start fresh
docker-compose up --build
```

**This recreates the DB volume and initializes a fresh database.**

---

### 3.9 Rebuild Images After Code Changes

**If code in `collector_service` or `admin_tool` is modified:**

```bash
# Rebuild and restart
docker-compose up --build

# Or rebuild specific service
docker-compose build collector_service
docker-compose up -d collector_service
```

---

## 4. Cluster Deployment (Kubernetes – nsready-tier2)

**Recommended mode for all NSReady testing beyond basic development.**

### 4.1 Prerequisites

- **kubectl** installed and configured
- **Docker Desktop Kubernetes** enabled OR real Kubernetes cluster
- **Namespace** ready (created automatically or manually)

**Check kubectl connection:**

```bash
kubectl cluster-info
```

**Enable Kubernetes in Docker Desktop:**

1. Open Docker Desktop
2. Go to Settings → Kubernetes
3. Enable Kubernetes
4. Click "Apply & Restart"

---

### 4.2 Create Namespace

**Create namespace (if it doesn't exist):**

```bash
kubectl apply -f deploy/k8s/namespace.yaml
```

**Or manually:**

```bash
kubectl create namespace nsready-tier2
```

**Verify:**

```bash
kubectl get namespace nsready-tier2
```

**If namespace already exists, this will show an error — ignore it.**

---

### 4.3 Apply All K8s Deployment Files

**From project root, apply all files at once:**

```bash
kubectl apply -f deploy/k8s/
```

**This deploys:**

| Component | File |
|-----------|------|
| Namespace | `namespace.yaml` |
| Collector-Service | `collector_service-deployment.yaml` |
| Admin-Tool | `admin_tool-deployment.yaml` |
| PostgreSQL | `postgres-statefulset.yaml` |
| NATS | `nats-statefulset.yaml` |
| ConfigMaps | `configmap.yaml` |
| Secrets | `secrets.yaml` |
| NodePort Services | `collector-nodeport.yaml`, `admin-tool-nodeport.yaml`, etc. |
| RBAC | `rbac.yaml` |
| HPA | `hpa.yaml` |
| Network Policies | `network-policies.yaml` |

**If applying individually:**

```bash
# Core resources first
kubectl apply -f deploy/k8s/namespace.yaml
kubectl apply -f deploy/k8s/configmap.yaml
kubectl apply -f deploy/k8s/secrets.yaml

# StatefulSets (database and NATS)
kubectl apply -f deploy/k8s/postgres-statefulset.yaml
kubectl apply -f deploy/k8s/nats-statefulset.yaml

# Deployments (services)
kubectl apply -f deploy/k8s/collector_service-deployment.yaml
kubectl apply -f deploy/k8s/admin_tool-deployment.yaml

# Services (NodePorts)
kubectl apply -f deploy/k8s/collector-nodeport.yaml
kubectl apply -f deploy/k8s/admin-tool-nodeport.yaml
kubectl apply -f deploy/k8s/nats-monitor-nodeport.yaml

# RBAC and policies
kubectl apply -f deploy/k8s/rbac.yaml
kubectl apply -f deploy/k8s/network-policies.yaml
kubectl apply -f deploy/k8s/hpa.yaml
```

---

### 4.4 Verify Pods

**Check all pods in namespace:**

```bash
kubectl get pods -n nsready-tier2
```

**Expected output (after a few minutes for startup):**

```
NAME                              READY   STATUS    RESTARTS   AGE
admin-tool-xxxxx                  1/1     Running   0          5m
collector-service-xxxxx           1/1     Running   0          5m
nsready-db-0                      1/1     Running   0          6m
nsready-nats-0                    1/1     Running   0          6m
```

**All pods should show STATUS: "Running" and READY: "1/1"**

**Watch pods startup (real-time):**

```bash
kubectl get pods -n nsready-tier2 -w
```

**Check specific pod:**

```bash
kubectl describe pod <pod-name> -n nsready-tier2
```

---

### 4.5 Check Service Status

**List all services:**

```bash
kubectl get svc -n nsready-tier2
```

**Expected output:**

```
NAME                   TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
admin-tool             ClusterIP   10.xxx.xxx.xxx  <none>        8000/TCP         5m
admin-tool-nodeport    NodePort    10.xxx.xxx.xxx  <none>        8000:32002/TCP   5m
collector-service      ClusterIP   10.xxx.xxx.xxx  <none>        8001/TCP         5m
collector-nodeport     NodePort    10.xxx.xxx.xxx  <none>        8001:32001/TCP   5m
nsready-db             ClusterIP   10.xxx.xxx.xxx  <none>        5432/TCP         6m
nsready-nats           ClusterIP   10.xxx.xxx.xxx  <none>        4222/TCP,8222/TCP 6m
nats-monitor-nodeport  NodePort    10.xxx.xxx.xxx  <none>        8222:32022/TCP   5m
```

---

### 4.6 Exposed NodePorts (Important)

**Services exposed via NodePort:**

| Service | NodePort | Purpose | URL |
|---------|----------|---------|-----|
| Collector | 32001 | `/v1/ingest`, `/v1/health`, `/metrics` | `http://localhost:32001` |
| Admin Tool | 32002 | `/admin/*`, `/health`, `/docs` | `http://localhost:32002` |
| NATS Monitor | 32022 | JetStream monitoring | `http://localhost:32022` |
| Grafana | 32000 | Dashboards (if deployed) | `http://localhost:32000` |
| Prometheus | 32090 | Metrics (if deployed) | `http://localhost:32090` |

**Test collector:**

```bash
curl http://localhost:32001/v1/health
```

**Expected response:**

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

**Test admin tool:**

```bash
curl http://localhost:32002/health
```

---

### 4.7 Logs & Monitoring (Kubernetes)

**Check Collector logs:**

```bash
kubectl logs -n nsready-tier2 -l app=collector-service --tail=50
```

**Follow logs (real-time):**

```bash
kubectl logs -n nsready-tier2 -l app=collector-service -f
```

**Check specific pod logs:**

```bash
kubectl logs -n nsready-tier2 <pod-name> --tail=100
```

**Check Worker logs (same pod as collector):**

```bash
kubectl logs -n nsready-tier2 -l app=collector-service -f | grep -E "(Worker|DB commit)"
```

**Check Admin Tool logs:**

```bash
kubectl logs -n nsready-tier2 -l app=admin-tool --tail=50
```

**Check PostgreSQL logs:**

```bash
kubectl logs -n nsready-tier2 nsready-db-0 --tail=50
```

**Check NATS logs:**

```bash
kubectl logs -n nsready-tier2 nsready-nats-0 --tail=50
```

---

### 4.8 Restart Services

**Restart Collector:**

```bash
kubectl rollout restart deployment/collector-service -n nsready-tier2
```

**Check rollout status:**

```bash
kubectl rollout status deployment/collector-service -n nsready-tier2
```

**Restart Admin Tool:**

```bash
kubectl rollout restart deployment/admin-tool -n nsready-tier2
```

**Restart NATS:**

```bash
kubectl rollout restart statefulset/nsready-nats -n nsready-tier2
```

**⚠️ Warning:** Restarting NATS may cause temporary message queue interruption.

**Restart PostgreSQL:**

```bash
kubectl rollout restart statefulset/nsready-db -n nsready-tier2
```

**⚠️ Warning:** Restarting PostgreSQL will cause temporary database unavailability.

---

### 4.9 Re-deploying After Code Changes (Collector/Admin)

**If code in `collector_service` or `admin_tool` is modified:**

#### Option 1: Build and Load Local Images (Docker Desktop Kubernetes)

```bash
# Build local images
docker build -t nsready-collector-service:latest ./collector_service
docker build -t nsready-admin-tool:latest ./admin_tool

# Load into Kubernetes (Docker Desktop)
kind load docker-image nsready-collector-service:latest
# OR if using Docker Desktop's Kubernetes
docker tag nsready-collector-service:latest nsready-collector-service:latest
docker tag nsready-admin-tool:latest nsready-admin-tool:latest
```

**Update deployment to use local images:**

```yaml
# Edit deployment YAML to set imagePullPolicy: Never
# Or use imagePullPolicy: IfNotPresent and tag images correctly
```

**Restart deployments:**

```bash
kubectl rollout restart deployment/collector-service -n nsready-tier2
kubectl rollout restart deployment/admin-tool -n nsready-tier2
```

#### Option 2: Push to Registry (Production)

```bash
# Tag images
docker tag nsready-collector-service:latest <registry>/nsready-collector-service:v1.0.0
docker tag nsready-admin-tool:latest <registry>/nsready-admin-tool:v1.0.0

# Push to registry
docker push <registry>/nsready-collector-service:v1.0.0
docker push <registry>/nsready-admin-tool:v1.0.0

# Update deployment YAML with new image tag
# Then apply
kubectl apply -f deploy/k8s/collector_service-deployment.yaml
kubectl apply -f deploy/k8s/admin_tool-deployment.yaml
```

**Or use the push script:**

```bash
./scripts/push-images.sh <github-org>
```

---

### 4.10 Database Access (Via kubectl)

**Open SQL shell:**

```bash
kubectl exec -it -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready
```

**Run single SQL command:**

```bash
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "SELECT now();"
```

**Check database size:**

```bash
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "SELECT pg_size_pretty(pg_database_size('nsready'));"
```

**List tables:**

```bash
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "\dt"
```

---

### 4.11 Port-Forward (Alternative to NodePort)

**For local access without NodePort:**

**Collector Service:**

```bash
# Terminal 1: Start port-forward (leave running)
kubectl port-forward -n nsready-tier2 svc/collector-service 8001:8001

# Terminal 2: Test
curl http://localhost:8001/v1/health
```

**Admin Tool:**

```bash
kubectl port-forward -n nsready-tier2 svc/admin-tool 8000:8000
```

**PostgreSQL:**

```bash
kubectl port-forward -n nsready-tier2 pod/nsready-db-0 5432:5432
```

**NATS Monitoring:**

```bash
kubectl port-forward -n nsready-tier2 svc/nsready-nats 8222:8222
```

---

### 4.12 Health Checks

**Collector Health:**

```bash
curl http://localhost:32001/v1/health
```

**Example output:**

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

**Admin Tool Health:**

```bash
curl http://localhost:32002/health
```

**Expected:**

```json
{
  "service": "ok"
}
```

**Metrics Endpoint:**

```bash
curl http://localhost:32001/metrics
```

**Expected:** Prometheus-formatted metrics

---

## 5. Validate Full System Readiness

### 5.1 Check All Pods Running

```bash
kubectl get pods -n nsready-tier2
```

**All pods should be:**

- STATUS: `Running`
- READY: `1/1` (or appropriate for multi-container pods)
- RESTARTS: `0` (or low number)

---

### 5.2 Test Ingestion Pipeline

**Create test event file (`test_event.json`):**

```json
{
  "project_id": "8212caa2-b928-4213-b64e-9f5b86f4cad1",
  "site_id": "89a66770-bdcc-4c95-ac97-e1829cb7a960",
  "device_id": "bc2c5e47-f17e-46f0-b5e7-76b214f4f6ad",
  "protocol": "GPRS",
  "source_timestamp": "2025-11-14T12:00:00Z",
  "metrics": [
    {
      "parameter_key": "voltage",
      "value": 230.5,
      "quality": 192,
      "attributes": {"unit": "V"}
    }
  ]
}
```

**Send test event:**

```bash
curl -X POST http://localhost:32001/v1/ingest \
  -H "Content-Type: application/json" \
  -d @test_event.json
```

**Expected response:**

```json
{
  "status": "queued",
  "trace_id": "uuid-here"
}
```

---

### 5.3 Check Queue Depth

```bash
curl http://localhost:32001/v1/health | jq .queue_depth
```

**Queue depth should be near:**

- `0` - Normal (all messages processed)
- `> 0` - Messages being processed (check again in a few seconds)
- `> 100` - Warning (backlog building)
- `> 1000` - Critical (system may be overloaded)

---

### 5.4 Check Event Count in DB

**Before test:**

```bash
BEFORE=$(kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -t -c "SELECT COUNT(*) FROM ingest_events;")
echo "Before: $BEFORE"
```

**After test (wait 5 seconds):**

```bash
sleep 5

AFTER=$(kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -t -c "SELECT COUNT(*) FROM ingest_events;")
echo "After: $AFTER"
```

**Expected:** `AFTER > BEFORE` (count increased by number of metrics in test event)

---

### 5.5 Verify Worker Processing

**Check worker logs for successful commit:**

```bash
kubectl logs -n nsready-tier2 -l app=collector-service --tail=50 | grep "DB commit OK"
```

**Expected log line:**

```
[Worker-0] DB commit OK → acked 1 messages
```

---

## 6. Troubleshooting Common Deployment Issues

### ❗ Error: Pod stuck in `CrashLoopBackOff`

**Symptoms:**

```
NAME                              STATUS              RESTARTS   AGE
collector-service-xxxxx           0/1     CrashLoopBackOff   5          2m
```

**Possible causes:**

- Missing `.env` or environment variables
- Syntax error in Python imports
- Wrong DB hostname
- NATS not reachable
- Database not ready

**Fix:**

**Check logs:**

```bash
kubectl logs <pod-name> -n nsready-tier2 --tail=100
```

**Check events:**

```bash
kubectl describe pod <pod-name> -n nsready-tier2
```

**Common fixes:**

- Verify ConfigMap and Secrets exist: `kubectl get configmap,secret -n nsready-tier2`
- Check database pod is running: `kubectl get pods -n nsready-tier2 | grep db`
- Verify NATS pod is running: `kubectl get pods -n nsready-tier2 | grep nats`
- Check environment variables: `kubectl get configmap nsready-config -n nsready-tier2 -o yaml`

---

### ❗ Error: "ImagePullBackOff"

**Symptoms:**

```
NAME                              STATUS              RESTARTS   AGE
collector-service-xxxxx           0/1     ImagePullBackOff    0          2m
```

**Cause:**

Local images not in cluster registry OR image doesn't exist.

**Fix:**

**Option 1: For Docker Desktop Kubernetes**

```bash
# Load image into cluster
kind load docker-image nsready-collector-service:latest
```

**Option 2: Use registry image**

Update deployment YAML to use registry image:

```yaml
image: <registry>/nsready-collector-service:v1.0.0
imagePullPolicy: Always
```

**Option 3: Build image in cluster**

Use Kaniko or build jobs to build images within cluster.

---

### ❗ Collector health shows `db: "disconnected"`

**Symptoms:**

```json
{
  "service": "ok",
  "db": "disconnected",
  "queue_depth": 0
}
```

**Cause:**

Database pod not running or network connectivity issue.

**Fix:**

**Check database pod:**

```bash
kubectl get pods -n nsready-tier2 | grep db
```

**If not running, restart:**

```bash
kubectl rollout restart statefulset/nsready-db -n nsready-tier2
```

**Wait for database to be ready:**

```bash
kubectl wait --for=condition=ready pod/nsready-db-0 -n nsready-tier2 --timeout=300s
```

**Check database logs:**

```bash
kubectl logs -n nsready-tier2 nsready-db-0 --tail=50
```

**Verify connectivity:**

```bash
kubectl exec -n nsready-tier2 collector-service-xxxxx -- \
  nc -zv nsready-db 5432
```

---

### ❗ Queue depth stuck > 0

**Symptoms:**

Queue depth consistently > 100 and not decreasing.

**Cause:**

Workers not processing messages or stuck.

**Fix:**

**Check worker logs:**

```bash
kubectl logs -n nsready-tier2 -l app=collector-service --tail=200 | grep -i error
```

**Restart collector (includes workers):**

```bash
kubectl rollout restart deployment/collector-service -n nsready-tier2
```

**Check NATS consumer:**

```bash
kubectl exec -n nsready-tier2 nsready-nats-0 -- \
  nats consumer info INGRESS ingest_workers
```

**If consumer is stuck, restart NATS:**

```bash
kubectl rollout restart statefulset/nsready-nats -n nsready-tier2
```

**⚠️ Warning:** Restarting NATS may cause temporary message queue interruption.

---

### ❗ Pods not starting

**Symptoms:**

Pods in `Pending` or `ContainerCreating` state for a long time.

**Possible causes:**

- Insufficient resources (CPU/memory)
- Storage class issues (PVC not bound)
- Image pull issues

**Fix:**

**Check pod events:**

```bash
kubectl describe pod <pod-name> -n nsready-tier2
```

**Check resource availability:**

```bash
kubectl top nodes
kubectl top pods -n nsready-tier2
```

**Check PVC status:**

```bash
kubectl get pvc -n nsready-tier2
```

**If PVC is pending:**

```bash
kubectl describe pvc <pvc-name> -n nsready-tier2
```

**Common fix:** Update storage class in StatefulSet YAML (see `QUICK_FIX.md` in `deploy/k8s/`)

---

## 7. Deployment Safety Guidelines

### ⚠️ Important Warnings

- **Never delete PVC unless intentionally resetting DB** - This will delete all data
- **Do not modify StatefulSets unless required** - StatefulSets manage persistent storage
- **All credentials must remain in Kubernetes Secrets** - Never commit secrets to Git
- **NodePorts must not conflict with other running services** - Check port availability before deployment
- **Always restart via rollout, never kill pods manually** - Rollout ensures graceful restart
- **Backup database before major changes** - Use backup scripts in `scripts/backups/`

### ✅ Best Practices

- **Use ConfigMaps for non-sensitive configuration** - Easier to manage and version
- **Use Secrets for sensitive data** - Passwords, tokens, certificates
- **Monitor pod health after deployment** - Check logs and metrics
- **Test in local mode first** - Use Docker Compose for initial testing
- **Document custom changes** - Note any modifications to deployment files

---

## 8. Deployment Checklist (Copy–Paste)

### Before Deployment

- [ ] Kubernetes cluster ready (`kubectl cluster-info`)
- [ ] Namespace created (`kubectl get namespace nsready-tier2`)
- [ ] `.env` file created (for Docker Compose) or ConfigMap/Secrets configured (for Kubernetes)
- [ ] NodePorts available (32001, 32002, 32022, etc.)
- [ ] Storage class configured (for Kubernetes)
- [ ] Docker images built (if deploying custom images)

### After Deployment

- [ ] All pods Running (`kubectl get pods -n nsready-tier2`)
- [ ] Collector health OK (`curl http://localhost:32001/v1/health`)
- [ ] Admin Tool health OK (`curl http://localhost:32002/health`)
- [ ] Worker logs OK (no errors in logs)
- [ ] Database reachable (`kubectl exec -n nsready-tier2 nsready-db-0 -- psql -U postgres -d nsready -c "SELECT now();"`)
- [ ] NATS reachable (check NATS monitor: `http://localhost:32022`)
- [ ] Test ingestion passed (send test event, verify DB count increases)
- [ ] Queue depth near 0 (`curl http://localhost:32001/v1/health | jq .queue_depth`)

---

## 9. Quick Command Reference

### Local (Docker Compose)

```bash
# Start
docker-compose up -d --build

# Stop
docker-compose down

# Logs
docker-compose logs -f collector_service

# Restart specific service
docker-compose restart collector_service
```

### Kubernetes

```bash
# Deploy all
kubectl apply -f deploy/k8s/

# Check pods
kubectl get pods -n nsready-tier2

# Check logs
kubectl logs -n nsready-tier2 -l app=collector-service -f

# Restart service
kubectl rollout restart deployment/collector-service -n nsready-tier2

# Health check
curl http://localhost:32001/v1/health
```

---

## 10. Next Steps

After successful deployment:

- **Module 5** - Configuration Import Manual
  - Import registry (customers, projects, sites, devices)
  - Import parameter templates

- **Module 7** - Data Ingestion and Testing Manual
  - Test the complete ingestion pipeline
  - Validate data flow

- **Module 9** - SCADA Integration Manual
  - Set up SCADA read-only access
  - Configure SCADA exports

---

**End of Module 4 – Deployment and Startup Manual**

**Last Updated:** 2025-11-18

_NSReady Data Collection Platform Documentation Team_

