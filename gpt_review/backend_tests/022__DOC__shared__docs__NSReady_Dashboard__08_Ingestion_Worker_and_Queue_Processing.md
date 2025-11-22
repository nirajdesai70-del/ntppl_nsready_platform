# Module 8 – Ingestion Worker & Queue Processing

_NSReady Data Collection Platform_

*(Suggested path: `docs/08_Ingestion_Worker_and_Queue_Processing.md`)*

---

## 1. Purpose of This Document

This module provides a comprehensive guide to the ingestion worker pool and queue processing architecture in the NSReady Data Collection Platform. It covers:

- NATS JetStream message queue architecture
- Worker pool design and operation
- Message processing pipeline
- Batch processing and optimization
- ACK/NACK mechanisms and exactly-once semantics
- Queue management and monitoring
- Scaling strategies and performance tuning
- Configuration and troubleshooting

This module is essential for:
- **Engineers** deploying and operating the system
- **Developers** understanding async processing architecture
- **Operators** monitoring queue health and worker performance
- **Architects** designing scalable ingestion pipelines

**Prerequisites:**
- Module 0 – Introduction and Terminology
- Module 2 – System Architecture and Data Flow
- Module 7 – Data Validation & Error Handling

---

## 2. Queue Processing Architecture Overview

The NSReady platform uses a **decoupled, asynchronous processing architecture** that separates fast request acceptance from slower database operations.

```
┌─────────────────────────────────────────────────────────────┐
│ Collector Service (Fast Path)                              │
│ - Accepts HTTP requests                                     │
│ - Validates event schema                                    │
│ - Publishes to NATS queue                                   │
│ - Returns immediately (200 OK)                              │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       v
┌─────────────────────────────────────────────────────────────┐
│ NATS JetStream (Message Queue)                             │
│ - Persistent message storage                                │
│ - Durable consumer groups                                   │
│ - Automatic redelivery                                      │
│ - Dead letter queue (DLQ)                                   │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       v
┌─────────────────────────────────────────────────────────────┐
│ Worker Pool (Processing Engine)                             │
│ - Pulls messages in batches                                 │
│ - Validates business logic                                  │
│ - Inserts into database                                     │
│ - ACKs on success, NACKs on failure                         │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       v
┌─────────────────────────────────────────────────────────────┐
│ PostgreSQL + TimescaleDB                                    │
│ - Batch inserts for efficiency                              │
│ - Transaction safety                                        │
│ - Hypertable optimization                                   │
└─────────────────────────────────────────────────────────────┘
```

**Key Design Principles:**

1. **Decoupling** - Collector and workers operate independently
2. **Resilience** - Queue buffers messages during worker failures
3. **Scalability** - Workers can scale independently of collectors
4. **Exactly-Once** - ACK-based processing ensures no data loss
5. **Backpressure Protection** - Queue absorbs traffic spikes

---

## 3. NATS JetStream Architecture

### 3.1 What is NATS JetStream?

NATS JetStream is a **persistent message streaming system** built on top of NATS. It provides:

- **Message Persistence** - Messages stored until consumed
- **Durable Consumers** - Consumer state persists across restarts
- **Exactly-Once Delivery** - ACK-based message acknowledgment
- **Automatic Redelivery** - Failed messages automatically retried
- **Dead Letter Queue** - Messages that fail after max retries

### 3.2 Stream Configuration

**Stream Name:** `INGRESS`

**Purpose:** Store all incoming telemetry events until processed.

**Configuration:**

```javascript
{
  "name": "INGRESS",
  "subjects": ["ingress.events"],
  "retention": "workqueue",  // Remove after ACK
  "max_age": 86400,          // 24 hours max age
  "storage": "file",         // Persistent to disk
  "replicas": 1,             // Single replica (can scale)
  "max_msgs": 1000000,       // Max 1M messages
  "max_bytes": 1073741824    // Max 1GB
}
```

**Key Settings:**

