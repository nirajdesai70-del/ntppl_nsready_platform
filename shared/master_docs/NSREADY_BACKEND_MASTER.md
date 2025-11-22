# NSREADY BACKEND – MASTER ARCHITECTURE & OPERATIONS MANUAL

**Version:** 1.0  
**Document Type:** Master Reference (Backend)  
**Branding:** Neutral / No Group Nish branding  
**Scope:** Backend architecture, ingestion, processing, storage, SCADA, monitoring, and AI-readiness design for NSReady platform.

---

## 1. Purpose of This Master Manual

This Master Document consolidates:

- All architectural knowledge from Modules 00–13
- Tenant/customer isolation design
- Ingestion pipeline fundamentals
- Storage models and SCADA integration
- Performance, scaling & monitoring patterns
- AI/ML readiness guardrails
- NSReady v1 backend rules & conventions

This manual is the single source of truth for backend engineering decisions.

This ensures:

- No ambiguity
- No rework when scaling
- Consistent designs across teams
- A stable contract between backend, SCADA, dashboards, and future NSWare modules

---

## 2. What NSReady Backend Does & Does NOT Do

### 2.1 What NSReady DOES

- Collects telemetry from field devices (modems, sensors, PLC proxies)
- Validates + normalizes input using the NormalizedEvent v1.0 contract
- Buffers events using NATS JetStream
- Performs reliable batch inserts into PostgreSQL/TimescaleDB
- Exposes read-only SCADA views (latest + history)
- Provides health checks + monitoring endpoints
- Maintains registry-based routing (customer → project → site → device)
- Enforces unique parameter_key identities
- Ensures tenant isolation automatically based on data hierarchy

### 2.2 What NSReady Does NOT Do

- Does NOT perform AI/ML processing (separate NSWare layer)
- Does NOT perform dashboard rendering (front-end)
- Does NOT serve multi-model analytics directly
- Does NOT rewrite or modify incoming raw data
- Does NOT implement SCADA logic (only exposed views)
- Does NOT compute process KPIs (steam efficiency, water loss, etc.) — see NSWare Phase-2
- Does NOT generate process alerts (threshold-based, rate-of-change, etc.) — see NSWare Phase-2

**For process KPIs and alerts (NSWare Phase-2), see:**
- `master_docs/NSWARE_DASHBOARD_MASTER.md` — Part 5 (KPI & Alert Model — future NSWare layer)

**For NSReady v1 operational dashboards (registry, packet health, ingestion logs), see:**
- `master_docs/PART5_NSREADY_OPERATIONAL_DASHBOARDS.md` — NSReady operational UI specification

---

## 3. Backend Guiding Principles

These rules guide every design decision and prevent future rework.

### 3.1 Immutable Raw Data

All telemetry arrives → validated → stored without mutation in `ingest_events`.

### 3.2 Full-Form Parameter Keys Only

Every metric uses the canonical format:

```
project:<project_uuid>:<parameter_name>
```

Never accept shortened keys (e.g., `"voltage"`).

This ensures:

- Perfect lookup integrity
- AI/ML stability
- Multi-customer consistency

### 3.3 Tenant Isolation Automatically Derived

NSReady v1 formula:

```
tenant_id = customer_id
```

A customer can have `parent_customer_id` for group-level reporting,  
but tenant isolation stays at `customer → project → site → device`.

### 3.4 Stateless Collector-Service

Collector-service:

- Validates JSON
- Pushes to NATS
- Never touches DB directly
- Never performs business logic

### 3.5 Worker = Only Writer

All inserts happen here.

Workers:

- Batch multiple events
- Commit within a transaction
- Ack only after success

### 3.6 DB = Source of Truth

- Registry (customers, projects, sites, devices)
- Parameter templates
- Raw ingest data
- SCADA views

Are all stored & queried from PostgreSQL/Timescale.

### 3.7 Operational Safety First

- Health endpoints
- Queue depth thresholds
- Error logs
- Backup + restore
- No destructive operations without explicit scripts

### 3.8 SCADA-Friendly by Design

- Clean latest views
- Separate history view
- Optional materialized views for heavy SCADA systems

### 3.9 AI/Feature-Store Ready

- Stable IDs
- Trace IDs
- Raw + derived separation
- Event time vs ingest time stored separately

---

## 4. Master Document Structure

This manual is divided into 10 major sections:

1. **Overview & Principles** (this part)
2. **High-Level Architecture**
3. **Tenant/Customer Model**
4. **NormalizedEvent + Ingestion Contract**
5. **Collector-Service Design**
6. **NATS JetStream Queueing Model**
7. **Worker Pool + Database Commit Design**
8. **PostgreSQL + Timescale Storage Model**
9. **SCADA Integration Model**
10. **Monitoring, Performance, AI Readiness**

---

---

## 2. High-Level Architecture

This section defines the backend architecture blueprint for the NSReady platform.

It is the authoritative reference for all backend services, pipelines, and data flows.

### 2.1 End-to-End Architecture Diagram

```
                 ┌───────────────────────┐
                 │   Field Devices       │
                 │  (GSM, PLC, Sensors)  │
                 └──────────┬────────────┘
                            │
                            ▼
                  ┌───────────────────┐
                  │  Collector-Service│
                  │  (Stateless API)  │
                  └──────────┬────────┘
                            │
                            ▼
                  ┌───────────────────┐
                  │    NATS JetStream │
                  │  (Ingest Queue)   │
                  └──────────┬────────┘
                            │
                            ▼
                  ┌───────────────────┐
                  │   Worker Pool      │
                  │ (Batch DB Writer)  │
                  └──────────┬────────┘
                            │
                            ▼
             ┌──────────────────────────────────┐
             │   PostgreSQL / TimescaleDB       │
             │  - Raw ingest_events             │
             │  - Registry (cust→proj→site→dev) │
             │  - Parameter templates           │
             │  - SCADA views (latest/history)  │
             └──────────────────────────────────┘
                            │
                            ▼
             ┌──────────────────────────────────┐
             │   SCADA Systems (Read-Only)      │
             │  - v_scada_latest                │
             │  - v_scada_history                │
             │  - Optional materialized views   │
             └──────────────────────────────────┘
                            │
                            ▼
             ┌──────────────────────────────────┐
             │   NSWare / Dashboards / AI/ML     │
             │   (Future layers, read-only)      │
             └──────────────────────────────────┘
```

### 2.2 Architectural Responsibilities Overview

#### 2.2.1 Field Devices (Edge Layer)

Responsible for:

- Generating raw measurements
- Sending data via GPRS/SMS/HTTP
- Maintaining accurate clocks (or following modem timestamping)

#### 2.2.2 Collector-Service (Ingress API Layer)

Stateless microservice that:

- Validates NormalizedEvent JSON
- Does not touch the database
- Pushes events to NATS JetStream
- Returns trace_id for debugging

#### 2.2.3 NATS JetStream (Queue Layer)

Acts as:

- Durable ingestion queue
- Buffer for burst loads
- Message retention point
- Backpressure controller

#### 2.2.4 Worker Pool (Processing Layer)

Responsibilities:

- Pull events from NATS in batches
- Validate + resolve device/parameter IDs
- Insert into PostgreSQL using a transactional batch
- Acknowledge only after successful commit

#### 2.2.5 PostgreSQL + TimescaleDB (Storage Layer)

Stores:

- Raw time-series data
- Normalized registry (customer→project→site→device)
- Parameter templates
- Error logs
- SCADA views

This is the source of truth for all downstream systems.

#### 2.2.6 SCADA (Output Layer)

Reads from:

- Live/latest view: `v_scada_latest`
- History: `v_scada_history`

Optional:

- Materialized views for performance
- Per-customer / per-device slices

#### 2.2.7 NSWare / Dashboard / AI Layer (Future)

Consumes:

- Raw ingest data
- SCADA views
- Rollups
- Feature stores

Important:

- Never writes to `ingest_events`
- Never mutates raw telemetry

### 2.3 Architectural Goals

**Goal 1: Safety & Reliability**

- Every event must be stored exactly once
- No data loss, even under modem bursts
- No blocking on expensive DB operations

**Goal 2: Scalability**

- Horizontal scaling:
  - Collector replicas
  - Worker replicas
  - NATS partitions
- Vertical scaling:
  - Database CPU/RAM/I/O

**Goal 3: Clean Separation of Concerns**

Each layer has one job:

