# Module 13 – Operational Checklist & Runbook

_NSReady Data Collection Platform_

*(Suggested path: `docs/13_Operational_Checklist_and_Runbook.md`)*

---

## 1. Purpose of This Document

This module provides a comprehensive operational checklist and runbook for the NSReady Data Collection Platform. It covers:

- Pre-deployment checklists
- Deployment procedures and verification
- Daily operational checks
- Monitoring and alerting procedures
- Troubleshooting guides
- Maintenance tasks and schedules
- Backup and recovery procedures
- Incident response procedures
- Performance optimization
- Security checks

This module is essential for:
- **Operations Engineers** managing day-to-day operations
- **DevOps Engineers** deploying and maintaining the system
- **On-Call Engineers** responding to incidents
- **System Administrators** performing maintenance tasks
- **Team Leads** ensuring operational readiness

**Prerequisites:**
- Module 0 – Introduction and Terminology
- Module 2 – System Architecture and Data Flow
- Module 4 – Deployment & Startup Manual
- Module 7 – Data Validation & Error Handling
- Module 8 – Ingestion Worker & Queue Processing
- Module 12 – API Developer Manual

---

## 2. Operational Overview

### 2.1 System Components

The NSReady platform consists of the following operational components:

1. **Collector Service** (Port 8001) - Telemetry ingestion API
2. **Admin Tool** (Port 8000) - Configuration management API
3. **PostgreSQL + TimescaleDB** (Port 5432) - Time-series database
4. **NATS JetStream** (Ports 4222, 8222) - Message queue
5. **Dashboard** (Internal) - Operational UI

### 2.2 Operational Responsibilities

**Daily Operations:**
- Monitor system health and performance
- Verify data ingestion is working
- Check queue depth and processing rates
- Review error logs and alerts
- Validate SCADA exports

**Weekly Operations:**
- Review performance metrics
- Check database growth and storage
- Verify backup completion
- Review security logs
- Update documentation

**Monthly Operations:**
- Performance optimization review
- Capacity planning
- Security audit
- Disaster recovery testing
- Documentation updates

---

## 3. Pre-Deployment Checklist

### 3.1 Environment Preparation

**Infrastructure:**
- [ ] Docker Desktop installed and running (local) OR Kubernetes cluster available (production)
- [ ] Sufficient disk space (minimum 50GB for database)
- [ ] Network connectivity verified
- [ ] Firewall rules configured (ports 8000, 8001, 5432, 4222, 8222)
- [ ] DNS/hostname resolution working

**Configuration:**
- [ ] `.env` file created and configured
- [ ] Database credentials set and secure
- [ ] NATS URL configured correctly
- [ ] Admin Bearer token set (strong token for production)
- [ ] Environment variables validated

**Dependencies:**
- [ ] PostgreSQL 15+ available
- [ ] NATS JetStream available
- [ ] Docker Compose or Kubernetes manifests ready
- [ ] Database migrations ready

### 3.2 Code and Artifacts

- [ ] Latest code pulled from repository
- [ ] Docker images built or pulled
- [ ] Database migrations reviewed
- [ ] Configuration files validated
- [ ] Documentation reviewed

### 3.3 Backup Preparation

- [ ] Backup strategy defined
- [ ] Backup scripts tested
- [ ] Backup storage location configured
- [ ] Recovery procedures documented
- [ ] Backup retention policy defined

---

## 4. Deployment Procedures

### 4.1 Local Deployment (Docker Compose)

**Step 1: Start Services**
```bash
# Navigate to project root
cd /path/to/ntppl_nsready_platform

# Start all services
docker-compose up -d --build

# Verify containers are running
docker-compose ps
```

**Expected Output:**
```
NAME                  STATUS              PORTS
admin_tool            Up                  0.0.0.0:8000->8000/tcp
collector_service     Up                  0.0.0.0:8001->8001/tcp
nsready_db            Up                  0.0.0.0:5432->5432/tcp
nsready_nats          Up                  0.0.0.0:4222->4222/tcp, 0.0.0.0:8222->8222/tcp
```

