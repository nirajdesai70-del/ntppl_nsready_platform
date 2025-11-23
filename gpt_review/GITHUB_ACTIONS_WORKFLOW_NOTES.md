# GitHub Actions Workflow - Implementation Notes

**Date:** 2025-01-XX  
**Status:** ✅ Backend tests workflow created

---

## New Workflow Created

### `.github/workflows/backend_tests.yml`

**Purpose:** Run Baseline Set tests automatically on every push/PR to main.

**What it does:**
1. Starts docker compose stack
2. Waits for services to be healthy
3. Seeds registry database
4. Runs Baseline Set (3 tests):
   - `test_data_flow.sh`
   - `test_batch_ingestion.sh --count 100`
   - `test_stress_load.sh`
5. Uploads test reports as artifacts
6. Uploads service logs if tests fail

**Key Features:**
- ✅ Uses exact same commands as SOP
- ✅ Proper timeout handling (30 min total, 5-15 min per step)
- ✅ Environment variable setup for docker-compose.yml
- ✅ Service health checks before running tests
- ✅ Test report summary display
- ✅ Automatic artifact upload (reports + logs)
- ✅ Manual trigger support (`workflow_dispatch`)

---

## Improvements Added

### 1. Environment Variables
- Creates `.env` file automatically with test defaults
- Uses environment variables compatible with `docker-compose.yml`
- Can be overridden via GitHub Secrets if needed

### 2. Service Health Checks
- Waits for `nsready_db` to be ready (up to 5 minutes)
- Checks `collector_service` health endpoint
- Checks `admin_tool` health endpoint
- Shows service logs if startup fails

### 3. Better Error Handling
- Timeout per step (prevents hanging)
- Continue-on-error only where appropriate
- Uploads logs if tests fail for debugging
- Clear error messages with emojis

### 4. Test Report Summary
- Shows which reports were generated
- Lists recent report files
- Easy to see what passed/failed

### 5. Cleanup
- Always stops docker stack after tests
- Removes volumes with `-v` flag
- Prevents resource leaks

---

## Existing Workflow Needs Updates

**⚠️ Note:** The existing `.github/workflows/build-test-deploy.yml` uses **old paths** that need updating:

**Old paths (line 45):**
```yaml
./scripts/test_tenant_isolation.sh
```

**Should be:**
```yaml
./shared/scripts/test_tenant_isolation.sh
```

**Other outdated paths in existing workflow:**
- Line 31: `tests/requirements.txt` → Should check if path is correct
- Line 92: `./admin_tool` → Should be `./nsready_backend/admin_tool`
- Line 102: `./collector_service` → Should be `./nsready_backend/collector_service`

**Recommendation:** Update `build-test-deploy.yml` to use new repository structure paths.

---

## How to Use

### Automatic Runs
- Runs on every push to `main`
- Runs on every pull request to `main`
- Jobs appear in GitHub Actions tab

### Manual Runs
- Go to GitHub Actions tab
- Select "Backend Baseline Tests" workflow
- Click "Run workflow" button
- Select branch and click "Run workflow"

### Viewing Results
1. Go to GitHub Actions tab
2. Click on the workflow run
3. Expand "Upload backend test reports" step
4. Download artifacts to see:
   - Test reports (`.md` files)
   - Service logs (if tests failed)

---

## Integration with SOP

This workflow matches exactly with `nsready_backend/tests/README_BACKEND_TESTS.md`:

✅ **Same commands:**
- `docker compose up -d`
- `docker exec -i nsready_db psql -U postgres -d nsready < nsready_backend/db/seed_registry.sql`
- `./shared/scripts/test_data_flow.sh`
- `./shared/scripts/test_batch_ingestion.sh --count 100`
- `./shared/scripts/test_stress_load.sh`

✅ **Same paths:**
- Scripts: `shared/scripts/`
- Reports: `nsready_backend/tests/reports/`
- Seed file: `nsready_backend/db/seed_registry.sql`

✅ **Same container names:**
- `nsready_db` (matches docker-compose.yml)

---

## Next Steps

### Option 1: Update Existing Workflow
Update `.github/workflows/build-test-deploy.yml` to use new paths:
- `./scripts/` → `./shared/scripts/`
- `./admin_tool` → `./nsready_backend/admin_tool`
- `./collector_service` → `./nsready_backend/collector_service`
- Check `tests/requirements.txt` path

### Option 2: Expand New Workflow
Add optional jobs for extended tests:
- Negative tests
- Tenant isolation tests
- Full test drive (on `workflow_dispatch` only)

### Option 3: Add Workflow to SOP
Reference this workflow in `README_BACKEND_TESTS.md`:
- Section 7 (Standard Test Run Sequence) can mention CI
- Note that CI runs Baseline Set automatically

---

## Environment Variables

**Current defaults (in workflow):**
```yaml
POSTGRES_DB: nsready
POSTGRES_USER: postgres
POSTGRES_PASSWORD: nsready_password
APP_ENV: test
```

**To use GitHub Secrets (recommended for production):**
1. Go to Repository Settings → Secrets and variables → Actions
2. Add secrets:
   - `POSTGRES_PASSWORD` (if different from default)
   - Other environment-specific values
3. Update workflow to use: `${{ secrets.POSTGRES_PASSWORD }}`

---

## Timeouts

**Current timeout settings:**
- Job total: 30 minutes
- DB wait: 5 minutes
- Service health: 5 minutes
- Database seed: 5 minutes
- Test execution: 15 minutes

**Adjust if needed:**
- Increase `timeout-minutes` if tests are slow
- Decrease if tests should be faster

---

**Status:** ✅ **Workflow is ready to use!**

Test it by pushing to `main` or creating a pull request.


