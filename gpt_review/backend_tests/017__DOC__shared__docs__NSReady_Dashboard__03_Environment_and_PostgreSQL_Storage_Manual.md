# Module 3 – Environment and PostgreSQL Storage Manual

_NSReady Data Collection Platform_

*(Suggested path: `docs/03_Environment_and_PostgreSQL_Storage_Manual.md`)*

---

## 1. Introduction

This module explains how to operate and check the PostgreSQL database and storage used by the NSReady Data Collection Software.

You will learn:

- Where the database runs (Docker / Kubernetes)
- How to connect to it from your Mac
- How to run basic checks (health, size, data)
- How to export and back up data
- Where the data is stored (volumes)
- What to check if something stops working

This module is designed so that any engineer (even with limited DB experience) can safely:

- Verify the DB is up
- Run simple commands
- Call for help with clear information

---

## 2. Architecture Overview

The database is part of the NSReady stack:

```
 Field Devices / Simulation (Mac)
           |
           v
   Collector-Service
           |
           v
        NATS
           |
           v
         Worker
           |
           v
      PostgreSQL (Timescale)
           |
           v
        SCADA / NSWare
```

We run PostgreSQL in one of two ways:

1. **Local Docker / Docker Desktop** (developer testing on Mac)
2. **Kubernetes** (`nsready-tier2` namespace) (more realistic / server-like environment)

---

## 3. Where is PostgreSQL Running?

### 3.1 Check current environment

**In Terminal:**

```bash
# Check Kubernetes
kubectl get pods -n nsready-tier2 | grep db

# Check Docker
docker ps | grep nsready
```

**If you see:**

- `nsready-db-0   1/1   Running   ...` → The DB is running in Kubernetes
- `nsready_db   ...   Up ...` → The DB is running in Docker Compose

**Typical outputs:**

- `nsready-db-0` → Kubernetes (preferred for NSReady stack)
- `nsready_db` → Local Docker container (for local development)

**Recommendation:**

For our current NSReady testing, we can use either Kubernetes (`nsready-tier2` namespace) or Docker Compose. The scripts automatically detect which environment you're using.

---

## 4. Connecting to the Database

### 4.1 Basic health check

**For Kubernetes:**

```bash
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "SELECT now();"
```

**For Docker Compose:**

```bash
docker exec nsready_db psql -U postgres -d nsready -c "SELECT now();"
```

**Expected result:**

```
              now              
-------------------------------
 2025-11-14 15:30:12.123456+00
(1 row)
```

If you see a timestamp → DB is alive and reachable ✅

### 4.2 Open an interactive SQL shell (psql)

**For Kubernetes:**

```bash
kubectl exec -it -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready
```

**For Docker Compose:**

```bash
docker exec -it nsready_db psql -U postgres -d nsready
```

You will see a prompt:

```
nsready=#
```

Now you can run SQL commands, for example:

```sql
SELECT COUNT(*) FROM ingest_events;
SELECT COUNT(*) FROM devices;
\dt        -- list tables
\l         -- list databases
\q         -- to quit
```

---

## 5. Connecting via localhost (optional)

Sometimes you want tools on your Mac to directly talk to the DB.

### 5.1 Temporary port-forward (for local tools)

**For Kubernetes:**

In Terminal 1:

```bash
kubectl port-forward -n nsready-tier2 pod/nsready-db-0 5432:5432
```

Leave this running.

**For Docker Compose:**

Docker Compose already exposes port 5432 to localhost (if configured in `docker-compose.yml`).

Now in Terminal 2 (or your database client):

```bash
psql -h localhost -p 5432 -U postgres -d nsready
```

**Note:** If you don't have `psql` locally installed, you can also connect via:

- **DBeaver** (Free, cross-platform)
- **TablePlus** (macOS, paid)
- **pgAdmin** (Free, cross-platform)
- **VS Code** with PostgreSQL extension

**Connection details:**

- **Host:** `localhost`
- **Port:** `5432`
- **User:** `postgres`
- **Database:** `nsready`
- **Password:** (check your `.env` file or Kubernetes secrets)

**For production**, we will use NodePorts/Ingress or direct cluster IP with a read-only user – see SCADA module later.

---

## 6. Basic Operational Commands (Copy & Paste)

### 6.1 Check which DB and schema you are in

From psql:

