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
- Troubleshooting common issues
- Maintenance tasks and schedules
- Backup and recovery procedures
- Emergency response procedures
- Performance optimization
- Security best practices

This module is essential for:
- **Operations Engineers** managing day-to-day operations
- **DevOps Engineers** deploying and maintaining the system
- **On-Call Engineers** responding to incidents
- **System Administrators** performing maintenance tasks
- **Team Leads** ensuring operational readiness

**Prerequisites:**
- Module 0 – Introduction and Terminology
- Module 2 – System Architecture and Data Flow
- Module 3 – Environment and PostgreSQL Storage Manual
- Module 4 – Deployment & Startup Manual
- Module 7 – Data Validation & Error Handling
- Module 8 – Ingestion Worker & Queue Processing

---

## 2. Operational Overview

### 2.1 System Components

The NSReady platform consists of the following operational components:

1. **Collector Service** (Port 8001) - Telemetry ingestion API
2. **Admin Tool** (Port 8000) - Configuration management API
3. **PostgreSQL + TimescaleDB** (Port 5432) - Database
4. **NATS JetStream** (Ports 4222, 8222) - Message queue
5. **Worker Pool** - Background message processing

### 2.2 Operational Responsibilities

**Daily Operations:**
- Monitor system health and performance
- Verify data ingestion is working
- Check queue depth and processing rates
- Review error logs and metrics
- Verify SCADA exports are current

**Weekly Operations:**
- Review system performance metrics
- Check database growth and storage
- Verify backup procedures
- Review error trends
- Update documentation

**Monthly Operations:**
- Performance optimization review
- Security audit
- Capacity planning
- Documentation updates
- Disaster recovery testing

---

## 3. Pre-Deployment Checklist

### 3.1 Environment Preparation

**Before deploying NSReady, verify:**

- [ ] Docker Desktop is installed and running (for local deployment)
- [ ] Kubernetes cluster is accessible (for cluster deployment)
- [ ] Network connectivity to required services
- [ ] Required ports are available (8000, 8001, 5432, 4222, 8222)
- [ ] Sufficient disk space (minimum 10GB free)
- [ ] Required environment variables are configured
- [ ] `.env` file is created and validated

**Environment Variables Checklist:**
```bash
# Required variables
POSTGRES_DB=nsready
POSTGRES_USER=postgres
POSTGRES_PASSWORD=<secure_password>
POSTGRES_HOST=db
POSTGRES_PORT=5432
NATS_URL=nats://nats:4222
ADMIN_BEARER_TOKEN=<secure_token>

# Optional variables
APP_ENV=production
LOG_LEVEL=INFO
```

### 3.2 Database Preparation

- [ ] PostgreSQL 15+ is available
- [ ] TimescaleDB extension is installed
- [ ] Database user has required privileges
- [ ] Database migrations are ready
- [ ] Backup strategy is configured

### 3.3 Configuration Preparation

- [ ] Customer/project/site/device configuration is prepared
- [ ] Parameter templates are defined
- [ ] Registry versioning strategy is planned
- [ ] SCADA integration requirements are documented

### 3.4 Security Preparation

- [ ] Strong passwords are set for database
- [ ] Secure Bearer token is generated for Admin Tool
- [ ] Network security rules are configured
- [ ] Firewall rules allow required ports
- [ ] SSL/TLS certificates are ready (for production)

---

## 4. Deployment Procedures

### 4.1 Local Deployment (Docker Compose)

**Step 1: Verify Prerequisites**
```bash
# Check Docker is running
docker ps

# Verify docker-compose is available
docker-compose --version
```

**Step 2: Create Environment File**
```bash
# Copy example file
cp .env.example .env

# Edit .env with production values
nano .env
```

**Step 3: Start Services**
```bash
# Start all services
docker-compose up -d --build

# Verify containers are running
docker-compose ps
```

**Step 4: Verify Services**
```bash
# Check Collector Service
curl http://localhost:8001/v1/health

# Check Admin Tool
curl http://localhost:8000/health

# Check NATS
curl http://localhost:8222/varz
```

**Step 5: Check Logs**
```bash
# View all logs
docker-compose logs

# View specific service logs
docker-compose logs collector_service
docker-compose logs admin_tool
docker-compose logs db
docker-compose logs nats
```

### 4.2 Cluster Deployment (Kubernetes)