- **Retention: Workqueue** - Messages removed after ACK (not kept forever)
- **Storage: File** - Messages persisted to disk (survives restarts)
- **Max Age: 24 hours** - Old unprocessed messages expire
- **Max Messages: 1M** - Prevents unbounded growth

### 3.3 Consumer Configuration

**Consumer Name:** `ingest_workers`

**Purpose:** Worker pool consumes messages from this consumer.

**Configuration:**

```javascript
{
  "durable_name": "ingest_workers",
  "deliver_subject": "",      // Pull mode (no push)
  "ack_policy": "explicit",   // Must ACK after processing
  "max_deliver": 5,          // Max 5 redelivery attempts
  "ack_wait": 30,            // 30s ACK timeout
  "pull_batch_size": 50,     // Pull 50 messages at a time
  "max_ack_pending": 100     // Max 100 un-ACKed messages
}
```

**Key Settings:**

- **Ack Policy: Explicit** - Workers must explicitly ACK messages
- **Max Deliver: 5** - Messages redelivered up to 5 times
- **Ack Wait: 30s** - If not ACKed in 30s, redeliver
- **Pull Batch Size: 50** - Workers pull 50 messages per batch
- **Max Ack Pending: 100** - Limit un-ACKed messages per worker

### 3.4 Message Flow

```
1. Collector publishes message to "ingress.events"
   ↓
2. JetStream stores message in INGRESS stream
   ↓
3. Worker pulls batch from "ingest_workers" consumer
   ↓
4. Worker processes messages
   ↓
5. Worker ACKs successful messages
   ↓
6. JetStream removes ACKed messages
   ↓
7. Failed messages (NACK) are redelivered after timeout
```

### 3.5 NATS Connection

**Connection Details:**

- **Host:** `nats` (default, configurable via `NATS_HOST`)
- **Port:** `4222` (default, configurable via `NATS_PORT`)
- **Subject:** `ingress.events` (default, configurable via `QUEUE_SUBJECT`)
- **Protocol:** NATS (non-TLS by default, TLS available)

**Connection Retry Logic:**

```python
async def connect(self, max_retries: int = 10, retry_delay: int = 2):
    """Connect to NATS with retry logic"""
    for attempt in range(max_retries):
        try:
            await self.nc.connect(f"nats://{self.host}:{self.port}")
            logger.info(f"Connected to NATS at {self.host}:{self.port}")
            return
        except Exception as e:
            logger.warning(f"NATS connection attempt {attempt + 1}/{max_retries} failed: {e}")
            if attempt < max_retries - 1:
                await asyncio.sleep(retry_delay)
            else:
                raise
```

**Benefits:**

- **Automatic Retry** - Handles temporary NATS unavailability
- **Graceful Degradation** - Service starts even if NATS is slow to come up
- **Health Monitoring** - Connection status tracked in health checks

---

## 4. Worker Pool Architecture

### 4.1 Worker Design

**Worker Class:** `IngestWorker`

**Responsibilities:**

1. **Subscribe** to NATS subject
2. **Receive** messages from queue
3. **Parse** JSON event data
4. **Validate** business logic (device exists, parameter exists)
5. **Insert** into database (batch insert)
6. **Commit** transaction
7. **Acknowledge** message (implicit ACK on success)

**Worker Lifecycle:**

```python
class IngestWorker:
    def __init__(self, nc: NATS, session_factory, subject: str):
        self.nc = nc
        self.session_factory = session_factory
        self.subject = subject
        self.subscription = None
        self.running = False
    
    async def start(self):
        """Start the worker"""
        self.running = True
        self.subscription = await self.nc.subscribe(
            self.subject, 
            cb=self._handle_message
        )
        logger.info(f"Worker started, subscribed to {self.subject}")
    
    async def stop(self):
        """Stop the worker gracefully"""
        self.running = False
        if self.subscription:
            await self.subscription.unsubscribe()
        logger.info("Worker stopped")
```

### 4.2 Message Processing Pipeline

**Processing Flow:**

