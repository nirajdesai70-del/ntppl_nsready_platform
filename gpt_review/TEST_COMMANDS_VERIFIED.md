# Test Commands - Verification & Usage

**Date:** 2025-01-XX  
**Status:** ✅ All paths updated and verified

---

## ✅ Verified Commands

All three test commands are ready to use with the updated repository structure:

### 1. Data Flow Test
```bash
./shared/scripts/test_data_flow.sh
```

**What it does:**
- Tests complete end-to-end data flow
- Dashboard input → Ingestion API → Database → SCADA Export
- Creates report in: `nsready_backend/tests/reports/DATA_FLOW_TEST_*.md`

**Prerequisites:**
- Services running: `docker compose up -d`
- Registry seeded: `docker exec -i nsready_db psql -U postgres -d nsready < nsready_backend/db/seed_registry.sql`

---

### 2. Batch Ingestion Test
```bash
./shared/scripts/test_batch_ingestion.sh --count 100
```

**What it does:**
- Tests sending multiple events in batches
- Tests sequential and parallel ingestion
- Creates report in: `nsready_backend/tests/reports/BATCH_INGESTION_TEST_*.md`

**Options:**
- `--count N` - Number of events (default: 50)
- `--sequential` - Run sequential batches only
- `--parallel` - Run parallel batches only
- Default: Both sequential and parallel modes

**Prerequisites:**
- Same as data flow test

---

### 3. Stress/Load Test
```bash
./shared/scripts/test_stress_load.sh
```

**What it does:**
- Tests system under sustained high load
- Default: 1000 events over 60s at 50 RPS
- Creates report in: `nsready_backend/tests/reports/STRESS_LOAD_TEST_*.md`

**Options:**
- `--events N` - Total number of events (default: 1000)
- `--duration SEC` - Test duration in seconds (default: 60)
- `--rate RPS` - Rate per second (default: 50)

**Custom example:**
```bash
./shared/scripts/test_stress_load.sh --events 5000 --duration 120 --rate 100
```

**Prerequisites:**
- Same as data flow test

---

## Quick Start Guide

### 1. Ensure Services Are Running

```bash
# Start all services
docker compose up -d

# Verify containers are running
docker ps | grep -E "(admin_tool|collector_service|nsready_db|nsready_nats)"
```

Expected output should show:
- `admin_tool`
- `collector_service`
- `nsready_db`
- `nsready_nats`

---

### 2. Seed the Registry (Required)

```bash
docker exec -i nsready_db psql -U postgres -d nsready < nsready_backend/db/seed_registry.sql
```

**Note:** This is the updated path! Old path was `db/seed_registry.sql`, now it's `nsready_backend/db/seed_registry.sql`.

---

### 3. Run Tests (from repository root)

```bash
# Basic data flow test
./shared/scripts/test_data_flow.sh

# Batch ingestion test
./shared/scripts/test_batch_ingestion.sh --count 100

# Stress test
./shared/scripts/test_stress_load.sh

# All three in sequence
./shared/scripts/test_data_flow.sh && \
./shared/scripts/test_batch_ingestion.sh --count 100 && \
./shared/scripts/test_stress_load.sh
```

---

## Expected Output Locations

All test reports will be created in:
```
nsready_backend/tests/reports/
├── DATA_FLOW_TEST_YYYYMMDD_HHMMSS.md
├── BATCH_INGESTION_TEST_YYYYMMDD_HHMMSS.md
└── STRESS_LOAD_TEST_YYYYMMDD_HHMMSS.md
```

**Note:** The directory will be created automatically if it doesn't exist.

---

## Path Updates Summary

All paths have been updated for the new repository structure:

| Old Path | New Path |
|----------|----------|
| `./scripts/test_data_flow.sh` | `./shared/scripts/test_data_flow.sh` ✅ |
| `tests/reports/` | `nsready_backend/tests/reports/` ✅ |
| `db/seed_registry.sql` | `nsready_backend/db/seed_registry.sql` ✅ |
| `DB_CONTAINER=nsready_db` | ✅ (unchanged - already correct) |

---

## Troubleshooting

### Script not found
**Error:** `./shared/scripts/test_data_flow.sh: No such file or directory`

**Solution:** Run from repository root:
```bash
cd /path/to/ntppl_nsready_platform
./shared/scripts/test_data_flow.sh
```

---

### Report directory not found
**Error:** Script creates reports successfully, but directory doesn't exist

**Solution:** Scripts automatically create the directory. If issues persist:
```bash
mkdir -p nsready_backend/tests/reports
```

---

### Container not found
**Error:** `docker exec: nsready_db: No such container`

**Solution:** 
1. Check services are running: `docker ps`
2. Verify container name: Should be `nsready_db`
3. Start services: `docker compose up -d`

---

### No device/site/project found
**Error:** Test fails with "No device/site/project found in DB"

**Solution:** Seed the registry:
```bash
docker exec -i nsready_db psql -U postgres -d nsready < nsready_backend/db/seed_registry.sql
```

---

## All Available Test Scripts

Full list of test scripts in `shared/scripts/`:

1. ✅ `test_data_flow.sh` - Basic data flow test
2. ✅ `test_batch_ingestion.sh` - Batch ingestion test
3. ✅ `test_stress_load.sh` - Stress/load test
4. ✅ `test_multi_customer_flow.sh` - Multi-customer tenant isolation
5. ✅ `test_negative_cases.sh` - Negative test cases
6. ✅ `test_roles_access.sh` - Role-based access tests
7. ✅ `test_tenant_isolation.sh` - Tenant isolation tests
8. ✅ `test_scada_connection.sh` - SCADA connection test
9. ✅ `test_drive.sh` - Test drive script
10. ✅ `final_test_drive.sh` - Final test drive

All scripts now use:
- ✅ Correct report directory: `nsready_backend/tests/reports/`
- ✅ Correct script paths: `shared/scripts/`
- ✅ Correct container names: `nsready_db`

---

**Status:** ✅ **Ready to use!** All paths updated and verified.


