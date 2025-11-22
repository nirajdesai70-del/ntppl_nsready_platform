# ND Ready – Backend Test Process (Data Collection Backend)

This document defines the standard test procedure for the ND Ready / NSReady data collection backend, aligned with the new repository structure and docker layout.

**Repository:** `ntppl_nsready_platform`  
**Scope:** backend services + database + ingestion/data-flow tests.

> **📋 Quick Operator View:** For a condensed operator reference with just commands and minimal checks, see [`README_BACKEND_TESTS_QUICK.md`](./README_BACKEND_TESTS_QUICK.md).

---

## 1. Purpose

- Validate that the **data collection backend** is working correctly after code changes, refactors, or docker/folder reorganisation.

- Confirm:
  - DB connectivity (`nsready_db`)
  - Registry/seed data availability
  - Data flow from test scripts into the backend
  - Behaviour under batch and stress loads

- Generate traceable test reports under:
  - `nsready_backend/tests/reports/`

---

## 2. Pre-requisites

Run all commands from the **repository root**:

```bash
cd /Users/nirajdesai/Documents/Projects/NTPPL_NSREADY_Platforms/ntppl_nsready_platform
```

### 2.1. Docker stack up

```bash
docker compose up -d
docker compose ps
```

**Confirm that:**
- `nsready_db` is Up
- Other backend services required for testing are Up (e.g., API/collector containers as per docker-compose.yml)

### 2.2. Ensure scripts are executable (one-time or after git clone)

```bash
chmod +x shared/scripts/*.sh
```

### 2.3. Seed the registry database

**Only required if:**
- DB has been recreated, or
- Seed data has changed, or
- You are preparing a clean test environment.

```bash
docker exec -i nsready_db psql -U postgres -d nsready < nsready_backend/db/seed_registry.sql
```

**Note:**
- `nsready_db` = container name (matches docker-compose.yml)
- `nsready` = database name
- Seed file = `nsready_backend/db/seed_registry.sql`

---

## 3. Report locations

All test scripts write their outputs to:

```
nsready_backend/tests/reports/
```

**Expected report naming patterns** (exact names may vary by implementation):

- **Data flow tests:**
  - `nsready_backend/tests/reports/DATA_FLOW_TEST_*.md`

- **Batch ingestion tests:**
  - `nsready_backend/tests/reports/BATCH_INGESTION_TEST_*.md`

- **Stress/load tests:**
  - `nsready_backend/tests/reports/STRESS_LOAD_TEST_*.md`

After each test, verify that new files appear in this directory.

---

## 4. Test 1 – Data Flow Sanity Check

**Goal:** Validate basic end-to-end data flow and connectivity with minimal load.

**Command (from repo root):**

```bash
./shared/scripts/test_data_flow.sh
```

**What this test should do (high level):**
- Connect to `nsready_db`
- Use seeded registry/config data
- Simulate a small, controlled data flow path
- Write a summary report into `nsready_backend/tests/reports/`

### Post-checks:

```bash
ls nsready_backend/tests/reports
```

**Confirm:**
- A new `DATA_FLOW_TEST_*.md` (or equivalent) file is created.
- The report indicates:
  - DB connection success
  - No critical errors in core backend pipeline

**Pass/Fail Criteria:**
- **PASS** if:
  - Script exits with code `0`, and
  - Report contains no `ERROR:` or `CRITICAL:` entries.
- **FAIL** if:
  - Script exits with non-zero status, or
  - Report logs indicate connection failure, unhandled exceptions, or missing core steps.

**If this test fails:**
- Capture:
  - The command used
  - The stderr/stdout output
  - Save or copy error logs, then share them for analysis (do not fix randomly in scripts).

---

## 5. Test 2 – Batch Ingestion Test

**Goal:** Validate batch handling and ingestion under moderate, controlled load.

**Command:**

```bash
./shared/scripts/test_batch_ingestion.sh --count 100
```

**Where:**
- `--count 100` = number of records/messages/rows to simulate (parameterizable if script supports it).

**What this test should do (high level):**
- Generate a batch of test data (size = count)
- Push that batch through the ingestion pipeline
- Verify that expected rows/records are created/updated
- Write a detailed report under `nsready_backend/tests/reports/`

### Post-checks:

```bash
ls nsready_backend/tests/reports
```

