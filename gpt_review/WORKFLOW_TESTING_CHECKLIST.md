# Workflow Testing Checklist

**Date:** 2025-01-XX  
**Purpose:** Systematic testing of updated GitHub Actions workflows  
**Order:** 1. Test workflows → 2. Update docs → 3. Extra docs (if needed)

---

## ✅ Pre-Flight Validation (Before Testing)

### Workflow Files Check

- [x] ✅ `backend_tests.yml` - Uses `shared/scripts/` and `nsready_backend/`
- [x] ✅ `build-test-deploy.yml` - Uses `nsready_backend/admin_tool` and `nsready_backend/collector_service`
- [x] ✅ `backend_extended_tests.yml` - Created for manual trigger

### Path Validation

- [x] ✅ `shared/scripts/test_data_flow.sh` exists
- [x] ✅ `nsready_backend/db/seed_registry.sql` exists
- [x] ✅ `docker-compose.yml` exists
- [x] ✅ All container names match (`nsready_db`)

### Documentation Check

- [x] ✅ `README_BACKEND_TESTS.md` - Section 12 (CI Integration) added
- [x] ✅ `README_BACKEND_TESTS_QUICK.md` - Quick reference created
- [x] ✅ Intent comments added to all workflows

**Status:** ✅ Ready for testing

---

## 1. Test Workflows (Do This First)

### 1.1 Test `backend_tests.yml` (Baseline Set CI)

**Goal:** Verify Baseline Set runs correctly in CI

**Steps:**

1. **Create a test branch:**
   ```bash
   git checkout -b test-backend-ci
   ```

2. **Make a tiny non-risk change:**
   ```bash
   # Option A: Add a comment to README
   echo "# Test comment for CI validation" >> README.md
   
   # Option B: Add a comment to a workflow file
   # (Already done, but you can verify)
   
   git add .
   git commit -m "Test: Validate backend_tests.yml CI workflow"
   ```

3. **Push and create PR:**
   ```bash
   git push origin test-backend-ci
   # Then open PR to main via GitHub UI
   ```

4. **Check GitHub Actions:**
   - Go to GitHub Actions tab
   - Find "Backend Baseline Tests" workflow
   - Check job status: ✅ Green or ❌ Red

**Expected Results:**

✅ **SUCCESS:**
- Job "Backend Baseline Tests" runs
- Job turns ✅ Green
- Artifact `backend-test-reports` exists
- Reports contain files in `nsready_backend/tests/reports/`:
  - `DATA_FLOW_TEST_*.md`
  - `BATCH_INGESTION_TEST_*.md`
  - `STRESS_LOAD_TEST_*.md`

❌ **FAILURE:**
- Capture:
  - Job logs (full output)
  - Error messages
  - Which step failed
  - Artifact contents (if any)

**Common Issues & Fixes:**

| Issue | Likely Cause | Fix |
|-------|--------------|-----|
| "No such file or directory" | Wrong path | Check `shared/scripts/` path |
| "Container not found" | Container name mismatch | Verify `nsready_db` in docker-compose.yml |
| "Service not ready" | Startup timeout | Increase wait time in workflow |
| "Database connection failed" | Seed file path wrong | Check `nsready_backend/db/seed_registry.sql` |

---

### 1.2 Smoke-Check `build-test-deploy.yml`

**Goal:** Verify deploy workflow runs and health checks work

**Note:** Don't need to test full deploy, just verify workflow runs and health checks

**Steps:**

1. **Push to `main` or `develop` branch:**
   ```bash
   # This will trigger the workflow automatically
   git checkout main
   git push origin main
   ```

2. **Or trigger manually:**
   - Go to GitHub Actions tab
   - Find "Build, Test, and Deploy" workflow
   - Click "Run workflow" (if manual trigger is enabled)

**Check:**

- [ ] Workflow runs without syntax errors
- [ ] Build steps complete (images build)
- [ ] Health checks run:
  - `Wait for admin_tool health` ✅
  - `Wait for collector_service health` ✅

**Expected Results:**

✅ **SUCCESS:**
- Workflow runs
- Build steps complete
- Health checks pass (services respond)

❌ **FAILURE:**
- If health checks fail:
  - Check ports: `8000` (admin_tool), `8001` (collector_service)
  - Check health paths: `/health`, `/v1/health`
  - Check service startup time (may need more wait time)

**Common Issues:**

| Issue | Fix |
|-------|-----|
| Health endpoint wrong path | Verify `/health` vs `/v1/health` |
| Services not ready in time | Increase retry count or wait time |
| Wrong port | Verify docker-compose.yml ports match |

---

### 1.3 (Optional) Test `backend_extended_tests.yml`

**Goal:** Verify extended tests workflow runs manually

**Steps:**

1. **Go to GitHub Actions:**
   - Navigate to "Backend Extended Tests (Manual)"
   - Click "Run workflow"
   - Select branch (e.g., `main`)
   - Click "Run workflow"

2. **Monitor job:**
   - Watch job progress
   - Check each test step

**Expected Results:**

✅ **SUCCESS:**
- All 6 extended tests run
- Tests complete
- Reports uploaded as artifact

**Tests Included:**
- `test_negative_cases.sh`
- `test_roles_access.sh`
- `test_multi_customer_flow.sh`
- `test_tenant_isolation.sh`
- `test_scada_connection.sh` (may skip)
- `final_test_drive.sh`

