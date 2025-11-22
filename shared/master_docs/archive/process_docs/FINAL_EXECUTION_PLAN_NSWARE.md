# NSReady / NSWare – Final Execution Plan

**Status:** ✅ Ready for Execution  
**Created:** 2025-11-18  
**Purpose:** Consolidated plan combining all documentation fixes, AI-readiness guardrails, and code/test updates

---

## Overview

This plan consolidates:
1. ✅ **Already Completed** - Critical fixes from previous execution
2. 📝 **New Additions** - AI-readiness notes, data contracts, time-series guardrails
3. 📝 **Code/Test Updates** - Comments and documentation enhancements

**All changes are documentation-only or comments-only** - zero production code changes.

---

## PART 1 – Critical Documentation Fixes (Already Completed ✅)

### 1.1 Fix parameter_key format in all docs ✅

**Status:** COMPLETED

**Files Updated:**
- ✅ `docs/00_Introduction_and_Terminology.md`
- ✅ `docs/02_System_Architecture_and_DataFlow.md`
- ✅ `docs/04_Deployment_and_Startup_Manual.md`
- ✅ `docs/07_Data_Ingestion_and_Testing_Manual.md`

**What Was Done:**
- All short-form `parameter_key` values replaced with full format
- All examples use: `project:8212caa2-b928-4213-b64e-9f5b86f4cad1:voltage`

**New Addition Needed:**
- Enhance Module 7 warning with NS-AI & DB CONSISTENCY context (see 1.1.1 below)

---

### 1.1.1 Enhance Module 7 Warning (NEW)

**File:** `docs/07_Data_Ingestion_and_Testing_Manual.md`

**Location:** After main NormalizedEvent JSON example (Section 2.2)

**Add:**

> ⚠️ **NOTE (DB & AI CONSISTENCY):**  
> All `parameter_key` values in real ingestion MUST use the full canonical format  
> `project:<project_uuid>:<parameter_name_lowercase_with_underscores>`.  
> Short-form keys like `"voltage"` or `"current"` were used in early drafts for readability,  
> but are **invalid** and will cause foreign-key errors in the database  
> and will break future AI/ML and analytics pipelines that rely on stable parameter identifiers.

**Purpose:** Explain both DB integrity and AI-readiness benefits.

---

### 1.2 Strengthen Module 6 as canonical reference ✅

**Status:** COMPLETED

**File Updated:**
- ✅ `docs/06_Parameter_Template_Manual.md`

**What Was Done:**
- Added canonical reference box at top
- Added important note in Section 5.1

**New Addition Needed:**
- Enhance with NS-KEYS context (see 1.2.1 below)

---

### 1.2.1 Enhance Module 6 Warnings (NEW)

**File:** `docs/06_Parameter_Template_Manual.md`

**Location 1:** Top of file, under title

**Enhance existing box:**

> ⚠️ **CANONICAL REFERENCE (NS-KEYS)**  
> This module defines the ONLY correct `parameter_key` format.  
> All ingestion examples, SCADA mappings, and future analytics/AI work must adhere to this format.  
> The `parameter_templates.key` column is the single source of truth for parameter identifiers.

**Location 2:** Section 5.1 – Parameter Key Generation

**Enhance existing note:**

> **NOTE (READABILITY vs REAL FORMAT):**  
> Some documentation examples in other modules may show shortened parameter names (e.g., `"voltage"`)  
> for readability when explaining concepts.  
> However, actual telemetry ingestion MUST always use the full key format defined here, e.g.:  
> `project:8212caa2-b928-4213-b64e-9f5b86f4cad1:voltage`.  
>  
> This guarantees stable joins for SCADA, analytics, and NSWare AI models.

---

### 1.3 Add critical warning in Module 12 ✅

**Status:** COMPLETED

**File Updated:**
- ✅ `docs/12_API_Developer_Manual.md`

**What Was Done:**
- Added critical warning in Section 6.1
- Added cross-reference to Module 6

