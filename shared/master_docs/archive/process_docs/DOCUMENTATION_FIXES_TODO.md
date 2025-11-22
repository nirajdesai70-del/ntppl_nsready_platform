# NSReady Documentation – Gap & Improvement Correction TODO List

**Status:** ⏸️ **PENDING APPROVAL** - Review before execution

**Created:** 2025-11-18

**Purpose:** This document lists all identified inconsistencies, gaps, and recommended improvements across Modules 00–13. Each item is a clear, actionable correction task.

---

## 📋 Validation Summary

**Issues Confirmed:**
- ✅ Short-form `parameter_key` values found in Modules 0, 2, 4, 7 (CRITICAL)
- ✅ `/monitor/*` endpoints not clearly marked as PLANNED in Module 8
- ✅ Naming inconsistencies (nsready_db vs nsready-db-0, etc.)
- ✅ Missing cross-references between modules
- ✅ Queue depth thresholds need consistency check

**Total Modules Affected:** 14 (Modules 0-13)

---

## 🔥 PRIORITY 1: CRITICAL FIXES (Data Accuracy)

### Task Group 1.1: Fix parameter_key Format (CRITICAL)

**Impact:** High - Affects all ingestion examples and could mislead developers

**Files to Update:**
- `docs/00_Introduction_and_Terminology.md`
- `docs/02_System_Architecture_and_DataFlow.md`
- `docs/04_Deployment_and_Startup_Manual.md`
- `docs/07_Data_Ingestion_and_Testing_Manual.md` (MULTIPLE instances)

**Actions:**
1. **Module 0** - Replace ALL short-form `parameter_key` values with full format:
   - `"parameter_key": "voltage"` → `"parameter_key": "project:8212caa2-...:voltage"`
   - `"parameter_key": "current"` → `"parameter_key": "project:8212caa2-...:current"`
   - `"parameter_key": "power"` → `"parameter_key": "project:8212caa2-...:power"`
   - `"parameter_key": "temperature"` → `"parameter_key": "project:8212caa2-...:temperature"`
   - `"parameter_key": "humidity"` → `"parameter_key": "project:8212caa2-...:humidity"`
   - `"parameter_key": "status"` → `"parameter_key": "project:8212caa2-...:status"`

2. **Module 2** - Replace ALL short-form parameter_key values in architecture example

3. **Module 4** - Replace ALL short-form parameter_key values in deployment test example

4. **Module 7** - Replace ALL short-form parameter_key values (found 8+ instances):
   - Line 65: `"parameter_key": "voltage"` → `"parameter_key": "project:8212caa2-...:voltage"`
   - Line 73: `"parameter_key": "current"` → `"parameter_key": "project:8212caa2-...:current"`
   - Line 214: `"parameter_key": "voltage"` → full format
   - Line 222: `"parameter_key": "current"` → full format
   - Line 230: `"parameter_key": "power"` → full format
   - Lines 616-618: Multiple JSON examples need updating
   - Update text description on line 193
   - Check for any other short-form keys (temperature, humidity, status)

**Add Warning Box in Module 7:**
- Add after Section 2.2 (NormalizedEvent JSON Structure):
  ```markdown
  > ⚠️ **IMPORTANT**  
  > All `parameter_key` values in real ingestion MUST use the full format  
  > `project:<project_uuid>:<parameter_name>`.  
  > Short-form keys like `"voltage"` will cause foreign-key errors.
  ```

**Estimated Effort:** 30 minutes

---

### Task Group 1.2: Strengthen Module 6 as Canonical Reference

**Impact:** High - Module 6 should be the single source of truth

**File:** `docs/06_Parameter_Template_Manual.md`

**Actions:**
1. Add at top of Module 6 (after title, before Section 1):
   ```markdown
   > ⚠️ **CANONICAL REFERENCE**  
   > This module defines the ONLY correct `parameter_key` format.  
   > All ingestion examples in other modules must follow this format.
   ```

