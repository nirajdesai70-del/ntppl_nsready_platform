# Step-by-Step Commands for Testing

**Purpose:** Exact commands to test `backend_tests.yml` workflow

---

## Step 1: Commit All Current Work

**Before testing, commit all the work we've done:**

```bash
cd /Users/nirajdesai/Documents/Projects/NTPPL_NSREADY_Platforms/ntppl_nsready_platform

# Check what we're committing
git status

# Add all our changes
git add .

# Commit with descriptive message
git commit -m "feat: Update backend test scripts and workflows for new repo structure

- Update all test scripts to use shared/scripts/ and nsready_backend/tests/reports/
- Create backend_tests.yml workflow for Baseline Set CI
- Update build-test-deploy.yml with new paths and health checks
- Add backend_extended_tests.yml workflow (manual trigger)
- Create README_BACKEND_TESTS.md (full SOP)
- Create README_BACKEND_TESTS_QUICK.md (operator quick view)
- Update TEST_SCRIPTS_README.md with new paths
- Add CI integration section to SOP (Section 12)
- Add test matrix to SOP (Section 9)
- Create gpt_review/ collection scripts and documentation"

# Verify commit
git log -1 --oneline
```

**Expected:** All changes committed to `main` branch

---

## Step 2: Push Current Work to Main (Optional)

**If you want to keep main branch updated:**

```bash
git push origin main
```

**Or skip this and create test branch from current state (recommended for testing)**

---

## Step 3: Create Test Branch

**Create a branch for testing CI:**

```bash
# Ensure we're on main
git checkout main

# Create test branch
git checkout -b test-backend-ci
```

**Expected:** Branch created and switched to `test-backend-ci`

---

## Step 4: Make Tiny Test Change

**Add a small comment to trigger CI (non-breaking):**

```bash
# Add a test comment to README
echo "" >> README.md
echo "<!-- CI Test: Testing backend_tests.yml workflow - $(date +%Y-%m-%d) -->" >> README.md
```

**Expected:** README.md has a new comment line

---

## Step 5: Commit Test Change

```bash
git add README.md
git commit -m "test: Validate backend_tests.yml CI workflow"
```

**Expected:** Test change committed

---

## Step 6: Push and Create PR

```bash
# Push test branch
git push origin test-backend-ci
```

**Then in GitHub:**
1. Go to repository page
2. Click "Pull requests" tab
3. Click "New pull request"
4. Base: `main` ← Compare: `test-backend-ci`
5. Title: "Test: Validate backend_tests.yml CI workflow"
6. Description: "Testing backend Baseline Set CI workflow"
7. Click "Create pull request"

**Expected:**
- PR created
- `backend_tests.yml` workflow automatically triggers

---

## Step 7: Monitor CI

**In GitHub Actions:**
1. Go to "Actions" tab
2. Find workflow run: **"Backend Baseline Tests"**
3. Click on it

**Watch for:**
- ✅ Green checkmark = Success
- ❌ Red X = Failure

**If SUCCESS:**
- Check "Artifacts" section
- Download `backend-test-reports`
- Verify reports exist

**If FAILURE:**
- Check which step failed
- Copy error messages
- Share here for help

---

## Quick Copy-Paste Sequence

**All steps in one go (after committing current work):**

```bash
# Step 1: Create test branch
git checkout -b test-backend-ci

# Step 2: Make test change
echo "" >> README.md
echo "<!-- CI Test: Testing backend_tests.yml workflow - $(date +%Y-%m-%d) -->" >> README.md

# Step 3: Commit
git add README.md
git commit -m "test: Validate backend_tests.yml CI workflow"

# Step 4: Push
git push origin test-backend-ci
```

**Then open PR to main via GitHub UI**

---

**Status:** ✅ Ready for Step 1

**Next:** Run the commands above!