```sql
SELECT current_database(), current_schema();
```

**Expected:**

```
 current_database | current_schema
------------------+----------------
 nsready          | public
(1 row)
```

### 6.2 Check table list

```sql
\dt
```

You should see tables like:

- `customers`
- `projects`
- `sites`
- `devices`
- `parameter_templates`
- `ingest_events`
- `measurements`
- `error_logs`
- `registry_versions`

### 6.3 Quick data checks

**Count events:**

```sql
SELECT COUNT(*) FROM ingest_events;
```

**Check last 5 events:**

```sql
SELECT device_id, source_timestamp, received_timestamp
FROM ingest_events
ORDER BY received_timestamp DESC
LIMIT 5;
```

**Check devices:**

```sql
SELECT id, name, device_type, external_id, site_id 
FROM devices 
LIMIT 10;
```

**Check customers and projects:**

```sql
SELECT c.name AS customer, p.name AS project, COUNT(s.id) AS site_count
FROM customers c
JOIN projects p ON p.customer_id = c.id
LEFT JOIN sites s ON s.project_id = p.id
GROUP BY c.name, p.name
ORDER BY c.name, p.name;
```

This confirms that:

- Data is being stored
- Devices are present
- Timestamps look correct
- Registry structure is intact

---

## 7. Storage – Where is the data stored?

### 7.1 In Kubernetes (`nsready-tier2`)

The PostgreSQL pod uses a **Persistent Volume Claim (PVC)**.

**Check:**

```bash
kubectl get pvc -n nsready-tier2
```

You should see something like:

```
NAME           STATUS   VOLUME       CAPACITY   ACCESS MODES   STORAGECLASS   AGE
postgres-pvc   Bound    pvc-xxxx..   20Gi       RWO            standard       2d
backup-pvc     Bound    pvc-yyyy..   50Gi       RWO            hostpath        1d
```

This means:

- The data is in a Kubernetes volume (not in the container's ephemeral filesystem)
- If the pod restarts, data is preserved
- `postgres-pvc` contains the database
- `backup-pvc` is used for backups

**Check volume details:**

```bash
kubectl describe pvc postgres-pvc -n nsready-tier2
```

### 7.2 In Docker Compose

**Check volumes:**

```bash
docker volume ls | grep nsready
```

You should see:

```
local     nsready_db_data
local     nats_data
```

**Find volume location:**

```bash
docker volume inspect nsready_db_data
```

**On macOS (Docker Desktop):**

The data is typically stored in Docker's VM, accessible via:

```bash
# Find mount point
docker volume inspect nsready_db_data | grep Mountpoint
```

Or check: `~/Library/Containers/com.docker.docker/Data/vms/0/data/docker/volumes/nsready_db_data/_data`

**On Linux:**

Usually: `/var/lib/docker/volumes/nsready_db_data/_data`

### 7.3 Check DB size

**For Kubernetes:**

```bash
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c \
  "SELECT pg_size_pretty(pg_database_size('nsready')) AS size;"
```

**For Docker Compose:**

```bash
docker exec nsready_db psql -U postgres -d nsready -c \
  "SELECT pg_size_pretty(pg_database_size('nsready')) AS size;"
```

**Example output:**

```
 size 
-------
 512 MB
(1 row)
```

### 7.4 Check size per table

**For Kubernetes:**

```bash
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  psql -U postgres -d nsready -c "
SELECT relname AS table,
       pg_size_pretty(pg_total_relation_size(relid)) AS total_size
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC
LIMIT 20;"
```

**For Docker Compose:**

```bash
docker exec nsready_db psql -U postgres -d nsready -c "
SELECT relname AS table,
       pg_size_pretty(pg_total_relation_size(relid)) AS total_size
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC
LIMIT 20;"
```

This tells you which tables use the most space (often `ingest_events`).

---

## 8. Backups

### 8.1 Automated Backups (Kubernetes)

The platform includes a **CronJob** for automated daily backups.

**Check if backup CronJob is running:**

```bash
kubectl get cronjob -n nsready-tier2
```

**Check backup job history:**

```bash
kubectl get jobs -n nsready-tier2 | grep postgres-backup
```

**View backup logs:**

```bash
kubectl logs -n nsready-tier2 -l job-name=postgres-backup --tail=50
```

**List available backups:**

```bash
kubectl run list-backups --rm -i --restart=Never \
  --image=postgres:15-alpine \
  --namespace=nsready-tier2 \
  -v backup-pvc:/backups \
  -- ls -lh /backups/pg_backup_*.sql.gz
```

### 8.2 Manual backup (ad-hoc)

**For Kubernetes:**

**Option 1: Using kubectl exec (backup to local machine)**

```bash
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  pg_dump -U postgres nsready | gzip > nsready_backup_$(date +%Y%m%d_%H%M%S).sql.gz
```

This creates a `.sql.gz` file on your Mac in the current directory.

**Option 2: Using backup script in pod**

```bash
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  bash /path/to/backup/scripts/backups/backup_pg.sh
```

**Option 3: Create a temporary backup pod**

```bash
kubectl run postgres-backup-manual --rm -i --restart=Never \
  --image=postgres:15-alpine \
  --namespace=nsready-tier2 \
  --env="POSTGRES_HOST=nsready-db" \
  --env-from=secret:nsready-secrets \
  -- sh -c 'PGPASSWORD="${POSTGRES_PASSWORD}" pg_dump -h nsready-db -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" | gzip > /tmp/backup.sql.gz && cat /tmp/backup.sql.gz' > backup_$(date +%Y%m%d_%H%M%S).sql.gz
```

**For Docker Compose:**

```bash
docker exec nsready_db pg_dump -U postgres nsready | gzip > nsready_backup_$(date +%Y%m%d_%H%M%S).sql.gz
```

Or use the backup script:

```bash
docker exec nsready_db /path/to/scripts/backups/backup_pg.sh
```

### 8.3 Restore from backup

**For Kubernetes:**

**Option 1: Using restore job (recommended)**

```bash
# Edit deploy/k8s/restore-job.yaml to set BACKUP_FILE (or leave empty for latest)
kubectl apply -f deploy/k8s/restore-job.yaml
kubectl logs -f job/postgres-restore -n nsready-tier2
```

**Option 2: Manual restore**

```bash
# If backup is on local machine, copy to pod first
kubectl cp backup_YYYYMMDD_HHMMSS.sql.gz nsready-tier2/nsready-db-0:/tmp/

# Then restore
kubectl exec -n nsready-tier2 nsready-db-0 -- \
  gunzip -c /tmp/backup_YYYYMMDD_HHMMSS.sql.gz | \
  psql -U postgres -d nsready
```

**For Docker Compose:**

```bash
# Copy backup to container
docker cp backup_YYYYMMDD_HHMMSS.sql.gz nsready_db:/tmp/

# Restore
docker exec -i nsready_db gunzip -c /tmp/backup_YYYYMMDD_HHMMSS.sql.gz | \
  docker exec -i nsready_db psql -U postgres -d nsready
```

**Warning:** Restoring will **overwrite** existing data. Always backup first!

### 8.4 Logical backup vs physical backup (simple view)

- **Logical backup (pg_dump)**
  - Exports schema + data as SQL
  - Good for migrating or restoring onto new instances
  - Portable across PostgreSQL versions
  - Can restore individual tables

- **Physical backup (volume snapshot)**
  - Taken at storage layer (Kubernetes PV / cloud snapshot)
  - Good for entire cluster/volume restore
  - Faster for large databases
  - Requires same PostgreSQL version

For now, logical backups with `pg_dump` are enough for your Phase-1/Phase-1.1 testing.

### 8.5 Backup retention

The automated backup CronJob is configured to:

- Keep backups for **7 days** by default
- Clean up older backups automatically
- Optionally upload to S3 (if configured)

---

## 9. Safety: What NOT to do

- ❌ **Do NOT** directly delete or drop tables in `nsready` unless you know exactly what you're doing
- ❌ **Do NOT** shrink or format the PVC manually
- ❌ **Do NOT** run destructive SQL from SCADA or test scripts
- ❌ **Do NOT** delete PVCs without backing up data first
- ❌ **Do NOT** modify TimescaleDB hypertables directly without understanding the implications

**Always:**

- Take a backup before large changes
- Test destructive operations in a separate dev namespace/database
- Verify your SQL queries with `SELECT` before running `DELETE` or `UPDATE`
- Use transactions when possible (`BEGIN; ... ROLLBACK;` to test)

---

## 10. Quick Health & Storage Checklist

Before running major tests or connecting a real datalogger:

- [ ] `nsready-db-0` pod is `Running` (Kubernetes) or `nsready_db` container is `Up` (Docker)
- [ ] `kubectl exec ... SELECT now();` or `docker exec ... SELECT now();` works
- [ ] `SELECT COUNT(*) FROM ingest_events;` runs without error
- [ ] PVC status is `Bound` and has enough space (Kubernetes)
- [ ] No obvious errors in pod/container logs
- [ ] Simple backup (`pg_dump`) works at least once
- [ ] Database size is reasonable (check `pg_database_size`)
- [ ] Tables exist (`\dt` shows expected tables)

---

## 11. Troubleshooting

### 11.1 Database won't start

**Symptoms:** Pod/container is in `CrashLoopBackOff` or keeps restarting

**Check logs:**

```bash
# Kubernetes
kubectl logs -n nsready-tier2 nsready-db-0 --tail=50

# Docker
docker logs nsready_db --tail=50
```

**Common causes:**

- Corrupted database files
- Disk full
- Permission issues
- Wrong PostgreSQL version

### 11.2 Connection refused

**Symptoms:** Cannot connect to database

**Check:**

- Pod/container is running
- Port forwarding is active (if using localhost)
- Network policies allow connections
- Firewall rules (for Docker Desktop)

### 11.3 Out of disk space

**Symptoms:** Database operations fail, "no space left on device"

**Check:**

```bash
# Kubernetes
kubectl describe pvc postgres-pvc -n nsready-tier2

# Docker
docker system df
docker volume inspect nsready_db_data
```

**Solution:**

- Clean up old data (archive old `ingest_events`)
- Increase PVC size (Kubernetes)
- Increase Docker disk image size (Docker Desktop)

### 11.4 Slow queries

**Check:**

- Table sizes (large `ingest_events` table?)
- Indexes exist (`\d+ table_name` to see indexes)
- Database stats are updated (`ANALYZE;`)

---

## 12. Summary

After completing this module, you can:

- Confirm PostgreSQL is running and healthy
- Connect to the DB from your Mac or via `kubectl`/`docker exec`
- Check which data is stored and how big it is
- Create simple backups
- Understand where data lives in Kubernetes volumes or Docker volumes
- Restore from backups if needed

This gives you enough confidence to:

- Trust that the NSReady Data Collection Software is storing correctly
- Support SCADA engineers with clear DB info
- Proceed safely to Module 5 – Configuration Import, Module 7 – Data Ingestion and Testing, and Module 9 – SCADA Integration

---

**End of Module 3 – Environment and PostgreSQL Storage Manual**

**Related Modules:**

- Module 4 – Deployment and Startup Manual
- Module 5 – Configuration Import Manual
- Module 7 – Data Ingestion and Testing Manual
- Module 9 – SCADA Integration Manual

---

## Appendix: Quick Reference Commands

### Health Check

```bash
# Kubernetes
kubectl exec -n nsready-tier2 nsready-db-0 -- psql -U postgres -d nsready -c "SELECT now();"

# Docker
docker exec nsready_db psql -U postgres -d nsready -c "SELECT now();"
```

### Interactive Shell

```bash
# Kubernetes
kubectl exec -it -n nsready-tier2 nsready-db-0 -- psql -U postgres -d nsready

# Docker
docker exec -it nsready_db psql -U postgres -d nsready
```

### Check Size

```bash
# Kubernetes
kubectl exec -n nsready-tier2 nsready-db-0 -- psql -U postgres -d nsready -c "SELECT pg_size_pretty(pg_database_size('nsready'));"

# Docker
docker exec nsready_db psql -U postgres -d nsready -c "SELECT pg_size_pretty(pg_database_size('nsready'));"
```

### Backup

```bash
# Kubernetes - to local file
kubectl exec -n nsready-tier2 nsready-db-0 -- pg_dump -U postgres nsready | gzip > backup_$(date +%Y%m%d_%H%M%S).sql.gz

# Docker - to local file
docker exec nsready_db pg_dump -U postgres nsready | gzip > backup_$(date +%Y%m%d_%H%M%S).sql.gz
```

### Port Forward (for local tools)

```bash
# Kubernetes only
kubectl port-forward -n nsready-tier2 pod/nsready-db-0 5432:5432
```