**Step 2: Wait for Services to Initialize**
```bash
# Wait 30 seconds for services to start
sleep 30

# Check logs for errors
docker-compose logs --tail=50
```

**Step 3: Verify Health**
```bash
# Check Collector Service
curl http://localhost:8001/v1/health

# Check Admin Tool
curl http://localhost:8000/health
```

**Expected Responses:**
```json
// Collector Service
{
  "service": "ok",
  "queue_depth": 0,
  "db": "connected"
}

// Admin Tool
{
  "service": "ok"
}
```

### 4.2 Production Deployment (Kubernetes)

**Step 1: Apply Kubernetes Manifests**
```bash
# Create namespace (if not exists)
kubectl create namespace nsready-tier2

# Apply database
kubectl apply -f shared/deploy/k8s/db.yaml -n nsready-tier2

# Apply NATS
kubectl apply -f shared/deploy/k8s/nats.yaml -n nsready-tier2

# Apply services
kubectl apply -f shared/deploy/k8s/admin-tool.yaml -n nsready-tier2
kubectl apply -f shared/deploy/k8s/collector-service.yaml -n nsready-tier2
```

**Step 2: Verify Pods**
```bash
# Check pod status
kubectl get pods -n nsready-tier2

# Expected: All pods in Running state
```

**Step 3: Verify Services**
```bash
# Check service endpoints
kubectl get svc -n nsready-tier2

# Test health endpoints
kubectl port-forward -n nsready-tier2 svc/collector-service 8001:8001
curl http://localhost:8001/v1/health
```

### 4.3 Post-Deployment Verification

**Checklist:**
- [ ] All containers/pods running
- [ ] Health endpoints responding
- [ ] Database connection successful
- [ ] NATS connection successful
- [ ] Queue consumer created
- [ ] Database migrations applied
- [ ] TimescaleDB hypertables created
- [ ] SCADA views accessible
- [ ] Metrics endpoint working
- [ ] Logs showing no errors

**Verification Commands:**
```bash
# Check database connection
docker-compose exec db psql -U postgres -d nsready -c "SELECT now();"

# Check NATS connection
docker-compose exec collector_service curl http://nats:8222/varz

# Check queue consumer
docker-compose exec collector_service curl http://nats:8222/jsz?streams=1

# Check database schema
docker-compose exec db psql -U postgres -d nsready -c "\dt"

# Check TimescaleDB hypertables
docker-compose exec db psql -U postgres -d nsready -c "SELECT hypertable_name FROM timescaledb_information.hypertables;"
```

---

## 5. Daily Operational Checks

### 5.1 Health Check Routine

**Frequency:** Every 4 hours (or as configured)

**Checklist:**
- [ ] Collector Service health endpoint responding
- [ ] Admin Tool health endpoint responding
- [ ] Database connection healthy
- [ ] NATS connection healthy
- [ ] Queue depth within normal range (< 1000)
- [ ] Error rate within acceptable limits (< 1%)
- [ ] Worker processing messages successfully

**Health Check Script:**
```bash
#!/bin/bash
# daily_health_check.sh

COLLECTOR_URL="http://localhost:8001"
ADMIN_URL="http://localhost:8000"

echo "=== NSReady Health Check ==="
echo ""

# Check Collector Service
echo "Collector Service:"
COLLECTOR_HEALTH=$(curl -s ${COLLECTOR_URL}/v1/health)
echo "$COLLECTOR_HEALTH" | jq '.'

QUEUE_DEPTH=$(echo "$COLLECTOR_HEALTH" | jq -r '.queue_depth')
if [ "$QUEUE_DEPTH" -gt 1000 ]; then
  echo "⚠️  WARNING: Queue depth is high: $QUEUE_DEPTH"
fi

# Check Admin Tool
echo ""
echo "Admin Tool:"
ADMIN_HEALTH=$(curl -s ${ADMIN_URL}/health)
echo "$ADMIN_HEALTH" | jq '.'

# Check Metrics
echo ""
echo "Metrics:"
curl -s ${COLLECTOR_URL}/metrics | grep -E "ingest_events_total|ingest_errors_total|ingest_queue_depth"
```

