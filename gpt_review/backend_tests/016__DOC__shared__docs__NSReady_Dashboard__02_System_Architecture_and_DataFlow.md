# Module 2 – System Architecture and DataFlow

_NSReady Data Collection Platform_

*(Suggested path: `docs/02_System_Architecture_and_DataFlow.md`)*

---

## 1. Purpose of This Document

This module provides a full architectural overview of the NSReady Data Collection Platform, covering:

- Core components
- Their responsibilities
- How they communicate
- Data flow from field devices to SCADA
- System lifecycle
- Synchronous vs asynchronous paths
- Key design principles

This module is critical for engineers, SCADA teams, integrators, and developers to understand the complete system before proceeding to deployment, configuration, or ingestion testing.

---

## 2. High-Level Architecture Overview

NSReady follows a modular microservice + message streaming architecture, optimized for industrial data collection reliability.

```
+-------------------+        +-----------------+        +-----------------+
| Field Devices     | --->   | Collector API   | --->   | NATS JetStream |
| (GPRS/SMS/Sim.)   |        | (/v1/ingest)    |        |   (Queue)       |
+-------------------+        +-----------------+        +-----------------+
                                                         |
                                                         v
                                                +----------------+
                                                | Worker Pool    |
                                                | (Consumers)    |
                                                +----------------+
                                                         |
                                                         v
                                            +-------------------------+
                                            | PostgreSQL / Timescale  |
                                            | - ingest_events         |
                                            | - SCADA views           |
                                            +-------------------------+
                                                         |
                                                         v
                                            +-------------------------+
                                            | SCADA / Export / API    |
                                            +-------------------------+
```

---

## 3. Architectural Principles

### ✔ Modular

Each component is independent and replaceable.

- Collector can scale independently from workers
- Database can be upgraded without affecting services
- NATS can be replaced with another message broker (with code changes)

### ✔ Reliable

JetStream ensures delivery even during temporary outages.

- Messages persisted to disk
- Automatic redelivery on worker failure
- Exactly-once semantics via ACK-based consumption

### ✔ Scalable

Worker pool can scale horizontally.

- Multiple workers process messages in parallel
- Collector stateless, can run multiple replicas
- Database scales vertically (TimescaleDB hypertables)

### ✔ Transparent

Metrics, logs, views, and health APIs provide full visibility.

- `/v1/health` endpoint shows queue depth and DB status
- `/metrics` endpoint provides Prometheus metrics
- SCADA views expose latest and historical data
- Comprehensive logging at all levels

### ✔ NSWare-ready

Output format and structure fully align with future NSWare integration.

- NormalizedEvent schema designed for NSWare compatibility
- Clean data separation (raw vs. processed)
- API-ready architecture

---

## 4. Component-Level Architecture

The platform consists of 6 primary components.

### 4.1 Component 1 — Field Devices (Real or Simulator)

**Devices send telemetry using:**

- JSON (preferred format)
- HTTP POST requests
- GPRS/GSM networks
- SMS via gateway (if adapted in future)
- Simulator input via Mac/curl/JSON files

**Device responsibility:**

- Generate raw telemetry measurements
- Assign source timestamps (ISO 8601 format)
- Send at configured intervals (typically 3 minutes to 6 hours)
- Include device identity (device_id, project_id, site_id)

**Data Format:**

Devices must send data conforming to the `NormalizedEvent` schema:

```json
{
  "project_id": "uuid",
  "site_id": "uuid",
  "device_id": "uuid",
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

**Data is normalized using NormalizedEvent.**

---

### 4.2 Component 2 — Collector-Service (FastAPI)

**Collector-service exposes the ingestion API:**

```
POST /v1/ingest
GET /v1/health
GET /metrics
```

**Responsibilities:**

- **Validate** NormalizedEvent JSON schema
- **Check** required fields (device_id, metrics, etc.)
- **Verify** UUID format and parameter_key existence
- **Assign** trace_id for request tracking
- **Push** validated event into JetStream queue
- **Expose** `/v1/health` with queue depth + DB status
- **Expose** `/metrics` for Prometheus monitoring

**Key Features:**

- **Stateless** - No internal state, can be horizontally scaled
- **Fast** - Minimal processing, queues immediately
- **Validation** - Rejects invalid events before queuing
- **Idempotency** - Supports `event_id` for duplicate detection

**Ports:**

- `8001` - Default service port (Docker Compose)
- `32001` - Kubernetes NodePort (external access)

**Scaling:**

- Can run multiple collector replicas
- Stateless design allows load balancing
- Each replica connects to same NATS stream

---

### 4.3 Component 3 — NATS JetStream

**JetStream provides:**

#### Message Persistence

Messages are stored until consumed.

- Messages persisted to disk
- Survives service restarts
- Configurable retention policies

#### Durable Consumer

Workers pick up exactly once (ack-based).

- Consumer named "ingest_workers"
- Pull-based consumption
- ACK required after successful processing
- Automatic NACK on failure for redelivery

#### Backpressure Protection

Collector never slows down when worker load increases.

- Queue buffers messages during peak load
- Collector responds immediately after queuing
- Workers process at their own pace

#### Redelivery

Automatically retries if worker fails.

- Messages redelivered if not ACKed within timeout
- Configurable max redelivery attempts
- Failed messages can be sent to DLQ (Dead Letter Queue)

#### Queue Depth Metrics

Used for monitoring and packet health in Module 08.

- Real-time queue depth available via `/v1/health`
- Metrics exposed via `/metrics` endpoint
- Critical for understanding system load

**Architecture:**

```
Stream: INGRESS
   ↓
Consumer: ingest_workers (pull mode)
   ↓