```
1. Message received from NATS
   ↓
2. Parse JSON payload
   ↓
3. Extract event data and trace_id
   ↓
4. Validate event structure
   ↓
5. For each metric in event:
   a. Generate unique event_id
   b. Insert into ingest_events table
   c. Use ON CONFLICT for idempotency
   ↓
6. Commit database transaction
   ↓
7. Increment success metrics
   ↓
8. Log success (implicit ACK)
```

**Code Flow:**

```python
async def _handle_message(self, msg):
    """Handle incoming NATS message"""
    try:
        # Parse JSON
        data = json.loads(msg.data.decode())
        trace_id = data.get("trace_id")
        event_data = data.get("event")
        
        # Validate structure
        if not event_data:
            logger.error("Invalid message format: missing event data")
            error_counter.labels(error_type="invalid_format").inc()
            return
        
        # Parse event
        event = NormalizedEvent(**event_data)
        
        # Process event
        await self._process_event(event, trace_id)
        
    except json.JSONDecodeError as e:
        logger.error(f"Failed to decode message: {e}")
        error_counter.labels(error_type="json_decode").inc()
    except Exception as e:
        logger.error(f"Error handling message: {e}", exc_info=True)
        error_counter.labels(error_type="processing").inc()
```

### 4.3 Database Insertion

**Batch Insert Strategy:**

Workers process events one at a time, but each event can contain multiple metrics. Metrics are inserted using a batch approach within a single transaction.

**Insert Logic:**

```python
async def _process_event(self, event: NormalizedEvent, trace_id: str):
    """Process a single event and insert into database"""
    async with self.session_factory() as session:
        try:
            # Insert each metric as a separate row
            for metric in event.metrics:
                # Generate unique event_id for idempotency
                if event.event_id:
                    event_id = f"{event.event_id}:{metric.parameter_key}"
                else:
                    event_id = f"{event.device_id}:{event.source_timestamp.isoformat()}:{metric.parameter_key}"
                
                # Use ON CONFLICT for idempotency
                insert_stmt = text("""
                    INSERT INTO ingest_events (
                        time, device_id, parameter_key, value, quality, 
                        source, event_id, attributes, created_at
                    ) VALUES (
                        :time, CAST(:device_id AS uuid), :parameter_key, :value, :quality,
                        :source, :event_id, CAST(:attributes AS jsonb), NOW()
                    )
                    ON CONFLICT (time, device_id, parameter_key) 
                    DO UPDATE SET
                        value = EXCLUDED.value,
                        quality = EXCLUDED.quality,
                        source = EXCLUDED.source,
                        event_id = EXCLUDED.event_id,
                        attributes = EXCLUDED.attributes
                """)
                
                await session.execute(insert_stmt, {
                    "time": event.source_timestamp,
                    "device_id": event.device_id,
                    "parameter_key": metric.parameter_key,
                    "value": metric.value,
                    "quality": metric.quality,
                    "source": event.protocol,
                    "event_id": event_id,
                    "attributes": json.dumps(metric.attributes or {})
                })
            
            # Commit transaction
            await session.commit()
            ingest_counter.labels(status="success").inc()
            
        except IntegrityError as e:
            await session.rollback()
            logger.warning(f"Integrity error for trace_id={trace_id}: {e}")
            error_counter.labels(error_type="integrity").inc()
        except Exception as e:
            await session.rollback()
            logger.error(f"Error processing event trace_id={trace_id}: {e}", exc_info=True)
            error_counter.labels(error_type="database").inc()
            raise
```

**Key Features:**

- **Idempotency** - `ON CONFLICT` prevents duplicate inserts
- **Transaction Safety** - All metrics in event inserted atomically
- **Error Handling** - Rollback on failure, metrics tracked
- **Performance** - Single transaction per event (efficient)

### 4.4 Worker Pool Configuration

**Current Implementation:**

- **Single Worker** - One worker instance per collector service
- **Async Processing** - Non-blocking message handling
- **Database Sessions** - One session per event (transaction safety)

