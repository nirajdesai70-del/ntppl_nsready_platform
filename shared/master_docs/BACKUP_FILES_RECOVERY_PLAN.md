# Backup Files Recovery Plan

**Date:** 2025-11-22  
**Source:** Commit `7eb2afc` (Backup before test_backup_script)  
**Total Missing Files:** ~250 files

---

## Summary

Found **250 files** in backup that are not in current structure. These need to be reviewed and placed in appropriate locations.

---

## File Categories

### 1. 🔴 CRITICAL - Must Recover (Active Files)

#### Code Files (Already in new structure, but need to verify)
- `admin_tool/*.py` - Already moved to `nsready_backend/admin_tool/`
- `collector_service/*.py` - Already moved to `nsready_backend/collector_service/`
- `db/*.sql` - Already moved to `nsready_backend/db/`

**Action:** Verify these exist in new structure, recover if missing.

#### Database Migrations
- `db/migrations/150_customer_hierarchy.sql` ⭐ **NEW MIGRATION**
- `db/seed_registry.sql` ⭐ **SEED DATA**

**Action:** Recover to `nsready_backend/db/migrations/` and `nsready_backend/db/`

#### Contracts (YAML)
- `contracts/nsready/ingest_events.yaml`
- `contracts/nsready/parameter_templates.yaml`
- `contracts/nsready/v_scada_history.yaml`
- `contracts/nsready/v_scada_latest.yaml`

**Action:** Recover to `shared/contracts/nsready/`

#### Deployment Configs
- `deploy/k8s/*.yaml` - Kubernetes configs
- `deploy/helm/nsready/*.yaml` - Helm charts
- `deploy/monitoring/*.yaml` - Monitoring configs
- `deploy/traefik/*.yml` - Traefik configs

**Action:** Recover to `shared/deploy/`

#### Test Scripts
- `scripts/test_*.sh` - Multiple test scripts
- `scripts/export_*.sh` - Export scripts
- `scripts/import_*.sh` - Import scripts

**Action:** Recover to `shared/scripts/`

---

### 2. 🟡 IMPORTANT - Documentation to Review

#### Additional Documentation Modules
- `docs/07_Data_Ingestion_and_Testing_Manual.md` - Different from Module 07 we have
- `docs/08_Monitoring_API_and_Packet_Health_Manual.md` - New module
- `docs/09_SCADA_Integration_Manual.md` - Different from Module 09 we have
- `docs/10_Scripts_and_Tools_Reference_Manual.md` - New module
- `docs/11_Troubleshooting_and_Diagnostics_Manual.md` - New module
- `docs/13_Performance_and_Monitoring_Manual.md` - Different from Module 13 we have

**Action:** Review and decide if these replace or supplement existing modules.

#### Master Documentation
- `master_docs/NSREADY_BACKEND_MASTER.md`
- `master_docs/NSWARE_DASHBOARD_MASTER.md`
- `master_docs/NSREADY_PLATFORM_VALIDATION.md`
- `master_docs/SECURITY_FAQ.md`
- `master_docs/SECURITY_POSITION_NSREADY.md`
- `master_docs/SECURITY_TEST_MAPPING_ISO_IEC.md`
- Many implementation summaries and reviews

**Action:** Review and organize in `shared/master_docs/` or archive.

---

### 3. 🟢 ARCHIVE - Historical/Process Documents

#### Root-Level Process Documents
- `CHECKPOINT_NEXT_STEPS.md`
- `DEPLOYMENT_GUIDE.md`
- `PERFORMANCE_OPTIMIZATIONS.md`
- `POST_FIX_VALIDATION.md`
- `PRODUCTION_HARDENING.md`
- `README_RESTRUCTURE_DIFF.md`
- `README_UPDATE_CHECKLIST.md`
- `RUNBOOK_Restore.md`
- `TEST_BACKUP_FILE.md`

**Action:** Archive to `shared/master_docs/archive/process_docs/`

#### Historical Documentation
- `docs/CODE_CHANGES_REQUIRED.md`
- `docs/DOCUMENTATION_FIXES_TODO.md`
- `docs/DOCUMENTATION_TRACKING.md`
- `docs/EXECUTION_CHECKLIST.md`
- `docs/EXECUTION_PLAN_SUMMARY_NSWARE.md`
- `docs/FINAL_EXECUTION_PLAN_NSWARE.md`
- `docs/IMPACT_ANALYSIS_NSWARE.md`
- `docs/PROPOSED_CHANGES_REVIEW.md`
- `docs/PROPOSED_CODE_CHANGES_NSWARE.md`
- `docs/PROPOSED_DOCUMENTATION_CHANGES_NSWARE.md`

**Action:** Archive to `shared/master_docs/archive/process_docs/`

---

## Recovery Plan by Category

### Category 1: Code & Database Files

**Priority:** 🔴 HIGH

```bash
# Database migrations
git show 7eb2afc:db/migrations/150_customer_hierarchy.sql > nsready_backend/db/migrations/150_customer_hierarchy.sql
git show 7eb2afc:db/seed_registry.sql > nsready_backend/db/seed_registry.sql

# Verify code files exist in new structure
# (Most should already be there, but verify)
```

### Category 2: Contracts (YAML)

**Priority:** 🔴 HIGH

