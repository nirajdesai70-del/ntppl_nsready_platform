# Repository Reorganization - Quick Checklist

**Quick reference for executing the repo reorganization**

---

## Pre-Migration Checklist

- [ ] Review `master_docs/REPO_REORGANIZATION_REVIEW_AND_EXECUTION_PLAN.md`
- [ ] Ensure current state is working: `docker-compose build && docker-compose up -d`
- [ ] Ensure git status is clean (or commit/stash changes)
- [ ] Run backup script (Phase 0)

---

## Phase 0: Backup (DO FIRST!)

```bash
./scripts/backup_before_change.sh repo_reorg_nsready_nsware --tag \
  --files README.md docker-compose.yml .gitignore Makefile scripts/ docs/ master_docs/ deploy/
```

**Verify:**
- [ ] Backup directory created: `backups/YYYY_MM_DD_repo_reorg_nsready_nsware/`
- [ ] Backup branch created: `backup/YYYY-MM-DD-repo_reorg_nsready_nsware`
- [ ] Backup tag created: `vBACKUP-YYYY-MM-DD`

---

## Phase 1: Create Folders

```bash
mkdir -p nsready_backend nsware_frontend shared
git add nsready_backend/ nsware_frontend/ shared/
git commit -m "chore: create new top-level folder structure"
```

---

## Phase 2: Move Backend

```bash
git mv admin_tool nsready_backend/admin_tool
git mv collector_service nsready_backend/collector_service
git mv db nsready_backend/db
git mv tests nsready_backend/tests
git commit -m "refactor: move backend folders to nsready_backend/"
```

**Verify:**
- [ ] `ls nsready_backend/` shows: admin_tool, collector_service, db, tests

---

## Phase 3: Move Frontend

```bash
git mv frontend_dashboard nsware_frontend/frontend_dashboard
git commit -m "refactor: move frontend_dashboard to nsware_frontend/"
```

**Verify:**
- [ ] `ls nsware_frontend/` shows: frontend_dashboard

---

## Phase 4: Move Shared

```bash
git mv docs shared/docs
git mv master_docs shared/master_docs
git mv deploy shared/deploy
git mv scripts shared/scripts

# Handle contracts
mkdir -p shared/contracts
git mv shared/docs/contracts/* shared/contracts/ 2>/dev/null || true
rmdir shared/docs/contracts 2>/dev/null || true

git commit -m "refactor: move shared folders to shared/"
```

**Verify:**
- [ ] `ls shared/` shows: contracts, docs, master_docs, deploy, scripts

---

## Phase 5: Update docker-compose.yml

**Change these paths:**
- `./admin_tool` → `./nsready_backend/admin_tool`
- `./collector_service` → `./nsready_backend/collector_service`
- `./db` → `./nsready_backend/db`

**Verify:**
```bash
docker-compose config  # Should pass
docker-compose build   # Should build successfully
```

```bash
git add docker-compose.yml
git commit -m "refactor: update docker-compose.yml build contexts"
```

---

## Phase 6: Update README.md

**Update:**
1. Repository Structure section
2. All path references (`scripts/` → `shared/scripts/`, etc.)
3. Script examples

**Verify:**
- [ ] All paths in README match actual structure
- [ ] No broken references

```bash
git add README.md
git commit -m "docs: update README.md for new structure"
```

---

## Phase 7: Update Scripts & Docs

**Update `shared/scripts/backup_before_change.sh`:**
- Line 83: `"master_docs/"` → `"shared/master_docs/"`

**Search and update docs:**
```bash
# Search for old paths in documentation
grep -r "admin_tool/" shared/master_docs/ shared/docs/ 2>/dev/null || echo "OK"
# Update any found references
```

**Verify:**
```bash
./shared/scripts/backup_before_change.sh test_run --files README.md
```

```bash
git add shared/scripts/ shared/docs/ shared/master_docs/
git commit -m "refactor: update script defaults and documentation paths"
```

---

## Phase 8: Create Folder READMEs & Dashboard Clarification (Recommended)

**Create:**
- `nsready_backend/README.md`
- `nsware_frontend/README.md`
- `shared/README.md`
- `shared/master_docs/NSREADY_VS_NSWARE_DASHBOARD_CLARIFICATION.md`

**Dashboard Clarification:**
- Documents critical distinction between NSReady UI (internal, under `nsready_backend/admin_tool/ui/`) and NSWare Dashboard (future SaaS platform, under `nsware_frontend/frontend_dashboard/`)
- Prevents confusion and namespace collisions

(Content in full execution plan)

```bash
git add nsready_backend/README.md nsware_frontend/README.md shared/README.md shared/master_docs/NSREADY_VS_NSWARE_DASHBOARD_CLARIFICATION.md
git commit -m "docs: add folder-level READMEs and dashboard clarification"
```

---

## Phase 9: Final Validation

**Structure Check:**
```bash
ls -la
ls nsready_backend/
ls nsware_frontend/
ls shared/
```

**Docker Check:**
```bash
docker-compose config
docker-compose build
docker-compose up -d
docker-compose ps
docker-compose down
```

**Script Check:**
```bash
./shared/scripts/backup_before_change.sh validation_test --files README.md
```

**Documentation Check:**
```bash
# Verify README matches reality
grep -E "(admin_tool|collector_service|db|frontend_dashboard)" README.md | head -5
```

**Git Check:**
```bash
git status  # Should be clean
git log --oneline -10  # Review commits
```

---

## Phase 10: Push Changes

```bash
# Review commits
git log --oneline -10

# Push main branch
git push origin main

# Push backup branch and tag
git push origin backup/YYYY-MM-DD-repo_reorg_nsready_nsware
git push origin vBACKUP-YYYY-MM-DD
```

---

## Rollback (If Needed)

```bash
# Restore from backup branch
git checkout backup/YYYY-MM-DD-repo_reorg_nsready_nsware
git checkout -b rollback/YYYY-MM-DD-repo_reorg
```

---

## Success Criteria

**Must Have:**
- [ ] All folders in correct locations
- [ ] `docker-compose config` passes
- [ ] `docker-compose build` succeeds
- [ ] Services start without errors
- [ ] Backup script works
- [ ] README.md updated
- [ ] Git history preserved

**Should Have:**
- [ ] Folder READMEs created
- [ ] Documentation paths updated
- [ ] Script defaults updated

---

**Quick Reference Created:** 2025-11-22