**New Addition Needed:**
- Enhance with API & DB CONTRACT context (see 1.3.1 below)

---

### 1.3.1 Enhance Module 12 Warning (NEW)

**File:** `docs/12_API_Developer_Manual.md`

**Location:** Section 6.1 – NormalizedEvent Schema, after "Field Details" table

**Enhance existing warning:**

> ⚠️ **CRITICAL (API & DB CONTRACT):**  
> The `parameter_key` field MUST exactly match the `key` column in the `parameter_templates` table.  
> Always use the full format `project:<project_uuid>:<parameter_name>`.  
> Short keys like `"voltage"` or `"current"` will fail database constraints  
> and will break downstream analytics/AI pipelines that rely on consistent keys.

**Keep existing cross-reference:**
> For complete `parameter_key` rules, see **Module 6 – Parameter Template Manual** (canonical reference).

---

## PART 2 – Monitoring, Naming, Cross-References, Queue (Already Completed ✅)

### 2.1 Mark /monitor/* endpoints as PLANNED ✅

**Status:** COMPLETED

**Files Updated:**
- ✅ `docs/08_Monitoring_API_and_Packet_Health_Manual.md`
- ✅ `docs/12_API_Developer_Manual.md` (already had status notes)

**What Was Done:**
- Added PLANNED FEATURE warning box in Module 8 Section 4
- Added status notes to each endpoint

**New Addition Needed:**
- Enhance with MONITOR API context (see 2.1.1 below)

---

### 2.1.1 Enhance Module 8 Warning (NEW)

**File:** `docs/08_Monitoring_API_and_Packet_Health_Manual.md`

**Location:** Section 4 (top), before first endpoint

**Enhance existing warning:**

> ⚠️ **PLANNED FEATURE (MONITOR API)**  
> All `/monitor/*` endpoints described in this section are **PLANNED** and  
> **NOT implemented in the current release**.  
> The current production monitoring surface consists of `/v1/health` (JSON status)  
> and `/metrics` (Prometheus).  
> The `/monitor/*` API is reserved for future NSWare AI/observability enhancements.

---

### 2.2 Standardize naming conventions ✅

**Status:** COMPLETED

**File Updated:**
- ✅ `docs/00_Introduction_and_Terminology.md`

**What Was Done:**
- Added naming conventions table in Section 7.20

**New Addition Needed:**
- Enhance with NS-OPS-FUTURE context (see 2.2.1 below)

---

### 2.2.1 Enhance Module 0 Naming Section (NEW)

**File:** `docs/00_Introduction_and_Terminology.md`

**Location:** Section 7.20 – Naming Conventions

**Enhance existing section title:**

### 7.20 Naming Conventions (NS-OPS & ENVIRONMENT)

To keep commands and examples consistent across Kubernetes and Docker environments,  
we standardize the following names:

**Add note after table:**

> **NOTE (NS-OPS-FUTURE):**  
> These conventions also help future automation, monitoring agents, and NSWare AI services  
> find the right components without ambiguity across environments.

---

### 2.3 Add "Related Modules" sections ✅

**Status:** COMPLETED

**Files Updated:**
- ✅ All modules now have "Related Modules" sections

**No additional changes needed.**

---

### 2.4 Standardize queue depth thresholds ✅

**Status:** COMPLETED

**Files Updated:**
- ✅ `docs/08_Monitoring_API_and_Packet_Health_Manual.md`
- ✅ `docs/13_Performance_and_Monitoring_Manual.md`

**What Was Done:**
- Standardized to: 0–5 Normal, 6–20 Warning, 21–100 Critical, >100 Overload

**No additional changes needed.**

---

## PART 3 – AI-Readiness Guardrails (NEW - Documentation Only)

### 3.1 Entity identity stability

**Files to Update:**
- `docs/02_System_Architecture_and_DataFlow.md`
- `docs/03_Environment_and_PostgreSQL_Storage_Manual.md`

**Changes:**

**In Module 2:**
Add after Component 5 (PostgreSQL + TimescaleDB) section:

> **NOTE (NS-AI-ENTITY-STABILITY):**  
> `customer_id`, `project_id`, `site_id`, and `device_id` are treated as stable, never-repurposed identifiers.  
> Future NSWare AI and feature stores will rely on these keys to track entities across time  
> without changing the existing schema or ingestion format.

**In Module 3:**
Add in Section 6 (Database Structure) after table list:

> **NOTE (NS-AI-ENTITY-BACKBONE):**  
> The `devices` and `sites` tables form the entity backbone for NSReady and NSWare.  
> All future AI/ML and advanced analytics will join on these tables for context,  
> without altering their core structure.

---

### 3.2 Raw vs feature separation

**Files to Update:**
- `docs/03_Environment_and_PostgreSQL_Storage_Manual.md`
- `docs/07_Data_Ingestion_and_Testing_Manual.md`

**Changes:**

**In Module 3:**
Add in Section 6 (Database Structure) after `ingest_events` table description:

> **NOTE (NS-AI-RAW-DATA):**  
> `ingest_events` is treated as the raw, append-only time-series telemetry store.  
> Any future AI/ML features (aggregates, window statistics, derived KPIs)  
> will be stored in separate tables or continuous aggregates (e.g., `feature_store_*`),  
> not by changing or overwriting the `ingest_events` schema.

**In Module 7:**
Add after Section 2 (NormalizedEvent JSON Structure):

> **NOTE (NS-AI-FEATURES-FUTURE):**  
> In this phase we validate ingestion and SCADA directly from `ingest_events` and SCADA views.  
> When NSWare AI modules are introduced, they will build additional feature tables on top of this data  
> without changing the ingestion contract or SCADA views.

---

### 3.3 Traceability via trace_id

**Files to Update:**
- `docs/07_Data_Ingestion_and_Testing_Manual.md`
- `docs/11_Troubleshooting_and_Diagnostics_Manual.md`

**Changes:**

**In Module 7:**
Add in Section 4 (End-to-End Ingestion Test) after trace_id explanation:

> **NOTE (NS-AI-TRACEABILITY):**  
> The `trace_id` returned by `/v1/ingest` and logged by workers is intended to support  
> future AI/ML experiment tracking and debugging.  
> It allows linking an external request, the stored events, and future model scores.

**In Module 11:**
Add in Section 4 (Troubleshooting by Category) or Section 7 (Verification Steps):

> **NOTE (NS-AI-DEBUG-FUTURE):**  
> When diagnosing complex AI/ML behaviours in future phases, the `trace_id` will be used  
> to cross-reference telemetry, model scores, and SCADA behaviour.

---

## PART 4 – Data Contracts (NEW - YAML Files)

### 4.1 Create contracts folder and initial YAMLs

**New Files to Create:**
- `contracts/nsready/ingest_events.yaml`
- `contracts/nsready/parameter_templates.yaml`
- `contracts/nsready/v_scada_latest.yaml`
- `contracts/nsready/v_scada_history.yaml`

**Structure for `contracts/nsready/ingest_events.yaml`:**