- Collector → Validate & Queue
- NATS → Persist & Buffer
- Worker → Commit to DB
- DB → Store & Serve Views
- SCADA → Display & Control

**Goal 4: Predictable Performance**

- Queue depth must remain near zero
- Worker batches optimize DB writes
- Timescale compression reduces storage costs

**Goal 5: Multi-Customer Isolation**

- Isolation handled automatically by registry hierarchy
- No cross-customer data mixing
- Parent–child (group-level) reporting supported

**Goal 6: Future AI-Readiness**

- Stable entity IDs
- Whitelisted parameter keys
- Raw + derived separation
- Trace-ID support

### 2.4 High-Level Data Contracts Between Layers

#### Collector → NATS

**Contract:** NormalizedEvent v1.0

- Full parameter_key format
- UUIDs validated
- Device exists
- Exact JSON schema enforced

#### NATS → Worker

**Contract:**

NATS message = Validated NormalizedEvent + trace_id

#### Worker → DB

**Contract:**

- Inserts only
- Append-only
- No updates
- FK-verified device & parameter keys

#### DB → SCADA

**Contract:**

- SCADA sees pre-defined views
- No direct access to `ingest_events`
- Read-only credentials

#### DB → AI/ML

**Contract (future):**

- Read-only
- Feature extraction from raw & rollup tables
- No schema mutations

### 2.5 Backend Deployment Architecture

#### Supported Environments

| Environment | Purpose |
|------------|---------|
| Docker Compose | Local development & small pilots |
| Kubernetes (nsready-tier2) | Production-grade simulations & deployments |

#### Runtime Components

| Component | Replicas | Scaling |
|-----------|----------|---------|
| Collector-service | 1–3 | Horizontal |
| NATS JetStream | 1 | Stateful |
| Worker pool | 1–6 | Horizontal |
| PostgreSQL/TimescaleDB | 1 (HA optional) | Vertical |
| Admin-tool | 1 | Horizontal |

### 2.6 Why This Architecture Works

**✔ Stable under high bursts**

Modems often send data in sudden bursts.  
NATS protects against overload while workers process smoothly.

**✔ Uses best practices of time-series storage**

- Append-only
- Partitions
- Compression
- Hypertables

**✔ Keeps ingestion contract immutable**

Critical for AI/ML, dashboards, SCADA, and audits.

**✔ Multi-customer safe**

Registry defines customer/project/site/device relations.  
Isolation is preserved automatically.

**✔ Future-proof**

NSWare can sit on top without changing ingestion:

```
ingest_events → rollups → feature store → AI models → dashboards
```

---

---

## 3. Tenant–Customer Model (Final Architecture Rulebook)

This is the canonical design for NSReady v1 and the foundation for future NSWare multi-tenant expansion.

This section defines how NSReady separates customers, groups, and tenants, and how access, isolation, and reporting work across the entire system — SCADA, dashboards, ingest, exports, and future AI.

This is a zero-refactor-required model, fully compatible with your current DB schema.

### 3.1 Core Rule — Tenant = Customer (in NSReady v1)

**✔ This is the final v1 rule:**

```
tenant_id = customer_id
```

**Meaning:**

- Each company (e.g., Customer Group Textool) is treated as its own tenant.
- A "parent group" (e.g., Customer Group) is NOT a tenant—it is only used for report grouping.
- All platform isolation — ingest, SCADA, dashboards, exports — is done at customer/company level.

This avoids rework.  
This avoids changing schema.  
This avoids refactoring ingestion or registry.

### 3.2 Why We Chose This Model

**🔵 Reason 1 — SCADA isolation requirements**

Each company receives its own SCADA setup.  
Cross-company visibility is not allowed unless explicitly configured.

**🔵 Reason 2 — Ingestion does NOT include "group" context**

```
Devices → Sites → Projects → Customers
```

The ingest payload contains `device_id + project_id + site_id`, not "Group".

**🔵 Reason 3 — DB schema already supports company-level tenants**

```
customers.id                → tenant
customers.parent_customer_id → group (optional)
```

**🔵 Reason 4 — Group reporting is optional**

Group aggregation is a reporting requirement, not a tenant boundary requirement.

**🔵 Reason 5 — We avoid massive refactor**

Renaming customer → tenant would break:

- Admin tool
- Registry import scripts
- SCADA SQL views
- API contracts
- Documentation
- Test scripts

With zero benefit.

### 3.3 The Hierarchical Customer Model

This is the complete hierarchy now supported:

```
Customer Group (parent, optional)
     ↓
Customer (tenant in v1)
     ↓
Project
     ↓
Site
     ↓
Device
```

**Example:**

```
Customer Group          ← parent_customer_id = NULL
 ├── Customer Group Textool   ← customer_id = uuidA, parent_customer_id = Customer Group
 ├── Customer Group Texpin    ← customer_id = uuidB, parent_customer_id = Customer Group
 └── Customer Group Texspin   ← customer_id = uuidC, parent_customer_id = Customer Group
```

### 3.4 What Each Layer Uses

**Collector-Service**

- Does NOT know "tenant"
- Resolves customer automatically through:

```
device → site → project → customer
```

**NATS + Worker**

- Only see `device_id + parameter_key`.
- Customer resolution happens in SQL when joining.

**PostgreSQL**

- Stores customer and parent-customer
- Provides grouping capability
- Provides tenant/filter boundaries
- Does NOT require schema refactor

**SCADA**

- Uses `customer_id` as filter
- Parent is ONLY for rollup views

**Dashboards**

- Each user logs into one tenant (company)
- Group dashboards optionally available
- Company-level isolation guaranteed

**Future AI/ML**

- Models operate per company (tenant)
- Group-level insights possible via parent-customer grouping

### 3.5 Final NSReady v1 Definitions

**Definition: Tenant**

A single operating company that receives NSReady features, dashboards, SCADA, KPIs, alerts, etc.  
This is a customer table entry with `parent_customer_id = NULL OR NOT_GROUPED`.

**Definition: Customer (in registry)**

The same as tenant for v1.

**Definition: Customer Group**

A parent entity used for:

- Reporting
- Rollups
- Aggregated analytics
- Multi-company OEM insights

**Definition: Parent–Child Relationship**

`parent_customer_id` defines grouping ONLY, NOT isolation.

**Definition: Isolation Boundary**

```
tenant boundary = customer_id
```

**Definition: Reporting Boundary**

```
reporting group = parent_customer_id + all children
```

### 3.6 Tenant Isolation Rules (Hard Rules for NSReady)

**✔ Rule 1 — No cross-customer visibility**

Dashboards MUST NOT mix telemetry of two customers.

**✔ Rule 2 — All SCADA exports must include customer_id filter**

All SCADA output:

- `v_scada_latest`
- `v_scada_history`
- `mv_scada_latest_readable`
- `export_scada_data_readable.sh`

must always filter by `customer_id`.

**✔ Rule 3 — Ingestion automatically maps to customer**

No device can exist under 2 customers.  
This guarantees complete safety.

**✔ Rule 4 — User login controls tenant**

Dashboard login = tenant context.

**✔ Rule 5 — AI/ML models operate per tenant**

Feature stores MUST include:

```
tenant_id / customer_id
```

**✔ Rule 6 — Group dashboards optional**

Group dashboards are aggregated views, not identity or security boundaries.

### 3.7 Future Upgrade Path (For NSWare Multi-Tenant)

Your design keeps full forward-compatibility.

**Phase 2.0 (Future):**

- Introduce `tenants` table (OPTIONAL)
- Migrate customers under tenants
- Add RLS (row-level security)

**Phase 2.1:**

- Add per-tenant rate limits
- Add tenant-level billing/usage metering

**Phase 2.2:**

- Add tenant-level model registry for AI/ML

**Phase 2.3:**

- Add cross-tenant OEM dashboards  
  (enabled via `parent_customer` relation)

All without breaking v1 because the base is stable.

### 3.8 Customer Group Example (Final Clarification)

**✔ Conceptually (Business Side):**

Customer Group is the tenant.  
Customer Group Textool is a customer.  
Customer Group Texpin is a customer.

**✔ BUT in NSReady v1 (System Side):**

```
Tenant = Textool
Tenant = Texpin
Tenant = Texspin
```

```
Group = Customer Group
```

**Why the difference?**

Because:

- SCADA
- dashboards
- device configuration
- alarms
- ingestion path
- permissions

all operate per company, not per group.

Group is for reporting only.

### 3.9 What to Document for Frontend / Dashboard Team

Use this final rulebook line:

```
UI/UX login and dashboard context = customer_id (company-level)
```

Group dashboards = optional aggregation mode.

### 3.10 Section Summary for Master Document

**✔ Stable, no-refactor design**

**✔ Fully aligned with NSReady architecture**

**✔ Supports Customer Group use case perfectly**

**✔ Future-proof for NSWare multi-tenant**

**✔ Zero side effects or breaking changes**

---

---

## 4. Registry & Parameter Templates (Canonical System of Record)

The NSReady registry defines who the customer is, what the project structure is, how many sites exist, which devices are active, and what parameters each device will send.

It is the heart of NSReady — without a correct registry, the ingestion pipeline, SCADA, dashboards, health logic, and AI models will all behave incorrectly.

This is the official rulebook for how the registry works and how it must be maintained in NSReady v1 and NSWare.

### 4.1 Registry Architecture Overview

```
Customer (tenant, company-level)
     ↓
Project (logical boundary)
     ↓
Site (physical boundary)
     ↓
Device (individual hardware)
     ↓
Parameter Template (the "data contract" for ingestion)
```

Registry is composed of these tables:

| Table | Purpose |
|-------|---------|
| `customers` | Represents company-level tenants (NSReady v1) |
| `projects` | Logical division under a customer |
| `sites` | Physical location under a project |
| `devices` | Actual hardware (GSM modem, PLC, datalogger) |
| `parameter_templates` | Canonical definitions of parameters |

Everything in ingestion, SCADA and dashboards depends on these five registry components.

### 4.2 Customer → Project → Site → Device (Strict Hierarchy)

This hierarchy is mandatory:

A device must map to exactly 1 site,  
which must map to exactly 1 project,  
which must map to exactly 1 customer.

**Why strict hierarchy matters:**

- Ensures ingestion automatically resolves `customer_id` from `device_id`
- Guarantees tenant isolation
- Ensures SCADA exports cannot leak data
- Ensures dashboards only show correct customer data
- Ensures AI feature stores join correctly

### 4.3 Canonical Registry Rules

**Rule 1 — All entities MUST be created before ingestion begins**

Devices MUST NOT be allowed to ingest data until:

- customer exists
- project exists
- site exists
- device exists
- parameter templates exist

This prevents orphaned data and foreign-key failures.

**Rule 2 — Device identity is permanent**

Once created:

- `device_id` (UUID) is immutable
- `external_id` (device_code) is immutable
- device must never be moved across customers

**Reason:**

- SCADA mappings break
- AI feature stores break
- Dashboards break
- Data lineage breaks

If hardware moves, create a new device, do not reassign.

**Rule 3 — One device cannot exist under two customers**

Guaranteed by schema:

```
device → site → project → customer
```

This is the tenant isolation backbone.

**Rule 4 — For multi-company groups, customers remain separate**

As per the tenant model:

- `customer = tenant` (isolated)
- `parent_customer = grouping only`

No registry merging allowed.

**Rule 5 — Project names must be unique within a customer**

To prevent:

- confusion in dashboards
- SCADA misalignment
- parameter template collisions

**Rule 6 — Parameter names must be unique within a project**

Example:

- `voltage` = allowed
- `voltage_phase1` = allowed
- `voltage` = duplicate (not allowed)

### 4.4 Parameter Templates – Canonical Format

Parameter templates define what data a device is allowed to send.

**Mandatory fields:**

- `key` (always full canonical key)
- `name`
- `unit`
- `metadata.project_id`
- `metadata.dtype`

**Canonical parameter_key format:**

```
project:<project_uuid>:<parameter_name>
```

**Example:**

```
project:8212caa2-b928-4213-b64e-9f5b86f4cad1:voltage
```

This is the non-negotiable global rule.

**Why this matters:**

- Worker validates foreign key → no bad data
- SCADA views join reliably
- Dashboards group reliably
- AI/ML models use parameter keys as stable features
- No accidental collisions across customers/projects

### 4.5 Data Contract Embedded in Templates

Parameter templates act as the internal data contract.

Each template includes:

| Field | Meaning |
|-------|---------|
| `name` | Human-friendly name |
| `unit` | Engineering unit |
| `dtype` | Data type (float, int, bool, etc.) |
| `min_value` | Optional QC |
| `max_value` | Optional QC |
| `frequency` | Expected update interval |
| `metadata.project_id` | The project this parameter belongs to |

Validated by:

- import scripts
- worker
- SCADA views
- future AI feature stores

### 4.6 Parameter Template Lifecycle (Master Rules)

**Stage 1 — Template Creation (Registry Import)**

Created via CSV or Admin Tool.

**Stage 2 — Template Freeze**

Once data ingestion begins:

- Templates become locked
- No renaming, no unit change, no key change

**Stage 3 — Template Versioning (Future NSWare)**

V2 of templates will include:

- version number
- migration notes
- feature compatibility

But v1 uses static templates.

### 4.7 Canonical SQL Reference

Full definition of `parameter_templates.key` FK:

```sql
ALTER TABLE ingest_events
ADD CONSTRAINT ingest_events_parameter_fkey
FOREIGN KEY (parameter_key)
REFERENCES parameter_templates(key);
```

This enforces:

- no unknown metrics
- no device misconfiguration
- perfect SCADA visibility

### 4.8 Registry Import – Required Order

Correct sequence:

1. `customers.csv`
2. `projects.csv`
3. `sites.csv`
4. `devices.csv`
5. `parameter_templates.csv`
6. `registry_versions.json` (auto-generated)

Do NOT change order.

If a device arrives before its template exists, ingestion fails.

### 4.9 Examples (Canonical)

**Customer example:**

```
customer_id: b39f99e1-5afc-4da0-93cf-3399b5a17d40
name: "Customer Group Textool"
```

**Project example:**

```
project_id: 8212caa2-b928-4213-b64e-9f5b86f4cad1
customer_id: b39f99e1-5afc-4da0-93cf-3399b5a17d40
```

**Parameter Template example:**

```
key: project:8212caa2-b928-4213-b64e-9f5b86f4cad1:power
name: Power
unit: W
dtype: float
```

### 4.10 Registry & Templates – Future NSWare Enhancements (For Reference)

These are planned but NOT required for NSReady v1:

**Future additions:**

- template versioning
- soft-delete lifecycle
- migration history tracking
- parameter grouping
- derived KPI parameter templates
- tenant-specific template overrides
- template → AI feature mapping
- auto-template generation via Modbus dictionary

These are stored here for future compatibility planning.

---

---

## 5. Ingestion Engine – Master Rules & Architecture Specification

The ingestion engine is the beating heart of NSReady.

It is responsible for accepting field telemetry, validating it, queueing it correctly, processing it reliably, and storing it durably.

This section defines the canonical, future-proof rules for how ingestion must behave across:

- Collector-Service (REST API layer)
- NATS JetStream (Queue + Persistence)
- Worker Pool (Consumers + DB writers)
- Database Storage contract

These rules ensure NSReady remains stable, predictable, scalable, and AI-compatible for years.

### 5.1 High-Level Ingestion Architecture

```
NormalizedEvent JSON
        |
        v
  Collector-Service
        |
        v
     NATS JetStream
   (durable, fault-tolerant)
        |
        v
    Worker Pool (N)
        |
        v
     PostgreSQL / Timescale
        |
        v
  SCADA Views / NSWare Apps
```

### 5.2 Ingestion Core Principles (Non-Negotiable)

**Rule 1 – Collector never writes to the database**

Collector only:

- Validates JSON
- Assigns trace_id
- Publishes to NATS JetStream

Collector never:

- touches the database
- blocks on DB latency
- performs joins
- performs insert/update/delete

This is what makes NSReady scalable and robust.

**Rule 2 – All ingestion is asynchronous**

Once Collector publishes to NATS successfully:

```
status = queued
trace_id = uuid…
```

The request is considered successfully ingested.

End devices (GSM modems, PLCs, APIs) do not block on DB speed.

**Rule 3 – Every event MUST have a trace_id**

Trace ID guarantees:

- auditability
- debugging
- cross-system tracing
- future AI scoring correlation

Trace ID never changes as the event travels across the pipeline.

**Rule 4 – Workers are the ONLY writers into the database**

Workers pull from JetStream, then:

1. group events
2. perform validation
3. insert as batch
4. commit transaction
5. acknowledge to NATS

This ensures:

- data integrity
- transactional behaviour
- consistent performance
- no duplicate writes

**Rule 5 – Database inserts always use batch writes**