**Configuration Variables:**

```bash
# NATS Configuration
NATS_HOST=nats                    # NATS server host
NATS_PORT=4222                    # NATS server port
QUEUE_SUBJECT=ingress.events      # NATS subject for events

# Worker Configuration (future)
WORKER_POOL_SIZE=4                # Number of parallel workers (not yet implemented)
WORKER_BATCH_SIZE=50              # Messages per batch (JetStream consumer setting)
WORKER_BATCH_TIMEOUT=0.5          # Batch timeout in seconds
```

**Scaling Strategy:**

Currently, workers scale by:
1. **Horizontal Scaling** - Run multiple collector service replicas
2. **Each Replica** - Has one worker instance
3. **Load Balancing** - NATS JetStream distributes messages across consumers

**Future Enhancement:**

- **Worker Pool** - Multiple workers per service instance
- **Parallel Processing** - Process multiple events concurrently
- **Batch Processing** - Process multiple messages in single transaction

---

## 5. ACK/NACK Mechanisms

### 5.1 Acknowledgment Model

**NATS JetStream ACK Modes:**

- **Explicit ACK** - Worker must explicitly acknowledge message
- **Implicit ACK** - Message ACKed automatically on success
- **NACK** - Negative acknowledgment (redeliver message)

**Current Implementation:**

- **Implicit ACK** - Messages are ACKed automatically when processing completes successfully
- **NACK on Error** - Failed messages are not ACKed, causing automatic redelivery

### 5.2 ACK Flow

**Successful Processing:**

```
1. Worker receives message
   ↓
2. Worker processes event
   ↓
3. Database insert succeeds
   ↓
4. Transaction commits
   ↓
5. Worker function returns (no exception)
   ↓
6. NATS automatically ACKs message (implicit)
   ↓
7. Message removed from queue
```

**Failed Processing:**

```
1. Worker receives message
   ↓
2. Worker processes event
   ↓
3. Database insert fails (exception raised)
   ↓
4. Transaction rolls back
   ↓
5. Worker function raises exception
   ↓
6. NATS does NOT ACK message
   ↓
7. After ACK_WAIT timeout (30s), message redelivered
   ↓
8. Process repeats up to MAX_DELIVER (5) times
   ↓
9. If still failing → Move to Dead Letter Queue (DLQ)
```

### 5.3 Exactly-Once Semantics

**Idempotency Guarantees:**

1. **Database Level** - `ON CONFLICT` prevents duplicate inserts
2. **Message Level** - ACK ensures message processed exactly once
3. **Trace ID** - Optional trace_id for end-to-end tracking

**Idempotency Key:**

```python
# Unique event_id per metric
event_id = f"{event.device_id}:{event.source_timestamp.isoformat()}:{metric.parameter_key}"

# Database constraint
UNIQUE (time, device_id, parameter_key)
```

**Benefits:**

- **No Duplicates** - Same event processed multiple times = single database row
- **Crash Recovery** - Worker crash doesn't cause data loss (message redelivered)
- **Retry Safety** - Retrying failed messages is safe (idempotent)

### 5.4 Redelivery Logic

**Automatic Redelivery:**

- **Trigger:** Message not ACKed within `ACK_WAIT` (30 seconds)
- **Max Attempts:** `MAX_DELIVER` (5 times)
- **Backoff:** Configurable (currently immediate)

**Redelivery Flow:**

```
Attempt 1: Process → Fail → Wait 30s → Redeliver
Attempt 2: Process → Fail → Wait 30s → Redeliver
Attempt 3: Process → Fail → Wait 30s → Redeliver
Attempt 4: Process → Fail → Wait 30s → Redeliver
Attempt 5: Process → Fail → Wait 30s → Redeliver
After 5: Move to DLQ (Dead Letter Queue)
```

**Dead Letter Queue (DLQ):**

- **Purpose:** Store messages that fail after max retries
- **Analysis:** Investigate DLQ messages to identify systemic issues
- **Recovery:** Manually reprocess DLQ messages after fixing root cause