### 5.2 Data Ingestion Verification

**Checklist:**
- [ ] Events being ingested (check metrics)
- [ ] Events being processed (queue depth decreasing)
- [ ] Events stored in database
- [ ] No validation errors
- [ ] No processing errors

**Verification Commands:**
```bash
# Check recent ingestions
docker-compose exec db psql -U postgres -d nsready -c "
  SELECT COUNT(*) as recent_events, 
         MAX(time) as latest_event
  FROM ingest_events 
  WHERE time > NOW() - INTERVAL '1 hour';
"

# Check queue depth
curl -s http://localhost:8001/v1/health | jq '.queue_depth'

# Check error rate
curl -s http://localhost:8001/metrics | grep ingest_errors_total
```

### 5.3 Queue Monitoring

**Key Metrics:**
- Queue depth (should be < 1000)
- Processing rate (events/second)
- Error rate (should be < 1%)
- Redelivery count (should be low)

**Monitoring Commands:**
```bash
# Get queue statistics
curl -s http://localhost:8222/jsz?streams=1 | jq '.'

# Check consumer status
curl -s http://localhost:8222/jsz?consumers=1 | jq '.'
```

### 5.4 Database Health

**Checklist:**
- [ ] Database connection healthy
- [ ] Database size within limits
- [ ] No long-running queries
- [ ] Index usage optimal
- [ ] TimescaleDB compression working

**Database Health Check:**
```bash
# Check database size
docker-compose exec db psql -U postgres -d nsready -c "
  SELECT pg_size_pretty(pg_database_size('nsready')) as db_size;
"

# Check table sizes
docker-compose exec db psql -U postgres -d nsready -c "
  SELECT schemaname, tablename, 
         pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
  FROM pg_tables
  WHERE schemaname = 'public'
  ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
"

# Check active connections
docker-compose exec db psql -U postgres -d nsready -c "
  SELECT count(*) as active_connections 
  FROM pg_stat_activity 
  WHERE datname = 'nsready';
"
```

---

## 6. Monitoring and Alerting

### 6.1 Key Metrics to Monitor

**System Metrics:**
- Service availability (uptime)
- Response time (latency)
- Error rate
- Queue depth
- Database connections
- Disk usage
- Memory usage
- CPU usage

**Business Metrics:**
- Events ingested per hour/day
- Events processed per hour/day
- Processing latency (P50, P95, P99)
- Validation error rate
- Processing error rate
- Data freshness (time since last event)

### 6.2 Prometheus Metrics

**Available Metrics:**
```
# Event ingestion
ingest_events_total{status="queued"}
ingest_events_total{status="success"}
ingest_events_total{status="error"}

# Errors
ingest_errors_total{error_type="validation"}
ingest_errors_total{error_type="processing"}
ingest_errors_total{error_type="database"}

# Queue
ingest_queue_depth

# Rate
ingest_rate_per_second
```

**Access Metrics:**
```bash
# Get all metrics
curl http://localhost:8001/metrics

# Get specific metric
curl http://localhost:8001/metrics | grep ingest_queue_depth
```

### 6.3 Alerting Thresholds

**Critical Alerts:**
- Service down (health check fails)
- Queue depth > 10,000
- Error rate > 5%
- Database connection failure
- NATS connection failure
- Disk usage > 90%

**Warning Alerts:**
- Queue depth > 1,000
- Error rate > 1%
- Processing latency P95 > 5 seconds
- Database size > 80% of limit
- Memory usage > 80%

### 6.4 Log Monitoring

**Key Log Patterns to Monitor:**
- ERROR level logs
- WARNING level logs
- Database connection errors
- NATS connection errors
- Validation failures
- Processing failures

**Log Access:**
```bash
# View all logs
docker-compose logs -f

# View specific service logs
docker-compose logs -f collector_service
docker-compose logs -f admin_tool

# Search for errors
docker-compose logs | grep -i error

# Tail last 100 lines
docker-compose logs --tail=100 collector_service
```