```bash
# Recover contracts
mkdir -p shared/contracts/nsready
git show 7eb2afc:contracts/nsready/ingest_events.yaml > shared/contracts/nsready/ingest_events.yaml
git show 7eb2afc:contracts/nsready/parameter_templates.yaml > shared/contracts/nsready/parameter_templates.yaml
git show 7eb2afc:contracts/nsready/v_scada_history.yaml > shared/contracts/nsready/v_scada_history.yaml
git show 7eb2afc:contracts/nsready/v_scada_latest.yaml > shared/contracts/nsready/v_scada_latest.yaml
```

### Category 3: Deployment Configs

**Priority:** 🔴 HIGH

```bash
# Recover all deployment configs
git checkout 7eb2afc -- deploy/
# Then move to shared/deploy/
mv deploy/* shared/deploy/ 2>/dev/null
```

### Category 4: Scripts

**Priority:** 🔴 HIGH

```bash
# Recover scripts
git checkout 7eb2afc -- scripts/
# Then move to shared/scripts/
mv scripts/*.sh shared/scripts/ 2>/dev/null
mv scripts/*.sql shared/scripts/ 2>/dev/null
mv scripts/*.md shared/scripts/ 2>/dev/null
```

### Category 5: Test Reports

**Priority:** 🟡 MEDIUM

```bash
# Recover test reports
git checkout 7eb2afc -- tests/reports/
# Then move to nsready_backend/tests/reports/
mv tests/reports/*.md nsready_backend/tests/reports/ 2>/dev/null
```

### Category 6: Additional Documentation

**Priority:** 🟡 MEDIUM (Review First)

```bash
# Recover additional docs for review
git checkout 7eb2afc -- docs/07_Data_Ingestion_and_Testing_Manual.md
git checkout 7eb2afc -- docs/08_Monitoring_API_and_Packet_Health_Manual.md
git checkout 7eb2afc -- docs/09_SCADA_Integration_Manual.md
git checkout 7eb2afc -- docs/10_Scripts_and_Tools_Reference_Manual.md
git checkout 7eb2afc -- docs/11_Troubleshooting_and_Diagnostics_Manual.md
git checkout 7eb2afc -- docs/13_Performance_and_Monitoring_Manual.md

# Review and decide placement
```

### Category 7: Master Documentation

**Priority:** 🟡 MEDIUM (Review First)

```bash
# Recover master docs for review
git checkout 7eb2afc -- master_docs/NSREADY_BACKEND_MASTER.md
git checkout 7eb2afc -- master_docs/NSWARE_DASHBOARD_MASTER.md
git checkout 7eb2afc -- master_docs/SECURITY_FAQ.md
# ... etc

# Review and organize
```

### Category 8: Archive Historical Documents

**Priority:** 🟢 LOW

```bash
# Create archive structure
mkdir -p shared/master_docs/archive/process_docs

# Recover and archive process documents
git checkout 7eb2afc -- CHECKPOINT_NEXT_STEPS.md
git checkout 7eb2afc -- DEPLOYMENT_GUIDE.md
# ... etc

# Move to archive
mv CHECKPOINT_NEXT_STEPS.md shared/master_docs/archive/process_docs/
# ... etc
```

---

## Detailed File List

### Critical Files (Must Recover)

1. **Database:**
   - `db/migrations/150_customer_hierarchy.sql` - Tenant migration
   - `db/seed_registry.sql` - Seed data

2. **Contracts:**
   - `contracts/nsready/*.yaml` (4 files)

3. **Deployment:**
   - `deploy/k8s/*.yaml` (~20 files)
   - `deploy/helm/nsready/*.yaml` (~10 files)
   - `deploy/monitoring/*.yaml` (~5 files)
   - `deploy/traefik/*.yml` (1 file)

4. **Scripts:**
   - `scripts/*.sh` (~15 files)
   - `scripts/*.md` (~7 files)
   - `scripts/*.sql` (1 file)

5. **Test Files:**
   - `tests/reports/*.md` (~20 files)
   - `tests/*.py` (~5 files)

### Documentation to Review

1. **Additional Modules:**
   - `docs/07_Data_Ingestion_and_Testing_Manual.md`
   - `docs/08_Monitoring_API_and_Packet_Health_Manual.md`
   - `docs/09_SCADA_Integration_Manual.md`
   - `docs/10_Scripts_and_Tools_Reference_Manual.md`
   - `docs/11_Troubleshooting_and_Diagnostics_Manual.md`
   - `docs/13_Performance_and_Monitoring_Manual.md`

2. **Master Docs:**
   - `master_docs/NSREADY_BACKEND_MASTER.md`
   - `master_docs/NSWARE_DASHBOARD_MASTER.md`
   - `master_docs/SECURITY_FAQ.md`
   - `master_docs/SECURITY_POSITION_NSREADY.md`
   - `master_docs/SECURITY_TEST_MAPPING_ISO_IEC.md`
   - Many implementation summaries

### Archive Documents

1. **Process Documents:**
   - Root-level checklists and guides
   - Execution plans and summaries
   - Review documents

---

## Execution Order

1. **Phase 1:** Recover critical files (database, contracts, deployment, scripts)
2. **Phase 2:** Recover test files and reports
3. **Phase 3:** Review and recover additional documentation
4. **Phase 4:** Archive historical/process documents
5. **Phase 5:** Verify all files are in correct locations

---

**Status:** Ready for Execution  
**Estimated Time:** ~30 minutes


