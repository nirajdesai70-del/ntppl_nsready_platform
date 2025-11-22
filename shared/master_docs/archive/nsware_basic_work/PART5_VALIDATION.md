# Part 5 Validation: KPI & Alert Model

**Date:** 2025-01-XX  
**Document:** NSWARE_DASHBOARD_MASTER.md - Part 5  
**Status:** ✅ Validated with Alignment Notes

---

## Validation Summary

Part 5 (KPI & Alert Model) has been validated against:
- NSREADY_BACKEND_MASTER.md
- Database schema (migrations)
- Tenant model documentation
- Parameter template structure
- Existing codebase

**Result:** ✅ **Part 5 aligns correctly** with backend architecture and platform design principles, with some architectural clarifications noted.

---

## 1. Parameter Templates Connection ✅

**Part 5 Claims:**
- KPIs are backed by `parameter_keys` from NSReady registry
- Format: `project:<project_uuid>:<parameter_name>`
- Source includes `parameter_keys` array

**Backend Validation:**
- ✅ `parameter_templates` table exists with `key` column (UNIQUE)
- ✅ `ingest_events.parameter_key` REFERENCES `parameter_templates(key)` (FK constraint)
- ✅ Backend Master Section 4.4 confirms canonical format: `project:<project_uuid>:<parameter_name>`
- ✅ Backend Master Section 7.3 confirms parameter_key format is mandatory

**Alignment:** ✅ Perfect match

---

## 2. Tenant Isolation (customer_id) ✅

**Part 5 Claims:**
- KPI `scope` always includes `customer_id` (tenant boundary)
- Alerts include `scope.customer_id`
- Per-customer KPI profiles supported

**Backend Validation:**
- ✅ Backend Master Section 3.1: `tenant_id = customer_id` (NSReady v1)
- ✅ Backend Master Section 9.1: Customer = Tenant boundary
- ✅ Tenant Model Summary confirms: `tenant_id = customer_id`
- ✅ Database schema: `projects.customer_id` → `customers.id` (FK chain)

**Alignment:** ✅ Perfect match

**Note:** Part 5 correctly assumes tenant isolation at customer level, which aligns with backend architecture.

---

## 3. Data Sources (ingest_events, Rollups) ✅

**Part 5 Claims:**
- KPIs computed from:
  - `parameter_keys` from parameter_templates
  - Rollups (1m/5m/hourly)
  - Registry context (device/site/project/customer)

**Backend Validation:**
- ✅ `ingest_events` table exists (hypertable on `time`)
- ✅ `measurements` table exists (aggregated data with `agg_interval`: '1m', '5m', '1h')
- ✅ Backend Master Section 7.9 mentions continuous aggregates (1-minute, 5-minute, hourly)
- ✅ SCADA views (`v_scada_latest`, `v_scada_history`) read from `ingest_events`

**Alignment:** ✅ Perfect match

**Note:** Backend has the foundation. NSWare KPI engine will compute KPIs from these sources.

---

## 4. Registry Hierarchy (Scope Fields) ✅

**Part 5 Claims:**
- KPI scope includes: `customer_id`, `project_id`, `site_id`, `device_id`

**Backend Validation:**
- ✅ Database schema has full hierarchy:
  - `customers.id`
  - `projects.id` → `projects.customer_id`
  - `sites.id` → `sites.project_id`
  - `devices.id` → `devices.site_id`
  - `ingest_events.device_id` → `devices.id`
- ✅ Backend Master Section 4.2 confirms strict hierarchy: Customer → Project → Site → Device

**Alignment:** ✅ Perfect match

**Note:** Scope fields can be resolved via FK joins from `device_id` upward.

---

## 5. KPI/Alert Storage (Future Tables) ⚠️

**Part 5 Claims:**
- Backend maintains per-customer KPI profiles
- KPI dictionary (`kpi_key` → formula)
- Alert definitions and lifecycle

**Backend Validation:**
- ⚠️ **No existing tables** for:
  - KPI definitions/profiles
  - Alert definitions
  - Alert lifecycle (acknowledged/resolved)
  - KPI limits/thresholds storage

**Alignment:** ⚠️ **Expected Gap - Future Implementation**

**Justification:**
- Part 5 defines the **contract** for NSWare (future layer)
- NSReady v1 is data collection only (no KPI/alert engine)
- These tables will be added when NSWare KPI engine is implemented
- Part 5 correctly states: "Backend maintains per-customer KPI profile" (future)

**Recommendation:** ✅ This is correct. Part 5 is documenting the target architecture, not current implementation.

---

## 6. Alert vs System Health Alerts (Separation) ✅

**Part 5 Claims:**
- Process-facing alerts (flow, pressure, energy, uptime, efficiency)
- NOT system-health alerts (ingest/queue health)

**Backend Validation:**
- ✅ Backend Master Section 6.8 defines system-health alerts:
  - Queue depth alerts
  - DB disconnects
  - Worker crashes
- ✅ Prometheus alerts (deploy/monitoring) are system-health alerts
- ✅ Part 5 explicitly states: "Process-facing, not system-health-facing"

**Alignment:** ✅ Correct separation

**Note:** Part 5 correctly focuses on process KPIs/alerts, which is different from operational monitoring alerts.

---