---

## 7. Troubleshooting Procedures

### 7.1 Service Not Starting

**Symptoms:**
- Container/pod not running
- Health endpoint not responding
- Service crashes on startup

**Diagnosis:**
```bash
# Check container status
docker-compose ps

# Check logs
docker-compose logs collector_service
docker-compose logs admin_tool

# Check for port conflicts
netstat -an | grep -E "8000|8001|5432|4222"
```

**Common Causes:**
1. **Port already in use** - Another service using the port
2. **Database not ready** - Database not started or not accessible
3. **NATS not ready** - NATS not started or not accessible
4. **Configuration error** - Invalid environment variables
5. **Dependency issue** - Missing dependencies or incorrect versions

**Resolution:**
```bash
# Stop conflicting services
docker-compose down

# Check port availability
lsof -i :8000
lsof -i :8001

# Restart services
docker-compose up -d --build

# Wait for dependencies
sleep 30

# Verify health
curl http://localhost:8001/v1/health
```

### 7.2 High Queue Depth

**Symptoms:**
- Queue depth > 1,000
- Events not being processed
- Processing lag increasing

**Diagnosis:**
```bash
# Check queue depth
curl -s http://localhost:8001/v1/health | jq '.queue_depth'

# Check worker status
docker-compose logs collector_service | grep -i worker

# Check NATS consumer
curl -s http://localhost:8222/jsz?consumers=1 | jq '.'
```

**Common Causes:**
1. **Worker not running** - Worker process crashed
2. **Database slow** - Database performance issues
3. **High ingestion rate** - More events than workers can handle
4. **Processing errors** - Messages failing and being redelivered

**Resolution:**
```bash
# Restart worker
docker-compose restart collector_service

# Check database performance
docker-compose exec db psql -U postgres -d nsready -c "
  SELECT pid, state, query, query_start
  FROM pg_stat_activity
  WHERE datname = 'nsready'
  ORDER BY query_start;
"

# Scale workers (if using Kubernetes)
kubectl scale deployment collector-service --replicas=3 -n nsready-tier2

# Check for processing errors
docker-compose logs collector_service | grep -i error
```

### 7.3 Database Connection Issues

**Symptoms:**
- Health check shows "db": "disconnected"
- Database queries failing
- Connection timeout errors

**Diagnosis:**
```bash
# Check database container
docker-compose ps db

# Check database logs
docker-compose logs db

# Test database connection
docker-compose exec db psql -U postgres -d nsready -c "SELECT now();"

# Check connection from service
docker-compose exec collector_service python -c "
import asyncio
from core.db import create_engine
engine = create_engine()
print('Connection test')
"
```

**Common Causes:**
1. **Database not running** - Container/pod not started
2. **Wrong credentials** - Incorrect username/password
3. **Network issue** - Cannot reach database host
4. **Connection pool exhausted** - Too many connections
5. **Database full** - No disk space

**Resolution:**
```bash
# Restart database
docker-compose restart db

# Check database status
docker-compose exec db pg_isready -U postgres

# Check disk space
docker-compose exec db df -h

# Check connection limits
docker-compose exec db psql -U postgres -d nsready -c "
  SHOW max_connections;
  SELECT count(*) FROM pg_stat_activity;
"
```

### 7.4 NATS Connection Issues

**Symptoms:**
- Health check shows queue issues
- Events not being queued
- Worker not receiving messages

**Diagnosis:**
```bash
# Check NATS container
docker-compose ps nats

# Check NATS logs
docker-compose logs nats

# Test NATS connection
docker-compose exec collector_service curl http://nats:8222/varz

# Check NATS streams
curl -s http://localhost:8222/jsz?streams=1 | jq '.'
```

**Common Causes:**
1. **NATS not running** - Container/pod not started
2. **Wrong URL** - Incorrect NATS_URL configuration
3. **Network issue** - Cannot reach NATS host
4. **Stream not created** - Stream configuration missing

