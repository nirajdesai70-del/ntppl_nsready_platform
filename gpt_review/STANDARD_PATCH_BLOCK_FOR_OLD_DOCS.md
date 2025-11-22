# Standard Patch Block for Updating Older Docs

**Purpose:** Use this standard reference block to replace outdated test instructions in older documentation files.

**Scope:** This block is intended to update **only the testing-related sections** in older documents. Do not remove or replace configuration / operations content; only replace outdated "how to run tests" instructions and old script paths.

**Date:** 2025-01-XX

---

## Standard Reference Block

At the relevant place in each older doc (e.g., "Backend Testing" or "How to run tests" section), **replace old content with:**

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

**For any changes to backend test flow, update the main SOP first and keep this section aligned.**
```

---

## Path Clean-up Patterns

When updating older docs, apply these consistent replacements:

| Old Path | New Path |
|----------|----------|
| `./scripts/…` | `./shared/scripts/…` |
| `scripts/test_…` | `shared/scripts/test_…` |
| `tests/reports/` | `nsready_backend/tests/reports/` |
| `db/seed_registry.sql` | `nsready_backend/db/seed_registry.sql` |
| `scripts/export_scada_data.sh` | `shared/scripts/export_scada_data.sh` |
| `scripts/import_registry.sh` | `shared/scripts/import_registry.sh` |
| `scripts/export_registry_data.sh` | `shared/scripts/export_registry_data.sh` |
| `scripts/list_customers_projects.sh` | `shared/scripts/list_customers_projects.sh` |
| `scripts/parameter_template_template.csv` | `shared/scripts/parameter_template_template.csv` |
| `scripts/example_parameters.csv` | `shared/scripts/example_parameters.csv` |
| `scripts/registry_template.csv` | `shared/scripts/registry_template.csv` |

---

## Documents That Need Updates

**Files that still reference old paths:**

1. 🟡 `shared/scripts/CONFIGURATION_IMPORT_USER_GUIDE.md`
   - Multiple references to `scripts/` (should be `shared/scripts/`)
   - ~20+ occurrences

2. 🟡 `shared/scripts/ENGINEER_GUIDE_PARAMETER_TEMPLATES.md`
   - Multiple references to `./scripts/` → `./shared/scripts/`
   - ~15+ occurrences

3. 🟡 `shared/scripts/PARAMETER_TEMPLATE_IMPORT_GUIDE.md`
   - References to `./scripts/` → `./shared/scripts/`
   - ~7 occurrences

4. 🟡 `shared/scripts/SCADA_INTEGRATION_GUIDE.md`
   - References to `./scripts/export_scada_data.sh` → `./shared/scripts/export_scada_data.sh`
   - ~4 occurrences

5. 🟡 `shared/scripts/POSTGRESQL_LOCATION_GUIDE.md`
   - References to `scripts/backups/` – **TODO:** decide and document the new backups path (e.g., `shared/backups/` or `nsready_backend/backups/`)
   - Do not change this path until the new standard location is finalised
   - ~2 occurrences

6. 🟡 `shared/scripts/create_parameter_csv_guide.md`
   - References to `scripts/` → `shared/scripts/`
   - ~3 occurrences

---

## How to Apply Updates

### Option 1: Manual Update (Recommended)

1. Open each file listed above
2. Find the "Backend Testing" or "Testing" section
3. Replace old content with the standard reference block above
4. Apply path clean-up patterns throughout the file
5. Save and verify paths are correct

### Option 2: Use Cursor AI

**Prompt for Cursor:**

> "In the following docs, replace old backend test references with the standard block from `nsready_backend/tests/README_BACKEND_TESTS.md` and update paths as per the new repo layout:
> 
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
> - `db/seed_registry.sql` → `nsready_backend/db/seed_registry.sql`
> 
> For test sections, use the standard reference block pointing to `nsready_backend/tests/README_BACKEND_TESTS.md`."

---

## Verification Checklist

After updating each doc:

- [ ] Old script paths replaced with `shared/scripts/`
- [ ] Test sections use standard reference block
- [ ] Report paths point to `nsready_backend/tests/reports/`
- [ ] Seed file paths use `nsready_backend/db/seed_registry.sql`
- [ ] Links to main SOP are present: `nsready_backend/tests/README_BACKEND_TESTS.md`
- [ ] All code examples use updated paths
- [ ] File has been saved and verified

---

## Benefits of Standardization

✅ **Single Source of Truth:**
- All test procedures documented in one place (`nsready_backend/tests/README_BACKEND_TESTS.md`)
- Older docs just point to the main SOP
- Easier to maintain and update

✅ **Consistent Paths:**
- All paths use new repository structure
- No confusion between old and new paths
- Clear hierarchy: backend → `nsready_backend/`, shared → `shared/`

✅ **Reduced Duplication:**
- Test instructions not duplicated across multiple files
- Changes only need to be made in one place
- Less risk of outdated information

---

**Last Updated:** 2025-01-XX  
**Next Steps:** Apply standard block to the 6 documents listed above