Workers never insert row-by-row.

Batching:

- reduces IO
- reduces locks
- increases throughput
- increases stability

Default batch size: 50 events  
(Default worker pool size: 4–6 workers)

**Rule 6 – NATS is the single source of truth for in-flight data**

JetStream provides:

- ack-based guarantee
- persistence
- replay on failure
- redelivery handling
- flow control
- backpressure management

If the DB is slow → queue grows  
If workers are slow → backlog increases  
Collector remains unaffected.

**Rule 7 – ingestion must never fail due to consumer outage**

If all workers crash:

- collector still accepts data
- JetStream persists it
- data is not lost
- workers catch up after recovery

This is mandatory behaviour.

### 5.3 NormalizedEvent – Master Contract

This is the official ingestion contract used by:

- GSM modem proxies
- PLC protocol translators
- SCADA interfaces
- Edge gateways
- NSWare integration layer
- Simulation tools

It MUST NOT be changed without a version increment.

**Canonical Format:**

```json
{
  "project_id": "UUID",
  "site_id": "UUID",
  "device_id": "UUID",
  "protocol": "string",
  "source_timestamp": "ISO 8601 (Z)",
  "metrics": [
    {
      "parameter_key": "project:<uuid>:<name>",
      "value": "float | int | null",
      "quality": "int (0–255)",
      "attributes": "json object"
    }
  ],
  "config_version": "string",
  "event_id": "string",
  "metadata": "object"
}
```

**Master rules:**

| Field | Rules |
|-------|-------|
| `project_id` | MUST match the project owning the device |
| `site_id` | MUST be consistent with device's site |
| `device_id` | MUST exist in registry |
| `parameter_key` | MUST match full-format template key |
| `source_timestamp` | MUST be valid ISO time |
| `metrics` | MUST NOT be empty |

**AI/ML requirement:**

Trace the final stored event using:

- `trace_id`
- `device_id`
- `parameter_key`
- `source_timestamp`
- `created_at`

This becomes your future feature lineage identifier.

### 5.4 Collector-Service Behaviour Rules

**Rule A – Validate, don't transform**

Collector validates:

- UUID formats
- timestamp format
- metric structure

Collector must not:

- modify values
- infer units
- auto-cast nulls
- rewrite timestamps
- rewrite parameter keys

**Rule B – Always return deterministic responses**

Success:

```
200 OK
{"status":"queued","trace_id":"..."}
```

Failure:

- `400` for invalid JSON
- `400` for missing required fields
- `500` for internal JetStream errors

**Rule C – Collector MUST be fast**

Target response time: < 50ms

This ensures modems and PLCs are not blocked.

### 5.5 NATS JetStream – Master Rules

**NATS Streams**

- Name: `INGRESS`
- Subject: `events.raw.*`
- Mode: Work-Queue / Pull Consumer

**Durability Rules**

- Stream is persistent
- Ack-based delivery
- Max redeliveries: 3
- Backpressure enabled

**Queue Depth Rules**

Defined globally:

| Depth | Meaning |
|-------|---------|
| 0–5 | Normal |
| 6–20 | Warning |
| 21–100 | Critical |
| >100 | Overload |

These numbers appear in:

- health endpoint
- performance manual
- monitoring design

### 5.6 Worker Pool – Master Rules

**Rule 1 – Pull from NATS in batches**

Each worker performs:

```
pull N messages from JetStream
validate
insert batch into DB
commit
ack to JetStream
```

**Rule 2 – Batch Size**

Default batch size = 50 events

**Rule 3 – DB Commit Rules**

Workers only ack after:

- successful DB commit
- all rows written

If DB fails:

- batch is retried
- errors logged
- no partial commits

**Rule 4 – Error handling logic**

Errors:

- Foreign-key violation → skipped & logged
- Unexpected JSON type → logged
- DB timeout → retry
- Parameter key mismatch → logged

Everything is logged into:

- `error_logs`
- worker log stream

**Rule 5 – Performance expectations**

- Sustained throughput: >250 events/sec
- Worker latency: <50ms per batch
- JetStream backlog drain: <3 seconds under load

These thresholds are from NSReady's load test results.

### 5.7 Database Writes – Canonical Rules

**Time-series table:** `ingest_events`

**Rules:**

- append-only
- immutable rows
- no updates
- no deletes except retention policy

**Foreign Keys:**

- `device_id → devices.id`
- `parameter_key → parameter_templates.key`

These MUST NEVER be removed.

**Indexes:**

- `(device_id, parameter_key, time DESC)`
- `(event_id) WHERE event_id IS NOT NULL`

### 5.8 SCADA & Dashboards – Contract Rules

**SCADA reads:**

- `v_scada_latest`
- `v_scada_history`

**Worker inserts must guarantee:**

- all timestamps valid
- no invalid device IDs
- no unregistered parameter keys

**Dashboards:**

Only read from:

- rollups
- materialized views
- optimized slices

Never directly from raw ingest table for long ranges.

### 5.9 AI/ML Compatibility Rules (Future-Proofing)

These ingestion rules guarantee future ML capabilities:

**1. Traceability**

Each event is trackable through:

```
trace_id → DB → SCADA → AI baseline store
```

**2. Feature store compatibility**

Worker enforces stable:

- `device_id`
- `parameter_key`
- `timestamp`
- feature lineage

**3. Temporal stability**

raw events remain immutable  
consistent with ML best practices.

**4. Schema stability**

No ingestion-breaking changes allowed once templates freeze.

### 5.10 Ingestion Checklist (Master Reference)

**Collector:**

- JSON validated
- trace_id generated
- Published to JetStream
- Response <50ms

**JetStream:**

- Consumer healthy
- queue_depth <5
- No redeliveries

**Workers:**

- Batch size correct
- Commit OK
- No integrity errors
- Ack after commit

**DB:**

- Inserts correct
- FK constraints enforced
- No orphaned records

**SCADA:**

- Visible in latest
- Visible in history

---

---

## 6. Health, Monitoring & Operational Observability – Master Specification

This section defines the canonical operational health rules, observability metrics, queue-depth logic, and monitoring contracts used across the NSReady system.

These rules ensure NSReady is:

- Predictable
- Supportable
- Diagnosable
- Non-fragile
- Operator-friendly

…and fully compatible with future NSWare AI/ML monitoring and auto-healing systems.

### 6.1 Health API – Official Contract (/v1/health)

The Collector-Service exposes a stable health endpoint:

```
GET /v1/health
```

**Expected Response Structure:**

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

**Master Rules:**

| Field | Meaning | Rule |
|-------|---------|------|
| `service` | Collector internal health | MUST be "ok" when accepting requests |
| `queue_depth` | pending + ack_pending | MUST remain low in steady state |
| `db` | Worker → DB connection | "connected" required for ingestion |
| `queue.*` | JetStream consumer stats | MUST reflect real-time state |

**API Stability Requirement:**

This endpoint is contractual.  
Future monitoring dashboards rely on this structure.  
It must not be changed without versioning.

### 6.2 Queue Depth – Global Canonical Thresholds

Queue depth (pending + ack_pending) is the primary health indicator for ingestion stability.

**Canonical Threshold Table:**

| queue_depth | System State | Meaning | Action |
|-------------|--------------|---------|--------|
| 0–5 | 🟢 Normal | Workers keeping up | None |
| 6–20 | 🟡 Warning | System under mild load | Watch, but OK |
| 21–100 | 🟠 Critical | Workers falling behind | Check workers & DB |
| >100 | 🔴 Overload | System cannot keep up | Scale workers or check DB |

**Where These Values Are Used:**

These exact thresholds are referenced in:

- Module 8 (Monitoring)
- Module 11 (Troubleshooting)
- Module 13 (Performance & Alerts)
- Prometheus/Grafana dashboards
- Test-Drive script
- AI anomaly detection (future)

They must remain consistent across the platform.

### 6.3 Metrics API (/metrics) – Prometheus Contract

This endpoint exposes quantitative telemetry for:

- JetStream health
- Worker activity
- Insert success/error counts
- Latency

**Supported Metrics (v1):**

| Metric | Type | Description |
|--------|------|-------------|
| `ingest_events_total{status="queued"}` | Counter | total accepted events |
| `ingest_events_total{status="success"}` | Counter | total DB-written events |
| `ingest_errors_total{error_type="..."}` | Counter | number of failures |
| `ingest_queue_depth` | Gauge | pending+ack_pending |
| `ingest_consumer_pending` | Gauge | raw pending count |
| `ingest_consumer_ack_pending` | Gauge | messages delivered but unacknowledged |