**Step 1: Verify Cluster Access**
```bash
# Check cluster connection
kubectl cluster-info

# Verify namespace exists
kubectl get namespace nsready-tier2
```

**Step 2: Apply Configurations**
```bash
# Apply database configuration
kubectl apply -f shared/deploy/k8s/db/

# Apply NATS configuration
kubectl apply -f shared/deploy/k8s/nats/

# Apply service configurations
kubectl apply -f shared/deploy/k8s/services/
```

**Step 3: Verify Pods**
```bash
# Check all pods are running
kubectl get pods -n nsready-tier2

# Check pod status
kubectl describe pod <pod-name> -n nsready-tier2
```

**Step 4: Verify Services**
```bash
# Check service endpoints
kubectl get svc -n nsready-tier2

# Test health endpoints
kubectl port-forward -n nsready-tier2 svc/collector-service 8001:8001
curl http://localhost:8001/v1/health
```

### 4.3 Post-Deployment Verification

**Verification Checklist:**
- [ ] All containers/pods are running
- [ ] Health endpoints return "ok"
- [ ] Database connection is successful
- [ ] NATS connection is successful
- [ ] Worker is processing messages
- [ ] API endpoints are accessible
- [ ] Metrics endpoint is working
- [ ] Logs show no critical errors

**Verification Commands:**
```bash
# Health checks
curl http://localhost:8001/v1/health
curl http://localhost:8000/health

# Metrics
curl http://localhost:8001/metrics

# Database connection
docker exec -it nsready_db psql -U postgres -d nsready -c "SELECT now();"

# NATS connection
docker exec -it nsready_nats nats stream info INGRESS
```

---

## 5. Daily Operational Checks

### 5.1 Morning Checklist

**System Health:**
```bash
# 1. Check all services are running
docker-compose ps
# OR
kubectl get pods -n nsready-tier2

# 2. Check health endpoints
curl http://localhost:8001/v1/health
curl http://localhost:8000/health

# 3. Check queue depth
curl http://localhost:8001/v1/health | jq .queue_depth

# 4. Check database connection
docker exec -it nsready_db psql -U postgres -d nsready -c "SELECT count(*) FROM ingest_events;"
```

**Data Ingestion:**
```bash
# 1. Check recent ingestion events
docker exec -it nsready_db psql -U postgres -d nsready -c \
  "SELECT COUNT(*), MAX(ingested_at) FROM ingest_events WHERE ingested_at > NOW() - INTERVAL '1 hour';"

# 2. Check for errors in last hour
docker exec -it nsready_db psql -U postgres -d nsready -c \
  "SELECT COUNT(*) FROM error_logs WHERE time > NOW() - INTERVAL '1 hour';"
```

**Metrics Review:**
```bash
# Get Prometheus metrics
curl http://localhost:8001/metrics | grep ingest_events_total
curl http://localhost:8001/metrics | grep ingest_errors_total
curl http://localhost:8001/metrics | grep ingest_queue_depth
```

### 5.2 Afternoon Checklist

**Performance Monitoring:**
```bash
# 1. Check queue depth (should be low)
curl http://localhost:8001/v1/health | jq .queue_depth

# 2. Check processing rate
curl http://localhost:8001/metrics | grep ingest_rate_per_second

# 3. Check database size
docker exec -it nsready_db psql -U postgres -d nsready -c \
  "SELECT pg_size_pretty(pg_database_size('nsready'));"
```

**Error Review:**
```bash
# Check error logs
docker exec -it nsready_db psql -U postgres -d nsready -c \
  "SELECT level, message, time FROM error_logs ORDER BY time DESC LIMIT 10;"
```

### 5.3 End-of-Day Checklist

**Daily Summary:**
```bash
# 1. Total events ingested today
docker exec -it nsready_db psql -U postgres -d nsready -c \
  "SELECT COUNT(*) FROM ingest_events WHERE ingested_at::date = CURRENT_DATE;"

# 2. Error count today
docker exec -it nsready_db psql -U postgres -d nsready -c \
  "SELECT COUNT(*) FROM error_logs WHERE time::date = CURRENT_DATE;"

# 3. Queue status
curl http://localhost:8001/v1/health | jq .

# 4. Service uptime
docker-compose ps
```

---

## 6. Monitoring and Alerting

### 6.1 Key Metrics to Monitor