---

## 6. Queue Management and Monitoring

### 6.1 Queue Depth Monitoring

**Health Check Endpoint:**

```bash
GET /v1/health
```

**Response:**

```json
{
  "service": "ok",
  "queue_depth": 0,
  "db": "connected"
}
```

**Queue Depth Metric:**

```python
queue_depth_gauge = Gauge(
    'ingest_queue_depth',
    'Current depth of the ingestion queue'
)
```

**Monitoring:**

- **Low Queue Depth (< 100)** - Healthy, workers keeping up
- **Medium Queue Depth (100-1000)** - Normal load, monitor
- **High Queue Depth (> 1000)** - Workers falling behind, investigate

### 6.2 Performance Metrics

**Key Metrics:**

1. **Ingestion Rate**
   ```
   ingest_events_total{status="success"} / time
   ```

2. **Error Rate**
   ```
   ingest_errors_total{error_type="..."} / time
   ```

3. **Queue Depth**
   ```
   ingest_queue_depth
   ```

4. **Processing Latency**
   ```
   time(ACK) - time(publish)
   ```

**Prometheus Queries:**

```promql
# Ingestion rate (events per second)
rate(ingest_events_total{status="success"}[5m])

# Error rate by type
rate(ingest_errors_total{error_type="database"}[5m])

# Queue depth trend
ingest_queue_depth

# Processing latency (if trace_id timestamps available)
histogram_quantile(0.95, ingest_processing_duration_seconds_bucket)
```

### 6.3 Alerting Recommendations

**Critical Alerts:**

1. **High Queue Depth**
   - Condition: `ingest_queue_depth > 5000`
   - Action: Scale workers or investigate processing delays

2. **High Error Rate**
   - Condition: `rate(ingest_errors_total[5m]) > 10`
   - Action: Investigate error types and root causes

3. **Worker Not Processing**
   - Condition: `rate(ingest_events_total[5m]) == 0 AND ingest_queue_depth > 0`
   - Action: Check worker health, restart if needed

4. **Database Connection Issues**
   - Condition: `rate(ingest_errors_total{error_type="database"}[5m]) > 1`
   - Action: Check database connectivity and health

### 6.4 Queue Health Checks

**Regular Monitoring:**

1. **Queue Depth** - Should remain low under normal load
2. **Processing Rate** - Should match ingestion rate
3. **Error Rate** - Should be minimal (< 1% of total)
4. **Worker Health** - All workers should be processing messages

**Health Check Script:**

```bash
#!/bin/bash
# Check queue health

QUEUE_DEPTH=$(curl -s http://localhost:8001/v1/health | jq -r '.queue_depth')
ERROR_RATE=$(curl -s http://localhost:8001/metrics | grep 'ingest_errors_total' | awk '{print $2}')

if [ "$QUEUE_DEPTH" -gt 1000 ]; then
    echo "WARNING: High queue depth: $QUEUE_DEPTH"
fi

if [ "$ERROR_RATE" -gt 10 ]; then
    echo "WARNING: High error rate: $ERROR_RATE"
fi
```

---

## 7. Scaling and Performance

### 7.1 Horizontal Scaling

**Current Approach:**

- **Multiple Collector Replicas** - Each has one worker
- **NATS Load Balancing** - JetStream distributes messages across consumers
- **Independent Scaling** - Scale collectors and workers independently

**Scaling Strategy:**

```yaml
# docker-compose.yml
services:
  collector_service:
    deploy:
      replicas: 3  # 3 collector instances = 3 workers
```

**Benefits:**

- **High Availability** - Worker failure doesn't stop processing
- **Load Distribution** - Messages distributed across workers
- **Easy Scaling** - Increase replicas to handle more load

### 7.2 Performance Optimization

**Database Optimization:**

1. **Batch Inserts** - Insert multiple metrics in single transaction
2. **Connection Pooling** - Reuse database connections
3. **Hypertable Partitioning** - TimescaleDB optimizes time-series inserts
4. **Index Optimization** - Proper indexes on frequently queried columns