**Master Rules:**

- Metrics MUST always be available when `service=ok`
- No metric name may be changed without versioning
- Missing metrics indicate a worker crash or misconfiguration

### 6.4 Worker Monitoring – Canonical Behaviour

Workers MUST expose via logs:

```
[Worker-N] DB commit OK → acked X messages
[Worker-N] inserting Y events into database
[Worker-N] error: <error>
```

**Master Monitoring Logic:**

- **Case 1:** High queue_depth + no worker logs → workers not running
- **Case 2:** High queue_depth + DB errors → DB issue
- **Case 3:** High redelivered count → consumer stuck
- **Case 4:** High ack_pending → DB commit slow
- **Case 5:** High pending → insufficient worker count

These patterns are used in:

- troubleshooting
- Grafana dashboards
- test automation
- AI anomaly detection (future NSWare upgrades)

### 6.5 DB Health Monitoring – Canonical Rules

Workers test DB connectivity every cycle.

**DB must satisfy:**

| Check | Requirement |
|-------|-------------|
| Connection | MUST be available |
| Write latency | SHOULD be <50ms per batch |
| Row insert | MUST succeed or fail fast |
| Retention | MUST NOT block inserts |
| Disk | PVC MUST NOT exceed 90% |

**Database-Level Alerts:**

1. Disk > 85%
2. Retention job failing
3. Continuous aggregate refresh failures
4. Worker transaction rollbacks > threshold
5. Invalid FK (device_id / parameter_key mismatches)

### 6.6 NATS JetStream Health – Canonical Rules

**JetStream MUST satisfy:**

| Check | Requirement |
|-------|-------------|
| Stream exists | YES |
| Consumer exists | YES |
| Max redeliveries | 3 |
| Ack mode | explicit |
| Pending messages | ideally <20 |
| Memory usage | stable |

**Failures indicate:**

- NATS pod restart
- corrupted consumer
- slow worker pool
- DB slowness cascading upstream

### 6.7 System-Wide Health Model

**3-Layer Health Contract:**

| Layer | Component | Health Signal |
|-------|-----------|---------------|
| 1. Ingest Acceptance | Collector | `/v1/health` |
| 2. Queue Reliability | JetStream | pending, ack_pending, redelivered |
| 3. Data Persistence | Worker + DB | `ingest_events_total{status="success"}` |

**Golden Rule:**

If collector is OK + queue is draining + inserts increase → ingestion is healthy.

### 6.8 Alerts & Auto-Remediation (Future NSWare AI Integration)

**Critical Alerts (required for SCADA/NSWare):**

1. Queue Depth > 100 for 2 minutes → Overload
2. DB disconnects → Worker unable to commit
3. Worker crash loop → ingestion stopped
4. NATS consumer deleted/corrupted → ingestion halted
5. Error logs spike → invalid payloads or FK mismatch

**Warning Alerts:**

- Queue depth 6–20
- Redelivery count > 5/min
- Worker batch latency >200ms
- DB write latency >100ms

**AI-Powered Alerts (Phase 2 future):**

- pattern-based anomaly detection
- temporal degradation
- customer-specific performance regression
- auto-scaling worker pool
- predictive backlog growth

### 6.9 Health Check CLI Commands (Master Reference)

**Kubernetes:**

```bash
kubectl exec -n nsready-tier2 nsready-db-0 -- psql -U postgres -d nsready -c "SELECT now();"
kubectl logs -n nsready-tier2 -l app=collector-service --tail=50
kubectl logs -n nsready-tier2 -l app=collector-service | grep "DB commit"
kubectl exec -n nsready-tier2 nsready-nats-0 -- nats consumer info INGRESS ingest_workers
```

**Docker Compose:**

```bash
docker exec nsready_db psql -U postgres -d nsready -c "SELECT now();"
docker logs collector_service
docker logs collector_service | grep "DB commit"
```

### 6.10 Operational Checklist (Copy/Paste)

**✔ Collector**

- `/v1/health` returns "ok"
- Response time <50ms

**✔ Queue**

- queue_depth <5
- redeliveries = 0
- ack_pending stable

**✔ Workers**

- "DB commit OK" in logs
- No batch insert failures
- No long latency spikes

**✔ Database**

- Inserts increasing
- No FK constraint failures
- Disk usage <85%

**✔ SCADA**

- Latest visible in `v_scada_latest`
- History visible in `v_scada_history`

---

---

## 7. Database Architecture & Storage Contracts – Canonical Specification

This section defines the official database model, storage rules, indexing standards, contract requirements, and AI/ML-ready constraints for NSReady.

This is the master reference that all modules (3, 5, 6, 7, 9, 12, 13) follow.

### 7.1 Core Database Tables (Canonical Model)

NSReady uses a normalized & strict registry tree:

```
CUSTOMER (Tenant)
   ↓
PROJECT
   ↓
SITE
   ↓
DEVICE
   ↓
INGEST EVENTS (Telemetry)
```

#### 7.1.1 Table List

| Table | Purpose | Must Not Change |
|-------|---------|-----------------|
| `customers` | top-level tenant / business entity | ❗ primary tenant boundary |
| `projects` | logical grouping under customer | FK → customer_id |
| `sites` | physical locations | FK → project_id |
| `devices` | physical or logical hardware endpoints | FK → site_id |
| `parameter_templates` | parameter metadata | canonical source of truth |
| `ingest_events` | raw time-series incoming telemetry | append-only |

**Master Rule:**

No future module may bypass or duplicate this hierarchy.  
All telemetry MUST always map into this chain.

### 7.2 Registry Contracts (Customers → Devices)

Registry tables form the identity backbone for NSReady and NSWare Phase-2 (AI).

#### 7.2.1 CUSTOMER (tenant boundary)

```
id (UUID, PK)
name (text)
parent_customer_id (UUID, nullable)   # for group/org structures
metadata (jsonb)
created_at (timestamptz)
```

**Rules:**

- `customer_id = tenant_id` (NSReady v1)
- `parent_customer_id` used ONLY for grouping, NOT for access boundary
- Each device strictly belongs to one customer through FK chain

#### 7.2.2 PROJECT

```
id (UUID, PK)
customer_id (UUID, FK)
name
description
created_at
```

**Rules:**

- Customer → Project is strict 1-to-many
- Parameter templates typically tied to project scope

#### 7.2.3 SITE

```
id (UUID, PK)
project_id (UUID, FK)
name
location (jsonb)
created_at
```

**Rules:**

- A site can only belong to one project
- SCADA grouping happens at site level

#### 7.2.4 DEVICE

```
id (UUID, PK)
site_id (UUID, FK)
name
device_type
external_id (code used by SCADA)
status
metadata (jsonb)
created_at
```

**Rules:**

- `external_id` is mandatory for SCADA mapping
- Device → parameter relationships are handled via parameter_templates

### 7.3 Parameter Template Contract (Canonical Source of Truth)

(Controlled by Module 6)

This defines the only valid parameter identifiers for ingestion.

```
key = project:<project_uuid>:<parameter_name_lowercase>
```

**Example:**

```
project:8212caa2-b928-4213-b64e-9f5b86f4cad1:voltage
```

**Master Rules:**

- No short keys allowed (e.g., `"voltage"` is invalid)
- Keys must be deterministic and stable
- Keys must be unique per project
- Parameter metadata must include:
  - `unit`
  - `dtype`
  - `min`, `max`, threshold ranges
  - alarm/quality attributes (optional)

**AI-Future Note:**

Parameter keys act as the stable feature identifiers for machine learning.  
They must never be renamed after deployment.

### 7.4 ingest_events Table – Canonical Raw Telemetry Store

**Schema:**

```
time              TIMESTAMPTZ   # device timestamp (UTC)
device_id         UUID          # FK → devices.id
parameter_key     TEXT          # FK → parameter_templates.key
value             DOUBLE PRECISION
quality           INTEGER
source            TEXT          # SMS / GPRS / HTTP
event_id          TEXT          # optional idempotency key
attributes        JSONB
created_at        TIMESTAMPTZ   # ingestion timestamp (UTC)
```

**Primary Key:**

```
PRIMARY KEY (time, device_id, parameter_key)
```

**Indexes:**

- `(device_id, parameter_key, time DESC)`
- `(time DESC)`

### 7.5 Canonical Data Contract for ingest_events

