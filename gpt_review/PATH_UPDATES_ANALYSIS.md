# Path Updates Analysis - Repository Reorganization Alignment

**Date:** 2025-01-XX  
**Purpose:** Comprehensive analysis of outdated path references in test scripts and documentation

---

## Executive Summary

**Total Files to Update:** ~20 files  
**Critical Updates:** All test scripts + TEST_SCRIPTS_README.md  
**Documentation Updates:** All guide files in `shared/scripts/`

---

## Canonical Path Changes

### ✅ Target Structure (Post-Reorg)

```
ntppl_nsready_platform/
├── nsready_backend/
│   ├── admin_tool/
│   ├── collector_service/
│   ├── db/
│   │   └── seed_registry.sql          # ✅ NEW PATH
│   └── tests/
│       └── reports/                    # ✅ NEW PATH
│
├── shared/
│   └── scripts/                        # ✅ NEW PATH
│       ├── test_*.sh
│       ├── export_*.sh
│       ├── import_*.sh
│       └── TEST_SCRIPTS_README.md
│
└── docker-compose.yml                  # Root level
```

### ❌ Old Paths → ✅ New Paths

| Old Path | New Path |
|----------|----------|
| `./scripts/test_data_flow.sh` | `./shared/scripts/test_data_flow.sh` |
| `scripts/export_scada_data.sh` | `shared/scripts/export_scada_data.sh` |
| `tests/reports/` | `nsready_backend/tests/reports/` |
| `db/seed_registry.sql` | `nsready_backend/db/seed_registry.sql` |
| `scripts/registry_template.csv` | `shared/scripts/registry_template.csv` |
| `scripts/example_parameters.csv` | `shared/scripts/example_parameters.csv` |

---

## Files Requiring Updates

### 🔴 Critical Priority (Test Scripts)

#### 1. Test Shell Scripts (`.sh` files)

**Files:**
- `shared/scripts/test_data_flow.sh` - Line 26: `REPORT_DIR="tests/reports"` → `nsready_backend/tests/reports`
- `shared/scripts/test_data_flow.sh` - Line 342: `scripts/export_scada_data.sh` → `shared/scripts/export_scada_data.sh`
- `shared/scripts/test_batch_ingestion.sh` - Line 27: `REPORT_DIR="tests/reports"` → `nsready_backend/tests/reports`
- `shared/scripts/test_stress_load.sh` - Line 27: `REPORT_DIR="tests/reports"` → `nsready_backend/tests/reports`
- `shared/scripts/test_multi_customer_flow.sh` - Line 26: `REPORT_DIR="tests/reports"` → `nsready_backend/tests/reports`
- `shared/scripts/test_negative_cases.sh` - Line 26: `REPORT_DIR="tests/reports"` → `nsready_backend/tests/reports`
- `shared/scripts/test_roles_access.sh` - Line 21: `REPORT_DIR="tests/reports"` → `nsready_backend/tests/reports`
- `shared/scripts/test_tenant_isolation.sh` - Multiple references to `./scripts/export_registry_data.sh` → `./shared/scripts/export_registry_data.sh`
- `shared/scripts/final_test_drive.sh` - Line 43: `REPORT_DIR="tests/reports"` → `nsready_backend/tests/reports`
- `shared/scripts/test_drive.sh` - Line 43: `REPORT_DIR="tests/reports"` → `nsready_backend/tests/reports`
- `shared/scripts/tenant_testing/test_data_flow.sh` - Line 26: `REPORT_DIR="tests/reports"` → `nsready_backend/tests/reports`
- `shared/scripts/tenant_testing/test_tenant_isolation.sh` - Multiple references to `./scripts/export_registry_data.sh`

**Usage Comments (top of scripts):**
- Multiple scripts have `# Usage: ./scripts/...` → Should be `# Usage: ./shared/scripts/...`

---

#### 2. TEST_SCRIPTS_README.md (🔴 CRITICAL)

**File:** `shared/scripts/TEST_SCRIPTS_README.md`

**Issues Found (31 references to fix):**