**Confirm:**
- A new `BATCH_INGESTION_TEST_*.md` file is present.
- Report should summarise:
  - Batch size requested
  - Successful ingestions
  - Any failures/retries/timeouts (if logged)

**Pass/Fail Criteria:**
- **PASS** if:
  - Script exits with code `0`,
  - All requested batch items were successfully ingested, and
  - No dropped messages or unhandled errors in report.
- **FAIL** if:
  - Script exits with non-zero status,
  - Partial ingestion with errors, or
  - Dropped messages exceed acceptable thresholds.

**If issues appear (e.g., partial ingestion):**
- Attach relevant sections of the report for review.
- Avoid editing the script logic until failure mode is understood.

---

## 6. Test 3 – Stress / Load Test

**Goal:** Validate behaviour under higher load; check for timeouts, resource constraints, and stability.

**Command:**

```bash
./shared/scripts/test_stress_load.sh
```

(If the script accepts parameters like `--duration` or `--rate`, document them here once finalised.)

**Custom options:**

```bash
# Custom: 5000 events over 120s at 100 RPS
./shared/scripts/test_stress_load.sh --events 5000 --duration 120 --rate 100
```

**What this test should do (high level):**
- Generate high-intensity traffic or frequent requests
- Exercise core parts of the backend under stress
- Capture results:
  - Throughput metrics (if available)
  - Errors, dropped messages, or timeouts
  - Any resource-related warnings

### Post-checks:

```bash
ls nsready_backend/tests/reports
```

**Pass/Fail Criteria:**
- **PASS** if:
  - Script exits with code `0`,
  - No critical failures or crashes,
  - Throughput within acceptable range for system capacity, and
  - Error rates below threshold (document in report).
- **FAIL** if:
  - Script exits with non-zero status,
  - System crashes or unhandled exceptions,
  - Error rates exceed acceptable thresholds, or
  - Resource exhaustion (memory, connections, etc.).

**Confirm:**
- A `STRESS_LOAD_TEST_*.md` file is present.
- Review report for:
  - Non-fatal warnings
  - Critical failures / crash indicators

---

## 7. Standard Test Run Sequence

For any meaningful backend change (code or infra):

### 1. Pre-checks

```bash
docker compose up -d
docker compose ps
# (Optional) re-seed DB if needed
```

### 2. Run tests in order

```bash
# Basic flow
./shared/scripts/test_data_flow.sh

# Batch ingestion
./shared/scripts/test_batch_ingestion.sh --count 100

# Stress test (optional, but recommended before major releases)
./shared/scripts/test_stress_load.sh
```

### 3. Verify reports

- All expected report files exist
- No critical failures in any report

### 4. Log results

For formal runs, record:
- Date/time
- Git commit hash
- Test results summary
- Link to report files under `nsready_backend/tests/reports/`

---

## 8. Troubleshooting – Quick Pointers

### If tests fail immediately with "command not found" or "permission denied":

**Ensure:**

```bash
chmod +x shared/scripts/*.sh
```

**Confirm you are in repo root:**

```bash
pwd
```

### If tests fail with DB connection errors:

**Check container:**

```bash
docker compose ps
docker logs nsready_db
```

**Re-seed:**

```bash
docker exec -i nsready_db psql -U postgres -d nsready < nsready_backend/db/seed_registry.sql
```

### If reports are not appearing:

**Confirm path:**

```bash
ls nsready_backend/tests/reports
```

**Inspect script body in `shared/scripts/test_*.sh` to ensure `REPORT_DIR` is set to `nsready_backend/tests/reports/`.**

---

## 9. Alignment with Repository Structure

This test process assumes:

- **Backend code:**
  - `nsready_backend/...`

- **Shared scripts:**
  - `shared/scripts/test_data_flow.sh`
  - `shared/scripts/test_batch_ingestion.sh`
  - `shared/scripts/test_stress_load.sh`

- **Docs and analysis:**
  - `gpt_review/backend_tests_bundle.md` (ChatGPT review bundle)
  - `gpt_review/backend_tests/` (individual TEST/DOC copies)

**Keep this document updated whenever:**
- Paths change (e.g., moving tests or scripts)
- New test scripts are added
- docker-compose service names change

---

## 9. Backend Test Matrix

This section summarises all backend test scripts, the reports they generate, what they validate, and when they should be run.

