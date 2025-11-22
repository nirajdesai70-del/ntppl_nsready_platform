# NSReady Documentation Fix – Execution Checklist

**Status:** ✅ **READY FOR EXECUTION**

**Adoption Decision:**
- ✅ Adopt both proposals (sample_event.json + README.md)
- ✅ UUID Option A: Standardize on documentation UUIDs (`8212caa2-...`) everywhere
- ✅ Update all 4 test files to use documentation UUIDs

**Created:** 2025-11-18

**Purpose:** Phase-by-phase execution checklist with grep commands for verification

---

## 🔥 Phase 1 – Critical Fixes (Parameter Keys & Canonical Reference)

### ✅ Phase 1.1 – Replace short-form parameter_key in docs

**Files:**
- `docs/00_Introduction_and_Terminology.md`
- `docs/02_System_Architecture_and_DataFlow.md`
- `docs/04_Deployment_and_Startup_Manual.md`
- `docs/07_Data_Ingestion_and_Testing_Manual.md`

**Checklist:**
- [ ] **Module 0:** Replace all `"parameter_key": "voltage"` / `current` / `power` / `temperature` / `humidity` / `status` with `project:8212caa2-...:<name>`
- [ ] **Module 2:** Update architecture JSON examples to full parameter_key format
- [ ] **Module 4:** Update any test JSONs / examples to full parameter_key format
- [ ] **Module 7:** Update all JSON examples to full parameter_key format (8+ instances found)

**Helper grep (to find issues):**
```bash
grep -R --line-number --ignore-case '"parameter_key": "voltage"' docs
grep -R --line-number --ignore-case '"parameter_key": "current"' docs
grep -R --line-number --ignore-case '"parameter_key": "power"' docs
grep -R --line-number --ignore-case '"parameter_key": "temperature"' docs
grep -R --line-number --ignore-case '"parameter_key": "humidity"' docs
grep -R --line-number --ignore-case '"parameter_key": "status"' docs
```

**Verification:**
- [ ] Run grep commands - should return 0 results after fixes
- [ ] All examples use format: `project:8212caa2-b928-4213-b64e-9f5b86f4cad1:<name>`

---

### ✅ Phase 1.2 – Strengthen Module 6 as Canonical

**File:**
- `docs/06_Parameter_Template_Manual.md`

**Checklist:**
- [ ] Add "⚠️ CANONICAL REFERENCE" box under title (after title, before Section 1):
  ```markdown
  > ⚠️ **CANONICAL REFERENCE**  
  > This module defines the ONLY correct `parameter_key` format.  
  > All ingestion examples in other modules must follow this format.
  ```
- [ ] Add "⚠️ IMPORTANT" note in Section 5.1 (Parameter Key Generation):
  ```markdown
  > ⚠️ **IMPORTANT**  
  > Some modules show short-form keys for readability.  
  > Actual ingestion ALWAYS requires the full key format defined here.
  ```

**Verification:**
- [ ] Warning box appears at top of Module 6
- [ ] Warning note appears in Section 5.1

---

### ✅ Phase 1.3 – Add warning in Module 12 (API Dev Manual)

**File:**
- `docs/12_API_Developer_Manual.md`

**Checklist:**
- [ ] Confirm all examples use full parameter_key format (verify with grep)
- [ ] Add CRITICAL warning in Section 6.1 (NormalizedEvent Schema), under "Field Details" table:
  ```markdown
  > ⚠️ **CRITICAL**  
  > The `parameter_key` field MUST exactly match `parameter_templates.key`.  
  > Always use the full format `project:<project_uuid>:<parameter>`.  
  > Short names like `"voltage"` are invalid.
  ```
- [ ] Add cross-reference in Section 6.1:
  ```markdown
  For complete parameter_key format rules, see **Module 6 – Parameter Template Manual**.
  ```

**Verification:**
- [ ] Warning box appears in Section 6.1
- [ ] Cross-reference to Module 6 is present

---

### ✅ Phase 1.4 – Update Code Files (HIGH PRIORITY)

