# Module 0 – Introduction and Terminology

_NSReady Data Collection Platform_

*(Suggested path: `docs/00_Introduction_and_Terminology.md`)*

---

## 1. Purpose of This Document

Module 0 serves as the starting point for all engineers, integrators, SCADA experts, and developers working with the NSReady Data Collection Platform.

It provides:

- A high-level introduction to the platform
- Definitions of core concepts and components
- Common terminology used throughout all modules
- The role of each subsystem
- Understanding required before working with ingestion, configuration, SCADA, deployments, or debugging

This module is mandatory reading before proceeding to Modules 01–13.

---

## 2. What Is the NSReady Data Collection Platform?

NSReady is a lightweight, modular, industrial data collection system designed to:

- Communicate with field devices
- Normalize and validate telemetry data
- Queue and stream data reliably
- Store time-series measurements
- Integrate with SCADA systems
- Integrate with cloud/NSWare systems in future phases
- Provide a clean operational workflow for industrial environments

It is engineered with:

- **Scalability** - Handles high-volume telemetry ingestion
- **Reliability** - Fault-tolerant message queuing and processing
- **Low installation cost** - Minimal infrastructure requirements
- **Multi-protocol support** - SMS, GPRS, MQTT, serial via bridge
- **Future-proof data layering** - NSWare compatibility
- **Industry-standard storage** - PostgreSQL + TimescaleDB
- **Message streaming** - NATS JetStream for reliable queuing

---

## 3. High-Level System Overview

```
Field Devices / Data Loggers
         |
         v
  Data Collection Ingestion
 (Collector-Service REST API)
         |
         v
     NATS JetStream
   (Reliable Message Queue)
         |
         v
     Worker Services
 (Validation, persistence)
         |
         v
 PostgreSQL / TimescaleDB
   (Raw + structured data)
         |
         v
   SCADA / Dashboards
  + Monitoring & Visibility
```

The system is designed to be robust, fault-tolerant, and transparent for SCADA & operations teams.

---

## 4. NSReady's Core Functional Responsibilities

The platform provides the following core capabilities:

### 4.1 Ingestion

- Receives telemetry in standard JSON format
- Validates payload schema
- Accepts data from field devices or simulators
- Applies basic metadata tagging (trace ID, timestamps)

### 4.2 Queueing

- Pushes data to NATS JetStream
- Ensures retry/delivery guarantees
- Buffers load during peak events

### 4.3 Processing

- Worker pool pulls messages from queue
- Validates device/parameter mapping
- Stores clean data into the database
- Generates packet health metrics

### 4.4 Storage

- Uses PostgreSQL (TimescaleDB)
- Hypertables for `ingest_events`
- Views for SCADA (latest/history)
- Raw payload auditing

### 4.5 Integration

- SCADA (SQL, views, exports)
- File export for third-party systems
- API-ready for NSWare
- Monitoring APIs for health/latency

### 4.6 Operations

- Logging
- Packet behavior monitoring
- Queue depth tracking
- Diagnostics

---

## 5. Platform Scope (What NSReady Does **Not** Do)

To keep the collector lightweight and maintain a clean architecture, NSReady intentionally does **NOT** implement:

- KPIs or advanced analytics
- Machine learning or prediction models
- GIS/map rendering
- Workflow/SOP engine
- Full alert rule engine
- Heavy UI dashboards
- Multi-tenant cloud systems
- Device firmware management

These belong to NSWare Phase 2+ (higher-level platform).

**NSReady focuses on clean ingestion + perfect handover.**

---

## 6. Who Should Use This Documentation?

### Engineers

- For configuring projects, sites, devices
- For testing ingestion & pipeline flow

### SCADA Teams

- For connecting SCADA to NSReady
- For reading latest/historical values

### Field Technicians

- For understanding packet behavior & device setup

### Developers

- For writing ingestion clients or simulators
- For debugging worker/queue/data path issues

### Operations Team

- For monitoring health and performing maintenance
- For troubleshooting cluster-level issues

### Management / Project Owners

- For understanding architecture & workflows

---

## 7. Terminology & Concepts (Glossary)

This section defines all key terms used in Modules 00–13.

### 7.1 Collector-Service

A FastAPI-based microservice that receives incoming telemetry at:

```
POST /v1/ingest
```

**Responsibilities:**

- Validate JSON
- Add trace ID
- Push event to NATS queue
- Provide health endpoint `/v1/health`

**Ports:**

- `8001` - Default service port
- `32001` - Kubernetes NodePort (if configured)

---

### 7.2 Worker-Service (Worker Pool)

Background workers that:

- Pull messages from JetStream
- Convert to DB rows
- Commit to `ingest_events`
- Calculate packet timestamps

**Configuration:**

- `WORKER_POOL_SIZE` - Number of parallel workers (default: 4)
- `WORKER_BATCH_SIZE` - Messages per batch (default: 50)
- `WORKER_BATCH_TIMEOUT` - Batch timeout in seconds (default: 0.5)

---