**Resolution:**
```bash
# Restart NATS
docker-compose restart nats

# Verify NATS is accessible
curl http://localhost:8222/varz

# Check stream configuration
curl -s http://localhost:8222/jsz?streams=1 | jq '.account_details[0].stream_detail[] | {name, state}'

# Restart collector service to recreate stream
docker-compose restart collector_service
```

### 7.5 Data Not Appearing in Database

**Symptoms:**
- Events accepted but not stored
- SCADA views empty
- No data in ingest_events table

**Diagnosis:**
```bash
# Check if events are being ingested
curl -s http://localhost:8001/metrics | grep ingest_events_total

# Check queue depth
curl -s http://localhost:8001/v1/health | jq '.queue_depth'

# Check database for recent events
docker-compose exec db psql -U postgres -d nsready -c "
  SELECT COUNT(*) as total_events,
         MAX(time) as latest_event
  FROM ingest_events;
"

# Check worker logs
docker-compose logs collector_service | grep -i "processing\|error"
```

**Common Causes:**
1. **Worker not processing** - Worker not running or stuck
2. **Validation failures** - Events failing validation
3. **Database errors** - Insert failures
4. **Idempotency conflicts** - Duplicate events being rejected

**Resolution:**
```bash
# Check worker status
docker-compose logs collector_service | tail -50

# Check for validation errors
docker-compose logs collector_service | grep -i "validation\|error"

# Manually trigger processing (if needed)
docker-compose restart collector_service

# Check database constraints
docker-compose exec db psql -U postgres -d nsready -c "
  SELECT * FROM error_logs 
  ORDER BY time DESC 
  LIMIT 10;
"
```

### 7.6 Performance Issues

**Symptoms:**
- Slow API responses
- High latency
- Timeout errors
- System resource exhaustion

**Diagnosis:**
```bash
# Check response times
time curl http://localhost:8001/v1/health

# Check system resources
docker stats

# Check database performance
docker-compose exec db psql -U postgres -d nsready -c "
  SELECT pid, state, wait_event_type, wait_event, query
  FROM pg_stat_activity
  WHERE datname = 'nsready'
  AND state != 'idle';
"

# Check slow queries
docker-compose exec db psql -U postgres -d nsready -c "
  SELECT query, calls, total_time, mean_time
  FROM pg_stat_statements
  ORDER BY mean_time DESC
  LIMIT 10;
"
```

**Common Causes:**
1. **Database slow** - Missing indexes, large tables
2. **High load** - Too many concurrent requests
3. **Resource limits** - CPU/memory constraints
4. **Network latency** - Slow network connections
5. **Inefficient queries** - Poor query performance

**Resolution:**
```bash
# Analyze database
docker-compose exec db psql -U postgres -d nsready -c "ANALYZE;"

# Check indexes
docker-compose exec db psql -U postgres -d nsready -c "
  SELECT schemaname, tablename, indexname, idx_scan
  FROM pg_stat_user_indexes
  WHERE schemaname = 'public'
  ORDER BY idx_scan;
"

# Scale services (if using Kubernetes)
kubectl scale deployment collector-service --replicas=3 -n nsready-tier2

# Optimize database
docker-compose exec db psql -U postgres -d nsready -c "VACUUM ANALYZE;"
```

---

## 8. Maintenance Tasks

### 8.1 Daily Maintenance

**Tasks:**
- [ ] Review health checks
- [ ] Check error logs
- [ ] Verify backups completed
- [ ] Monitor queue depth
- [ ] Review metrics

**Time Required:** 15 minutes

### 8.2 Weekly Maintenance

**Tasks:**
- [ ] Review performance metrics
- [ ] Check database growth
- [ ] Verify backup integrity
- [ ] Review security logs
- [ ] Update documentation
- [ ] Database vacuum (if needed)

**Time Required:** 1 hour

**Database Vacuum:**
```bash
# Vacuum analyze
docker-compose exec db psql -U postgres -d nsready -c "VACUUM ANALYZE;"

# Check table bloat
docker-compose exec db psql -U postgres -d nsready -c "
  SELECT schemaname, tablename,
         pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
         n_dead_tup,
         last_vacuum,
         last_autovacuum
  FROM pg_stat_user_tables
  WHERE schemaname = 'public'
  ORDER BY n_dead_tup DESC;
"
```

