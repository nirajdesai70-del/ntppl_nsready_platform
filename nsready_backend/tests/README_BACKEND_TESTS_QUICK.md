# Backend Tests – Quick Operator View

All commands run from repo root:

```bash
cd /Users/nirajdesai/Documents/Projects/NTPPL_NSREADY_Platforms/ntppl_nsready_platform
```

---

## 1. One-time / occasional setup

### 1.1 Start services

```bash
docker compose up -d
docker compose ps
```

- **Confirm `nsready_db` is Up.**

### 1.2 Make scripts executable (only if needed)

```bash
chmod +x shared/scripts/*.sh
```

### 1.3 Seed registry (only when DB is new / reset)

```bash
docker exec -i nsready_db psql -U postgres -d nsready < nsready_backend/db/seed_registry.sql
```

---

## 2. Standard test set (Baseline)

From repo root:

```bash
./shared/scripts/test_data_flow.sh

./shared/scripts/test_batch_ingestion.sh --count 100

./shared/scripts/test_stress_load.sh

For tenant / multi-customer or SCADA-specific changes, see the extended test set in:
- `nsready_backend/tests/README_BACKEND_TESTS.md` (Section 9 – Backend Test Matrix)
```

---

## 3. Where to see results

All test reports:

```bash
ls nsready_backend/tests/reports
```

**Expected files** (names may vary):

- `DATA_FLOW_TEST_*.md`
- `BATCH_INGESTION_TEST_*.md`
- `STRESS_LOAD_TEST_*.md`

---

## 4. If something fails

### 1. Check container status:

```bash
docker compose ps
docker logs nsready_db
```

### 2. Re-seed if needed:

```bash
docker exec -i nsready_db psql -U postgres -d nsready < nsready_backend/db/seed_registry.sql
```

### 3. Re-run the test command and capture:

- Command you ran
- Full error output

**For detailed explanation of each test, see:**

- `nsready_backend/tests/README_BACKEND_TESTS.md`

---

**Last Updated:** 2025-01-XX  
**Repository Structure:** Post-reorganization (`nsready_backend/`, `shared/scripts/`)

