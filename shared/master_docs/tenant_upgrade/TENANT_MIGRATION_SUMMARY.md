# Tenant Model & Customer Hierarchy - Implementation Summary

**Date:** 2025-01-XX  
**Status:** ✅ Complete

---

## What Was Done

### 1. Database Migration ✅

**File:** `db/migrations/150_customer_hierarchy.sql`

- Added `parent_customer_id` column to `customers` table
- Enables hierarchical organizations (e.g., Allidhra Group → Allidhra Textool, Allidhra Texpin)
- Backward compatible (existing customers have `parent_customer_id = NULL`)

**Model (NSReady v1):**
- **Tenant** = Each individual customer (`tenant_id = customer_id` for each company)
- **Parent/OEM** = Customer where `parent_customer_id IS NULL` (e.g., Allidhra Group) - used for grouping/reporting only
- **Child Customer** = Customer where `parent_customer_id IS NOT NULL` (e.g., Allidhra Textool)

---

### 2. Documentation Updates ✅

#### Module 0 - Introduction and Terminology
- Added **Section 7.1 Tenant Model (NS-TENANT-CUSTOMER RULE)**
- Explains: `tenant_id = customer_id`
- Documents hierarchical organizations (Allidhra Group example)

#### Module 2 - System Architecture
- Added **NOTE (NS-TENANT-BOUNDARY)** after Component 1
- Explains tenant boundary for multi-customer dashboards, SCADA, AI/ML

#### Module 3 - Environment and PostgreSQL Storage
- Added **NOTE (NS-TENANT-STORAGE-MODEL)** after entity backbone notes
- Documents `customer_id` as physical tenant key

#### Module 7 - Data Ingestion and Testing
- Added **NOTE (NS-TENANT-INGESTION)** after NormalizedEvent example
- Explains tenant resolution from `project_id → site_id → device_id`

#### Module 9 - SCADA Integration
- Added **NOTE (NS-TENANT-SCADA-BOUNDARY)** at start of Option 1
- Added **NOTE (TENANT ISOLATION – NS-TENANT-02)** in SCADA views section
- Added **Section 5: SCADA Profiles per Customer (NS-MULTI-SCADA-FUTURE)**
- Includes Allidhra Group example

#### Module 12 - API Developer Manual
- Added **NOTE (NS-TENANT-API-BOUNDARY)** before Core API Endpoints
- Documents tenant boundary for all APIs

#### Module 13 - Performance and Monitoring
- Added **Section 15.2: Tenant Context for AI/Monitoring (NS-TENANT-03)**
- Documents tenant-aware AI feature stores and monitoring

#### Collector Service README
- Added **Section: Tenant Identity (NS-TENANT-ID)**
- Explains automatic tenant resolution

---

### 3. Data Contracts ✅

**Files Updated:**
- `contracts/nsready/ingest_events.yaml`
- `contracts/nsready/parameter_templates.yaml`
- `contracts/nsready/v_scada_latest.yaml`
- `contracts/nsready/v_scada_history.yaml`

**Added:**
```yaml
tenant_model:
  rule: "tenant_id = customer_id"
  rationale: "Ensures clean cross-customer isolation and future multi-tenant NSWare compatibility."
  enforcement: "Tenant is derived automatically from project/site/device ownership."
```

---

### 4. Test Files ✅

**Files Updated:**
- `tests/regression/test_api_endpoints.py`
- `tests/performance/locustfile.py`
- `tests/resilience/test_recovery.py`
- `tests/regression/test_ingestion_flow.py`

**Added Comment:**
```python
# NOTE (NS-TENANT-MODEL):
# In NSReady/NSWare v1, tenant_id = customer_id.
# Tests use documentation UUIDs to maintain consistent tenant routing for API, SCADA, and AI.
```

---

## Key Concepts

### Tenant Model Rule
```
tenant_id = customer_id
```

### Hierarchical Organizations (NSReady v1)
- **Parent (OEM/Group):** `parent_customer_id IS NULL` (e.g., Allidhra Group) - used for grouping/reporting
- **Child (Customer/Tenant):** `parent_customer_id = parent UUID` (e.g., Allidhra Textool) - each child is a tenant
- **Note:** In v1, tenant isolation is at company level (`tenant_id = customer_id`), not at parent level

### Benefits
1. ✅ Clean multi-customer separation
2. ✅ No schema changes required in future
3. ✅ SCADA, exports, AI pipelines route data consistently
4. ✅ Per-tenant access control becomes trivial
5. ✅ Supports group reports (all children) and individual reports (single customer)

---

## Allidhra Group Example

### Structure:
```
Allidhra Group (parent/OEM, parent_customer_id = NULL) - for grouping only
├── Allidhra Textool (tenant/customer, parent_customer_id = Allidhra Group UUID)
├── Allidhra Texpin (tenant/customer, parent_customer_id = Allidhra Group UUID)
└── ... (4 more companies)
```

**Note:** In v1, each company (Textool, Texpin) is a tenant (`tenant_id = customer_id`), not the parent.

### Reports:
- **Group Report:** Filter by `parent_customer_id = Allidhra Group UUID` OR `id = Allidhra Group UUID`
- **Individual Report:** Filter by `customer_id = Allidhra Textool UUID` (this is the tenant boundary in v1)

---

## Files Modified

### Database
- ✅ `db/migrations/150_customer_hierarchy.sql` (NEW)

### Documentation
- ✅ `docs/00_Introduction_and_Terminology.md`
- ✅ `docs/02_System_Architecture_and_DataFlow.md`
- ✅ `docs/03_Environment_and_PostgreSQL_Storage_Manual.md`
- ✅ `docs/07_Data_Ingestion_and_Testing_Manual.md`
- ✅ `docs/09_SCADA_Integration_Manual.md`
- ✅ `docs/12_API_Developer_Manual.md`
- ✅ `docs/13_Performance_and_Monitoring_Manual.md`

### Code/Examples
- ✅ `collector_service/README.md`

### Data Contracts
- ✅ `contracts/nsready/ingest_events.yaml`
- ✅ `contracts/nsready/parameter_templates.yaml`
- ✅ `contracts/nsready/v_scada_latest.yaml`
- ✅ `contracts/nsready/v_scada_history.yaml`

### Tests
- ✅ `tests/regression/test_api_endpoints.py`
- ✅ `tests/performance/locustfile.py`
- ✅ `tests/resilience/test_recovery.py`
- ✅ `tests/regression/test_ingestion_flow.py`

---

## Next Steps

1. **Run Migration:**
   ```bash
   kubectl exec -n nsready-tier2 nsready-db-0 -- \
     psql -U postgres -d nsready -f /path/to/150_customer_hierarchy.sql
   ```

2. **Test Hierarchical Structure:**
   - Create Allidhra Group (parent)
   - Create Allidhra Textool (child)
   - Verify group reports work
   - Verify individual reports work

3. **Update Admin Tool (if needed):**
   - Add UI for `parent_customer_id` selection
   - Update customer creation forms

---

## Verification

To verify all tenant notes are in place:

```bash
grep -r "NS-TENANT" docs/ contracts/ collector_service/ tests/ --exclude-dir=.git
```

Expected: Multiple matches across all modules and contracts.

---

**Status:** ✅ All changes complete and ready for testing.