### 7.3 NATS JetStream

Message streaming engine used for:

- Persistent queue
- Delivery guarantees
- Retry logic
- Scaling worker consumers

**Concepts:**

- **Stream** - Named message stream (e.g., "INGRESS")
- **Consumer** - Message consumer (e.g., "ingest_workers")
- **Pending** - Unprocessed messages
- **Ack pending** - Messages being processed
- **Redelivery** - Failed messages retried

---

### 7.4 PostgreSQL / TimescaleDB

The database storing:

- `ingest_events` - Time-series telemetry data
- `parameter_templates` - Parameter definitions
- `devices`, `sites`, `projects`, `customers` - Registry metadata
- SCADA-friendly views (`v_scada_latest`, `v_scada_history`)

**TimescaleDB provides:**

- **Hypertables** - Partitioned time-series tables
- **Compression** - Automatic data compression
- **Retention** - Automatic data retention policies
- **High-performance time-series inserts** - Optimized for telemetry

---

### 7.5 Ingest Event (NormalizedEvent)

Standard JSON schema representing telemetry from a device.

**Fields include:**

- `project_id` - UUID of the project
- `site_id` - UUID of the site
- `device_id` - UUID of the device
- `metrics[]` - Array of metric values (value, quality, attributes)
- `source_timestamp` - ISO 8601 timestamp from device
- `protocol` - Communication protocol (SMS, GPRS, HTTP, etc.)
- `config_version` - Optional configuration version
- `event_id` - Optional idempotency key
- `metadata` - Optional additional metadata