### 8.3 Monthly Maintenance

**Tasks:**
- [ ] Performance optimization review
- [ ] Capacity planning
- [ ] Security audit
- [ ] Disaster recovery test
- [ ] Documentation review
- [ ] Database maintenance (if needed)

**Time Required:** 4 hours

**Database Maintenance:**
```bash
# Full vacuum (if needed, during maintenance window)
docker-compose exec db psql -U postgres -d nsready -c "VACUUM FULL;"

# Reindex (if needed)
docker-compose exec db psql -U postgres -d nsready -c "REINDEX DATABASE nsready;"

# Check database statistics
docker-compose exec db psql -U postgres -d nsready -c "
  SELECT schemaname, tablename,
         n_live_tup, n_dead_tup,
         last_vacuum, last_autovacuum,
         last_analyze, last_autoanalyze
  FROM pg_stat_user_tables
  WHERE schemaname = 'public';
"
```

### 8.4 Database Backup

**Frequency:** Daily (automated) + Before major changes (manual)

**Backup Procedure:**
```bash
# Create backup
docker-compose exec db pg_dump -U postgres -d nsready -F c -f /tmp/nsready_backup_$(date +%Y%m%d_%H%M%S).dump

# Copy backup from container
docker cp nsready_db:/tmp/nsready_backup_$(date +%Y%m%d_%H%M%S).dump ./backups/

# Verify backup
docker-compose exec db pg_restore --list /tmp/nsready_backup_*.dump | head -20
```

**Restore Procedure:**
```bash
# Stop services
docker-compose stop collector_service admin_tool

# Restore database
docker-compose exec db psql -U postgres -c "DROP DATABASE IF EXISTS nsready;"
docker-compose exec db psql -U postgres -c "CREATE DATABASE nsready;"
docker cp ./backups/nsready_backup_YYYYMMDD_HHMMSS.dump nsready_db:/tmp/
docker-compose exec db pg_restore -U postgres -d nsready /tmp/nsready_backup_*.dump

# Restart services
docker-compose start collector_service admin_tool
```

### 8.5 Configuration Backup

**Frequency:** Before any configuration changes

**Backup Procedure:**
```bash
# Use backup script
./shared/scripts/backup_before_change.sh config_change --tag --files .env docker-compose.yml
```

**Manual Backup:**
```bash
# Backup configuration files
cp .env backups/.env.backup.$(date +%Y%m%d_%H%M%S)
cp docker-compose.yml backups/docker-compose.yml.backup.$(date +%Y%m%d_%H%M%S)

# Backup registry data
docker-compose exec db psql -U postgres -d nsready -c "
  COPY (SELECT * FROM customers) TO '/tmp/customers_backup.csv' CSV HEADER;
  COPY (SELECT * FROM projects) TO '/tmp/projects_backup.csv' CSV HEADER;
  COPY (SELECT * FROM sites) TO '/tmp/sites_backup.csv' CSV HEADER;
  COPY (SELECT * FROM devices) TO '/tmp/devices_backup.csv' CSV HEADER;
  COPY (SELECT * FROM parameter_templates) TO '/tmp/parameter_templates_backup.csv' CSV HEADER;
"
```

---

## 9. Incident Response

### 9.1 Incident Severity Levels

**Critical (P1):**
- System completely down
- Data loss
- Security breach
- All services unavailable

**High (P2):**
- Partial service outage
- High error rate (> 5%)
- Queue depth > 10,000
- Performance degradation

**Medium (P3):**
- Intermittent issues
- Low error rate (< 5%)
- Queue depth > 1,000
- Minor performance issues

**Low (P4):**
- Cosmetic issues
- Documentation errors
- Feature requests

### 9.2 Incident Response Procedure

**Step 1: Assess Impact**
- Identify affected services
- Determine user impact
- Check error logs
- Review metrics