**System Health Metrics:**
- Service status (up/down)
- Database connection status
- NATS connection status
- Queue depth
- Worker processing status

**Performance Metrics:**
- Events ingested per second
- Queue processing rate
- Database query performance
- API response times
- Error rates

**Resource Metrics:**
- CPU usage
- Memory usage
- Disk usage
- Network I/O
- Database size

### 6.2 Prometheus Metrics

**Available Metrics:**
```bash
# Total events ingested
ingest_events_total{status="queued"}

# Total errors
ingest_errors_total{error_type="validation"}

# Queue depth
ingest_queue_depth

# Ingestion rate
ingest_rate_per_second
```

**Access Metrics:**
```bash
# Get all metrics
curl http://localhost:8001/metrics

# Filter specific metric
curl http://localhost:8001/metrics | grep ingest_queue_depth
```

### 6.3 Alerting Thresholds

**Critical Alerts (Immediate Action Required):**
- Service is down
- Database connection lost
- NATS connection lost
- Queue depth > 10,000
- Error rate > 10% of ingestion rate

**Warning Alerts (Investigation Required):**
- Queue depth > 1,000
- Error rate > 5% of ingestion rate
- Database size > 80% of allocated space
- API response time > 1 second (P95)
- Worker processing rate < 10 events/second

**Info Alerts (Monitoring):**
- Queue depth > 100
- Database size > 50% of allocated space
- Unusual error patterns

### 6.4 Log Monitoring

**Log Locations:**
```bash
# Docker Compose logs
docker-compose logs collector_service
docker-compose logs admin_tool
docker-compose logs db
docker-compose logs nats

# Kubernetes logs
kubectl logs -n nsready-tier2 <pod-name>
kubectl logs -n nsready-tier2 -f <pod-name>  # Follow logs
```

**Key Log Patterns to Monitor:**
- `ERROR` - Critical errors requiring immediate attention
- `WARNING` - Warnings that may indicate issues
- `Failed to connect` - Connection failures
- `Queue depth` - Queue depth warnings
- `Processing error` - Message processing failures

---

## 7. Troubleshooting Procedures

### 7.1 Service Not Starting

**Symptoms:**
- Container/pod fails to start
- Service returns 500 errors
- Health check fails

**Diagnosis:**
```bash
# Check container/pod status
docker-compose ps
# OR
kubectl get pods -n nsready-tier2

# Check logs
docker-compose logs collector_service
# OR
kubectl logs -n nsready-tier2 <pod-name>

# Check resource usage
docker stats
# OR
kubectl top pod -n nsready-tier2
```

**Common Causes:**
- Database connection failure
- NATS connection failure
- Missing environment variables
- Port conflicts
- Insufficient resources

**Resolution:**
1. Verify database is running and accessible
2. Verify NATS is running and accessible
3. Check environment variables
4. Verify ports are not in use
5. Check resource limits

### 7.2 Database Connection Issues

**Symptoms:**
- Health check shows "db": "disconnected"
- Worker fails to process messages
- API returns database errors

**Diagnosis:**
```bash
# Test database connection
docker exec -it nsready_db psql -U postgres -d nsready -c "SELECT now();"

# Check database logs
docker-compose logs db

# Check connection pool
docker exec -it nsready_db psql -U postgres -d nsready -c \
  "SELECT count(*) FROM pg_stat_activity WHERE datname = 'nsready';"
```

**Common Causes:**
- Database is down
- Incorrect connection credentials
- Network connectivity issues
- Connection pool exhausted
- Database is locked

**Resolution:**
1. Restart database container/pod
2. Verify connection credentials in `.env`
3. Check network connectivity
4. Increase connection pool size
5. Check for long-running transactions

### 7.3 NATS Connection Issues

**Symptoms:**
- Health check shows queue issues
- Events are not being queued
- Worker cannot consume messages

**Diagnosis:**
```bash
# Check NATS status
curl http://localhost:8222/varz

# Check NATS logs
docker-compose logs nats

# Check stream status
docker exec -it nsready_nats nats stream info INGRESS
```

**Common Causes:**
- NATS service is down
- Incorrect NATS URL
- Network connectivity issues
- Stream/consumer configuration issues

**Resolution:**
1. Restart NATS container/pod
2. Verify NATS URL in `.env`
3. Check network connectivity
4. Recreate stream/consumer if needed

### 7.4 Queue Depth Issues

