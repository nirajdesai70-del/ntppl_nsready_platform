# PostgreSQL Installation & Data Storage Location Guide

This guide explains where PostgreSQL is installed and where your data is stored, depending on your deployment method.

---

## Deployment Methods

Your platform supports two deployment methods:

1. **Docker Compose** (Local Development)
2. **Kubernetes** (Production/Staging)

---

## Method 1: Docker Compose Deployment

### PostgreSQL Installation Location

**Container Name:** `nsready_db`  
**Image:** `timescale/timescaledb:2.16.1-pg15` (custom image with TimescaleDB)  
**Port:** `5432` (mapped to host)

### Data Storage Location

**Inside Container:** `/var/lib/postgresql/data`

**On Host Machine (Docker Volume):**
- **Volume Name:** `nsready_db_data`
- **Location:** Managed by Docker

To find the exact location on your host:

**macOS/Linux:**
```bash
# Find volume location
docker volume inspect nsready_db_data

# Or list all volumes
docker volume ls | grep nsready_db_data
```

**macOS (Docker Desktop):**
- Data is typically stored in: `~/Library/Containers/com.docker.docker/Data/vms/0/data/docker/volumes/nsready_db_data/_data`
- Or check: `docker volume inspect nsready_db_data | grep Mountpoint`

**Linux:**
- Usually: `/var/lib/docker/volumes/nsready_db_data/_data`

### Accessing the Database

**From Host Machine:**
```bash
# Connect via psql (if installed)
psql -h localhost -p 5432 -U postgres -d nsready_db

# Or via Docker exec
docker exec -it nsready_db psql -U postgres -d nsready_db
```

**Connection String:**
```
postgresql://postgres:password@localhost:5432/nsready_db
```

### Viewing Data Files

```bash
# Enter the container
docker exec -it nsready_db bash

# Inside container, view data directory
ls -la /var/lib/postgresql/data

# Check database size
du -sh /var/lib/postgresql/data
```

---

## Method 2: Kubernetes Deployment

### PostgreSQL Installation Location

**StatefulSet Name:** `nsready-db`  
**Pod Name:** `nsready-db-0`  
**Namespace:** `nsready-tier2`  
**Image:** `timescale/timescaledb:latest-pg15`  
**Service:** `nsready-db` (headless service)

### Data Storage Location

**Inside Pod:** `/var/lib/postgresql/data`

**Persistent Storage:**
- **PVC Name:** `postgres-pvc`
- **Storage Class:** `hostpath` (for Docker Desktop Kubernetes)
- **Size:** `20Gi`
- **Access Mode:** `ReadWriteOnce`

### Finding the Actual Data Location

**On Kubernetes Node (Docker Desktop):**

For Docker Desktop Kubernetes with `hostpath` storage class:

```bash
# Find the pod
kubectl get pods -n nsready-tier2 | grep nsready-db

# Check PVC details
kubectl get pvc -n nsready-tier2 postgres-pvc

# Describe the PVC to see volume details
kubectl describe pvc -n nsready-tier2 postgres-pvc

# Find the actual mount point (if using hostpath)
# On macOS with Docker Desktop:
# ~/Library/Containers/com.docker.docker/Data/vms/0/data/k8s/volumes/kubernetes.io~hostpath/pvc-*/
```

**For Production Kubernetes:**
- Location depends on your storage class (e.g., AWS EBS, Azure Disk, etc.)
- Check your cloud provider's storage documentation

### Accessing the Database

**From Kubernetes Cluster:**
```bash
# Connect via kubectl exec
kubectl exec -it -n nsready-tier2 nsready-db-0 -- psql -U postgres -d nsready

# Port forward for external access
kubectl port-forward -n nsready-tier2 svc/nsready-db 5432:5432

# Then connect from your machine
psql -h localhost -p 5432 -U postgres -d nsready
```

**Connection String (Internal):**
```
postgresql://postgres:password@nsready-db.nsready-tier2.svc.cluster.local:5432/nsready
```

**Connection String (External via Port-Forward):**
```
postgresql://postgres:password@localhost:5432/nsready
```

### Viewing Data Files

```bash
# Enter the pod
kubectl exec -it -n nsready-tier2 nsready-db-0 -- bash

# Inside pod, view data directory
ls -la /var/lib/postgresql/data

# Check database size
du -sh /var/lib/postgresql/data

# Check disk usage
df -h /var/lib/postgresql/data
```

---

## Database Structure

### Databases

- **Main Database:** `nsready` (or `nsready_db` in docker-compose)
- **System Databases:** `postgres`, `template0`, `template1`

### Key Tables & Views

**Registry Tables:**
- `customers` - Customer information
- `projects` - Project information
- `sites` - Site locations
- `devices` - Device registry
- `parameter_templates` - Parameter definitions

**Telemetry Tables:**
- `ingest_events` - Raw telemetry data (TimescaleDB hypertable)
- `measurements` - Aggregated measurements
- `missing_intervals` - Data gap tracking
- `error_logs` - Error logging