Workers pull in batches (default: 50 messages)
```

**Ports:**

- `4222` - NATS client port
- `8222` - NATS monitoring port

**Configuration:**

- Stream name: "INGRESS"
- Consumer name: "ingest_workers"
- Pull batch size: Configurable (default: 50)
- ACK mode: Explicit (ACK required)

---

### 4.4 Component 4 — Worker Pool

**Workers are the processing engine.**

**Responsibilities:**

- **Pull** messages from JetStream (batch mode)
- **Parse** events from JSON
- **Validate** device/parameter mapping against database
- **Convert** metrics into database rows
- **Insert** into PostgreSQL (batch insert)
- **Commit** transaction
- **Acknowledge** message to JetStream

**Worker Scaling:**

- **Default:** 4 workers (configurable via `WORKER_POOL_SIZE`)
- **Recommended:** 4-10 workers depending on ingestion volume
- **Independent** from collector scaling
- **Automatic** load balancing via JetStream consumer

**Configuration:**

```bash
WORKER_POOL_SIZE=4              # Number of parallel workers
WORKER_BATCH_SIZE=50            # Messages per batch
WORKER_BATCH_TIMEOUT=0.5        # Batch timeout (seconds)
```

**Why this separation?**

```
Collector: Fast → accepts request → queues
Worker:    Slow, controlled → DB safe insert
```

**Benefits:**

- **Prevents DB overload** - Workers control insert rate
- **Better throughput** - Batch inserts are more efficient
- **Fault isolation** - Worker failures don't affect collector
- **Independent scaling** - Scale workers based on DB capacity

**Transaction Safety:**

- Workers only ACK messages **after** successful DB commit
- Failed transactions cause message NACK (redelivery)
- Ensures exactly-once processing semantics

---

### 4.5 Component 5 — PostgreSQL + TimescaleDB

**Database roles:**

- **Store** raw telemetry (`ingest_events` hypertable)
- **Store** registry (customers/projects/sites/devices)
- **Store** parameter templates
- **Provide** SCADA-friendly views (`v_scada_latest`, `v_scada_history`)
- **Provide** time-series compression & retention
- **Support** high write throughput (hypertables)

**Important DB structures:**

#### Tables:

- `customers` - Customer registry
- `projects` - Project registry
- `sites` - Site registry
- `devices` - Device registry
- `parameter_templates` - Parameter definitions
- `ingest_events` - **Hypertable** for raw telemetry (time-series)
- `measurements` - Optional aggregated measurements (future)
- `error_logs` - Error logging table
- `missing_intervals` - Missing data tracking (future)
- `registry_versions` - Configuration versioning

#### Views:

- `v_scada_latest` - Latest value per device/parameter
- `v_scada_history` - Full historical data for SCADA

**TimescaleDB Features:**

- **Hypertables** - Automatic time-based partitioning
- **Compression** - Automatic data compression (after 7 days)
- **Retention** - Automatic data retention policies (default: 90 days)
- **High Performance** - Optimized for time-series inserts

**Connection:**

- Default port: `5432`
- Database name: `nsready`
- Users:
  - `postgres` - Admin user
  - `scada_reader` - Read-only SCADA user (created via script)

---

### 4.6 Component 6 — SCADA Integration

**SCADA consumes NSReady output through:**

1. **SQL read-only connection**
   - Direct PostgreSQL connection
   - User: `scada_reader` (read-only privileges)
   - Views: `v_scada_latest`, `v_scada_history`

2. **SCADA export files**
   - TXT/CSV format exports
   - Latest values or full history
   - Human-readable or raw format

3. **Materialized views** (optional)
   - Pre-aggregated data
   - Faster queries for dashboards

4. **NodePort or port-forward**
   - Kubernetes NodePort for external access
   - Port-forward for local testing

5. **Monitoring dashboard**
   - Grafana dashboards
   - Prometheus metrics

**SCADA connections are defined in Module 09.**

---

## 5. Data Flow (Detailed Sequence)

Below is the full ingestion pipeline.

### 5.1 Step-by-Step Event Journey

**Step 1** → Device sends JSON via HTTP POST to `/v1/ingest`

**Step 2** → Collector receives, validates JSON schema

**Step 3** → Collector pushes validated event into NATS JetStream

**Step 4** → JetStream persists message until worker pulls

**Step 5** → Worker pulls batch of messages from JetStream

**Step 6** → Worker parses events and validates device/parameter mapping

**Step 7** → Worker writes rows to PostgreSQL (batch insert)

**Step 8** → Worker commits transaction

**Step 9** → Worker ACKs messages to JetStream

**Step 10** → SCADA reads updated values from `v_scada_latest` view

---

### 5.2 Detailed Sequence Diagram (ASCII)

```
Device/Simulator           Collector          NATS Stream           Worker           DB
      |                       |                   |                   |               |
      | POST /v1/ingest       |                   |                   |               |
      | (JSON payload)        |                   |                   |               |
      | --------------------> |                   |                   |               |
      |                       | validate JSON     |                   |               |
      |                       | generate trace_id |                   |               |
      |                       | push to NATS      |                   |               |
      |                       | ----------------> | store msg         |               |
      |                       |                   | (persist to disk) |               |
      | <------- queued ------|                   |                   |               |
      | {"status":"queued"}   |                   |                   |               |
      |                       |                   |                   |               |
      |                       |                   |  pull request     |               |
      |                       |                   | (batch: 50 msgs)  |               |
      |                       |                   | <---------------  |               |
      |                       |                   |                   | parse events   |
      |                       |                   |                   | validate FK    |
      |                       |                   |                   | batch insert   |
      |                       |                   |                   | commit         |
      |                       |                   |                   | -------->     |
      |                       |                   |                   |               |
      |                       |                   |                   | ack messages   |
      |                       |                   | <---------------  |               |
      |                       |                   |                   |               |
      |                       |                   |                   | SCADA query    |
      |                       |                   |                   | <-------       |
      |                       |                   |                   | SELECT FROM   |
      |                       |                   |                   | v_scada_latest |
