# NSReady / NSWare – Proposed Documentation Changes

**Status:** 📋 Ready for Review  
**Context:** Documentation fixes + AI-readiness guardrails + time-series design decisions  
**Goal:** Make NSReady documentation consistent, AI-ready, and future-proof without breaking current usage

---

## Overview

This document lists all proposed documentation changes that:
1. Fix inconsistencies (parameter_key format, monitoring endpoints, naming)
2. Add AI-readiness guardrails (stable IDs, data contracts, traceability)
3. Document time-series design decisions (narrow + hybrid model, rollup strategy)

**All changes are documentation-only** - no code changes required for these items.

---

## PART 1 – Critical Documentation Fixes (Already Completed ✅)

### 1.1 Fix parameter_key format in documentation ✅

**Status:** COMPLETED in previous execution

**Files Updated:**
- ✅ `docs/00_Introduction_and_Terminology.md`
- ✅ `docs/02_System_Architecture_and_DataFlow.md`
- ✅ `docs/04_Deployment_and_Startup_Manual.md`
- ✅ `docs/07_Data_Ingestion_and_Testing_Manual.md`

**What Was Done:**
- Replaced all short-form `parameter_key` values with full format
- Added warning boxes in Module 7
- All examples now use: `project:8212caa2-b928-4213-b64e-9f5b86f4cad1:voltage`

**New Addition Needed:**
- Add NS-AI & DATA-CONSISTENCY note in Module 7 explaining why this matters for future analytics

---

### 1.2 Strengthen Module 6 as canonical reference ✅

**Status:** COMPLETED in previous execution

**File Updated:**
- ✅ `docs/06_Parameter_Template_Manual.md`

**What Was Done:**
- Added canonical reference box at top
- Added important note in Section 5.1

**New Addition Needed:**
- Enhance warning boxes with NS-AI & SCADA context
- Add note about future analytics/AI relying on stable parameter IDs

---

### 1.3 Add critical warning in Module 12 ✅

**Status:** COMPLETED in previous execution

**File Updated:**
- ✅ `docs/12_API_Developer_Manual.md`

**What Was Done:**
- Added critical warning in Section 6.1
- Added cross-reference to Module 6

**New Addition Needed:**
- Enhance warning with NS-AI & DB-INTEGRITY context
- Add note about breaking future analytics/ML pipelines

---

### 1.4 Mark /monitor/* endpoints as PLANNED ✅

**Status:** COMPLETED in previous execution

**Files Updated:**
- ✅ `docs/08_Monitoring_API_and_Packet_Health_Manual.md`
- ✅ `docs/12_API_Developer_Manual.md` (already had status notes)

**What Was Done:**
- Added PLANNED FEATURE warning box in Module 8 Section 4
- Added status notes to each endpoint

**New Addition Needed:**
- Enhance with NS-AI & OBSERVABILITY context
- Note that these are reserved for future NSWare AI/monitoring enhancements

---

### 1.5 Standardize naming conventions ✅

**Status:** COMPLETED in previous execution

**File Updated:**
- ✅ `docs/00_Introduction_and_Terminology.md`

**What Was Done:**
- Added naming conventions table in Section 7.20

**New Addition Needed:**
- Add NS-AI-FUTURE note about monitoring/AI probes relying on consistent naming

---

### 1.6 Add "Related Modules" cross-reference ✅

**Status:** COMPLETED in previous execution

**Files Updated:**
- ✅ All modules now have "Related Modules" sections

**What Was Done:**
- Added standard cross-reference blocks to all modules

**No additional changes needed.**

---

### 1.7 Standardize queue depth thresholds ✅

**Status:** COMPLETED in previous execution

**Files Updated:**
- ✅ `docs/08_Monitoring_API_and_Packet_Health_Manual.md`
- ✅ `docs/13_Performance_and_Monitoring_Manual.md`

**What Was Done:**
- Standardized to: 0–5 Normal, 6–20 Warning, 21–100 Critical, >100 Overload

**New Addition Needed:**
- Add note about AI/ops using queue metrics for auto-scaling

---

## PART 2 – AI-Readiness Guardrails (NEW - Documentation Only)

### 2.1 Stable entity IDs and semantics

**Files to Update:**
- `docs/02_System_Architecture_and_DataFlow.md`
- `docs/03_Environment_and_PostgreSQL_Storage_Manual.md`

**Changes:**

**In Module 2 (Architecture):**
Add after Component 5 (PostgreSQL + TimescaleDB) section:

> **NOTE (NS-AI-READY):**  
> `customer_id`, `project_id`, `site_id`, and `device_id` are treated as stable, never-repurposed identifiers.  
> All future NSWare AI and feature engineering will key off these IDs for entity tracking.

**In Module 3 (Database):**
Add in Section 6 (Database Structure) or after table list:

> **NOTE (NS-AI-READY):**  
> The `devices` and `sites` tables form the stable entity backbone for NSReady and NSWare.  
> Future feature stores and AI scoring services will join on these keys without changing this schema.

**Purpose:** Document that entity IDs are stable for future AI/ML work.

---

### 2.2 Raw vs features separation