**Views:**
- `v_scada_latest` - Latest value per device/parameter
- `v_scada_history` - Full historical data

---

## Checking Current Deployment

### Determine Your Deployment Method

```bash
# Check if running in Docker Compose
docker ps | grep nsready_db

# Check if running in Kubernetes
kubectl get pods -n nsready-tier2 | grep nsready-db
```

### Get Database Connection Info

**Docker Compose:**
```bash
# Check container status
docker ps | grep nsready_db

# Check environment variables
docker exec nsready_db env | grep POSTGRES
```

**Kubernetes:**
```bash
# Check pod status
kubectl get pods -n nsready-tier2 -l app=nsready-db

# Get database credentials (from secrets)
kubectl get secret -n nsready-tier2 nsready-secrets -o jsonpath='{.data.POSTGRES_USER}' | base64 -d
kubectl get secret -n nsready-tier2 nsready-secrets -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d

# Get database name (from configmap)
kubectl get configmap -n nsready-tier2 nsready-config -o jsonpath='{.data.POSTGRES_DB}'
```

---

## Data Backup & Recovery

### Backup Location

Backups are stored separately from the database:

**Docker Compose:**
- Use backup scripts in `scripts/backups/`
- Backups typically saved to `reports/` or specified directory

**Kubernetes:**
- CronJob: `postgres-backup` (runs daily at 2 AM)
- Backup PVC: `backup-pvc` (50Gi)
- Optional: S3 upload if configured

### Backup Commands

```bash
# Manual backup (Docker Compose)
./scripts/backups/backup_pg.sh

# Manual backup (Kubernetes)
kubectl exec -n nsready-tier2 nsready-db-0 -- pg_dump -U postgres nsready > backup.sql

# Check backup cronjob (Kubernetes)
kubectl get cronjob -n nsready-tier2 postgres-backup
```

---

## Storage Management

### Check Storage Usage

**Docker Compose:**
```bash
# Check volume size
docker system df -v | grep nsready_db_data

# Check database size inside container
docker exec nsready_db psql -U postgres -d nsready_db -c "SELECT pg_size_pretty(pg_database_size('nsready_db'));"
```

**Kubernetes:**
```bash
# Check PVC usage
kubectl describe pvc -n nsready-tier2 postgres-pvc

# Check database size
kubectl exec -n nsready-tier2 nsready-db-0 -- psql -U postgres -d nsready -c "SELECT pg_size_pretty(pg_database_size('nsready'));"

# Check table sizes
kubectl exec -n nsready-tier2 nsready-db-0 -- psql -U postgres -d nsready -c "
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
"
```

### Expanding Storage

**Docker Compose:**
- Docker volumes can be expanded, but it's complex
- Better to backup, recreate with larger volume, restore

**Kubernetes:**
```bash
# Edit PVC to request more storage (if storage class supports expansion)
kubectl patch pvc postgres-pvc -n nsready-tier2 -p '{"spec":{"resources":{"requests":{"storage":"50Gi"}}}}'
```

---

## Troubleshooting

### Database Not Accessible

**Docker Compose:**
```bash
# Check if container is running
docker ps | grep nsready_db

# Check logs
docker logs nsready_db

# Restart if needed
docker restart nsready_db
```

**Kubernetes:**
```bash
# Check pod status
kubectl get pods -n nsready-tier2 -l app=nsready-db

# Check logs
kubectl logs -n nsready-tier2 nsready-db-0

# Check events
kubectl describe pod -n nsready-tier2 nsready-db-0
```

### Data Not Persisting

**Docker Compose:**
```bash
# Verify volume exists
docker volume ls | grep nsready_db_data

# Check volume mount
docker inspect nsready_db | grep -A 10 Mounts
```

**Kubernetes:**
```bash
# Check PVC status
kubectl get pvc -n nsready-tier2 postgres-pvc

# Check volume mount in pod
kubectl describe pod -n nsready-tier2 nsready-db-0 | grep -A 5 Mounts
```

---

## Quick Reference

### Connection Details

| Deployment | Host | Port | Database | User |
|------------|------|------|----------|------|
| Docker Compose | `localhost` | `5432` | `nsready_db` | `postgres` |
| Kubernetes (Internal) | `nsready-db.nsready-tier2.svc.cluster.local` | `5432` | `nsready` | `postgres` |
| Kubernetes (Port-Forward) | `localhost` | `5432` | `nsready` | `postgres` |

### Data Paths

| Deployment | Container Path | Host Path |
|------------|----------------|-----------|
| Docker Compose | `/var/lib/postgresql/data` | Docker volume: `nsready_db_data` |
| Kubernetes | `/var/lib/postgresql/data` | PVC: `postgres-pvc` (20Gi) |

---

## Next Steps

1. **Identify your deployment method** using the commands above
2. **Locate your data** using the appropriate method
3. **Set up backups** if not already configured
4. **Monitor storage usage** regularly
5. **For SCADA integration**, see `SCADA_INTEGRATION_GUIDE.md`