> **Note:** All commands below are run from the repository root:
> 
> ```bash
> cd /Users/nirajdesai/Documents/Projects/NTPPL_NSREADY_Platforms/ntppl_nsready_platform
> ```

### 9.1 Core Baseline Tests

These tests should cover the core "does the backend fundamentally work" questions.

| # | Script | Report Prefix / Files | Purpose | When to Run | Criticality |
|---|--------|-----------------------|---------|-------------|-------------|
| 1 | `./shared/scripts/test_data_flow.sh` | `nsready_backend/tests/reports/DATA_FLOW_TEST_*.md` | Verify DB connectivity, basic pipeline wiring, and end-to-end path with minimal load. | **Every change** affecting backend, DB, or docker-compose. | 🔴 High |
| 2 | `./shared/scripts/test_batch_ingestion.sh --count 100` | `nsready_backend/tests/reports/BATCH_INGESTION_TEST_*.md` | Validate that ingestion can handle a moderate batch of records without errors. | After changes to ingestion logic, queue/worker configs, or performance tuning. | 🔴 High |
| 3 | `./shared/scripts/test_stress_load.sh` | `nsready_backend/tests/reports/STRESS_LOAD_TEST_*.md` | Check behaviour under higher load: timeouts, failures, resource bottlenecks. | Before major releases; after significant infra/performance changes. | 🟠 Medium–High |

### 9.2 Extended Functional Tests

These tests validate specific behaviours beyond the core pipeline.

| # | Script | Report Prefix / Files | Purpose | When to Run | Criticality |
|---|--------|-----------------------|---------|-------------|-------------|
| 4 | `./shared/scripts/test_negative_cases.sh` | `nsready_backend/tests/reports/NEGATIVE_TEST_*.md` | Ensure invalid / malformed / out-of-range data is rejected cleanly and does not corrupt DB or queues. | After validation rules change, schema updates, or error-handling changes. | 🔴 High |
| 5 | `./shared/scripts/test_roles_access.sh` | `nsready_backend/tests/reports/ROLES_ACCESS_TEST_*.md` | Validate role-based access behaviour (who can run what / see what) at backend/API level. | After RBAC changes, auth layer updates, or role configuration changes. | 🔴 High for multi-user setups |
| 6 | `./shared/scripts/test_multi_customer_flow.sh` | `nsready_backend/tests/reports/MULTI_CUSTOMER_FLOW_TEST_*.md` | Validate data routing and separation across multiple customers within the same backend cluster. | Before enabling multi-customer deployments; after changes to routing/tenant logic. | 🔴 High in multi-customer mode |
| 7 | `./shared/scripts/test_scada_connection.sh` | `nsready_backend/tests/reports/SCADA_CONNECTION_TEST_*.md` | Validate SCADA connectivity, export/import path, and that SCADA data can be correctly pulled into the backend. | Before SCADA-related rollouts; after network/connection setting changes. | 🟠 Medium–High |

> **Note:** Exact report filenames for some extended tests may differ slightly. Use `ls nsready_backend/tests/reports` to see actual generated files and keep this table updated if naming conventions change.

### 9.3 Tenant and Isolation Tests

These tests focus specifically on tenant isolation and multi-tenant correctness.

| # | Script | Report Prefix / Files | Purpose | When to Run | Criticality |
|---|--------|-----------------------|---------|-------------|-------------|
| 8 | `./shared/scripts/test_tenant_isolation.sh` | `nsready_backend/tests/reports/TENANT_ISOLATION_TEST_*.md` and/or `TENANT_ISOLATION_TEST_RESULTS.md` | Validate that tenant boundaries are respected: no cross-tenant data leakage in backend views or exports. | Before enabling/altering tenant logic; after schema or filter updates that touch tenant_id/customer_id. | 🔴 Critical in multi-tenant mode |
| 9 | `./shared/scripts/tenant_testing/test_data_flow.sh` | `nsready_backend/tests/reports/TENANT_DATA_FLOW_TEST_*.md` (if configured) | Tenant-focused data flow sanity check under tenant-specific configurations. | Alongside `test_tenant_isolation.sh` when testing tenant-specific changes. | 🟠 Medium–High |
| 10 | `./shared/scripts/tenant_testing/test_tenant_isolation.sh` | Additional tenant-specific isolation reports | Deep dive / extended isolation checks for particular tenant scenarios. | For focused tenant troubleshooting or before signing off complex tenant configurations. | 🟠 Medium–High |