**Files to Update:**
- `docs/03_Environment_and_PostgreSQL_Storage_Manual.md`
- `docs/07_Data_Ingestion_and_Testing_Manual.md`

**Changes:**

**In Module 3:**
Add in Section 6 (Database Structure) after `ingest_events` table description:

> **NOTE (NS-AI-RAW-DATA):**  
> `ingest_events` is treated as raw, append-only time-series telemetry.  
> Any future AI/ML features (aggregations, windowed stats) will be stored in separate tables  
> such as `feature_store_*` and will NOT change the structure or semantics of `ingest_events`.

**In Module 7:**
Add after Section 2 (NormalizedEvent JSON Structure):

> **NOTE (NS-AI-FEATURES-FUTURE):**  
> For now, we validate ingestion and SCADA directly from `ingest_events` and SCADA views.  
> In future NSWare AI modules, additional feature tables may be built from `ingest_events`  
> without altering this ingestion contract.

**Purpose:** Clarify that raw data stays raw, features are separate.

---

### 2.3 Traceability via trace_id

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

**Purpose:** Document trace_id for future AI debugging and experiment tracking.

---

## PART 3 – Data Contracts Minimal Adoption (NEW - YAML Files)

### 3.1 Create contracts folder and initial YAMLs

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

**Purpose:** Document semantics, units, keys, and change process for future AI/data validation.

---

### 3.2 Reference contracts in docs

**File to Update:**
- `docs/03_Environment_and_PostgreSQL_Storage_Manual.md`

**Change:**

Add new subsection in Section 6 (Database Structure):

### 6.4 Data Contracts for Core Tables (NS-DATA-CONTRACTS)

For key NSReady tables (`ingest_events`, `devices`, `parameter_templates`, `v_scada_latest`, `v_scada_history`),  
we maintain lightweight data contracts under `/contracts/nsready/*.yaml`.

> **NOTE (NS-AI & DATA-GOVERNANCE):**  
> These contracts define schema, units, allowed ranges, timezones, and change process.  
> They are the reference point for both SCADA consumers and future NSWare AI modules.  
> Any change to the meaning or unit of a column in these tables must be reflected in the contract first.

**Purpose:** Make contracts discoverable and part of documentation workflow.

---

## PART 4 – Time-Series Modeling & Storage Guardrails (NEW - Documentation Only)

### 4.1 Adopt "narrow + hybrid" model conceptually

**Files to Update:**
- `docs/03_Environment_and_PostgreSQL_Storage_Manual.md`
- `docs/13_Performance_and_Monitoring_Manual.md`

**Changes:**

**In Module 3:**
Add in Section 6 (Database Structure) after `ingest_events` description:

> **NOTE (NS-TS-FUTURE):**  
> We intentionally keep `ingest_events` narrow and append-only for write performance and retention.  
> Any "wide-style" read optimizations will be implemented as materialized views or continuous aggregates  
> on top of `ingest_events`, NOT by changing its schema.

**In Module 13:**
Add in Section 8 (Worker Performance Tuning) or new subsection:

### 8.4 Time-Series Storage Model (NS-TS-DESIGN)

NSReady uses `ingest_events` as the canonical narrow ingest table.  
For dashboards and SCADA-heavy reads, we will model hybrid views:

- Continuous aggregates and/or materialized views per:
  - Site
  - Project
  - Metric family (e.g., all flow metrics)

> **NOTE (NS-TS-FUTURE):**  
> Dashboards and AI services should be wired to call these rollup views where possible,  
> and NOT hit the raw `ingest_events` table directly for large time ranges.

**Purpose:** Document that we keep narrow table, add rollups later.

---

### 4.2 Clarify rollup / continuous aggregate strategy

**File to Update:**
- `docs/13_Performance_and_Monitoring_Manual.md`

**Change:**

Add new subsection in Module 13:

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

**Purpose:** Document intended rollup strategy without implementing now.

---

### 4.3 Tag and series strategy (columns vs JSONB)

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

**Purpose:** Document structured vs JSONB approach for future-proof tagging.

---

### 4.4 Dashboard query guardrail

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

**Purpose:** Prevent dashboards from hammering raw table.

---

## Summary of Changes

### Already Completed ✅
- All PART 1 critical fixes (parameter_key, monitoring, naming, cross-refs, queue thresholds)

### New Additions Needed 📝
- **PART 2:** AI-readiness guardrails (3 subsections, ~6 note additions)
- **PART 3:** Data contracts (4 YAML files + 1 doc reference)
- **PART 4:** Time-series guardrails (4 subsections, ~6 note additions)

### Total Impact
- **Documentation files to modify:** ~10 files
- **New files to create:** 4 YAML contract files
- **New folder:** `contracts/nsready/`
- **All changes are documentation-only** - no code changes

---

## Verification Checklist

Before execution, verify:
- [ ] All PART 1 items are already completed (can skip those)
- [ ] PART 2 notes align with current architecture
- [ ] PART 3 YAML contracts match actual schema
- [ ] PART 4 time-series notes don't conflict with current design
- [ ] All note formats use consistent NS-AI-* or NS-TS-* prefixes

---

**Status:** Ready for review and confirmation before execution.