**Symptoms:**
- Queue depth is high (> 1,000)
- Events are queued but not processed
- Worker is not consuming messages

**Diagnosis:**
```bash
# Check queue depth
curl http://localhost:8001/v1/health | jq .queue_depth

# Check worker status
docker-compose logs collector_service | grep worker

# Check NATS consumer status
docker exec -it nsready_nats nats consumer info INGRESS ingest_workers
```

**Common Causes:**
- Worker is not running
- Worker is processing slowly
- High ingestion rate
- Worker crashes

**Resolution:**
1. Restart worker/service
2. Scale up worker instances
3. Check worker logs for errors
4. Optimize worker processing
5. Check database performance

### 7.5 Data Ingestion Failures

**Symptoms:**
- Events are rejected with 400 errors
- Events are queued but not stored
- Validation errors in logs

**Diagnosis:**
```bash
# Check error logs
docker exec -it nsready_db psql -U postgres -d nsready -c \
  "SELECT * FROM error_logs ORDER BY time DESC LIMIT 10;"

# Check recent events
docker exec -it nsready_db psql -U postgres -d nsready -c \
  "SELECT * FROM ingest_events ORDER BY ingested_at DESC LIMIT 10;"

# Check metrics
curl http://localhost:8001/metrics | grep ingest_errors_total
```

**Common Causes:**
- Invalid event schema
- Missing required fields
- Invalid UUIDs
- Device/parameter not found
- Database constraint violations

**Resolution:**
1. Verify event schema matches requirements
2. Check device/parameter exists in database
3. Review validation error messages
4. Fix event payload format
5. Check database constraints

### 7.6 Performance Issues

**Symptoms:**
- Slow API response times
- High queue depth
- Slow database queries
- High CPU/memory usage

**Diagnosis:**
```bash
# Check API response times
time curl http://localhost:8001/v1/health

# Check database performance
docker exec -it nsready_db psql -U postgres -d nsready -c \
  "SELECT * FROM pg_stat_statements ORDER BY total_time DESC LIMIT 10;"

# Check resource usage
docker stats
# OR
kubectl top pod -n nsready-tier2
```

**Common Causes:**
- Insufficient resources
- Database query optimization needed
- High ingestion rate
- Missing indexes
- Connection pool issues

**Resolution:**
1. Increase resource allocation
2. Optimize database queries
3. Add missing indexes
4. Scale services horizontally
5. Tune connection pool settings

---

## 8. Maintenance Tasks

### 8.1 Daily Maintenance

**Tasks:**
- [ ] Review error logs
- [ ] Check queue depth
- [ ] Verify data ingestion
- [ ] Check service health
- [ ] Review metrics

**Commands:**
```bash
# Quick health check
./scripts/health_check.sh

# Review errors
docker exec -it nsready_db psql -U postgres -d nsready -c \
  "SELECT level, COUNT(*) FROM error_logs WHERE time > NOW() - INTERVAL '24 hours' GROUP BY level;"
```

### 8.2 Weekly Maintenance

**Tasks:**
- [ ] Review performance metrics
- [ ] Check database growth
- [ ] Verify backups
- [ ] Review error trends
- [ ] Update documentation

**Commands:**
```bash
# Database size
docker exec -it nsready_db psql -U postgres -d nsready -c \
  "SELECT pg_size_pretty(pg_database_size('nsready'));"

# Table sizes
docker exec -it nsready_db psql -U postgres -d nsready -c \
  "SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
   FROM pg_tables WHERE schemaname = 'public' ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;"
```

### 8.3 Monthly Maintenance

**Tasks:**
- [ ] Performance optimization review
- [ ] Security audit
- [ ] Capacity planning
- [ ] Disaster recovery testing
- [ ] Documentation updates

**Commands:**
```bash
# Database statistics
docker exec -it nsready_db psql -U postgres -d nsready -c \
  "SELECT schemaname, tablename, n_tup_ins, n_tup_upd, n_tup_del, n_live_tup, n_dead_tup
   FROM pg_stat_user_tables ORDER BY n_live_tup DESC;"

# Index usage
docker exec -it nsready_db psql -U postgres -d nsready -c \
  "SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read, idx_tup_fetch
   FROM pg_stat_user_indexes ORDER BY idx_scan DESC;"
```

### 8.4 Database Maintenance