**Files:**
- `collector_service/tests/sample_event.json` - 🔥 **CRITICAL**
- `collector_service/README.md` - 🔥 **CRITICAL**
- `tests/regression/test_api_endpoints.py` - 🟦 **MEDIUM**
- `tests/performance/locustfile.py` - 🟦 **MEDIUM**
- `tests/resilience/test_recovery.py` - 🟦 **MEDIUM**
- `tests/regression/test_ingestion_flow.py` - 🟦 **MEDIUM**

**Checklist:**

**1. sample_event.json:**
- [ ] Replace entire file with proposed version using:
  - Project UUID: `8212caa2-b928-4213-b64e-9f5b86f4cad1`
  - Site UUID: `89a66770-bdcc-4c95-ac97-e1829cb7a960`
  - Device UUID: `bc2c5e47-f17e-46f0-b5e7-76b214f4f6ad`
  - Full parameter_key format: `project:8212caa2-...:voltage`
  - Timestamp: `2025-11-14T12:00:00Z`

**2. README.md:**
- [ ] Update Main example (lines 23-45) - Use proposed version
- [ ] Update SMS Protocol example (lines 85-99) - Full parameter_key format
- [ ] Update GPRS Protocol example (lines 103-128) - Full parameter_key format
- [ ] Update cURL example (lines 137-150) - Full parameter_key format
- [ ] Add warning box after examples section:
  ```markdown
  > ⚠️ **IMPORTANT**  
  > The `parameter_key` field MUST exactly match the `key` column in the `parameter_templates` table.  
  > Always use the full format: `project:<project_uuid>:<parameter_name_lowercase_with_underscores>`  
  > Short-form keys like `"voltage"` or `"current"` are invalid and will cause foreign-key errors when the worker inserts into the database.  
  > 
  > For full details, see **Module 6 – Parameter Template Manual** in the `docs/` directory.
  ```

**3. Test Files (UUID Standardization - Option A):**
- [ ] `tests/regression/test_api_endpoints.py` - Update project_id, site_id, parameter_key
- [ ] `tests/performance/locustfile.py` - Update project_id, site_id
- [ ] `tests/resilience/test_recovery.py` - Update project_id, site_id
- [ ] `tests/regression/test_ingestion_flow.py` - Update project_id, site_id, parameter_key

**Helper grep (from project root):**
```bash
grep -R --line-number '"parameter_key": "voltage"' .
grep -R --line-number '"parameter_key": "current"' .
grep -R --line-number '"parameter_key": "power"' .
grep -R --line-number '4360b675-5135-435d-b281-93a551a3986d' .  # Old project UUID
grep -R --line-number '11cede34-1e6a-47f2-b7b2-8fc4634a760a' .  # Old site UUID
```

**Verification:**
- [ ] All grep commands return 0 results (or only in this checklist file)
- [ ] All test files use documentation UUIDs
- [ ] All parameter_key values use full format

---

## 🟦 Phase 2 – Clarity & Consistency Fixes

### ✅ Phase 2.1 – Mark /monitor/* as PLANNED

**Files:**
- `docs/08_Monitoring_API_and_Packet_Health_Manual.md`
- `docs/12_API_Developer_Manual.md`
- `docs/11_Troubleshooting_and_Diagnostics_Manual.md`
- `docs/13_Performance_and_Monitoring_Manual.md`

