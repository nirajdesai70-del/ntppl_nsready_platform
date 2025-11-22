# NSReady / NSWare – Proposed Code Changes

**Status:** 📋 Ready for Review  
**Context:** Code/example consistency updates for AI-readiness  
**Goal:** Ensure all code examples, tests, and sample files use consistent UUIDs and parameter_key format

---

## Overview

This document lists all proposed code changes that:
1. Update sample files and examples to use documentation UUIDs
2. Ensure parameter_key format consistency across all code
3. Add AI-readiness comments where appropriate

**All changes are in example/test files** - no production code changes required.

---

## PART 1 – Sample Files & Examples (Already Completed ✅)

### 1.1 Update collector_service/tests/sample_event.json ✅

**Status:** COMPLETED in previous execution

**File:** `collector_service/tests/sample_event.json`

**What Was Done:**
- ✅ Updated to use documentation UUIDs (`8212caa2-...`)
- ✅ All parameter_key values use full format
- ✅ Uses standard documentation format

**New Addition Needed:**
- Add comment in README or adjacent file noting NS-AI-COMPAT purpose

---

### 1.2 Update collector_service/README.md ✅

**Status:** COMPLETED in previous execution

**File:** `collector_service/README.md`

**What Was Done:**
- ✅ Updated all 4 JSON examples
- ✅ Added warning box about parameter_key format
- ✅ All examples use documentation UUIDs

**New Addition Needed:**
- Enhance warning box with NS-AI & DEV-GUIDE context
- Add note about future NSWare analytics/AI modules

---

### 1.3 Standardize UUIDs in test files ✅

**Status:** COMPLETED in previous execution

**Files Updated:**
- ✅ `tests/regression/test_api_endpoints.py`
- ✅ `tests/performance/locustfile.py`
- ✅ `tests/resilience/test_recovery.py`
- ✅ `tests/regression/test_ingestion_flow.py`

**What Was Done:**
- ✅ All test files use documentation UUIDs
- ✅ All parameter_key values use full format
- ✅ Dynamic parameter_key generation in locustfile.py

**New Addition Needed:**
- Add code comment in each test file about NS-AI-COMPAT purpose

---

## PART 2 – AI-Readiness Comments (NEW - Code Comments Only)

### 2.1 Add NS-AI-COMPAT comments to test files

**Files to Update:**
- `tests/regression/test_api_endpoints.py`
- `tests/performance/locustfile.py`
- `tests/resilience/test_recovery.py`
- `tests/regression/test_ingestion_flow.py`

**Changes:**

Add at top of each test file (after imports, before test functions):

```python
# NOTE(NS-AI-COMPAT): These IDs and parameter_keys match the documentation examples
# so docs, tests, and future analytics/AI samples all refer to the same entities.
# This ensures consistency across documentation, testing, and future NSWare AI modules.
```

**Purpose:** Document why we use specific UUIDs and format.

---

### 2.2 Add NS-AI-COMPAT note to sample_event.json README

**File to Update:**
- `collector_service/README.md` (already has warning, enhance it)

**Change:**

Enhance existing warning box:

```markdown
> ⚠️ **IMPORTANT (NS-AI & DEV-GUIDE)**  
> The `parameter_key` field MUST exactly match the `key` column in the `parameter_templates` table.  
> Always use the full format: `project:<project_uuid>:<parameter_name_lowercase_with_underscores>`  
> Short-form keys like `"voltage"` or `"current"` are invalid and will cause foreign-key errors.  
> 
> **NS-AI Compatibility:** This format ensures future NSWare analytics/AI modules can safely  
> join telemetry to parameter definitions and maintain stable feature engineering pipelines.
> 
> For full details, see **Module 6 – Parameter Template Manual** in the `docs/` directory.
```

**Purpose:** Explain AI-readiness benefit of correct format.

---

### 2.3 Add NS-AI-COMPAT comment to sample_event.json

**File to Update:**
- `collector_service/tests/sample_event.json`

**Note:** JSON doesn't support comments, so add note in adjacent README or create `sample_event.json.README.md`

**Alternative:** Add comment in `collector_service/tests/README.md`:

```markdown
## sample_event.json

This sample event uses:
- Full `parameter_key` format (`project:<uuid>:<name>`)
- Documentation UUIDs (`8212caa2-...`)

**NOTE (NS-AI-COMPAT):** This sample event uses full parameter_key format and documentation UUIDs  
so future analytics/ML can reuse test data directly. All test files should follow this pattern.
```

**Purpose:** Document why sample file uses specific format.

---

## PART 3 – No Production Code Changes Required

### 3.1 No schema changes

**Status:** ✅ No changes needed

- `ingest_events` table schema stays as-is
- No new columns required
- No migration scripts needed

---

### 3.2 No API changes

**Status:** ✅ No changes needed

- `/v1/ingest` endpoint stays as-is
- `/v1/health` endpoint stays as-is
- No new endpoints required

---

### 3.3 No worker changes

**Status:** ✅ No changes needed

- Worker logic stays as-is
- No new processing required
- No new validation rules

---

## Summary of Changes

### Already Completed ✅
- All PART 1 sample files and examples updated
- All test files use correct UUIDs and format

### New Additions Needed 📝
- **PART 2:** Add AI-readiness comments to test files (4 files)
- **PART 2:** Enhance README warning with NS-AI context (1 file)
- **PART 2:** Add sample_event.json documentation (1 new README or enhance existing)

### Total Impact
- **Code files to modify:** 5 files (all test/example files)
- **New files to create:** 0 (or 1 optional README)
- **Production code changes:** 0
- **All changes are comments/documentation** - no functional changes

---

## Verification Checklist

Before execution, verify:
- [ ] All PART 1 items are already completed (can skip those)
- [ ] PART 2 comments don't break any existing functionality
- [ ] Comments are clear and explain AI-readiness purpose
- [ ] All test files still pass after comment additions
- [ ] README enhancements maintain existing formatting

---

## Execution Order

1. **Review this document** - Confirm all changes are acceptable
2. **Verify PART 1 is complete** - Check that previous execution completed all items
3. **Execute PART 2** - Add comments to test files and enhance README
4. **Verify** - Run tests to ensure nothing broke
5. **Document** - Update execution checklist with completion status

---

**Status:** Ready for review and confirmation before execution.