**Vacuum and Analyze:**
```bash
# Vacuum database
docker exec -it nsready_db psql -U postgres -d nsready -c "VACUUM ANALYZE;"

# Vacuum specific table
docker exec -it nsready_db psql -U postgres -d nsready -c "VACUUM ANALYZE ingest_events;"
```

**Index Maintenance:**
```bash
# Reindex database
docker exec -it nsready_db psql -U postgres -d nsready -c "REINDEX DATABASE nsready;"

# Reindex specific table
docker exec -it nsready_db psql -U postgres -d nsready -c "REINDEX TABLE ingest_events;"
```

---

## 9. Backup and Recovery

### 9.1 Backup Procedures

**Database Backup:**
```bash
# Full database backup
docker exec -it nsready_db pg_dump -U postgres -d nsready -F c -f /backup/nsready_$(date +%Y%m%d_%H%M%S).dump

# Backup specific tables
docker exec -it nsready_db pg_dump -U postgres -d nsready -t ingest_events -F c -f /backup/ingest_events.dump
```

**Configuration Backup:**
```bash
# Backup registry configuration
docker exec -it nsready_db psql -U postgres -d nsready -c \
  "SELECT * FROM customers, projects, sites, devices, parameter_templates;" > registry_backup.sql
```

**Automated Backup Script:**
```bash
#!/bin/bash
# backup_nsready.sh

BACKUP_DIR="/backups/nsready"
DATE=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p $BACKUP_DIR

# Database backup
docker exec nsready_db pg_dump -U postgres -d nsready -F c -f /backup/nsready_$DATE.dump

# Copy backup from container
docker cp nsready_db:/backup/nsready_$DATE.dump $BACKUP_DIR/

# Cleanup old backups (keep last 7 days)
find $BACKUP_DIR -name "*.dump" -mtime +7 -delete

echo "Backup completed: $BACKUP_DIR/nsready_$DATE.dump"
```

### 9.2 Recovery Procedures

**Database Recovery:**
```bash
# Stop services
docker-compose down

# Restore database
docker exec -it nsready_db pg_restore -U postgres -d nsready -c /backup/nsready_YYYYMMDD_HHMMSS.dump

# Start services
docker-compose up -d
```

**Point-in-Time Recovery:**
```bash
# Requires WAL archiving configured
# Restore base backup
docker exec -it nsready_db pg_basebackup -U postgres -D /var/lib/postgresql/data/restore

# Replay WAL logs to point in time
docker exec -it nsready_db pg_wal_replay -D /var/lib/postgresql/data/restore --target-time "2024-01-15 10:00:00"
```

### 9.3 Backup Verification

**Verify Backup Integrity:**
```bash
# Test backup restore to temporary database
docker exec -it nsready_db createdb -U postgres nsready_test
docker exec -it nsready_db pg_restore -U postgres -d nsready_test /backup/nsready_YYYYMMDD_HHMMSS.dump
docker exec -it nsready_db psql -U postgres -d nsready_test -c "SELECT COUNT(*) FROM ingest_events;"
docker exec -it nsready_db dropdb -U postgres nsready_test
```

---

## 10. Emergency Procedures

### 10.1 Service Outage

**Immediate Actions:**
1. Check service status: `docker-compose ps` or `kubectl get pods`
2. Check logs: `docker-compose logs` or `kubectl logs`
3. Check health endpoints: `curl http://localhost:8001/v1/health`
4. Restart services if needed: `docker-compose restart` or `kubectl rollout restart`

**Escalation:**
- If restart doesn't resolve, check database and NATS
- Review error logs for root cause
- Contact database administrator if database issues
- Contact network team if connectivity issues

### 10.2 Data Loss

**Immediate Actions:**
1. Stop data ingestion to prevent further loss
2. Assess extent of data loss
3. Check backup availability
4. Notify stakeholders

**Recovery:**
1. Restore from most recent backup
2. Verify data integrity
3. Resume data ingestion
4. Document incident and lessons learned

### 10.3 Security Incident

**Immediate Actions:**
1. Isolate affected services
2. Change all credentials (database, API tokens)
3. Review access logs
4. Notify security team

**Investigation:**
1. Review authentication logs
2. Check for unauthorized access
3. Review database access logs
4. Document security incident

---

## 11. Performance Optimization

### 11.1 Database Optimization