```

---

## 6. Deployment Architecture

The same system can run in two deployment modes:

### 6.1 Local Developer Mode (Docker Compose)

**Characteristics:**

- **Docker Compose** - Single `docker-compose.yml` file
- **Single-container DB** - PostgreSQL in one container
- **Minimal scaling** - Typically 1 collector, 1-4 workers
- **Port mapping** - Services exposed on localhost ports
- **Quick setup** - Fast iteration for development

**Use Cases:**

- Development and testing
- Quick demos
- Local debugging
- CI/CD pipelines

**Configuration:**

- Services defined in `docker-compose.yml`
- Environment variables in `.env` file
- Data persisted in Docker volumes

---

### 6.2 Kubernetes Mode (Production/Staging)

**Characteristics:**

- **Kubernetes** - Production-grade orchestration
- **StatefulSets** - PostgreSQL and NATS with persistent storage
- **Deployments** - Collector and worker services
- **Horizontal scaling** - Multiple replicas supported
- **Service discovery** - Internal DNS-based communication
- **PVC-based storage** - Persistent volumes for data

**Use Cases:**

- Production deployments
- Staging environments
- High-availability requirements
- Multi-node clusters

**Configuration:**

- Kubernetes manifests in `deploy/k8s/`
- Helm charts in `deploy/helm/nsready/`
- Secrets stored in Kubernetes Secrets
- ConfigMaps for configuration

**Key Resources:**

- `postgres-statefulset.yaml` - Database with persistent storage
- `nats-statefulset.yaml` - NATS JetStream with persistence
- `collector_service-deployment.yaml` - Collector service
- `admin_tool-deployment.yaml` - Admin tool service
- NodePort/Ingress services for external access

---

## 7. Component Interaction Matrix

| Component | Communicates With | Protocol/Mechanism |
|-----------|------------------|-------------------|
| Collector | NATS JetStream | NATS protocol (push messages) |
| Collector | PostgreSQL | SQL (health checks only) |
| Worker | NATS JetStream | NATS protocol (pull messages) |
| Worker | PostgreSQL | SQL (async batch inserts) |
| SCADA | PostgreSQL | SQL (read-only SELECT queries) |
| SCADA | Export Scripts | File system (TXT/CSV files) |
| Test Tools | Collector | HTTP (POST /v1/ingest) |
| Test Tools | Admin Tool | HTTP (GET/POST /admin/*) |
| Scripts | Admin Tool | HTTP (REST API) |
| Scripts | PostgreSQL | SQL (direct queries) |
| Kubernetes | All services | Service discovery, health checks |
| Prometheus | Collector/Worker | HTTP (GET /metrics) |
| Grafana | Prometheus | PromQL queries |

---

## 8. Network Ports and Endpoints

### 8.1 Service Ports

| Component | Internal Port | External Port (NodePort) | Description |
|-----------|--------------|-------------------------|-------------|
| Collector-Service | 8001 | 32001 | `/v1/ingest`, `/v1/health`, `/metrics` |
| Admin Tool | 8000 | 32002 | `/admin/*`, `/health`, `/docs` |
| PostgreSQL | 5432 | 5432 (port-forward) | Database connections |
| NATS JetStream | 4222 | - | NATS client port |
| NATS Monitoring | 8222 | - | NATS monitoring/health |
| Grafana | 3000 | 3000 (port-forward) | Dashboard UI |
| Prometheus | 9090 | 9090 (port-forward) | Metrics engine |

### 8.2 Key Endpoints

#### Collector Service

- `POST http://localhost:8001/v1/ingest` - Ingest telemetry event
- `GET http://localhost:8001/v1/health` - Health check with queue depth
- `GET http://localhost:8001/metrics` - Prometheus metrics

#### Admin Tool

- `GET http://localhost:8000/admin/customers` - List customers
- `POST http://localhost:8000/admin/customers` - Create customer
- `GET http://localhost:8000/docs` - OpenAPI/Swagger UI

#### Database

- `postgresql://postgres:password@localhost:5432/nsready` - Direct connection
- `postgresql://scada_reader:password@localhost:5432/nsready` - SCADA read-only

---

## 9. Synchronous vs Asynchronous Paths

### 9.1 Synchronous (Real-Time) Path

**Used by collector when receiving data:**

```
Device → Collector → Validation → Queue → Response
                    (all synchronous)
```

**Steps:**

1. **JSON validation** - Immediate schema check
2. **Response: "queued"** - Return immediately after queuing
3. **No DB operation** - Database never contacted

**Benefits:**

- **Fast response** - Typically < 50ms
- **No blocking** - Collector never waits for DB
- **High throughput** - Can accept thousands of events/second

**Limitations:**

- **No immediate confirmation** - Event may fail later in worker
- **Queue depth monitoring** - Must check health endpoint

---

### 9.2 Asynchronous (Background) Path

**Used by workers:**

```
NATS Queue → Worker Pull → Parse → Validate → DB Insert → Commit → ACK
              (all asynchronous)
```

**Steps:**

1. **Message parsing** - Extract event from JSON
2. **Data insertion** - Batch insert into database
3. **Transaction commit** - Ensure data persistence
4. **Acknowledgment** - ACK message to JetStream
5. **Metric updates** - Update Prometheus metrics

**Benefits:**

- **DB load control** - Workers control insert rate
- **Batch efficiency** - Process multiple events together
- **Fault tolerance** - Failed events are redelivered
- **Scalability** - Multiple workers process in parallel

**Timeline:**

- **Typical latency:** 1-3 seconds from queue to DB
- **Batch processing:** 50 events per batch (default)
- **DB commit:** Atomic transaction per batch

---

### 9.3 Why This Architecture?

**This separation prevents:**

- **Request blocking** - Collector never blocked by DB operations
- **SCADA delays** - SCADA queries never affected by ingestion load
- **System slowdown** - High ingestion load doesn't impact collector responsiveness

**Example Scenario:**

```
1000 devices sending every 5 minutes = 200 events/minute

Without async:
  Collector waits for DB insert = 200ms per request
  Total: 200 requests × 200ms = 40 seconds of blocking

With async:
  Collector queues instantly = 1ms per request
  Workers process at controlled rate = no blocking
```

---

## 10. Scalability Strategy

### 10.1 Horizontal Scaling

#### More Collectors → More Ingestion Capacity

**Configuration:**

```yaml
# Kubernetes Deployment
replicas: 3  # 3 collector instances
```

**Benefits:**

- Handle more concurrent requests
- Load balancing across collectors
- Fault tolerance (if one fails, others continue)

**Limitations:**

- NATS queue becomes bottleneck (rarely)
- Shared queue depth across all collectors

---

#### More Workers → Higher DB Throughput

**Configuration:**

```bash
WORKER_POOL_SIZE=8  # 8 parallel workers
```

**Benefits:**

- Process more messages per second
- Parallel DB inserts
- Better CPU utilization

**Limitations:**

- Database connection pool limits
- DB write performance becomes bottleneck
- Too many workers can cause contention

**Recommended:**

- Start with 4 workers
- Monitor queue depth
- Scale up if queue depth grows
- Monitor DB connection pool

---

### 10.2 Vertical Scaling

#### Increase CPU/Memory on DB

**Benefits:**

- Faster query performance
- More concurrent connections
- Better compression performance

**Configuration:**

```yaml
resources:
  requests:
    cpu: "2"
    memory: "4Gi"
  limits:
    cpu: "4"
    memory: "8Gi"
```

---

#### Increase JetStream Retention

**Configuration:**

- Stream retention policy
- Consumer buffer size
- Max message age

**Use Cases:**

- High-volume deployments
- Network outages requiring longer buffering

---

### 10.3 Queue Depth Monitoring

**Essential for Module 08 packet health.**

**Metrics:**

- `queue_depth` - Total pending + ack_pending messages
- `pending` - Unprocessed messages
- `ack_pending` - Messages being processed

**Alerts:**

- Queue depth > 200 - Warning
- Queue depth > 1000 - Critical

**Scaling Triggers:**

- Queue depth consistently > 100 → Add workers
- Queue depth consistently > 500 → Scale horizontally

---

## 11. Reliability Strategy

### 11.1 Data Loss Prevention

**JetStream Persistence**

- Messages persisted to disk
- Survives service restarts
- Configurable replication (future)

**Worker ACK After Commit**

- Workers only ACK after successful DB commit
- Failed commits cause message NACK
- Ensures exactly-once processing

**Transaction Safety**

- Batch inserts in single transaction
- Atomic commit or rollback
- No partial data writes

---

### 11.2 Fault Recovery

**NATS Redelivery**

- Messages redelivered if not ACKed within timeout
- Automatic retry on worker failure
- Configurable max redelivery attempts

**Dead Letter Queue (DLQ)**

- Failed messages after max retries sent to DLQ
- Can be inspected and reprocessed manually
- Prevents infinite retry loops

**Database Resilience**

- TimescaleDB hypertables optimized for writes
- Automatic checkpoint and WAL management
- Supports replication (future enhancement)

---

### 11.3 High Availability

**Service Redundancy**

- Multiple collector replicas
- Multiple worker instances
- Load balancing via Kubernetes services

**Data Redundancy**

- Database backups (automated via CronJob)
- NATS JetStream replication (future)
- Persistent storage with PVCs

**Health Checks**

- Kubernetes liveness probes
- Kubernetes readiness probes
- Application health endpoints

---

## 12. Security Considerations

### 12.1 Database Security

**SCADA Read-Only User**

- Separate `scada_reader` user
- SELECT-only privileges
- No write/delete permissions
- Created via `setup_scada_readonly_user.sql`

**Admin User Isolation**

- `postgres` user for admin operations only
- Not exposed externally
- Used internally by services

---

### 12.2 API Security

**Bearer Token Authentication**

- Admin Tool uses Bearer token (configurable)
- Token stored in environment variables
- Default development token: "devtoken"

**HTTPS/TLS**

- Recommended in production
- TLS termination at Ingress or LoadBalancer
- Certificate management via cert-manager (Kubernetes)

---

### 12.3 Network Security

**Kubernetes Secrets**

- Credentials stored in Kubernetes Secrets
- Not committed to Git
- Encrypted at rest (Kubernetes default)

**Network Isolation**

- Services in dedicated namespace (`nsready-tier2`)
- Network policies restrict traffic
- SCADA access via port-forward or NodePort

**Firewall Rules**

- Only required ports exposed
- NodePort services restricted to specific IPs (recommended)

---

## 13. Summary

After reading this module, engineers should understand:

- ✅ **What each component does** - Collector, Worker, NATS, Database, SCADA
- ✅ **How data travels through the system** - From device to SCADA
- ✅ **Where the database fits** - Central storage with TimescaleDB
- ✅ **What role NATS plays** - Reliable message queuing
- ✅ **Where the worker pool processes events** - Background batch processing
- ✅ **How SCADA reads data** - Via views or file exports
- ✅ **How everything fits under NSWare architecture** - Clean separation of concerns

---

## 14. Next Steps

This prepares you for:

- **Module 03** - Environment and PostgreSQL Storage Manual
  - Set up local or Kubernetes environment
  - Understand database structure

- **Module 04** - Deployment and Startup Manual
  - Deploy services to Kubernetes
  - Start up Docker Compose environment

- **Module 05/06** - Configuration Import Manual / Parameter Template Manual
  - Import registry and parameters
  - Set up data collection definitions

- **Module 07** - Data Ingestion and Testing Manual
  - Test the complete ingestion pipeline
  - Validate data flow

- **Module 08** - Monitoring API and Packet Health Manual
  - Monitor system health
  - Track packet health metrics

- **Module 09** - SCADA Integration Manual
  - Connect SCADA systems
  - Configure read-only access

---

**End of Module 2 – System Architecture and DataFlow**

**Last Updated:** 2025-11-18

_NSReady Data Collection Platform Documentation Team_