```yaml
table: ingest_events
purpose: Raw time-series telemetry per device/parameter for SCADA + NSWare.

owners:
  data_owner: data-eng@groupnish
  steward: scada-team@groupnish

consumers: [scada-team@groupnish, nsware-platform@groupnish]

schema:
  - name: time
    type: timestamptz
    timezone: UTC
    semantics: Event time from device (source_timestamp)
    constraints: [not_null]
  
  - name: device_id
    type: uuid
    semantics: Reference to devices.id
    constraints: [not_null, foreign_key: devices.id]
  
  - name: parameter_key
    type: text
    semantics: Reference to parameter_templates.key (format: project:<uuid>:<name>)
    constraints: [not_null, foreign_key: parameter_templates.key]
  
  - name: value
    type: double precision
    semantics: Measured value
    constraints: []
  
  - name: quality
    type: integer
    semantics: Quality code (0–255); 192 = good
    constraints: []
  
  - name: source
    type: text
    semantics: Protocol (GPRS/SMS/HTTP/…)
    constraints: []
  
  - name: event_id
    type: text
    semantics: Optional idempotency key from source
    constraints: []
  
  - name: attributes
    type: jsonb
    semantics: Additional metadata (e.g., unit, calibration info)
    constraints: []
  
  - name: created_at
    type: timestamptz
    timezone: UTC
    semantics: Ingest time at NSReady
    constraints: [not_null]

primary_key: [time, device_id, parameter_key]

privacy:
  pii: false

sla:
  cadence: near-real-time
  delivery_deadline: "within 60s of event"
  late_window_minutes: 5

quality_rules:
  null_pct_max:
    value: 0.05
  duplicate_policy:
    description: "no duplicates per (time, device_id, parameter_key)"

changes:
  process: "PR to /contracts/nsready/ingest_events.yaml with approvals from data + SCADA owner"
  breaking_change_notice_days: 30

version: 1.0.0
changelog: "/contracts/nsready/ingest_events_changelog.md"
```

**Similar structure for other 3 YAML files** (parameter_templates, v_scada_latest, v_scada_history).

---

### 4.2 Reference contracts in docs

**File to Update:**
- `docs/03_Environment_and_PostgreSQL_Storage_Manual.md`

**Change:**

Add new subsection in Section 6 (Database Structure):

### 6.4 Data Contracts for Core Tables (NS-DATA-CONTRACTS – FUTURE)

For key NSReady tables (`ingest_events`, `devices`, `parameter_templates`, `v_scada_latest`, `v_scada_history`),  
we will maintain lightweight data contracts (YAML) under `/contracts/nsready/*.yaml`.

> **NOTE (NS-DATA-GOVERNANCE):**  
> These contracts define schema, units, allowed ranges, timezones, and change policies.  
> They protect downstream SCADA, analytics, and AI/ML consumers from silent schema drift.  
> Any breaking change to these tables will be proposed and reviewed via updates to these contracts.

**Note:** You can create the actual YAMLs later; this note is to record the intention.

---

## PART 5 – Time-Series Modeling Guardrails (NEW - Documentation Only)

### 5.1 Time-series modeling decision (narrow + hybrid)

**File to Update:**
- `docs/13_Performance_and_Monitoring_Manual.md`

**Change:**

Add new subsection in Module 13:

### 8.6 Time-Series Modeling Strategy (NS-TS-GUARDRAIL)

NSReady uses a **narrow ingest model** via `ingest_events`  
(one row per `(time, device_id, parameter_key, value, quality, source, ...)`).

> **Decision:**  
> - We will **keep `ingest_events` narrow and append-only** for performance and retention.  
> - For read-heavy workloads (dashboards, SCADA, AI baselines), we will use  
>   continuous aggregates and/or materialized views built on top of `ingest_events`,  
>   such as per-site or per-project rollup views (1m/5m/hourly).

This hybrid approach lets us:

- Maintain high ingest performance,
- Optimize for key dashboard slices,
- Avoid schema churn or wide tables for every new metric.

---

### 5.2 Rollup strategy clarification

**File to Update:**
- `docs/13_Performance_and_Monitoring_Manual.md`

**Change:**

Enhance existing Section 8.5 (Time-Series Rollup Plan) or add if missing:

### 8.5 Time-Series Rollup Plan (NS-TS-FUTURE)

NSReady uses `ingest_events` as the canonical narrow ingest table.  
For long-term performance and analytics/AI, we will introduce continuous aggregates and/or materialized views:

- **1-minute rollups** for short-term analysis (7–90 days)
- **5–15 minute rollups** for medium-term trends
- **Hourly rollups** for long-term dashboards and AI feature baselines

**Retention concept:**
- `ingest_events` raw: keep 7–30 days (depending on load)
- 1-minute aggregates: keep ~90 days
- Hourly aggregates: keep ~13 months or more
- Cold history: archive to Parquet (S3/MinIO) when needed