**Example:**

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
      "attributes": {
        "unit": "V"
      }
    }
  ],
  "config_version": "v1.0",
  "event_id": "optional-unique-id",
  "metadata": {}
}
```

---

### 7.6 Packet Health

Analysis of:

- Expected vs received packets
- Missing packets
- Late packets
- Quality codes
- Last packet time

**Defined formally in Module 08** - Monitoring API and Packet Health Manual.

---

### 7.7 SCADA Integration

Mechanisms for SCADA to read data:

- **SQL read-only user** - `scada_reader` user with SELECT privileges
- **SCADA export files** - TXT/CSV exports for file-based integration
- **v_scada_latest** - View with latest values per device/parameter
- **v_scada_history** - View with full historical data

**Defined fully in Module 09** - SCADA Integration Manual.

---

### 7.8 Registry

Core metadata defining:

```
Customer → Project → Site → Device → Parameters
```

**Imported via CSV** using `import_registry.sh` script.

**Components:**

- **Customer** - Organization owning the system
- **Project** - Logical grouping of sites
- **Site** - Physical or logical location
- **Device** - Field device/panel/controller
- **Parameter** - Measurement/tag definition

**Defined in Module 05** - Configuration Import Manual.

---

### 7.9 Parameter Template

Defines:

- `parameter_key` - Unique identifier (e.g., "voltage", "current")
- `unit` - Measurement unit (e.g., "V", "A", "kW")
- `dtype` - Data type (float, int, string)
- `min_value` / `max_value` - Engineering range
- `required` - Whether parameter is mandatory

**Used to map metrics from field devices.**

**Defined in Module 05** - Configuration Import Manual and **Module 06** - Parameter Template Manual.

---

### 7.10 Worker Queue Depth

Number of pending messages in JetStream for the worker consumer.

**Displayed in:**

```
GET /v1/health
```

**Response includes:**

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

**Used to measure system load.**

---

### 7.11 NodePort

A Kubernetes networking feature exposing services externally on ports like:

- `32001` - Collector service
- `32002` - Admin tool

**Used for ingestion and UI access** when not using port-forwarding.

---

### 7.12 Admin Tool

FastAPI-based microservice for registry management at:

```
http://localhost:8000
```

**Responsibilities:**

- Customer/Project/Site/Device management
- Parameter template management
- Configuration versioning
- Registry API endpoints

**Ports:**

- `8000` - Default service port
- `32002` - Kubernetes NodePort (if configured)

---

### 7.13 Trace ID

Unique identifier added to each ingested event for:

- Request tracing
- Debugging
- Log correlation

**Format:** UUID

**Example:** `abc123-def456-ghi789-jkl012`

---

### 7.14 Quality Code

Integer value (0-255) indicating data quality:

- `192` - Good quality (typical for production)
- `0` - Bad quality / invalid
- Other values - Vendor-specific quality codes

**Stored in:** `ingest_events.quality`

---

### 7.15 Hypertable

TimescaleDB feature that automatically partitions time-series data by time.

**Benefits:**

- Faster queries on time ranges
- Automatic compression
- Efficient data retention

**Used for:** `ingest_events` table

---

### 7.16 SCADA Views

Pre-defined database views for SCADA consumption:

- **v_scada_latest** - Latest value per device/parameter
- **v_scada_history** - Full historical data

**Defined in:** `db/migrations/130_views.sql`

---

### 7.17 CSV Import

Bulk import mechanism for:

- Registry data (customers, projects, sites, devices)
- Parameter templates

**Scripts:**

- `import_registry.sh` - Registry import
- `import_parameter_templates.sh` - Parameter import

**Defined in:** Module 05 - Configuration Import Manual

---

### 7.18 Docker Compose

Local development environment using Docker containers.

**Services:**

- `nsready_db` - PostgreSQL database
- `collector_service` - Collector service
- `admin_tool` - Admin tool
- `nsready_nats` - NATS server

**Defined in:** Module 03 - Environment and PostgreSQL Storage Manual

---

### 7.19 Kubernetes

Production/staging deployment environment.

**Namespace:** `nsready-tier2`

**Key Resources:**

- StatefulSets for database
- Deployments for services
- Services for networking
- PersistentVolumeClaims for storage

**Defined in:** Module 04 - Deployment and Startup Manual

---

## 8. Documentation Structure (Modules Overview)

This manual is part of the full NSReady documentation set:

| Module | File Name | Description |
|--------|-----------|-------------|
| 00 | `00_Introduction_and_Terminology.md` | **This document** - Platform introduction and glossary |
| 01 | `01_Folder_Structure_and_File_Descriptions.md` | Project structure and file organization |
| 02 | `02_System_Architecture_and_DataFlow.md` | High-level architecture and data flow |
| 03 | `03_Environment_and_PostgreSQL_Storage_Manual.md` | Database setup and storage management |
| 04 | `04_Deployment_and_Startup_Manual.md` | Deployment procedures and startup |
| 05 | `05_Configuration_Import_Manual.md` | Registry and parameter import |
| 06 | `06_Parameter_Template_Manual.md` | Detailed parameter template guide |
| 07 | `07_Data_Ingestion_and_Testing_Manual.md` | Data ingestion and testing procedures |
| 08 | `08_Monitoring_API_and_Packet_Health_Manual.md` | Monitoring APIs and packet health |
| 09 | `09_SCADA_Integration_Manual.md` | SCADA integration setup |
| 10 | `10_Scripts_and_Tools_Reference_Manual.md` | Scripts and tools documentation |
| 11 | `11_Troubleshooting_and_Diagnostics_Manual.md` | Troubleshooting guide |
| 12 | `12_API_Developer_Manual.md` | API reference and developer guide |
| 13 | `13_Performance_and_Monitoring_Manual.md` | Performance tuning and monitoring |
| Master | `Master_Operation_Manual.md` | Master reference and quick start |

---

## 9. Reading Path Recommendations

### For New Users

1. **Start here** - Module 0 (this document)
2. **Understand structure** - Module 1 - Folder Structure
3. **Learn architecture** - Module 2 - System Architecture
4. **Set up environment** - Module 3 - Environment and PostgreSQL
5. **Deploy** - Module 4 - Deployment and Startup
6. **Configure** - Module 5 - Configuration Import
7. **Test** - Module 7 - Data Ingestion and Testing

### For SCADA Engineers

1. Module 0 (this document)
2. Module 3 - Environment and PostgreSQL (database setup)
3. Module 5 - Configuration Import (registry setup)
4. Module 9 - SCADA Integration (integration procedures)

### For Developers

1. Module 0 (this document)
2. Module 2 - System Architecture (understand the system)
3. Module 7 - Data Ingestion and Testing (test your integration)
4. Module 12 - API Developer Manual (API reference)

### For Operations

1. Module 0 (this document)
2. Module 4 - Deployment and Startup (deployment procedures)
3. Module 8 - Monitoring API and Packet Health (monitoring)
4. Module 11 - Troubleshooting and Diagnostics (troubleshooting)
5. Module 13 - Performance and Monitoring (performance tuning)

---

## 10. Key Concepts Summary

Before proceeding to other modules, ensure you understand:

- ✅ **NSReady** is a data collection platform, not a full SCADA system
- ✅ **Collector-Service** receives telemetry via REST API
- ✅ **NATS JetStream** provides reliable message queuing
- ✅ **Worker Pool** processes messages and stores to database
- ✅ **PostgreSQL/TimescaleDB** stores time-series data
- ✅ **Registry** defines Customer → Project → Site → Device hierarchy
- ✅ **Parameter Templates** define what measurements are collected
- ✅ **SCADA Integration** uses read-only database access and views
- ✅ **Queue Depth** indicates system load and health

---

## 11. Next Steps

After reading Module 0, continue with:

- **Module 01** – Folder Structure & File Descriptions
  - Understand the project tree and file roles

Then:

- **Module 02** – System Architecture & DataFlow
  - Visual understanding of the whole pipeline

---

## 12. Related Resources

- **Project Repository:** See project root for source code
- **Scripts:** See `scripts/` directory for import/export tools
- **API Specification:** See `openapi_spec.yaml` for API documentation
- **Deployment Guide:** See `DEPLOYMENT_GUIDE.md` for deployment procedures

---

**End of Module 0 – Introduction and Terminology**

**Last Updated:** 2025-11-18

_NSReady Data Collection Platform Documentation Team_