The `ingest_events` table is governed by data contracts stored in:

```
contracts/nsready/ingest_events.yaml
```

**Contract Requirements:**

| Requirement | Purpose |
|-------------|---------|
| UTC timestamps only | Normalize across customers |
| Append-only | No updates/deletes allowed |
| FK enforced | Tenant isolation and SCADA correctness |
| Valid parameter_key | Required for AI features |
| Created_at auto-filled | Required for latency and SLAs |
| value may be NULL | Allowed for status-type metrics |
| attributes must be JSONB | Extensible future fields |
| event_id optional | For idempotency (future) |

**Retention Policy:**

- Raw data: 7–30 days
- Continuous aggregates (1m): 90 days
- Hourly rollups: 13+ months
- Cold history (optional): Parquet S3/MinIO (in future)

### 7.6 SCADA Views – Canonical Exposure Layer

The platform exposes read-only, SCADA-targeted views:

#### 7.6.1 v_scada_latest

- One latest value per device per parameter
- Used for real-time HMI/SCADA
- Should refresh every insert (view, not materialized)

#### 7.6.2 v_scada_history

- Full historical timeline
- Must always filter by date range for performance

#### 7.6.3 Requirements for SCADA Views

Must include:

- `customer_name`
- `project_name`
- `site_name`
- `device_name`
- `parameter_name`
- `unit`
- `value` / `quality`
- `time`

#### 7.6.4 Tenant Isolation

**Rule:** SCADA queries must ALWAYS filter by `customer_id`.  
This prevents cross-customer leakage.

### 7.7 Feature Tables (AI/ML Future) – Design Rules

When NSWare AI modules activate (Phase 2+), additional tables will be created:

#### 7.7.1 feature_store_online

- keyed by `(customer_id, entity_id, feature_name)`
- low-latency access

#### 7.7.2 feature_store_offline

- historical features for model training

#### 7.7.3 inference_log

- logs every model call (for tracing, debugging, compliance)

**Design Principles:**

- Never modify raw `ingest_events`
- Features computed downstream (materializers)
- All tables partitioned by `customer_id`
- Strict row-level isolation

### 7.8 Tenant Isolation — Database-Level Canonical Rules

**Rule 1 — Customer = Tenant Boundary (NSReady v1)**

- Each customer is a tenant
- No cross-customer data visibility

**Rule 2 — Parent Customer = Grouping Only**

- Used for "Customer Group → Customer Group Textool" reporting
- Not used for access control
- Only used for rollups & dashboards

**Rule 3 — Device → Site → Project → Customer chain determines tenant**

- Worker resolves tenant at insert time
- No overrides allowed

**Rule 4 — SCADA Reads MUST filter by tenant**

**Example:**

```sql
SELECT * FROM v_scada_latest
WHERE customer_id = '<customer UUID>';
```

### 7.9 Canonical Time-Series Modeling Strategy

NSReady uses a hybrid model:

#### 7.9.1 Narrow Raw Table (ingest_events)

- optimal for ingestion & FK integrity
- append-only
- time-indexed

#### 7.9.2 Continuous Aggregates

- 1-minute
- 5-minute
- hourly

#### 7.9.3 Materialized Views

- per customer
- per site
- per KPI family

**Retention Rule:**

The raw table is not queried for long-range dashboards.  
Dashboards must use rollups or materialized views.

### 7.10 Database Golden Rules

**MUST NOT:**

- Add columns to `ingest_events` without contract update
- Rename or delete `parameter_key` values
- Store timestamps in non-UTC
- Allow devices to exist without a site/project/customer
- Query `ingest_events` directly for large time ranges
- Mix customer data in rollups

**MUST:**

- Enforce FK constraints
- Use canonical `parameter_key` format
- Use tenant isolation on all reads
- Maintain data contracts
- Refresh continuous aggregates
- Monitor DB write latency

---

---

## 8. SCADA & External System Integration – Canonical Rules & Long-Term Architecture Alignment

This section defines the official, long-term SCADA integration model of NSReady.

It ensures any SCADA (Siemens WinCC, Wonderware, Ignition, Inductive, Custom OEM panels, PLC software) can read NSReady data safely, consistently, and tenant-isolated.

It also documents the contract for TXT/CSV export, Direct PostgreSQL access, and future NSWare dashboards.

### 8.1 SCADA Integration Options (Canonical)

NSReady supports two integration pathways:

#### Option 1 — File Export (TXT/CSV)

Recommended for Phase 1 & OEM deployments  
Zero DB dependency for OEM SCADA. Safe, predictable, and stable.

**Exports generated by:**

- `scripts/export_scada_data_readable.sh` → human-readable TXT/CSV
- `scripts/export_scada_data.sh` → raw TXT/CSV

**Key Characteristics:**

- Human-friendly
- Vendor-neutral
- Easily imported into any SCADA
- Can be emailed / FTP / folder-watched
- Perfect for OEMs with rigid SCADA systems

#### Option 2 — Direct Read-Only PostgreSQL Access

Recommended for utilities, large factories, and NSWare-integrated deployments

**Access via:**

- Read-only DB user (`scada_reader`)
- Narrow and safe views (`v_scada_latest`, `v_scada_history`)

**Key Characteristics:**

- Real-time
- Full metadata visibility
- Zero vendor lock
- Ideal for large enterprise SCADA

### 8.2 Canonical SCADA Views (NSReady v1)

NSReady exposes two canonical SCADA views.

#### 8.2.1 v_scada_latest (Real-time View)

Provides one latest row per device per parameter.

**Fields include:**

- `customer_id`
- `project_id`
- `site_id`
- `device_id`
- `device_code`
- `device_name`
- `parameter_key`
- `parameter_name`
- `unit`
- `value`
- `quality`
- `timestamp`

**Mandatory Requirements:**

- Must ALWAYS include `customer_id` for tenant isolation
- Must include `unit`, `parameter_name` for human readability
- Must resolve `device_code` (used by classic SCADA)

#### 8.2.2 v_scada_history (Historical View)

Provides the entire timeline of telemetry.

**Mandatory filtering rule:**

```sql
WHERE timestamp >= now() - interval '1 day'    -- recommended
```

**Canonical Contract:**

- SCADA systems are not allowed to pull the entire raw table
- Must use date range filters to protect DB performance
- For large histories, SCADA must use rollups (1m, 5m, 60m)

### 8.3 SCADA Tenant Isolation (Non-Negotiable Rule)

**Master Rule:** SCADA must NEVER see data from another tenant.

```
Tenant = Customer (NSReady v1)
```

**Enforcement Mechanisms:**

1. SCADA read-only user ONLY has access to views
2. Views contain `customer_id`
3. Filtering is enforced at:
   - SQL level
   - API level (future `/monitor/*`)
   - Export scripts

**Example Correct Query:**

```sql
SELECT * FROM v_scada_latest
WHERE customer_id = '<customer UUID>';
```

**Example Wrong Query (Forbidden):**

```sql
SELECT * FROM ingest_events;   -- ❌ Never permitted for SCADA
```

### 8.4 SCADA Export Format (Canonical)

(For file-based integrations)

#### 8.4.1 Columns for SCADA TXT Format

- `customer_name`
- `project_name`
- `site_name`
- `device_name`
- `device_code`
- `device_type`
- `parameter_name`
- `parameter_key`
- `parameter_unit`
- `timestamp` (UTC)
- `value`
- `quality`

**Master Requirements:**

