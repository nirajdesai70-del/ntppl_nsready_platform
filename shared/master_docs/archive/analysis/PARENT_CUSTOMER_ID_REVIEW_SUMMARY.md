# Parent Customer ID - Documentation Review & Updates Summary

**Date:** 2025-01-XX  
**Status:** ✅ Complete

---

## Issue Identified

After adding `parent_customer_id` for hierarchical organizations (Allidhra Group scenario), we needed to ensure all documentation correctly reflects the **NSReady v1 decision**:

- **Tenant isolation** = Company level (`tenant_id = customer_id` for each company)
- **Parent/OEM** = Used for grouping/reporting only, NOT as tenant boundary

Several documents had incorrect or ambiguous statements suggesting parent = tenant.

---

## Files Updated

### 1. ✅ Module 0 - Introduction and Terminology
**File:** `docs/00_Introduction_and_Terminology.md`

**Issue:** Line 201-202 said "parent organization acts as the **tenant**"

**Fixed:** Clarified that:
- Tenant isolation is at company level (`tenant_id = customer_id` for each company)
- Parent is used for grouping/reporting only, not as tenant boundary

---

### 2. ✅ TENANT_MIGRATION_SUMMARY.md
**File:** `docs/TENANT_MIGRATION_SUMMARY.md`

**Issues:**
- Line 19-20: Said "Tenant = Customer where parent_customer_id IS NULL"
- Line 106-107: Said "Parent (Tenant)"
- Structure diagram showed parent as "tenant"

**Fixed:**
- Clarified v1 model: Tenant = each individual customer, Parent = grouping only
- Updated structure diagram to show parent as "parent/OEM" and children as "tenant/customer"
- Added notes explaining v1 decision

---

### 3. ✅ Migration File Comments
**File:** `db/migrations/150_customer_hierarchy.sql`

**Issue:** Comments said "parent/tenant" and suggested tenant = parent

**Fixed:**
- Updated comments to clarify parent is for grouping/reporting
- Added explicit note: "Tenant isolation is at company level in v1"
- Updated column comment to explain v1 tenant model

---

### 4. ✅ Database README
**File:** `db/README.md`

**Issue:** Table list didn't mention `parent_customer_id`

**Fixed:** Added `parent_customer_id` to customers table description with reference to migration 150

---

### 5. ✅ Module 3 - Environment and PostgreSQL Storage
**File:** `docs/03_Environment_and_PostgreSQL_Storage_Manual.md`

**Issue:** Table list didn't mention `parent_customer_id`

**Fixed:** Added note that customers table includes `parent_customer_id` column (see migration 150)

---

### 6. ✅ Module 5 - Configuration Import
**File:** `docs/05_Configuration_Import_Manual.md`

**Status:** ✅ No changes needed
- CSV import doesn't currently support `parent_customer_id` (future enhancement)
- Current CSV format is sufficient for v1
- Parent relationships can be set via admin tool or direct DB if needed

---

## Key Clarifications Made

### NSReady v1 Tenant Model (Consistent Across All Docs):

```
tenant_id = customer_id    (each individual company)
```

### Hierarchical Organizations:

```
Parent (OEM/Group):
  - parent_customer_id IS NULL
  - Used for grouping/reporting only
  - NOT the tenant boundary

Child (Company/Tenant):
  - parent_customer_id = parent UUID
  - Each child is a tenant (tenant_id = customer_id)
  - Tenant isolation at company level
```

---

## Verification

All documentation now consistently states:

1. ✅ Tenant isolation is at company level (`tenant_id = customer_id`)
2. ✅ `parent_customer_id` is for grouping/reporting only
3. ✅ Parent is NOT the tenant boundary in v1
4. ✅ Future flexibility exists (can promote parent to tenant if needed)

---

## Files That Were Already Correct

- ✅ Module 2 - System Architecture (tenant boundary note already correct)
- ✅ Module 7 - Data Ingestion (tenant ingestion note already correct)
- ✅ Module 9 - SCADA Integration (tenant boundary notes already correct)
- ✅ Module 12 - API Developer Manual (tenant API boundary note already correct)
- ✅ Module 13 - Performance and Monitoring (tenant context note already correct)
- ✅ ALLIDHRA_GROUP_MODEL_ANALYSIS.md (already updated in previous session)

---

## Summary

**Total Files Updated:** 5  
**Files Verified Correct:** 6  
**Status:** ✅ All documentation now consistent with NSReady v1 tenant model

The system is now fully documented with:
- Clear tenant isolation at company level
- Parent/OEM for grouping/reporting only
- Future flexibility preserved
- No conflicting statements


