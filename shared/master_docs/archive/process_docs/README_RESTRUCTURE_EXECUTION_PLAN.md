# README Restructure - Final Execution Plan

**Date:** 2025-11-18  
**Status:** ✅ Approved - Ready to Execute  
**Approach:** Option A - Align README with Actual Structure

---

## Executive Summary

This plan updates the root `README.md` to:
- ✅ Clearly distinguish NSReady (active) vs NSWare (future)
- ✅ Use only real folder names (no broken references)
- ✅ Explain backend split across `admin_tool/`, `collector_service/`, `db/`
- ✅ Clarify `docs/` vs `master_docs/` distinction
- ✅ Remove broken security doc reference

**No file moves, no reorganization, text-only changes.**

---

## Decisions Made (Section 11 Answers)

### Q1: Security Document Reference
**Decision:** Remove direct link, use neutral reference  
**Action:** Replace `docs/NSREADY_VS_NSWARE_SECURITY_SPLIT.md` with:
> "For a deeper NSReady vs NSWare security and roadmap view, refer to the planning documents under `master_docs/` (a dedicated `NSREADY_VS_NSWARE_SECURITY_SPLIT.md` will be added there in a future update)."

### Q2: Backend Organization Explanation
**Decision:** Yes, add explanation  
**Action:** Add explainer block in NSReady section:
> **NSReady backend is split across three main folders:**
> - `admin_tool/` – Admin APIs, configuration, registry, parameter management
> - `collector_service/` – Telemetry ingestion pipeline and queue/worker logic
> - `db/` – Database schema, migrations, initialization scripts

### Q3: Documentation Location Clarification
**Decision:** Yes, add subsection  
**Action:** Add "Documentation Layout" block:
> ### Documentation Layout
> - `docs/` – Module and implementation-related documentation (00–13, operational manuals, how-to guides).
> - `master_docs/` – High-level design, architecture, security position papers, planning and roadmap documents (NSReady + NSWare).

### Q4: Future Reorganization Mention
**Decision:** Yes, keep it light  
**Action:** Add note in Repository Structure section:
> **Note:** In the future, the backend folders (`admin_tool/`, `collector_service/`, `db/`) may be grouped under a single parent (e.g. `nsready_backend/`) for cleaner structure. For now, the README reflects the actual, current layout and does not assume any reorganization.

---

## Execution Phases

### Phase 1: Pre-Execution Verification ✅ (COMPLETE)

- [x] Verified security doc doesn't exist
- [x] Verified all folder names in current structure
- [x] Reviewed current README content
- [x] Confirmed docker-compose.yml uses actual folder names

**Status:** All checks passed

---

### Phase 2: README Update (30 min)

**Tasks:**
1. Backup current README
2. Add new "NSReady / NSWare Platform" header section
3. **REMOVE old "Project Structure" section completely** (lines 29-50)
4. **REPLACE with new "Repository Structure" section** (no duplicates!)
5. Add backend organization explanation
6. Add documentation layout clarification
7. Add future reorganization note
8. Update "How to Work" sections with correct folder names
9. Fix security doc reference (neutral text only, no markdown links)

**Critical Watch Points:**
- ⚠️ **Only ONE structure section** - Remove old "Project Structure", keep only new "Repository Structure"
- ⚠️ **Heading levels** - Only one `#` (top level), rest should be `##` or `###`
- ⚠️ **Security doc** - No markdown links like `[text](path.md)`, use neutral text only

**See:** `README_RESTRUCTURE_DIFF.md` for exact changes

---

### Phase 3: Validation (15 min)

**Checklist:**
- [ ] All folder names match actual structure
- [ ] No typos in folder names
- [ ] **Only ONE structure section exists** (old "Project Structure" removed)
- [ ] **Heading levels correct** - Only one `#` at top, rest are `##` or `###`
- [ ] **Security doc reference** - No markdown links, just neutral text
- [ ] All internal links work (if any)
- [ ] README is readable and flows well
- [ ] NSReady vs NSWare distinction is clear
- [ ] No broken references
- [ ] Existing sections (Tenant Model, Prerequisites, etc.) maintain consistent heading levels

---

### Phase 4: Optional Sub-README Updates (30 min - DEFERRED)

**Status:** Not required for initial execution  
**Future work:** Update sub-READMEs to align with new structure

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Typo in folder name | 🟢 Low | Medium | Validation phase checks all names |
| Broken internal link | 🟢 Low | Low | Manual verification |
| Readability issues | 🟢 Low | Low | Review before commit |

**Overall Risk:** 🟢 **LOW** - Text-only changes, easy to revert

---

## Rollback Plan

If issues discovered:
```bash
git checkout README.md
# or
cp README.md.backup README.md
```

**No data loss risk** - README is text-only.

---

## Success Criteria

- [x] All folder references match actual structure
- [x] NSReady vs NSWare distinction is clear
- [x] Active vs future work is clearly marked
- [x] No broken folder references
- [x] Backend organization is explained
- [x] Documentation layout is clarified
- [x] Security doc reference is non-breaking

---

## Next Steps

1. ✅ Review this execution plan
2. ✅ Review diff document (`README_RESTRUCTURE_DIFF.md`)
3. ⏳ **Execute Phase 2** (when ready)
4. ⏳ **Execute Phase 3** (validation)
5. ✅ Done

---

---

## GitHub Workflow (When Ready)

### Step 1: Create Branch
```bash
git checkout -b chore/readme-nsready-nsware-split
```

### Step 2: Apply Changes
- Copy "NEW" parts from `README_RESTRUCTURE_DIFF.md`
- Remove old "Project Structure" section completely
- Add new sections as documented

### Step 3: Validate
- Run validation checklist (Phase 3)
- Check heading levels
- Verify no duplicate structure sections

### Step 4: Commit
```bash
git commit -am "docs: clarify NSReady vs NSWare and update repository structure"
```

### Step 5: Push and Create PR
```bash
git push origin chore/readme-nsready-nsware-split
```

**PR Description:** See PR description template below.

---

## PR Description Template

**Title:** `Clarify NSReady vs NSWare and update root README structure`

**Body:**
```markdown
## Summary

- Introduces a clear NSReady (current) vs NSWare (future) distinction at the top of README.md.
- Replaces the old "Project Structure" section with an accurate "Repository Structure" reflecting the real folders (admin_tool/, collector_service/, db/, frontend_dashboard/, contracts/, deploy/, scripts/, tests/, docs/, master_docs/).
- Adds an explicit explanation of the NSReady backend split across admin_tool/, collector_service/, and db/.
- Clarifies documentation layout between docs/ (implementation) and master_docs/ (design/security/roadmap).
- Adds "How to Work in This Repo (For Humans & AI)" guidance for NSReady vs NSWare work.
- Replaces a broken link to a non-existent security split doc with a neutral reference to master_docs/.

## Impact

- No code changes, text-only.
- No changes to Docker, paths, or deployments.
- Low risk; easy rollback if needed.
```

---

**Ready to execute when you are!** 🚀