- Must exclude UUIDs (SCADA engineers shouldn't handle them)
- Must be fully human-readable
- Must render customer → project → site hierarchy
- Must enforce tenant isolation

#### 8.4.2 SCADA Export Naming Convention

**Canonical naming:**

```
scada_latest_readable_<YYYYMMDD>_<HHMM>.txt
scada_history_readable_<YYYYMMDD>_<HHMM>.csv
```

This ensures:

- Traceability
- Automated pickup by SCADA scripts
- Auditability

### 8.5 SCADA Mapping Rules (Canonical Contract)

Each SCADA requires a mapping between NSReady parameters and SCADA tags.

**NSReady Side:**

- Uses `parameter_key` for identity
- Uses `device_code` for SCADA mapping
- Uses canonical hierarchy (customer → project → site → device)

**SCADA Side:**

Must map:

- `device_code` → SCADA device tag
- `parameter_key` → SCADA parameter tag

**Master Rule:**

No SCADA mapping may bypass `device_code` or `parameter_key`.  
This prevents ambiguity, duplication, or tag collision across tenants.

### 8.6 SCADA Profiles per Customer (NSReady v1)

Each customer receives a SCADA Profile describing:

#### 8.6.1 Profile Contents

- `customer_id`
- `allowed_sites`
- list of devices
- list of parameters
- SCADA tag mapping table
- export preferences (TXT/CSV/SQL)
- update frequency (manual/5m/15m/hourly)
- latency target

#### 8.6.2 Where Profiles Live

```
docs/CUSTOMER_EXAMPLES/<customer_name>_SCADA_PROFILE.md
```

#### 8.6.3 Why This Matters

- OEMs like Customer Group have multiple internal companies → unique mapping needs
- Utilities often have per-zone SCADA systems
- Profiles prevent mixing customer data accidentally

### 8.7 Safety & Data Quality Rules for SCADA

#### 8.7.1 Mandatory UTC

All SCADA timestamps must be in UTC.

#### 8.7.2 Mandatory Full Parameter Keys

Short keys (e.g., `"voltage"`) are forbidden.

Only valid format:

```
project:<project_uuid>:<parameter>
```

#### 8.7.3 No schema changes allowed by SCADA

SCADA cannot:

- Insert
- Update
- Delete
- Create tables
- Create views
- Modify schema

Read-only access only.

### 8.8 External System Integration (Beyond SCADA)

This covers integration with:

- OEM proprietary systems
- MES / ERP systems
- Analytics engines (Power BI / Tableau)
- NSWare dashboards

**Integration Contract (Canonical):**

All external systems must:

1. Use read-only views OR
2. Use export files OR
3. Use NSWare Monitoring API (future)

Direct access to raw tables is forbidden.

### 8.9 NSWare / Dashboard Integration Alignment

NSReady backend structure must fully support:

- Individual customer dashboards
- Group dashboards (using `parent_customer_id`)
- Full tenant isolation
- 1-minute rollups for high-traffic dashboards
- AI/ML scoring from Inference Router (Phase 2)

This is why:

- Views must include `customer_id`
- Exports must include customer hierarchy
- Raw tables must not be accessed directly

### 8.10 Golden Rules for SCADA Integration

**Must NOT:**

- Mix customers in the same SCADA export
- Query `ingest_events` directly
- Use non-UTC time
- Use short parameter keys
- Allow SCADA direct write access
- Break FK chain (device → site → project → customer)

**Must:**

- Filter SCADA reads by `customer_id`
- Use read-only user
- Use canonical SCADA views
- Use correct TXT/CSV format
- Maintain SCADA profile per customer
- Use `device_code` for mapping

---

---

## 9. Tenant Model & Multi-Customer Isolation – Master Specification

This section defines how NSReady handles multiple customers, groups, OEMs, multi-company structures, and data isolation.

It documents the tenant boundary, customer hierarchy, and future NSWare compatibility, so your platform remains scalable and clean even when dozens of customers are active.

This is a core architectural rule—all SCADA, dashboard, AI/ML, and export behaviour depends on this.

### 9.1 Core Tenant Rule (Canon)

**Tenant = Customer (NSReady v1)**

In NSReady v1, each customer is treated as an independent tenant.

```
tenant_id = customer_id
```

**Why this decision was made:**

- Keeps implementation simple
- Zero code refactoring
- Zero schema changes
- Zero impact on SCADA or ingestion
- Fully compatible with all documentation
- Supports strong security isolation

**This ensures:**

- No customer ever sees another customer's data
- SCADA exports remain isolated
- Dashboards remain isolated
- Future AI/ML models operate per-customer

### 9.2 Customer Hierarchy (Grouping / Rollups)

NSReady supports parent → child grouping using:

```
parent_customer_id (added in migration 150)
```

**This is NOT a tenant boundary.**  
It is a logical grouping for reporting and dashboards.

**Example using Customer Group:**

```
Customer Group (parent_customer_id = NULL)
│
├── Customer Group Textool      (parent_customer_id = Customer Group)
├── Customer Group Texpin       (parent_customer_id = Customer Group)
└── Customer Group Industries   (parent_customer_id = Customer Group)
```

**Interpretation:**

| Level | Meaning | Acts As Tenant? |
|-------|---------|-----------------|
| Parent Customer | Group / OEM / Holding Company | ❌ No |
| Child Customer | Actual operating company | ✅ Yes |

**Group Dashboards:**

Use:

```sql
WHERE customer_id = parent_id OR parent_customer_id = parent_id
```

**Tenant Isolation:**

Applies ONLY to the child customer, not the parent group.

### 9.3 Why Not Make Tenant = Parent Group?

**Because:**

1. Parent has no devices
2. Parent has no sites
3. Parent has no ingestion
4. Parent has no registry data
5. Parent cannot be a "login boundary"

**Therefore:**

- Parent = reporting layer
- Child = operational boundary (tenant)

**This avoids future complications in:**

- SCADA mappings
- Ingestion routing
- Data access policies
- AI/ML training
- Dashboard filters

### 9.4 Tenant Boundary Enforcement (Must Follow)

Isolation is enforced by:

**1. Foreign Key Chain**

```
ingest_events → devices → sites → projects → customers
```

**2. SCADA Views**

- `v_scada_latest`
- `v_scada_history`

Both include:

```
customer_id
```

**3. SCADA Profiles**

Each customer has an isolated profile folder.

**4. Read-only DB Users**

SCADA users can only access filtered views.

**5. Data Export Scripts**

Export scripts always filter by `customer_id`.

**6. Future NSWare APIs**

APIs will require tenant context.

### 9.5 Dashboard Routing & Access Control Rules

Dashboards in NSWare must use:

```
tenant_id = customer_id
```

**Meaning:**

- Users logging in under Customer Group Textool ONLY see Textool data
- Users logging in under Customer Group Texpin ONLY see Texpin data
- Users logging in under Customer Group see an aggregated group dashboard

**Group dashboard = union, not override:**

```
Customer Group Dashboard  
= Customer Group Textool  
+ Customer Group Texpin  
+ Customer Group Industries
```

**Tenant isolation stays intact:**

- Group user → can see children
- Child user → cannot see group

### 9.6 Tenant Context for Future NSWare AI/ML Layer

Tenant boundary is preserved in all AI/ML pipelines:

**Feature stores:**

```
tenant_id  
device_id  
feature_vector  
timestamp  
```

**Training datasets:**

- train per customer (tenant)
- no cross-customer feature mixing

**Scoring:**

```
router.score(tenant_id, use_case, device_id)
```

**Drift monitoring:**

- drift metrics segmented by `tenant_id`

**This ensures:**

- Isolation
- Compliance
- Clean models
- Accurate grouping

### 9.7 Canonical SQL Snippets

**Find all customers under a parent group:**

```sql
SELECT id 
FROM customers
WHERE id = '<parent_customer_id>'
   OR parent_customer_id = '<parent_customer_id>';
```

**Enforce isolation in SCADA view:**

```sql
WHERE customer_id = '<customer_id>';
```

**Enforce group dashboard:**

```sql
WHERE customer_id IN (
   SELECT id FROM customers
   WHERE id = '<group_id>'
      OR parent_customer_id = '<group_id>'
);
```

**Tenant boundary inside worker or API (future):**

```sql
tenant_id = registry.customer_from_device(device_id)
```

### 9.8 What Happens When NSWare Arrives?

NSReady's decision is future-safe.

**NSWare will add:**

- User accounts
- Role-based access control
- Tenant profiles
- Policy engine
- Per-tenant API keys
- Per-tenant dashboard themes

**ALL of this aligns perfectly with:**

```
tenant_id = customer_id
parent_customer_id → grouping only
```

**No migrations required**  
**No schema changes needed**  
**No architectural refactoring later**

### 9.9 Golden Rules (Must Respect Forever)

**Must NOT:**

- Treat parent customer as tenant
- Allow cross-customer SCADA access
- Allow ingestion to skip customer → project → site hierarchy
- Use group ID as tenant ID
- Permit SCADA or dashboards to query raw tables
- Use short-form parameter keys

**Must:**

- Enforce tenant boundary at customer level
- Use `parent_customer_id` ONLY for grouping
- Filter SCADA views by `customer_id`
- Filter exports by `customer_id`
- Implement dashboards by `tenant_id`
- Apply AI/ML scoring per `customer_id`

### 9.10 Tenant Model — Implementation Status

| Component | Status |
|-----------|--------|
| `parent_customer_id` added to DB | ✅ Completed (Migration 150) |
| Tenant rule documented | ✅ Completed |
| SCADA isolation rules implemented | ✅ Completed |
| SCADA views include `customer_id` | ✅ Completed |
| Export scripts isolate per tenant | ✅ Completed |
| Dashboard rules defined | ✅ Completed |
| AI/ML future alignment | ✅ Completed |

---

---

## 10. Master Documentation Index & Cross-Reference Map

(NSReady Unified Documentation System)

This section defines the official documentation structure, where every file lives, how modules relate, how tenant logic is applied, and how future NSWare layers will connect.

This acts as the central table of contents for developers, SCADA engineers, AI teams, and dashboard/UI teams.

### 10.1 The Master Documentation Folder Structure

The authoritative documentation tree for NSReady/NSWare is:

```
docs/
  MASTER/
    NSREADY_BACKEND_MASTER.md        ← THIS document
    NSWARE_DASHBOARD_MASTER.md       ← Dashboard/UI Master
  
  TENANT_MODEL/
    TENANT_MODEL_SUMMARY.md
    TENANT_DECISION_RECORD.md
    TENANT_MODEL_DIAGRAM.md
    (Additional ADRs in future…)

  CUSTOMER_EXAMPLES/
    ALLIDHRA_GROUP_MODEL_ANALYSIS.md
    (Future customer examples…)

  MODULES/   ← (Existing Module_00 to Module_13)
    00_Introduction_and_Terminology.md
    01_Folder_Structure_and_File_Descriptions.md
    02_System_Architecture_and_DataFlow.md
    03_Environment_and_PostgreSQL_Storage_Manual.md
    04_Deployment_and_Startup_Manual.md
    05_Configuration_Import_Manual.md
    06_Parameter_Template_Manual.md
    07_Data_Ingestion_and_Testing_Manual.md
    08_Monitoring_API_and_Packet_Health_Manual.md
    09_SCADA_Integration_Manual.md
    10_Scripts_and_Tools_Reference_Manual.md
    11_Troubleshooting_and_Diagnostics_Manual.md
    12_API_Developer_Manual.md
    13_Performance_and_Monitoring_Manual.md
```

This structure is FINALIZED.  
Future documentation must extend inside these same folders.

### 10.2 Cross-Reference Rules (Canonical)

All documents MUST cross-reference the following areas:

#### A) Tenant Model (Mandatory)

Every module referring to:

- registry
- SCADA
- ingestion
- dashboards
- AI readiness

MUST reference:

1. `TENANT_MODEL_SUMMARY.md`
2. `TENANT_DECISION_RECORD.md`
3. `TENANT_MODEL_DIAGRAM.md`

**Purpose:** ensures tenant isolation remains consistent across ALL features.

#### B) Master Documents

Every module that affects:

- ingestion
- dashboards
- SCADA
- AI

Must reference:

1. `MASTER/NSREADY_BACKEND_MASTER.md`
2. `MASTER/NSWARE_DASHBOARD_MASTER.md`

**Purpose:** ensures backend + dashboard work stay aligned.

#### C) Customer Examples

Modules 9, 12, 13 must reference:

- `CUSTOMER_EXAMPLES/ALLIDHRA_GROUP_MODEL_ANALYSIS.md`

**Purpose:** shows real-world multi-company grouping example.

### 10.3 Module-to-Master Cross-Mapping Table

This table shows exact connections between Modules 00–13 and Master-level docs.

| Module | Topic | Must Reference |
|--------|-------|----------------|
| 00 | Terminology | Tenant Summary, Diagram |
| 01 | Folder Structure | Master Index |
| 02 | Architecture | Tenant Summary, ADR |
| 03 | Database Storage | Tenant Diagram |
| 04 | Deployment | Backend Master |
| 05 | Registry Import | Tenant Model Summary |
| 06 | Parameter Templates | Backend Master |
| 07 | Ingestion Testing | Tenant Summary, Diagram |
| 08 | Monitoring API | Dashboard Master |
| 09 | SCADA Integration | Tenant Summary, Customer Example |
| 10 | Scripts/Tools | Backend Master |
| 11 | Troubleshooting | Backend Master |
| 12 | API Developer Manual | Tenant ADR, Backend Master |
| 13 | Performance & Monitoring | Tenant ADR, Dashboard Master |

This table is now the official mapping.

### 10.4 Where "Tenant Model" Hooks Into NSReady Architecture

Tenant context touches 5 layers:

```
Devices → Registry → Ingestion → SCADA Views → Dashboards → AI
```

**Mapping:**

1. **Registry Layer**
   - `customer_id = tenant_id`
   - `parent_customer_id = grouping only`

2. **Ingestion Layer**
   - We infer tenant from device via FK chain

3. **SCADA Layer**
   - SCADA queries must always filter by `customer_id`

4. **Dashboard Layer**
   - Each dashboard session MUST pass a tenant context

5. **AI Layer (Future)**
   - Feature stores store `tenant_id` on every row
   - Model scoring uses `(tenant_id, use_case, device_id)`
   - No cross-tenant training allowed

### 10.5 Where "Customer Groups" Are Used

Customer grouping is ONLY used for:

- Group dashboards (OEM-level)
- Rollup views
- Reporting dashboards
- Cross-company summarization
- OEM/Distributor scenarios
- Enterprise-level multi-subsidiary analytics

**THEY ARE NEVER USED FOR:**

- ingestion
- SCADA isolation
- API authentication
- request filtering
- worker logic
- database partitioning
- tenancy enforcement

### 10.6 How to Add New Features Safely

Any new backend/dashboards/AI feature MUST ask:

1. **Does this feature require tenant context?**  
   If yes → use `customer_id`

2. **Is group-level reporting needed?**  
   If yes → use `parent_customer_id`

3. **Could this leak data across customers?**  
   If yes → add isolation rule

4. **Does this require a new tenant-model ADR?**  
   If yes → create `TENANT_DECISION_RECORD_00X.md`

5. **Should this update the Master Backend or Dashboard docs?**  
   If yes → update appropriate master document

### 10.7 Future NSWare Integration Plan

This index is designed to survive the transition into full NSWare:

**NSWare will add:**

- User login system
- Roles (viewer/operator/admin/OEM)
- Tenant-specific dashboards
- AI scoring pipeline
- Multi-app module framework

**But the tenant rule remains EXACTLY the same:**

```
tenant_id = customer_id  
parent_customer_id → group dashboards only
```

**Thus:**

- ZERO schema changes
- ZERO ingestion changes
- ZERO SCADA changes
- ZERO conflicts with NSReady

Future NSWare builds ON TOP OF this stable architecture.

### 10.8 Master Document Update Rules

Whenever a feature is added or changed:

**Update these:**

- `NSREADY_BACKEND_MASTER.md`
- `NSWARE_DASHBOARD_MASTER.md`
- If tenant logic impacted → update ALL THREE tenant docs
- If customer example impacted → update `CUSTOMER_EXAMPLES` folder

**DO NOT modify:**

- Module 00–13 structure
- Migration history
- Existing FK chain

**ALWAYS update:**

- Master Index (this section)

### 10.9 Golden Standards for Documentation Consistency (Mandatory)

Every new feature must document:

- Tenant impact
- Customer grouping impact
- SCADA impact
- Dashboard impact
- AI/ML impact
- Performance impact

Every new file must adopt:

- same folder naming
- same YAML contract style
- same NSReady rule structure

Every change must be cross-linked in:

- Master Index
- Tenant Model Summary
- Dashboard Master

### 10.10 Final Words — Canonical Index Is Now Complete

This section makes the backend documentation enterprise-ready, ensuring:

- No duplication
- No ambiguity
- No accidental design drift
- No tenant isolation mistakes
- Full clarity for all team members
- Complete foundation for NSWare product roadmap

Your documentation set is now:

- Organized
- Version-safe
- Modular
- Tenant-aware
- Dashboard-ready
- AI-compatible

This forms the single source of truth for the entire NSReady → NSWare ecosystem.

---

**Status:** Part 10/10 Complete ✅  
**NSREADY_BACKEND_MASTER.md is now COMPLETE**

---

**Next Steps:**

- This master document is ready for use as the canonical backend reference
- All 10 sections have been validated against existing documentation and code
- Cross-references are established and documented
- Tenant model is fully integrated
- Future NSWare compatibility is ensured

**When ready, generate:**
- `NSWARE_DASHBOARD_MASTER.md` — Dashboard/UI Master Document