**Index Optimization:**
```sql
-- Check missing indexes
SELECT schemaname, tablename, attname, n_distinct, correlation
FROM pg_stats
WHERE schemaname = 'public'
AND n_distinct > 100
AND correlation < 0.1;

-- Create indexes for frequently queried columns
CREATE INDEX IF NOT EXISTS idx_ingest_events_device_timestamp
ON ingest_events(device_id, source_timestamp);
```

**Query Optimization:**
```sql
-- Analyze query performance
EXPLAIN ANALYZE SELECT * FROM ingest_events WHERE device_id = '...';

-- Update statistics
ANALYZE ingest_events;
```

### 11.2 Worker Optimization

**Batch Size Tuning:**
- Increase batch size for higher throughput
- Decrease batch size for lower latency
- Monitor queue depth and adjust accordingly

**Worker Scaling:**
- Scale workers horizontally for higher throughput
- Monitor CPU and memory usage
- Balance between workers and database connections

### 11.3 API Optimization

**Connection Pooling:**
- Tune database connection pool size
- Monitor connection pool usage
- Adjust based on load

**Caching:**
- Cache frequently accessed configuration data
- Use Redis for distributed caching (future)
- Implement response caching for read-heavy endpoints

---

## 12. Security Best Practices

### 12.1 Authentication

- Use strong, randomly generated Bearer tokens
- Rotate tokens regularly (every 90 days)
- Use different tokens for different environments
- Never commit tokens to version control

### 12.2 Network Security

- Use HTTPS in production
- Restrict network access to required ports
- Use firewall rules to limit access
- Implement VPN for remote access

### 12.3 Database Security

- Use strong database passwords
- Limit database user privileges
- Use read-only users for SCADA access
- Enable SSL/TLS for database connections

### 12.4 Monitoring and Auditing

- Monitor authentication attempts
- Log all API access
- Review access logs regularly
- Set up alerts for suspicious activity

---

## 13. Operational Runbook Quick Reference

### 13.1 Common Commands

**Health Checks:**
```bash
# Service health
curl http://localhost:8001/v1/health
curl http://localhost:8000/health

# Container status
docker-compose ps

# Pod status
kubectl get pods -n nsready-tier2
```

**Logs:**
```bash
# All logs
docker-compose logs -f

# Specific service
docker-compose logs -f collector_service

# Last 100 lines
docker-compose logs --tail=100 collector_service
```

**Database:**
```bash
# Connect to database
docker exec -it nsready_db psql -U postgres -d nsready

# Quick queries
docker exec -it nsready_db psql -U postgres -d nsready -c "SELECT COUNT(*) FROM ingest_events;"
```

**Metrics:**
```bash
# Prometheus metrics
curl http://localhost:8001/metrics

# Queue depth
curl http://localhost:8001/v1/health | jq .queue_depth
```

### 13.2 Emergency Contacts

**On-Call Rotation:**
- Primary: [Contact Information]
- Secondary: [Contact Information]
- Escalation: [Contact Information]

**Vendor Contacts:**
- Database Support: [Contact Information]
- Infrastructure Support: [Contact Information]

### 13.3 Escalation Procedures

**Level 1 (Operator):**
- Service restart
- Basic troubleshooting
- Log review

**Level 2 (Engineer):**
- Advanced troubleshooting
- Performance optimization
- Configuration changes

**Level 3 (Architect/Manager):**
- Architecture changes
- Major incidents
- Capacity planning

---

## 14. Summary

This module provides a comprehensive operational checklist and runbook for the NSReady Data Collection Platform.

**Key Takeaways:**
- Pre-deployment checklists ensure readiness
- Daily operational checks maintain system health
- Monitoring and alerting provide early warning
- Troubleshooting procedures resolve issues quickly
- Maintenance tasks keep system optimized
- Backup and recovery protect data
- Emergency procedures ensure rapid response

**Next Steps:**
- Customize checklists for your environment
- Set up monitoring and alerting
- Test backup and recovery procedures
- Train operations team on procedures
- Document environment-specific procedures

**Related Modules:**
- Module 4 – Deployment & Startup Manual (deployment procedures)
- Module 7 – Data Validation & Error Handling (error troubleshooting)
- Module 8 – Ingestion Worker & Queue Processing (queue management)
- Module 11 – Testing Strategy & Test Suite Overview (testing procedures)

---

**Document Version:** 1.0  
**Last Updated:** 2024-01-15  
**Author:** NSReady Platform Team