## 7. KPI Object Structure (AI Readiness) ✅

**Part 5 Claims:**
- KPI object includes `ai` block: `{ enabled, risk, confidence, top_factors }`
- Alert object includes `ai` block: `{ enabled, root_cause, suggested_action }`

**Backend Validation:**
- ✅ Backend Master Section 7.7 defines "Feature Tables (AI/ML Future)"
- ✅ Backend Master Section 5.9 mentions "AI/ML Compatibility Rules (Future-Proofing)"
- ✅ Part 5 states: "AI-upgradeable without rework"

**Alignment:** ✅ Future-proofing aligns with backend AI-readiness

**Note:** Part 5 correctly includes AI hooks in the contract, even though AI is not implemented yet.

---

## 8. Alert Lifecycle (States) ⚠️

**Part 5 Claims:**
- Alert states: `active`, `acknowledged`, `resolved`, `suppressed` (optional future)
- Operator can acknowledge via API: `PATCH /alerts/:alert_id { "state": "acknowledged" }`

**Backend Validation:**
- ⚠️ **No existing alert lifecycle tables** or API endpoints
- ✅ `error_logs` table exists but is for ingestion errors, not process alerts

**Alignment:** ⚠️ **Expected Gap - Future Implementation**

**Justification:**
- Part 5 is defining NSWare alert lifecycle (future)
- NSReady v1 doesn't have process alert system
- Lifecycle will be implemented when NSWare alert engine is added

**Recommendation:** ✅ This is correct. Part 5 documents the target architecture.

---

## 9. KPI Categories (Industry Agnostic) ✅

**Part 5 Claims:**
- KPI categories: Flow/Throughput, Pressure/Head/Level, Temperature/Quality, Energy/Efficiency, Uptime/Availability, Custom Domain
- Industry-agnostic design

**Backend Validation:**
- ✅ Backend Master does not prescribe specific KPI types
- ✅ Parameter templates are generic (name, unit, metadata)
- ✅ No industry-specific constraints in backend

**Alignment:** ✅ Generic design aligns with backend flexibility

**Note:** Backend provides the data foundation; NSWare KPI engine adds meaning.

---

## 10. Parameter Key Format in Examples ✅

**Part 5 Examples:**
```json
"parameter_keys": [
  "project:8212caa2-...:flow",
  "project:8212caa2-...:pressure"
]
```

**Backend Validation:**
- ✅ Matches canonical format: `project:<project_uuid>:<parameter_name>`
- ✅ Backend Master Section 4.4 confirms this format
- ✅ Database FK enforces this format via `parameter_templates.key`

**Alignment:** ✅ Perfect match

---

## 11. Summary & Recommendations

### ✅ Validated Alignments

1. **Parameter Templates**: Part 5 correctly references `parameter_templates` and canonical format
2. **Tenant Isolation**: Part 5 correctly uses `customer_id` as tenant boundary
3. **Data Sources**: Part 5 correctly identifies `ingest_events` and rollups as data sources
4. **Registry Hierarchy**: Part 5 scope fields match database FK chain
5. **Alert Separation**: Part 5 correctly distinguishes process alerts from system-health alerts
6. **AI Readiness**: Part 5 AI hooks align with backend future-proofing
7. **Industry Agnostic**: Part 5 generic categories align with backend flexibility

### ⚠️ Expected Gaps (Future Implementation)

1. **KPI Definition Tables**: Not yet implemented (NSWare layer)
2. **Alert Definition Tables**: Not yet implemented (NSWare layer)
3. **Alert Lifecycle Storage**: Not yet implemented (NSWare layer)
4. **KPI Profile Storage**: Not yet implemented (NSWare layer)

**These gaps are expected and correct** because:
- Part 5 defines the **contract/architecture** for NSWare (future layer)
- NSReady v1 is data collection only
- These will be implemented when NSWare KPI/Alert engine is built

### 📝 Minor Clarification Needed

**Section 5.9** could add a note:
> "Note: KPI dictionary and KPI profiles will be stored in NSWare layer tables (not yet implemented in NSReady v1). NSReady provides the foundation (`parameter_templates`, `ingest_events`, registry hierarchy) that NSWare KPI engine will use."

---

## 12. Cross-Reference Validation

**Part 5 References:**
- ✅ Part 3 (Universal Tile System) - KPI tiles align
- ✅ Part 4 (Dashboard JSON) - KPI objects fit dashboard structure
- ✅ Part 2 (Navigation) - Tenant context aligns

**Backend Master References:**
- ✅ Section 4 (Parameter Templates) - Matches Part 5 source.parameter_keys
- ✅ Section 7 (Database Architecture) - Matches Part 5 data sources
- ✅ Section 9 (Tenant Model) - Matches Part 5 scope.customer_id

---

## Final Verdict

✅ **Part 5 is architecturally sound and aligns with backend design.**

The only gaps are **expected future implementations** (KPI/Alert engine, storage tables), which Part 5 correctly documents as NSWare layer components.

**Recommendation:** ✅ **Approve Part 5** with optional minor clarification note in Section 5.9 about future implementation.

---

**Validation Completed:** 2025-01-XX  
**Validated By:** Platform Validation Process  
**Next Steps:** Proceed with Part 6 (Tenant Isolation Rules - UI/UX perspective)