---

## 2. Update the 6 Older Docs (Once CI is Green)

**Only proceed to this step after workflows are tested and working!**

### 2.1 Files to Update

1. 🟡 `shared/scripts/CONFIGURATION_IMPORT_USER_GUIDE.md`
2. 🟡 `shared/scripts/ENGINEER_GUIDE_PARAMETER_TEMPLATES.md`
3. 🟡 `shared/scripts/PARAMETER_TEMPLATE_IMPORT_GUIDE.md`
4. 🟡 `shared/scripts/SCADA_INTEGRATION_GUIDE.md`
5. 🟡 `shared/scripts/POSTGRESQL_LOCATION_GUIDE.md`
6. 🟡 `shared/scripts/create_parameter_csv_guide.md`

### 2.2 Update Process

**For each file:**

1. Find "Backend Testing" or "Testing" section
2. Replace with standard block (from `STANDARD_PATCH_BLOCK_FOR_OLD_DOCS.md`):
   ```markdown
   ### Backend Testing (Standard Process)
   
   Backend test procedures are now maintained centrally in:
   - `nsready_backend/tests/README_BACKEND_TESTS.md` (full SOP)
   - `nsready_backend/tests/README_BACKEND_TESTS_QUICK.md` (operator quick view)
   
   **Key commands (from repository root):**
   
   ```bash
   cd /Users/nirajdesai/Documents/Projects/NTPPL_NSREADY_Platforms/ntppl_nsready_platform
   
   ./shared/scripts/test_data_flow.sh
   ./shared/scripts/test_batch_ingestion.sh --count 100
   ./shared/scripts/test_stress_load.sh
   ```
   
   All reports are stored under:
   ```
   nsready_backend/tests/reports/
   ```
   
   For any changes to backend test flow, update the main SOP first and keep this section aligned.
   ```

3. Fix all path references:
   - `./scripts/` → `./shared/scripts/`
   - `scripts/` → `shared/scripts/`
   - `tests/reports/` → `nsready_backend/tests/reports/`
   - `db/seed_registry.sql` → `nsready_backend/db/seed_registry.sql`

**Cursor Prompt (if using AI):**
> "In the following docs, replace old backend test references with the standard block from `nsready_backend/tests/README_BACKEND_TESTS.md` and update paths as per the new repo layout:
> - `shared/scripts/CONFIGURATION_IMPORT_USER_GUIDE.md`
> - `shared/scripts/ENGINEER_GUIDE_PARAMETER_TEMPLATES.md`
> - `shared/scripts/PARAMETER_TEMPLATE_IMPORT_GUIDE.md`
> - `shared/scripts/SCADA_INTEGRATION_GUIDE.md`
> - `shared/scripts/POSTGRESQL_LOCATION_GUIDE.md`
> - `shared/scripts/create_parameter_csv_guide.md`
> 
> Apply these path replacements:
> - `./scripts/` → `./shared/scripts/`
> - `scripts/test_` → `shared/scripts/test_`
> - `tests/reports/` → `nsready_backend/tests/reports/`
> - `db/seed_registry.sql` → `nsready_backend/db/seed_registry.sql`"

---

## 3. Extra Documentation (If Needed)

**Only after 1 and 2 are complete!**

### 3.1 Test Matrix Section

**Already added:** ✅ Section 9 (Backend Test Matrix) in `README_BACKEND_TESTS.md`

### 3.2 Additional Documentation (Optional)

- "How CI fits into NSReady" note in `shared/master_docs/`
- CI/CD overview document
- Workflow decision tree (when to run which workflow)

---

## Testing Progress Tracker

### Phase 1: Workflow Testing

- [ ] ✅ `backend_tests.yml` - Pre-flight validation complete
- [ ] ⏳ `backend_tests.yml` - Actual CI test (create PR and check)
- [ ] ⏳ `build-test-deploy.yml` - Smoke check (push to main or trigger)
- [ ] ⏳ `backend_extended_tests.yml` - Manual trigger test (optional)

### Phase 2: Documentation Updates

- [ ] ⏳ Update 6 older docs with standard patch block
- [ ] ⏳ Verify all paths updated
- [ ] ⏳ Test references point to SOP

### Phase 3: Extra Documentation

- [x] ✅ Test Matrix added to SOP
- [ ] ⏳ Additional docs (if gaps identified)

---

## Quick Test Commands

### Local Validation (Before CI)

```bash
# 1. Verify scripts are executable
chmod +x shared/scripts/*.sh

# 2. Check paths exist
ls -la shared/scripts/test_data_flow.sh
ls -la nsready_backend/db/seed_registry.sql

# 3. Verify container names in docker-compose.yml
grep "container_name" docker-compose.yml

# 4. Test workflow syntax (if yamllint available)
yamllint .github/workflows/backend_tests.yml
```

---

## Next Steps After Testing

1. ✅ **If CI passes:** Proceed to Phase 2 (update 6 docs)
2. ❌ **If CI fails:** Share error logs and we'll fix before proceeding
3. ⏳ **If tests are slow:** Adjust timeouts in workflows
4. ⏳ **If health checks fail:** Verify ports and paths

---

**Status:** ✅ Ready for Phase 1 testing

**Recommendation:** Start with `backend_tests.yml` test (create PR and check results)