2. Add boxed highlight in Section 5.1 (Parameter Key Generation):
   ```markdown
   > ⚠️ **IMPORTANT**  
   > Some modules show short-form keys for readability.  
   > Actual ingestion ALWAYS requires the full key format defined here.
   ```

**Estimated Effort:** 10 minutes

---

### Task Group 1.3: Fix Module 12 API Examples

**Impact:** High - This is the developer manual, must be accurate

**File:** `docs/12_API_Developer_Manual.md`

**Actions:**
1. Verify all examples already use full format (grep shows they do, but check for consistency)
2. Add explicit warning box in Section 6.1 (NormalizedEvent Schema), under "Field Details" table:
   ```markdown
   > ⚠️ **CRITICAL**  
   > The `parameter_key` field MUST exactly match `parameter_templates.key`.  
   > Always use the full format `project:<project_uuid>:<parameter>`.  
   > Short names like `"voltage"` are invalid.
   ```

3. Add cross-reference in Section 6.1:
   ```markdown
   For complete parameter_key format rules, see **Module 6 – Parameter Template Manual**.
   ```

**Estimated Effort:** 15 minutes

---

## 🟦 PRIORITY 2: CLARITY & CONSISTENCY FIXES

### Task Group 2.1: Mark Monitoring Endpoints as PLANNED

**Impact:** Medium - Prevents confusion about available endpoints

**Files:**
- `docs/08_Monitoring_API_and_Packet_Health_Manual.md`
- `docs/12_API_Developer_Manual.md`
- `docs/11_Troubleshooting_and_Diagnostics_Manual.md` (if references exist)
- `docs/13_Performance_and_Monitoring_Manual.md` (if references exist)