**Queue Optimization:**

1. **Batch Pulling** - Pull multiple messages at once (50 messages)
2. **Parallel Processing** - Process multiple events concurrently (future)
3. **Message Compression** - Compress large messages (future)

**Worker Optimization:**

1. **Async Processing** - Non-blocking I/O for database operations
2. **Connection Reuse** - Reuse database sessions efficiently
3. **Error Handling** - Fast failure detection and recovery

### 7.3 Capacity Planning

**Throughput Estimates:**

- **Single Worker:** ~100-500 events/second (depends on metrics per event)
- **3 Workers:** ~300-1500 events/second
- **10 Workers:** ~1000-5000 events/second

**Factors Affecting Throughput:**

1. **Metrics per Event** - More metrics = slower processing
2. **Database Performance** - Faster DB = higher throughput
3. **Network Latency** - Lower latency = higher throughput
4. **Message Size** - Larger messages = slower processing

**Capacity Planning Formula:**

```
Required Workers = (Peak Events/Second) / (Events/Second per Worker)
```

**Example:**

- Peak load: 2000 events/second
- Worker capacity: 200 events/second
- Required workers: 2000 / 200 = 10 workers

---

## 8. Configuration

### 8.1 Environment Variables

**NATS Configuration:**

```bash
NATS_HOST=nats                    # NATS server hostname
NATS_PORT=4222                    # NATS server port
QUEUE_SUBJECT=ingress.events      # NATS subject for events
```

**Worker Configuration:**

```bash
# Future configuration options
WORKER_POOL_SIZE=4                # Number of workers per instance
WORKER_BATCH_SIZE=50              # Messages per batch
WORKER_BATCH_TIMEOUT=0.5          # Batch timeout (seconds)
WORKER_MAX_RETRIES=5              # Max retry attempts
WORKER_ACK_WAIT=30                # ACK wait timeout (seconds)
```

**Database Configuration:**

```bash
DB_HOST=db                        # Database hostname
DB_PORT=5432                      # Database port
POSTGRES_DB=nsready               # Database name
POSTGRES_USER=postgres            # Database user
POSTGRES_PASSWORD=postgres        # Database password
```

### 8.2 NATS JetStream Configuration

**Stream Configuration (via NATS CLI or API):**

```bash
# Create stream
nats stream add INGRESS \
  --subjects ingress.events \
  --retention workqueue \
  --storage file \
  --max-age 24h \
  --max-msgs 1000000 \
  --max-bytes 1GB

# Create consumer
nats consumer add INGRESS ingest_workers \
  --ack explicit \
  --max-deliver 5 \
  --ack-wait 30s \
  --pull-batch 50 \
  --max-ack-pending 100
```

### 8.3 Docker Compose Configuration

**Example Configuration:**

```yaml
services:
  collector_service:
    environment:
      - NATS_HOST=nats
      - NATS_PORT=4222
      - QUEUE_SUBJECT=ingress.events
      - DB_HOST=db
      - DB_PORT=5432
    deploy:
      replicas: 3  # Scale workers by scaling replicas
```

---

## 9. Troubleshooting

### 9.1 Queue Depth Growing

**Symptoms:**
- Queue depth continuously increasing
- Workers not keeping up with ingestion rate

**Diagnosis:**

```bash
# Check queue depth
curl http://localhost:8001/v1/health | jq '.queue_depth'

# Check processing rate
curl http://localhost:8001/metrics | grep ingest_events_total

# Check worker logs
docker logs collector_service | grep "Worker"
```

**Resolution:**

1. **Scale Workers** - Increase collector service replicas
2. **Check Database** - Ensure database can handle write load
3. **Check Errors** - Investigate high error rates
4. **Optimize Queries** - Review database insert performance

### 9.2 Messages Not Processing

**Symptoms:**
- Queue depth > 0 but no processing
- No worker activity in logs

**Diagnosis:**