> **NOTE (NS-TS-AI-FRIENDLY):**  
> This layered model ensures we don't overload the raw table with long-term reads,  
> and that AI/ML features can use rollups efficiently without changing ingestion.

---

### 5.3 Tag and series strategy

**Files to Update:**
- `docs/06_Parameter_Template_Manual.md`
- `docs/03_Environment_and_PostgreSQL_Storage_Manual.md`

**Changes:**

**In Module 6:**
Add in Section 4 (Parameter Template Structure) or Section 5 (Parameter Key Generation):

> **NOTE (NS-TS-TAGS):**  
> Stable tags (customer, site, device_type) will be modeled as structured and indexable,  
> while noisy/rapidly-changing attributes remain in JSONB to avoid schema churn and rework.

**In Module 3:**
Add in Section 6 (Database Structure):

> **NOTE (NS-TS-TAGS):**  
> For NSReady/NSWare, stable identifiers/tags (e.g., site_id, device_type, customer_id)  
> will be present as JOINs via registry tables and/or explicit columns in rollup/feature tables.  
> Volatile tags (e.g., firmware version, random labels) will live in metadata/attributes JSONB fields.

---

### 5.4 Dashboard query guardrail

**Files to Update:**
- `docs/09_SCADA_Integration_Manual.md`
- `docs/13_Performance_and_Monitoring_Manual.md`

**Changes:**

**In Module 9:**
Add in Section 4 (Option 2 — Direct SCADA → NSReady Database Connection):

> **NOTE (NS-TS-DASHBOARD-GUARDRAIL):**  
> For large time ranges (weeks/months), dashboards and SCADA should read from rollup views  
> or materialized views (e.g., hourly aggregates), not directly from the raw `ingest_events` table.  
> This avoids performance issues and keeps the system scalable as data grows.

**In Module 13:**
Add in Section 6 (Recommended Grafana Panels) or Section 8:

> **NOTE (NS-TS-DASHBOARD-GUARDRAIL):**  
> For long time ranges (weeks/months), dashboards should query rollup or materialized views,  
> not `ingest_events` directly. This avoids performance issues and keeps the system scalable.

---

## PART 6 – Code & Test Updates (Already Completed ✅)

### 6.1 Update sample_event.json ✅

**Status:** COMPLETED

**File Updated:**
- ✅ `collector_service/tests/sample_event.json`

**What Was Done:**
- Updated to use documentation UUIDs
- All parameter_key values use full format

**New Addition Needed:**
- Add note in README (see 6.1.1 below)

---

### 6.1.1 Add sample_event.json documentation (NEW)

**File to Create/Update:**
- `collector_service/tests/README.md` (or enhance existing)

**Add:**

```markdown
## sample_event.json

This sample event uses:
- Full `parameter_key` format (`project:<uuid>:<name>`)
- Documentation UUIDs (`8212caa2-...`)

**NOTE (NS-AI-COMPAT & TESTS):**  
This sample event is intentionally aligned with the documentation UUIDs and full parameter_key format,  
so that developers, tests, SCADA, and future AI pipelines can all reuse the same example cleanly.
```

---

### 6.2 Update collector_service/README.md ✅

**Status:** COMPLETED

**File Updated:**
- ✅ `collector_service/README.md`

**What Was Done:**
- Updated all 4 JSON examples
- Added warning box

**New Addition Needed:**
- Enhance warning with API & DB CONTRACT context (see 6.2.1 below)

---

### 6.2.1 Enhance README Warning (NEW)

**File:** `collector_service/README.md`

**Location:** After main ingestion example

**Enhance existing warning:**

> ⚠️ **NOTE (API & DB CONTRACT):**  
> The `parameter_key` shown above uses the full canonical format  
> `project:<project_uuid>:<parameter_name>`.  
> This MUST match the `parameter_templates.key` value in the database.  
> Short-form keys (e.g., `"voltage"`) will cause database foreign-key errors and can  
> break downstream analytics/AI pipelines that rely on stable keys.  
>  
> For more details, see **Module 6 – Parameter Template Manual**.

