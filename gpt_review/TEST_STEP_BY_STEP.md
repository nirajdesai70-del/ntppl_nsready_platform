# Step-by-Step Testing Guide

**Purpose:** Test `backend_tests.yml` workflow step by step

---

## Step 1: Create Test Branch

**Action:**
```bash
cd /Users/nirajdesai/Documents/Projects/NTPPL_NSREADY_Platforms/ntppl_nsready_platform

git checkout -b test-backend-ci
```

**Expected:** Branch created and switched to `test-backend-ci`

---

## Step 2: Make a Tiny Test Change

**Action:**
```bash
# Add a small comment to README (non-breaking change)
echo "" >> README.md
echo "<!-- CI Test: Testing backend_tests.yml workflow -->" >> README.md
```

**Or alternatively:**
```bash
# Add a comment to the workflow file itself (just to verify it exists)
# (No code change needed - workflow already exists)
```

**Expected:** README.md has a new comment line

---

## Step 3: Commit the Change

**Action:**
```bash
git add README.md
git commit -m "Test: Validate backend_tests.yml CI workflow"
```

**Expected:** Change committed to `test-backend-ci` branch

---

## Step 4: Push and Create PR

**Action:**
```bash
git push origin test-backend-ci
```

**Then:**
1. Go to GitHub (repository page)
2. Click "Pull requests" tab
3. Click "New pull request"
4. Select base: `main` ← compare: `test-backend-ci`
5. Click "Create pull request"

**Expected:**
- PR created
- `backend_tests.yml` workflow should automatically trigger

---

## Step 5: Monitor GitHub Actions

**Action:**
1. Go to GitHub Actions tab
2. Find workflow run: **"Backend Baseline Tests"**
3. Click on it to see details

**Expected Results:**

✅ **SUCCESS:**
- Job "Backend Baseline Tests" runs
- Job turns ✅ Green
- All steps complete:
  - ✅ Checkout repository
  - ✅ Verify Docker setup
  - ✅ Create .env file
  - ✅ Start docker compose stack
  - ✅ Wait for nsready_db
  - ✅ Wait for services to be healthy
  - ✅ Seed registry database
  - ✅ Make test scripts executable
  - ✅ Run baseline backend tests
  - ✅ Upload backend test reports
  - ✅ Stop docker compose stack

❌ **FAILURE:**
- Job turns ❌ Red
- Check which step failed
- Copy error messages
- Download artifacts (if any)

---

## Step 6: Check Results

**If SUCCESS:**

1. **Check Artifacts:**
   - In workflow run page, scroll to "Artifacts" section
   - Download `backend-test-reports`
   - Verify it contains:
     - `DATA_FLOW_TEST_*.md`
     - `BATCH_INGESTION_TEST_*.md`
     - `STRESS_LOAD_TEST_*.md`

2. **Check Reports:**
   - Open downloaded reports
   - Verify they show ✅ PASSED status
   - Check for any warnings

3. **Next Step:**
   - ✅ If all tests pass → Proceed to Step 2 (smoke-check `build-test-deploy.yml`)
   - ⚠️  If tests pass but have warnings → Note them for future review

**If FAILURE:**

1. **Capture Information:**
   - Full job logs (click "Download logs" in GitHub Actions)
   - Which step failed
   - Error messages
   - Any partial artifacts

2. **Common Issues:**

   | Error | Likely Cause | Fix |
   |-------|--------------|-----|
   | "No such file or directory: shared/scripts/test_data_flow.sh" | Path wrong | Verify script exists at `shared/scripts/` |
   | "Container not found: nsready_db" | Container name mismatch | Check docker-compose.yml |
   | "Service not ready" | Startup timeout | Increase wait time or check services |
   | "Database connection failed" | Seed file path wrong | Check `nsready_backend/db/seed_registry.sql` |
   | "Permission denied" | Script not executable | Add `chmod +x shared/scripts/*.sh` step |

3. **Share Results:**
   - Paste error messages here
   - Share which step failed
   - I'll help fix it

---

## Quick Commands Summary

**All-in-one command sequence:**
```bash
cd /Users/nirajdesai/Documents/Projects/NTPPL_NSREADY_Platforms/ntppl_nsready_platform

# Step 1: Create branch
git checkout -b test-backend-ci

# Step 2: Make test change
echo "" >> README.md
echo "<!-- CI Test: Testing backend_tests.yml workflow - $(date) -->" >> README.md

# Step 3: Commit
git add README.md
git commit -m "Test: Validate backend_tests.yml CI workflow"

# Step 4: Push
git push origin test-backend-ci
```

**Then:**
- Go to GitHub → Open PR to `main`
- Wait for workflow to run
- Check results

---

## What to Share After Testing

**If SUCCESS:**
- ✅ "Workflow passed! All tests green."
- Share screenshot or link to successful run
- Proceed to next step

**If FAILURE:**
- ❌ "Workflow failed at step X"
- Share:
  - Which step failed
  - Error message
  - Full job log (if possible)
- I'll help fix it

---

**Status:** ✅ Ready for Step 1

**Next:** Run the commands above to create PR and test!