```bash
# Check worker status
docker logs collector_service | grep "Worker started"

# Check NATS connection
docker logs collector_service | grep "NATS"

# Check database connection
docker logs collector_service | grep "Database"
```

**Resolution:**

1. **Restart Worker** - Restart collector service
2. **Check NATS** - Ensure NATS is running and accessible
3. **Check Database** - Ensure database is running and accessible
4. **Check Logs** - Review error logs for root cause

### 9.3 High Error Rate

**Symptoms:**
- High `ingest_errors_total` metric
- Many messages in DLQ

**Diagnosis:**

```bash
# Check error types
curl http://localhost:8001/metrics | grep ingest_errors_total

# Check DLQ messages
nats stream info INGRESS
```

**Resolution:**

1. **Identify Error Type** - Check which error_type is high
2. **Fix Root Cause** - Address underlying issue (see Module 7)
3. **Reprocess DLQ** - Manually reprocess DLQ messages after fix
4. **Monitor** - Watch error rate decrease

### 9.4 NATS Connection Issues

**Symptoms:**
- Worker cannot connect to NATS
- Connection errors in logs

**Diagnosis:**

```bash
# Check NATS connectivity
docker exec collector_service ping nats

# Check NATS logs
docker logs nats

# Check NATS health
curl http://nats:8222/healthz
```

**Resolution:**

1. **Check NATS Service** - Ensure NATS container is running
2. **Check Network** - Ensure containers are on same network
3. **Check Configuration** - Verify NATS_HOST and NATS_PORT
4. **Check Firewall** - Ensure port 4222 is accessible

---

## 10. Best Practices

### 10.1 Queue Management

1. **Monitor Queue Depth** - Set up alerts for high queue depth
2. **Scale Proactively** - Scale workers before queue depth grows
3. **Monitor Error Rates** - Investigate high error rates immediately
4. **Review DLQ Regularly** - Check DLQ for systemic issues

### 10.2 Worker Configuration

1. **Right-Size Workers** - Balance worker count with database capacity
2. **Monitor Performance** - Track processing rate and latency
3. **Optimize Batch Size** - Adjust batch size for optimal throughput
4. **Tune Timeouts** - Set appropriate ACK wait and batch timeouts

### 10.3 Error Handling

1. **Log Everything** - Comprehensive logging for troubleshooting
2. **Track Metrics** - Monitor error rates and types
3. **Set Alerts** - Alert on high error rates
4. **Investigate Root Causes** - Don't just retry, fix underlying issues

### 10.4 Performance Optimization

1. **Database Tuning** - Optimize database for write-heavy workload
2. **Connection Pooling** - Reuse database connections efficiently
3. **Batch Processing** - Process multiple messages when possible
4. **Monitor Latency** - Track end-to-end processing time

---

## 11. Summary

### 11.1 Key Takeaways

1. **Decoupled Architecture** - Collector and workers operate independently
2. **Queue as Buffer** - NATS JetStream buffers messages during load spikes
3. **Exactly-Once Processing** - ACK-based semantics ensure no data loss
4. **Automatic Recovery** - Failed messages automatically redelivered
5. **Horizontal Scaling** - Scale workers by scaling service replicas

### 11.2 Related Modules

- **Module 0** - Introduction and Terminology
- **Module 2** - System Architecture and Data Flow
- **Module 7** - Data Validation & Error Handling
- **Module 9** - SCADA Views & Export Mapping (upcoming)
- **Module 11** - Testing Strategy & Test Suite Overview (upcoming)
- **Module 13** - Operational Checklist & Runbook (upcoming)

### 11.3 Next Steps

After understanding worker and queue processing:

1. **Monitor Queue Health** - Set up monitoring and alerting
2. **Tune Performance** - Optimize worker and database configuration
3. **Scale as Needed** - Scale workers based on load
4. **Review Module 9** - Understand SCADA views and export mapping

---

**Module Created:** 2025-11-22  
**Last Updated:** 2025-11-22  
**Status:** Complete