---

### 6.3 Standardize test UUIDs ✅

**Status:** COMPLETED

**Files Updated:**
- ✅ `tests/regression/test_api_endpoints.py`
- ✅ `tests/performance/locustfile.py`
- ✅ `tests/resilience/test_recovery.py`
- ✅ `tests/regression/test_ingestion_flow.py`

**What Was Done:**
- All test files use documentation UUIDs
- All parameter_key values use full format

**New Addition Needed:**
- Add NS-AI-COMPAT comments (see 6.3.1 below)

---

### 6.3.1 Add NS-AI-COMPAT comments to test files (NEW)

**Files to Update:**
- `tests/regression/test_api_endpoints.py`
- `tests/performance/locustfile.py`
- `tests/resilience/test_recovery.py`
- `tests/regression/test_ingestion_flow.py`

**Change:**

Add at top of each test file (after imports, before test functions):

```python
# NOTE (DOC/TEST ALIGNMENT & NS-AI):  
# These IDs and parameter_keys match the examples used in the official documentation.  
# This ensures docs, tests, SCADA, and future AI examples all refer to the same entities.
```

---

## Execution Summary

### Already Completed ✅
- All PART 1 critical fixes
- All PART 2 monitoring/naming/cross-refs/queue
- All PART 6 code/test updates

### New Additions Needed 📝

| Part | Task | Files | Time |
|------|------|-------|------|
| **1.1.1** | Enhance Module 7 warning | 1 | 5 min |
| **1.2.1** | Enhance Module 6 warnings | 1 | 5 min |
| **1.3.1** | Enhance Module 12 warning | 1 | 5 min |
| **2.1.1** | Enhance Module 8 warning | 1 | 5 min |
| **2.2.1** | Enhance Module 0 naming | 1 | 5 min |
| **3.1** | Entity stability notes | 2 | 10 min |
| **3.2** | Raw vs features notes | 2 | 10 min |
| **3.3** | Traceability notes | 2 | 10 min |
| **4.1** | Create YAML contracts | 4 | 30 min |
| **4.2** | Reference contracts in docs | 1 | 5 min |
| **5.1** | Time-series modeling note | 1 | 10 min |
| **5.2** | Rollup strategy note | 1 | 5 min |
| **5.3** | Tag strategy notes | 2 | 10 min |
| **5.4** | Dashboard guardrail notes | 2 | 10 min |
| **6.1.1** | Sample event README | 1 | 5 min |
| **6.2.1** | Enhance README warning | 1 | 5 min |
| **6.3.1** | Test file comments | 4 | 10 min |

**Total:** ~20 files, ~2 hours

---

## Verification Checklist

Before execution:
- [ ] Review this final plan
- [ ] Confirm all PART 1-2-6 items are already completed
- [ ] Verify YAML contract structure matches actual schema
- [ ] Confirm note formats are acceptable

After execution:
- [ ] Run grep checks (see PART 7 below)
- [ ] Verify all tests still pass
- [ ] Check documentation formatting
- [ ] Update execution checklist

---

## PART 7 – Verification Commands

After execution, run these from project root:

```bash
# 1. Ensure no short-form parameter_key remains
grep -R --line-number '"parameter_key": "voltage"' . | grep -v "docs/FINAL"
grep -R --line-number '"parameter_key": "current"' . | grep -v "docs/FINAL"
grep -R --line-number '"parameter_key": "power"' . | grep -v "docs/FINAL"

# 2. Ensure old UUIDs are gone (if migrated)
grep -R --line-number '4360b675-5135-435d-b281-93a551a3986d' . | grep -v "docs/FINAL"
grep -R --line-number '11cede34-1e6a-47f2-b7b2-8fc4634a760a' . | grep -v "docs/FINAL"

# 3. Verify full format is used
grep -R --line-number '"parameter_key": "project:' . | head -10

# Expected: All grep commands show full format or no matches
```

---

**Status:** ✅ Ready for execution after review