**Step 2: Contain Impact**
- Stop problematic processes (if safe)
- Scale services (if needed)
- Enable maintenance mode (if applicable)
- Notify stakeholders

**Step 3: Diagnose Root Cause**
- Review logs
- Check system resources
- Verify dependencies
- Review recent changes

**Step 4: Resolve Issue**
- Apply fix
- Verify resolution
- Monitor for recurrence
- Document solution

**Step 5: Post-Incident Review**
- Document incident
- Identify root cause
- Implement preventive measures
- Update runbooks

### 9.3 Common Incident Scenarios

**Scenario 1: Service Down**
```bash
# 1. Check service status
docker-compose ps

# 2. Check logs
docker-compose logs --tail=100 collector_service

# 3. Restart service
docker-compose restart collector_service

# 4. Verify recovery
curl http://localhost:8001/v1/health
```

**Scenario 2: Database Full**
```bash
# 1. Check disk space
docker-compose exec db df -h

# 2. Check database size
docker-compose exec db psql -U postgres -d nsready -c "
  SELECT pg_size_pretty(pg_database_size('nsready'));
"

# 3. Clean old data (if retention policy allows)
docker-compose exec db psql -U postgres -d nsready -c "
  DELETE FROM ingest_events 
  WHERE time < NOW() - INTERVAL '90 days';
"

# 4. Vacuum
docker-compose exec db psql -U postgres -d nsready -c "VACUUM FULL;"
```

**Scenario 3: High Error Rate**
```bash
# 1. Check error metrics
curl -s http://localhost:8001/metrics | grep ingest_errors_total

# 2. Check error logs
docker-compose logs collector_service | grep -i error | tail -50

# 3. Check validation errors
docker-compose exec db psql -U postgres -d nsready -c "
  SELECT * FROM error_logs 
  WHERE time > NOW() - INTERVAL '1 hour'
  ORDER BY time DESC;
"

# 4. Fix root cause (validation rules, data format, etc.)
```

---

## 10. Performance Optimization

### 10.1 Database Optimization

**Index Maintenance:**
```bash
# Check index usage
docker-compose exec db psql -U postgres -d nsready -c "
  SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read, idx_tup_fetch
  FROM pg_stat_user_indexes
  WHERE schemaname = 'public'
  ORDER BY idx_scan;
"

# Rebuild unused indexes
docker-compose exec db psql -U postgres -d nsready -c "
  REINDEX INDEX CONCURRENTLY idx_ingest_events_device_parameter_time;
"
```

**Query Optimization:**
```bash
# Enable query statistics
docker-compose exec db psql -U postgres -d nsready -c "
  CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
"

# Check slow queries
docker-compose exec db psql -U postgres -d nsready -c "
  SELECT query, calls, total_time, mean_time, max_time
  FROM pg_stat_statements
  ORDER BY mean_time DESC
  LIMIT 10;
"
```

### 10.2 Worker Optimization

**Scaling Workers:**
```bash
# Kubernetes: Scale workers
kubectl scale deployment collector-service --replicas=3 -n nsready-tier2

# Docker Compose: Add more worker instances
# Edit docker-compose.yml to add worker replicas
```

**Batch Size Tuning:**
- Increase batch size for higher throughput
- Decrease batch size for lower latency
- Monitor queue depth and processing rate

### 10.3 Network Optimization

**Connection Pooling:**
- Configure appropriate connection pool size
- Monitor connection usage
- Adjust based on load

**Compression:**
- Enable gzip compression for API responses
- Reduce network bandwidth usage

---

## 11. Security Checks

### 11.1 Authentication

**Checklist:**
- [ ] Admin Bearer token is strong (production)
- [ ] Tokens rotated regularly
- [ ] No tokens in logs or code
- [ ] HTTPS enabled (production)
- [ ] API rate limiting configured (if available)

### 11.2 Database Security

**Checklist:**
- [ ] Strong database passwords
- [ ] Database access restricted
- [ ] Read-only user for SCADA (if applicable)
- [ ] Regular security updates
- [ ] Backup encryption (if applicable)

### 11.3 Network Security