**Actions:**
1. **Module 8** - Add bold note at start of Section 4 (Planned Monitoring API Endpoints):
   ```markdown
   > ⚠️ **PLANNED FEATURE**  
   > All `/monitor/*` endpoints are PLANNED and not implemented in the current release.  
   > Use `/v1/health` and `/metrics` for actual monitoring.
   ```

2. **Module 8** - Add note to each `/monitor/*` endpoint section (4.1, 4.2, 4.3, 4.4, 4.5):
   ```markdown
   **Status:** ⚠️ **PLANNED – Not implemented yet**
   ```

3. **Module 12** - Verify all `/monitor/*` endpoints are marked as "Planned" (grep shows they are, verify consistency)

4. **Module 11** - Check if any troubleshooting steps reference `/monitor/*` endpoints and add notes

5. **Module 13** - Check if any performance examples reference `/monitor/*` endpoints

**Estimated Effort:** 20 minutes

---

### Task Group 2.2: Standardize Naming Conventions

**Impact:** Medium - Reduces confusion across modules

**Files:** All modules (00-13)

**Actions:**
1. **Create Global Legend** - Add to Module 0 (after Terminology section, before Section 2):
   ```markdown
   ### Naming Conventions
   
   Throughout this documentation, the following naming conventions are used:
   
   | Context | Name | Example |
   |---------|------|---------|
   | Kubernetes Deployment | `collector-service`, `admin-tool` | `kubectl get deploy collector-service` |
   | Kubernetes Pod | `nsready-db-0`, `nsready-nats-0` | `kubectl get pod nsready-db-0` |
   | Docker Compose Container | `nsready_db`, `collector_service`, `admin_tool` | `docker exec nsready_db` |
   | Namespace | `nsready-tier2` | `kubectl -n nsready-tier2` |
   ```
   
   **Usage Rules:**
   - Use `nsready-db-0` for Kubernetes commands
   - Use `nsready_db` for Docker Compose commands
   - Use `collector-service` for Kubernetes deployment name
   - Use `collector_service` for Docker Compose container name
   - Use `admin-tool` for Kubernetes deployment name
   - Use `admin_tool` for Docker Compose container name

2. **Standardize Across All Modules:**
   - Replace `nsready_db` → `nsready-db-0` (Kubernetes) or `nsready_db` (Docker Compose) with context
   - Replace `admin_tool` → `admin-tool` (deployment) or `admin_tool` (container) with context
   - Ensure `collector-service` (deployment) vs `collector_service` (container) is clear

**Files to Check:**
- Module 4 (deployment commands)
- Module 7 (testing commands)
- Module 9 (SCADA commands)
- Module 10 (script descriptions)
- Module 11 (troubleshooting commands)

**Estimated Effort:** 45 minutes

---

### Task Group 2.3: Add Cross-References

**Impact:** Medium - Improves navigation and reduces duplication

**Files:** All modules (00-13)

**Actions:**
1. **Add Standard Cross-Reference Section** to end of each module (before "End of Module X"):
   ```markdown
   **Related Modules:**
   
   - **Module 6** – Parameter Template Manual
   - **Module 7** – Data Ingestion & Testing Manual
   - **Module 8** – Monitoring API & Packet Health Manual
   - **Module 9** – SCADA Integration Manual
   - **Module 11** – Troubleshooting Manual
   - **Module 12** – API Developer Manual
   ```

2. **Module-Specific Cross-References:**
   - **Module 0** - Add reference to Module 6 for parameter_key, Module 8 for monitoring
   - **Module 1** - Add reference to Module 10 for scripts
   - **Module 2** - Add reference to Module 6 for parameter_key format
   - **Module 3** - Add reference to Module 9 for SCADA DB usage
   - **Module 4** - Add references to Module 6 (parameters), Module 7 (ingestion), Module 8 (monitoring)
   - **Module 5** - Add reference to Module 6 (parameter format), Module 12 (API rules)
   - **Module 7** - Add reference to Module 6 (parameter_key format)
   - **Module 8** - Add reference to Module 13 (performance thresholds)
   - **Module 9** - Add reference to Module 6 (parameter_key in views)
   - **Module 10** - Add reference to Module 6 (parameter key generation)
   - **Module 11** - Add reference to Module 6 (parameter_key troubleshooting)
   - **Module 12** - Add reference to Module 6 (canonical parameter_key format)
   - **Module 13** - Add reference to Module 8 (packet health logic)

**Estimated Effort:** 30 minutes

---

### Task Group 2.4: Ensure Queue Depth Threshold Consistency

**Impact:** Medium - Prevents conflicting guidance

**Files:**
- `docs/08_Monitoring_API_and_Packet_Health_Manual.md`
- `docs/13_Performance_and_Monitoring_Manual.md`

**Actions:**
1. **Verify Thresholds Match:**
   - Module 8 Section 5.8: Queue Health table
   - Module 13 Section 6.3: Queue Depth panel
   - Module 13 Section 11.1-11.2: Alert rules

2. **Standardize to (apply consistently):**
   ```
   0–5   → Normal
   6–20  → Warning
   21–100 → Critical
   >100  → Overload
   ```

3. **Update if inconsistencies found**

**Estimated Effort:** 15 minutes

---

## 🟩 PRIORITY 3: ENHANCEMENTS & POLISH

### Task Group 3.1: Module-Specific Enhancements

**Impact:** Low-Medium - Improves clarity and completeness

**Actions:**

1. **Module 0:**
   - Add note referencing Module 6 for full parameter_key explanation
   - Add note referencing Module 8 for real-time monitoring (`/v1/health` & `/metrics` only)

2. **Module 1:**
   - Ensure "JetStream" spelling is consistent (no "Jet Stream" or "Jet-Stream")
   - Verify script names match Module 10 exactly

3. **Module 2:**
   - Add explicit note: "Collector never touches DB; workers do inserts."
   - Ensure architecture diagram labels full parameter_key format

4. **Module 3:**
   - Add cross-reference to Module 9 for SCADA-specific DB usage
   - Add explicit note: "DB always stores full-form parameter_key."

5. **Module 4:**
   - Add note in testing section: "Use only full parameter_key format (see Module 6)."

6. **Module 5:**
   - Add cross-reference: "For correct parameter_key format, see Module 6 (canonical reference)."
   - Add note: "Generated `parameter_key` must be used exactly as-is when sending telemetry."

7. **Module 9:**
   - Add note: "SCADA must map using full parameter_key, not display names."
   - Reinforce: "Views `v_scada_latest` and `v_scada_history` always contain full `parameter_key`."

8. **Module 10:**
   - Verify all script descriptions match actual file names exactly
   - Add pointer: "`parameter_template_template.csv` → generates full keys per Module 6."

9. **Module 11:**
   - Add troubleshooting note: "Foreign key errors usually mean short-form parameter_key was used."
   - Ensure troubleshooting steps refer users back to Module 6

**Estimated Effort:** 45 minutes

---

### Task Group 3.2: Remove Duplicate Explanations

**Impact:** Low - Reduces maintenance burden

**Files:**
- `docs/05_Configuration_Import_Manual.md`
- `docs/06_Parameter_Template_Manual.md`

**Actions:**
1. **Module 5** - If parameter_key format is explained, replace with: "For full parameter_key rules, see Module 6 (canonical reference)."
2. **Module 6** - Ensure it remains the single source of truth for parameter_key format

**Estimated Effort:** 15 minutes

---

## 📊 Execution Summary

### Total Estimated Effort
- **Priority 1 (Critical):** ~55 minutes
- **Priority 2 (Clarity):** ~110 minutes
- **Priority 3 (Enhancements):** ~60 minutes
- **Total:** ~225 minutes (~3.75 hours)

### Files to Modify
- **14 modules** (00-13)
- **Primary focus:** Modules 0, 2, 4, 6, 7, 8, 12

### Risk Assessment
- **Low Risk:** Most changes are additions/clarifications
- **Medium Risk:** Parameter_key replacements (need to verify UUIDs are placeholders)
- **Mitigation:** Use placeholder format `project:8212caa2-...:voltage` consistently

---

## ✅ Pre-Execution Checklist

Before starting corrections:

- [ ] Review this TODO list for completeness
- [ ] Confirm parameter_key placeholder format (use `project:8212caa2-...:voltage` or actual UUIDs?)
- [ ] Confirm monitoring endpoint marking strategy (bold note vs. status field)
- [ ] Confirm cross-reference format preference
- [ ] Backup current documentation (git commit)

---

## 🚀 Execution Order

**Recommended Sequence:**

1. **Phase 1:** Critical fixes (Task Groups 1.1, 1.2, 1.3, 1.4)
   - Fix all parameter_key examples in docs
   - Strengthen Module 6
   - Fix Module 12
   - Update code files (sample_event.json, README.md, test files)

2. **Phase 2:** Clarity fixes (Task Groups 2.1, 2.2, 2.3, 2.4)
   - Mark monitoring endpoints
   - Standardize naming
   - Add cross-references
   - Verify queue thresholds

3. **Phase 3:** Enhancements (Task Groups 3.1, 3.2)
   - Module-specific enhancements
   - Remove duplicates

**📋 Detailed Execution Checklist:**
See `docs/EXECUTION_CHECKLIST.md` for phase-by-phase checklist with grep commands for verification.

---

## 📝 Notes

- All parameter_key replacements should use placeholder format: `project:8212caa2-...:voltage` (with ellipsis for readability)
- When adding cross-references, use consistent format: "**Module X** – [Title]"
- When marking planned features, use consistent format: "⚠️ **PLANNED – Not implemented yet**"
- Preserve all existing content; only add clarifications and corrections
- Check for ALL short-form parameter_key values: `voltage`, `current`, `power`, `temperature`, `humidity`, `status`

---

## 📋 Updates Based on Additional Review

**New Items Added/Clarified:**

1. ✅ **Expanded parameter_key search** - Now includes `temperature`, `humidity`, `status` in addition to `voltage`, `current`, `power`
2. ✅ **More specific warning box formats** - Exact markdown format provided for consistency
3. ✅ **Enhanced naming convention table** - Added usage rules for clarity
4. ✅ **Simplified cross-reference format** - Removed descriptions for cleaner look
5. ✅ **More specific module enhancement instructions** - Clearer, more concise wording
6. ✅ **Queue threshold format** - Standardized arrow notation (→) for consistency

**All suggestions from review have been incorporated into this TODO list.**

---

## 🔧 Additional Code Files to Update

**Note:** These are code files (not documentation) that should be updated for consistency:

### Task Group 1.4: Update Code Files (HIGH PRIORITY)

**Impact:** High - These are actual code files developers will copy/use

**Files:**
- `collector_service/tests/sample_event.json` - 🔥 **CRITICAL**
- `collector_service/README.md` - 🔥 **CRITICAL**
- `tests/regression/test_api_endpoints.py` - 🟦 **MEDIUM** (if UUIDs changed)
- `tests/performance/locustfile.py` - 🟦 **MEDIUM** (if UUIDs changed)
- `tests/resilience/test_recovery.py` - 🟦 **MEDIUM** (if UUIDs changed)
- `tests/regression/test_ingestion_flow.py` - 🟦 **MEDIUM** (if UUIDs changed)

**Actions:**

1. **`collector_service/tests/sample_event.json`** - Replace with proposed version:
   - Use documentation UUIDs: `8212caa2-b928-4213-b64e-9f5b86f4cad1` (project), `89a66770-bdcc-4c95-ac97-e1829cb7a960` (site)
   - Use full `parameter_key` format: `project:8212caa2-...:voltage`
   - Keep `device_id`: `bc2c5e47-f17e-46f0-b5e7-76b214f4f6ad` (matches both)
   - Update timestamp to recent date: `2025-11-14T12:00:00Z`

2. **`collector_service/README.md`** - Update ALL JSON examples:
   - Main example (lines 23-45) - Replace with proposed version
   - SMS Protocol example (lines 85-99) - Update parameter_key format
   - GPRS Protocol example (lines 103-128) - Update parameter_key format
   - cURL example (lines 137-150) - Update parameter_key format
   - Add warning box after examples section (as proposed)

3. **Test Files** - Update UUIDs if standardizing on documentation UUIDs:
   - `tests/regression/test_api_endpoints.py` - Update project_id, site_id, parameter_key
   - `tests/performance/locustfile.py` - Update project_id, site_id
   - `tests/resilience/test_recovery.py` - Update project_id, site_id
   - `tests/regression/test_ingestion_flow.py` - Update project_id, site_id, parameter_key

**UUID Standardization Decision:**
- ✅ **ADOPTED: Option A** - Use documentation UUIDs (`8212caa2-...`) everywhere
  - ✅ Maximum consistency
  - ✅ Requires updating 4 test files (accepted)
  - ✅ All files will use same UUIDs as documentation

**Status:** ✅ **DECISION MADE** - Proceeding with Option A

**Estimated Effort:** 30 minutes (20 min for sample_event.json + README, 10 min for test files if Option A)
   - Currently uses: `"parameter_key": "voltage"`
   - Should use: `"parameter_key": "project:<uuid>:voltage"`

2. **`collector_service/README.md`** - 🟦 **MEDIUM PRIORITY**
   - Update all examples to use full `parameter_key` format
   - Add note about parameter_key format requirement

**See `docs/CODE_CHANGES_REQUIRED.md` for details.**

---

**Status:** ⏸️ **AWAITING APPROVAL**

**Next Step:** Review and approve this TODO list, then execute corrections in phases.