1. **Line 13:** `./scripts/test_data_flow.sh` → `./shared/scripts/test_data_flow.sh`
2. **Line 23:** `tests/reports/DATA_FLOW_TEST_*.md` → `nsready_backend/tests/reports/DATA_FLOW_TEST_*.md`
3. **Line 34:** `./scripts/test_batch_ingestion.sh` → `./shared/scripts/test_batch_ingestion.sh`
4. **Line 37:** `./scripts/test_batch_ingestion.sh` → `./shared/scripts/test_batch_ingestion.sh`
5. **Line 40:** `./scripts/test_batch_ingestion.sh` → `./shared/scripts/test_batch_ingestion.sh`
6. **Line 49:** `tests/reports/BATCH_INGESTION_TEST_*.md` → `nsready_backend/tests/reports/...`
7. **Line 60:** `./scripts/test_stress_load.sh` → `./shared/scripts/test_stress_load.sh`
8. **Line 63:** `./scripts/test_stress_load.sh` → `./shared/scripts/test_stress_load.sh`
9. **Line 73:** `tests/reports/STRESS_LOAD_TEST_*.md` → `nsready_backend/tests/reports/...`
10. **Line 84:** `./scripts/test_multi_customer_flow.sh` → `./shared/scripts/test_multi_customer_flow.sh`
11. **Line 87:** `./scripts/test_multi_customer_flow.sh` → `./shared/scripts/test_multi_customer_flow.sh`
12. **Line 96:** `tests/reports/MULTI_CUSTOMER_FLOW_TEST_*.md` → `nsready_backend/tests/reports/...`
13. **Line 106:** `./scripts/test_negative_cases.sh` → `./shared/scripts/test_negative_cases.sh`
14. **Line 120:** `tests/reports/NEGATIVE_TEST_*.md` → `nsready_backend/tests/reports/...`
15. **Line 140:** `db/seed_registry.sql` → `nsready_backend/db/seed_registry.sql` ⚠️ **CRITICAL**
16. **Line 150:** `./scripts/test_data_flow.sh` → `./shared/scripts/test_data_flow.sh`
17. **Line 156:** `./scripts/test_data_flow.sh` → `./shared/scripts/test_data_flow.sh`
18. **Line 159:** `./scripts/test_batch_ingestion.sh` → `./shared/scripts/test_batch_ingestion.sh`
19. **Line 162:** `./scripts/test_stress_load.sh` → `./shared/scripts/test_stress_load.sh`
20. **Line 165:** `./scripts/test_multi_customer_flow.sh` → `./shared/scripts/test_multi_customer_flow.sh`
21. **Line 168:** `./scripts/test_negative_cases.sh` → `./shared/scripts/test_negative_cases.sh`
22. **Line 182:** `./scripts/test_data_flow.sh` → `./shared/scripts/test_data_flow.sh`
23. **Line 192:** `tests/reports/` → `nsready_backend/tests/reports/`
24. **Line 219:** `db/seed_registry.sql` → `nsready_backend/db/seed_registry.sql` ⚠️ **CRITICAL**
25. **Line 220:** `./scripts/test_data_flow.sh` → `./shared/scripts/test_data_flow.sh`
26. **Line 221:** `./scripts/test_negative_cases.sh` → `./shared/scripts/test_negative_cases.sh`
27. **Line 231:** `db/seed_registry.sql` → `nsready_backend/db/seed_registry.sql` ⚠️ **CRITICAL**
28. **Line 242:** `./scripts/test_data_flow.sh` → `./shared/scripts/test_data_flow.sh`
29. **Line 274:** `../master_docs/DATA_FLOW_TESTING_GUIDE.md` → Check if path is correct

---

### 🟡 High Priority (Documentation Guides)

#### 3. CONFIGURATION_IMPORT_USER_GUIDE.md

**File:** `shared/scripts/CONFIGURATION_IMPORT_USER_GUIDE.md`

**Issues Found:**
- Multiple references to `scripts/` → Should be `shared/scripts/` or note that scripts are already in `shared/scripts/`
- Lines 30, 34, 38, 96, 100, 104, 189, 192, 199, 202, 209, 332-351: All `scripts/` references

---

#### 4. ENGINEER_GUIDE_PARAMETER_TEMPLATES.md

**File:** `shared/scripts/ENGINEER_GUIDE_PARAMETER_TEMPLATES.md`

**Issues Found:**
- Multiple references to `./scripts/` → Should be `./shared/scripts/` or relative paths
- Lines 24, 42, 50, 58, 85, 235, 244, 254, 286, 292, 307, 312, 345, 363

---

#### 5. PARAMETER_TEMPLATE_IMPORT_GUIDE.md

**File:** `shared/scripts/PARAMETER_TEMPLATE_IMPORT_GUIDE.md`

**Issues Found:**
- Lines 46, 54, 55, 56, 60, 71, 76: References to `./scripts/` or `scripts/`

---

#### 6. SCADA_INTEGRATION_GUIDE.md

**File:** `shared/scripts/SCADA_INTEGRATION_GUIDE.md`

**Issues Found:**
- Lines 16, 21, 49, 336: References to `./scripts/export_scada_data.sh`

---

#### 7. POSTGRESQL_LOCATION_GUIDE.md

**File:** `shared/scripts/POSTGRESQL_LOCATION_GUIDE.md`

**Issues Found:**
- Lines 241, 253: References to `scripts/backups/` - Check if this path exists

---

#### 8. create_parameter_csv_guide.md

**File:** `shared/scripts/create_parameter_csv_guide.md`

**Issues Found:**
- Lines 29, 49, 161: References to `scripts/`

---

---

## Container Name Verification

### ✅ Container Names (Already Correct)

From `docker-compose.yml`:
- Service: `admin_tool` → Container: `admin_tool` ✅
- Service: `collector_service` → Container: `collector_service` ✅
- Service: `db` → Container: `nsready_db` ✅
- Service: `nats` → Container: `nsready_nats` ✅

**All scripts use `nsready_db` correctly!** ✅

---

## Update Strategy

### Phase 1: Critical Test Scripts (Do First)
1. Fix all `REPORT_DIR` paths in test scripts
2. Fix script path references in test scripts
3. Fix usage comments in test scripts

### Phase 2: TEST_SCRIPTS_README.md (Critical Doc)
1. Update all script path references
2. Update all report directory paths
3. Update database seed file paths

### Phase 3: Documentation Guides (High Priority)
1. Update all script references in guides
2. Clarify that scripts are in `shared/scripts/`
3. Update relative path instructions

---

## Notes

### Relative vs Absolute Paths

**Current directory when running scripts:**
- Scripts are in `shared/scripts/`
- When running from repo root: `./shared/scripts/test_data_flow.sh` ✅
- When running from `shared/scripts/`: `./test_data_flow.sh` (relative)

**Recommendation:**
- Use paths relative to **repo root** for consistency
- Or note in docs: "Run from repository root"

---

## Validation Checklist

After updates:
- [ ] All test scripts use `nsready_backend/tests/reports/` for reports
- [ ] All script references use `shared/scripts/` or `./shared/scripts/`
- [ ] All database seed paths use `nsready_backend/db/seed_registry.sql`
- [ ] TEST_SCRIPTS_README.md matches new structure
- [ ] All guide docs have correct script paths
- [ ] Container names remain `nsready_db` (correct)
- [ ] Test scripts can run successfully from repo root

---

**Status:** ✅ Ready for systematic updates