**Checklist:**
- [ ] Firewall rules configured
- [ ] Only necessary ports exposed
- [ ] VPN access for production (if applicable)
- [ ] Network segmentation (if applicable)

### 11.4 Log Security

**Checklist:**
- [ ] No sensitive data in logs
- [ ] Log access restricted
- [ ] Log retention policy defined
- [ ] Log monitoring enabled

---

## 12. Emergency Procedures

### 12.1 Service Restart

**Complete Restart:**
```bash
# Stop all services
docker-compose down

# Start all services
docker-compose up -d --build

# Wait for initialization
sleep 60

# Verify health
curl http://localhost:8001/v1/health
curl http://localhost:8000/health
```

### 12.2 Database Recovery

**From Backup:**
```bash
# Stop services
docker-compose stop collector_service admin_tool

# Restore database
docker-compose exec db psql -U postgres -c "DROP DATABASE IF EXISTS nsready;"
docker-compose exec db psql -U postgres -c "CREATE DATABASE nsready;"
docker cp ./backups/nsready_backup_YYYYMMDD_HHMMSS.dump nsready_db:/tmp/
docker-compose exec db pg_restore -U postgres -d nsready /tmp/nsready_backup_*.dump

# Restart services
docker-compose start collector_service admin_tool
```

### 12.3 Rollback Procedure

**Code Rollback:**
```bash
# Checkout previous version
git checkout <previous-commit-hash>

# Rebuild and restart
docker-compose up -d --build

# Verify
curl http://localhost:8001/v1/health
```

**Configuration Rollback:**
```bash
# Restore configuration
cp backups/.env.backup.YYYYMMDD_HHMMSS .env

# Restart services
docker-compose restart
```

---

## 13. Operational Contacts

### 13.1 Escalation Path

**Level 1: Operations Team**
- Monitor and resolve common issues
- Perform routine maintenance
- Escalate to Level 2 for complex issues

**Level 2: Engineering Team**
- Resolve complex technical issues
- Performance optimization
- Architecture changes

**Level 3: Management**
- Critical incidents
- Business impact decisions
- Resource allocation

### 13.2 On-Call Rotation

- **Primary On-Call:** First responder for incidents
- **Secondary On-Call:** Backup for primary
- **Rotation Schedule:** Weekly rotation

### 13.3 Communication Channels

- **Slack/Teams:** Real-time communication
- **Email:** Non-urgent notifications
- **PagerDuty/Opsgenie:** Critical alerts
- **Phone:** Emergency escalation

---

## 14. Documentation and Knowledge Base

### 14.1 Operational Documentation

**Required Documents:**
- Deployment procedures
- Troubleshooting guides
- Runbooks (this document)
- Architecture diagrams
- API documentation

### 14.2 Knowledge Base

**Maintain:**
- Common issues and solutions
- Performance tuning tips
- Configuration examples
- Best practices
- Lessons learned from incidents

### 14.3 Documentation Updates

**Update When:**
- New procedures added
- Processes change
- Issues discovered
- Improvements made
- After incidents

---

## 15. Summary

This module provides a comprehensive operational checklist and runbook for the NSReady Data Collection Platform.

**Key Takeaways:**
- Pre-deployment checklists ensure successful deployments
- Daily operational checks maintain system health
- Monitoring and alerting provide early warning of issues
- Troubleshooting procedures guide incident resolution
- Maintenance tasks keep the system optimized
- Backup and recovery procedures protect data
- Incident response procedures ensure rapid resolution

**Next Steps:**
- Review and customize checklists for your environment
- Set up monitoring and alerting
- Test backup and recovery procedures
- Train operations team on procedures
- Establish on-call rotation

**Related Modules:**
- Module 4 – Deployment & Startup Manual (deployment procedures)
- Module 7 – Data Validation & Error Handling (error troubleshooting)
- Module 8 – Ingestion Worker & Queue Processing (queue management)
- Module 12 – API Developer Manual (API troubleshooting)

---

**Document Version:** 1.0  
**Last Updated:** 2024-01-15  
**Author:** NSReady Platform Team