> For full conceptual guidance on tenant testing, see:
> - `shared/master_docs/tenant_upgrade/TENANT_ISOLATION_TESTING_GUIDE.md`
> - `shared/master_docs/tenant_upgrade/TENANT_ISOLATION_TEST_STRATEGY.md`
> - `shared/master_docs/tenant_upgrade/TENANT_ISOLATION_TEST_RESULTS.md`

(Adjust paths to these docs if they live elsewhere.)

### 9.4 Full Regression / Final Test Drive

This is your "all in one" higher-level regression check.

| # | Script | Report Prefix / Files | Purpose | When to Run | Criticality |
|---|--------|-----------------------|---------|-------------|-------------|
| 11 | `./shared/scripts/final_test_drive.sh` | `nsready_backend/tests/reports/FINAL_TEST_DRIVE_*.md` | Run an extended, end-to-end test drive combining key flows (data flow, ingestion, isolation, etc.). | Before major milestones/releases, after large refactors or infra changes. | 🔴 High before release |

### 9.5 Standard Run Sets

To avoid guessing which subset to run, define standard "bundles":

- **Baseline Set (local dev sanity):**
  - `test_data_flow.sh`
  - `test_batch_ingestion.sh --count 100`

- **Pre-release Set (non-tenant deployments):**
  - Baseline set
  - `test_stress_load.sh`
  - `test_negative_cases.sh`
  - `test_scada_connection.sh` (if SCADA in scope)

- **Multi-tenant / Customer-aware Deployments:**
  - Pre-release set
  - `test_roles_access.sh`
  - `test_multi_customer_flow.sh`
  - `test_tenant_isolation.sh`
  - Tenant testing scripts under `shared/scripts/tenant_testing/…` as required

Keep this table and the run sets updated whenever new tests are added or report naming is changed.

---

## 10. Additional Test Scripts

For complete test scripts documentation and additional test scenarios, see:

- `shared/scripts/TEST_SCRIPTS_README.md` - Complete test scripts documentation

**See Section 9 (Backend Test Matrix) above for the full list of test scripts, their purposes, and usage guidelines.**

---

## 12. CI Integration – Backend Baseline Tests

The backend Baseline Set tests are also wired into GitHub Actions.

### 12.1 Workflow

- **Workflow file:** `.github/workflows/backend_tests.yml`

- **Triggers:**
  - `push` to `main`
  - `pull_request` targeting `main`
  - Manual trigger via `workflow_dispatch` (optional)

### 12.2 What the workflow does

The CI job performs the same steps as this SOP:

1. `docker compose up -d`

2. Waits for `nsready_db` to be ready

3. Seeds the registry database from:
   ```bash
   docker exec -i nsready_db psql -U postgres -d nsready < nsready_backend/db/seed_registry.sql
   ```

4. Ensures scripts are executable:
   ```bash
   chmod +x shared/scripts/*.sh
   ```

5. Runs the Baseline Set:
   ```bash
   ./shared/scripts/test_data_flow.sh
   ./shared/scripts/test_batch_ingestion.sh --count 100
   ./shared/scripts/test_stress_load.sh
   ```

6. Uploads all files from `nsready_backend/tests/reports/` as CI artifacts.

### 12.3 How to use it

- **For each PR / push to main**, check the **Backend Baseline Tests** job:
  - ✅ **Green** → baseline backend tests passed
  - ❌ **Red** → review:
    - Job logs
    - Attached `backend-test-reports` artifact

**Note:** Any change to the backend test process should be reflected in:
1. This SOP (`README_BACKEND_TESTS.md`)
2. `.github/workflows/backend_tests.yml`

This way operators and devs see clearly: **"CI is just the automated version of this SOP."**

### 12.4 Relationship to deploy workflows

Deploy workflows (e.g. `.github/workflows/build-test-deploy.yml`) assume that `backend_tests.yml` has passed, and only run light smoke checks against the deployed environment (health endpoints, service status). They do **not** duplicate the Baseline Set tests.

---

**Last Updated:** 2025-01-XX  
**Repository Structure:** Post-reorganization (`nsready_backend/`, `shared/scripts/`)