**Checklist:**
- [ ] **Module 8 Section 4:** Add PLANNED FEATURE block at start:
  ```markdown
  > ⚠️ **PLANNED FEATURE**  
  > All `/monitor/*` endpoints are PLANNED and not implemented in the current release.  
  > Use `/v1/health` and `/metrics` for actual monitoring.
  ```
- [ ] **Module 8:** Under each `/monitor/*` endpoint (4.1, 4.2, 4.3, 4.4, 4.5), add:
  ```markdown
  **Status:** ⚠️ **PLANNED – Not implemented yet**
  ```
- [ ] **Module 12:** Confirm all `/monitor/*` endpoints are marked as "Planned" or "Future"
- [ ] **Module 11:** Check if any troubleshooting steps reference `/monitor/*` - add "planned" notes
- [ ] **Module 13:** Check if any references to `/monitor/*` - add "planned" notes

**Helper grep:**
```bash
grep -R --line-number "/monitor/" docs
```

**Verification:**
- [ ] All `/monitor/*` references clearly marked as PLANNED
- [ ] No confusion about which endpoints are available

---

### ✅ Phase 2.2 – Naming Conventions

**Files:**
- All modules (00–13), but especially 3, 4, 7, 9, 10, 11

**Checklist:**
- [ ] **Module 0:** Add Naming Conventions table (after Terminology section, before Section 2):
  ```markdown
  ### Naming Conventions
  
  Throughout this documentation, the following naming conventions are used:
  
  | Context | Name | Example |
  |---------|------|---------|
  | Kubernetes Deployment | `collector-service`, `admin-tool` | `kubectl get deploy collector-service` |
  | Kubernetes Pod | `nsready-db-0`, `nsready-nats-0` | `kubectl get pod nsready-db-0` |
  | Docker Compose Container | `nsready_db`, `collector_service`, `admin_tool` | `docker exec nsready_db` |
  | Namespace | `nsready-tier2` | `kubectl -n nsready-tier2` |
  
  **Usage Rules:**
  - Use `nsready-db-0` for Kubernetes commands
  - Use `nsready_db` for Docker Compose commands
  - Use `collector-service` for Kubernetes deployment name
  - Use `collector_service` for Docker Compose container name
  - Use `admin-tool` for Kubernetes deployment name
  - Use `admin_tool` for Docker Compose container name
  ```
- [ ] **All Modules:** Standardize all commands:
  - Kubernetes: `nsready-db-0`, `nsready-nats-0`, `collector-service`, `admin-tool`
  - Docker: `nsready_db`, `collector_service`, `admin_tool`

**Helper grep (to scan variants):**
```bash
grep -R --line-number "nsready_db" docs
grep -R --line-number "nsready-db-0" docs
grep -R --line-number "collector_service" docs
grep -R --line-number "collector-service" docs
grep -R --line-number "admin_tool" docs
grep -R --line-number "admin-tool" docs
```

**Verification:**
- [ ] Naming conventions table added to Module 0
- [ ] All commands use correct naming based on context (K8s vs Docker)

---

### ✅ Phase 2.3 – Cross-Reference Section

**Files:**
- All `docs/0*_*.md` and `docs/1*_*.md` (Modules 00-13)

**Checklist:**
- [ ] **Each Module:** Add "Related Modules" section at the end (before "End of Module X"):
  ```markdown
  **Related Modules:**
  
  - **Module 6** – Parameter Template Manual
  - **Module 7** – Data Ingestion & Testing Manual
  - **Module 8** – Monitoring API & Packet Health Manual
  - **Module 9** – SCADA Integration Manual
  - **Module 11** – Troubleshooting Manual
  - **Module 12** – API Developer Manual
  ```
- [ ] **Module-Specific Additions:**
  - Module 0: Add reference to Module 6 (parameter_key) and Module 8 (/v1/health & /metrics)
  - Module 1: Add reference to Module 10 (scripts)
  - Module 2: Add reference to Module 6 (parameter_key format)
  - Module 3: Add reference to Module 9 (SCADA-specific DB usage)

**Verification:**
- [ ] All modules have "Related Modules" section
- [ ] Module-specific cross-references added

---

### ✅ Phase 2.4 – Queue Depth Thresholds

**Files:**
- `docs/08_Monitoring_API_and_Packet_Health_Manual.md`
- `docs/13_Performance_and_Monitoring_Manual.md`

**Checklist:**
- [ ] **Module 8:** Ensure queue-depth table uses:
  - `0–5` → Normal
  - `6–20` → Warning
  - `21–100` → Critical
  - `>100` → Overload
- [ ] **Module 13:** Ensure Grafana panels & alert rules match same threshold ranges:
  - `0–5` → Normal
  - `6–20` → Warning
  - `21–100` → Critical
  - `>100` → Overload

**Helper grep:**
```bash
grep -R --line-number "queue_depth" docs
grep -R --line-number "0-5" docs
grep -R --line-number "6-20" docs
grep -R --line-number "21-100" docs
grep -R --line-number "> 100" docs
```

**Verification:**
- [ ] All queue depth thresholds match standardized values
- [ ] Consistent formatting (use `→` arrow notation)

---

## 🟩 Phase 3 – Enhancements & Duplicate Cleanup

### ✅ Phase 3.1 – Module-Specific Enhancements

**Checklist:**
- [ ] **Module 0:** Mention Module 6 (parameter_key) and Module 8 (/v1/health & /metrics) in relevant sections
- [ ] **Module 2:** Add note: "Collector never touches DB; workers do inserts."
- [ ] **Module 3:** Add note: "DB always stores full-form parameter_key."
- [ ] **Module 4:** In test section: "Use only full parameter_key format (see Module 6)."
- [ ] **Module 5:** Add cross-reference: "For correct parameter_key format, see Module 6 (canonical reference)."
- [ ] **Module 9:** Add note: "SCADA must map using full parameter_key, not display names."
- [ ] **Module 10:** Add pointer: "`parameter_template_template.csv` → generates full keys per Module 6."
- [ ] **Module 11:** Add troubleshooting note: "Foreign key errors usually mean short-form parameter_key was used."

**Verification:**
- [ ] All module-specific enhancements added
- [ ] Consistent messaging across modules

---

### ✅ Phase 3.2 – Remove Duplicate Explanations

**Files:**
- `docs/05_Configuration_Import_Manual.md`
- `docs/06_Parameter_Template_Manual.md`

**Checklist:**
- [ ] **Module 5:** Replace any detailed parameter_key field description with:
  ```markdown
  For full parameter_key rules, see Module 6 (canonical reference).
  ```
- [ ] **Module 6:** Ensure it remains the single source of truth for parameter_key format

**Verification:**
- [ ] Module 5 defers to Module 6 for parameter_key details
- [ ] Module 6 is the only place with full parameter_key format definition

---

## 📊 Final Verification

**Before marking complete, run all verification greps:**

```bash
# Check for short-form parameter_key (should return 0 results)
grep -R --line-number --ignore-case '"parameter_key": "voltage"' docs
grep -R --line-number --ignore-case '"parameter_key": "current"' docs
grep -R --line-number --ignore-case '"parameter_key": "power"' docs

# Check for old UUIDs (should return 0 results, or only in test files if keeping them)
grep -R --line-number '4360b675-5135-435d-b281-93a551a3986d' docs
grep -R --line-number '550e8400-e29b-41d4-a716-446655440000' docs

# Check for /monitor/* references (should all be marked as PLANNED)
grep -R --line-number "/monitor/" docs

# Check naming consistency
grep -R --line-number "nsready_db" docs | grep -v "Docker"
grep -R --line-number "collector_service" docs | grep -v "Docker"
```

**Final Checklist:**
- [ ] All Phase 1 tasks complete
- [ ] All Phase 2 tasks complete
- [ ] All Phase 3 tasks complete
- [ ] All verification greps pass
- [ ] Code files updated (sample_event.json, README.md, test files)
- [ ] Documentation is consistent and accurate

---

## 📝 Notes

- **UUID Standardization:** Using Option A - documentation UUIDs (`8212caa2-...`) everywhere
- **Test Files:** All 4 test files need UUID updates for consistency
- **Execution Order:** Complete Phase 1 first (critical fixes), then Phase 2, then Phase 3
- **Verification:** Run grep commands after each phase to verify fixes

---

**Status:** ✅ **READY FOR EXECUTION**

**Estimated Total Time:** 2-3 hours (including verification)

**Next Step:** Begin Phase 1.1 - Replace short-form parameter_key in docs

