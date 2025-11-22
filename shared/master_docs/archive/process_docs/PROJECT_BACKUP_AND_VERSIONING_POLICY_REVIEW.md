# Backup & Versioning Policy - Review & Gap Analysis

**Review Date:** 2025-11-22  
**Reviewer:** Policy Review  
**Status:** Pre-Implementation Review

---

## Executive Summary

The proposed **PROJECT_BACKUP_AND_VERSIONING_POLICY.md** provides a solid foundation for protecting code and documentation changes. The three-layer backup approach (file-level, git branch, git tag) is sound and well-structured.

**Overall Assessment:** ✅ **Helpful and comprehensive**, but several gaps need addressing before execution.

---

## ✅ Strengths

1. **Clear three-layer backup model** - Provides multiple recovery options
2. **Well-defined workflow** - Step-by-step process is easy to follow
3. **Applies to both NSReady & NSWare** - Unified approach across platform
4. **Includes rollback procedures** - Practical recovery guidance
5. **Versioning rules** - Clear documentation versioning standards
6. **Change naming convention** - Consistent `CHANGE_NAME` approach

---

## 🔴 Critical Gaps (Must Address)

### 1. **Backup Folder Git Strategy** ⚠️ CRITICAL
**Issue:** Policy doesn't specify whether `backups/` should be:
- Committed to git (bloats repository)
- Ignored in `.gitignore` (backups not versioned)
- Stored externally (requires additional infrastructure)

**Recommendation:**
- Add `backups/` to `.gitignore` by default
- Create `backups/.gitkeep` to preserve folder structure
- Document that backups are **local safety nets**, not long-term archival
- For long-term archival, use git branches/tags (which are already in the policy)

**Action Required:**
```bash
# Add to .gitignore
echo "backups/" >> .gitignore
echo "!backups/.gitkeep" >> .gitignore
```

### 2. **Database Migration Backups** ⚠️ CRITICAL
**Issue:** Policy covers code/docs but **doesn't mention database schema migrations** (`db/migrations/*.sql`).

**Current State:** Project has:
- `db/migrations/` with SQL migration files
- `scripts/backups/backup_pg.sh` for data backups
- `RUNBOOK_Restore.md` for restore procedures

**Recommendation:**
- Add explicit step: "If change affects `db/migrations/`, backup current migration state"
- Include database schema export in backup process
- Link to existing `RUNBOOK_Restore.md` for data restore procedures

**Action Required:** Add section 4.4 for database-specific backups.

### 3. **Backup Verification** ⚠️ CRITICAL
**Issue:** No step to verify backups are actually valid/restorable.

**Recommendation:**
- Add verification step after backup creation:
  - Verify git branch was created and pushed
  - Verify files were copied correctly (checksum or diff)
  - For database migrations, verify SQL syntax is valid

**Action Required:** Add verification checklist to Step 2/3.

### 4. **Emergency/Hotfix Procedures** ⚠️ IMPORTANT
**Issue:** Policy assumes normal workflow, but production emergencies may need expedited process.

**Recommendation:**
- Add "Emergency Change Procedure" section:
  - Minimum: Git backup branch (skip file-level backup if time-critical)
  - Post-change: Create file backup and tag retroactively
  - Document in PR that emergency procedure was used

**Action Required:** Add Section 11: Emergency Procedures.

---

## 🟡 Important Gaps (Should Address)

### 5. **Backup Retention Policy**
**Issue:** No guidance on when/how to clean up old backups.

**Recommendation:**
- Add retention policy:
  - File-level backups: Keep for 30-90 days, then archive/delete
  - Git backup branches: Keep indefinitely (they're lightweight)
  - Git tags: Keep indefinitely
- Add cleanup script or manual process

**Action Required:** Add Section 12: Backup Retention & Cleanup.

### 6. **Cross-Repository Coordination**
**Issue:** If changes span multiple repos (e.g., NSReady backend + NSWare frontend), how to coordinate?

**Recommendation:**
- Add guidance for multi-repo changes:
  - Use same `CHANGE_NAME` across repos
  - Create backup branches in all affected repos
  - Link PRs across repos in descriptions

**Action Required:** Add note in Section 6 workflow.

### 7. **Automation Script**
**Issue:** Policy mentions automation but doesn't provide it.

**Recommendation:**
- Create `scripts/backup_before_change.sh` that:
  - Takes `CHANGE_NAME` as parameter
  - Creates file-level backup
  - Creates git backup branch
  - Creates git tag (optional flag)
  - Verifies all steps succeeded
  - Outputs summary for PR description

**Action Required:** Create automation script (see suggested implementation below).

### 8. **CI/CD Integration**
**Issue:** No automated checks to ensure backups were created.

**Recommendation:**
- Add PR template checklist:
  - [ ] Backup branch created: `backup/YYYY-MM-DD-CHANGE_NAME`
  - [ ] File-level backup created: `backups/YYYY_MM_DD_CHANGE_NAME/`
  - [ ] Tag created (if major change): `vBACKUP-YYYY-MM-DD`
- Consider GitHub Actions workflow to validate backup branch exists

**Action Required:** Add PR template or GitHub Actions check.

### 9. **Large File Handling**
**Issue:** Policy doesn't address large binary files or generated content.

**Recommendation:**
- Add guidance:
  - For large files (>10MB), consider git LFS or external storage
  - For generated files (e.g., `node_modules/`, build artifacts), exclude from backups
  - Document in `.gitignore` what's excluded

**Action Required:** Add note in Section 4.1.

### 10. **Backup Size Limits**
**Issue:** No guidance on backup size limits or when to split backups.

**Recommendation:**
- Add practical limits:
  - File-level backups: If >100MB, consider selective backup (only changed files)
  - Git branches: No practical limit (git handles efficiently)
  - Document when to use selective vs. full backup

**Action Required:** Add guidance in Section 4.1.

---

## 🟢 Nice-to-Have Enhancements

### 11. **Backup Index/Manifest**
**Recommendation:** Create `backups/INDEX.md` that lists all backups with:
- Date, CHANGE_NAME, what was backed up, link to PR/branch

### 12. **Integration with Existing Backup Scripts**
**Recommendation:** Link policy to existing:
- `scripts/backups/backup_pg.sh` (database data)
- `scripts/backups/backup_jetstream.sh` (NATS JetStream)
- `RUNBOOK_Restore.md` (restore procedures)

### 13. **Change Impact Assessment**
**Recommendation:** Add step to assess impact:
- Which services affected? (admin_tool, collector_service, frontend_dashboard, db)
- Which environments? (dev, staging, prod)
- Rollback complexity?

### 14. **Documentation of Rationale**
**Recommendation:** Beyond backing up state, document:
- Why the change was made
- What problem it solves
- Alternative approaches considered

This could be in PR description or `CHANGELOG.md`.

---

## 📋 Recommended Modifications to Policy

### Modification 1: Add to Section 4.1 (File-Level Backup)

```markdown
### 4.1.1 Git Strategy for backups/

The `backups/` folder is **excluded from git** (via `.gitignore`) because:
- File-level backups are local safety nets, not long-term archival
- Git branches and tags provide permanent versioning
- Prevents repository bloat

To preserve folder structure:
```bash
touch backups/.gitkeep
git add backups/.gitkeep
```

**Important:** File-level backups are temporary (30-90 day retention). 
For permanent archival, rely on git branches and tags.
```

### Modification 2: Add Section 4.4 (Database Migration Backups)

```markdown
### 4.4 Layer 4 – Database Migration Backups (When Applicable)

If your change affects database schema (`db/migrations/*.sql`):

1. **Backup current migration state:**
   ```bash
   cp -r db/migrations backups/$(date +%Y_%m_%d)_$CHANGE_NAME/db_migrations
   ```

2. **Export current schema (optional but recommended):**
   ```bash
   # If database is accessible
   pg_dump -s -n public nsready > backups/$(date +%Y_%m_%d)_$CHANGE_NAME/schema_before.sql
   ```

3. **Validate new migration SQL syntax:**
   ```bash
   psql --dry-run -f db/migrations/NEW_MIGRATION.sql
   ```

**Note:** For database data backups, see `scripts/backups/backup_pg.sh` and `RUNBOOK_Restore.md`.
```

### Modification 3: Add Verification Step to Section 6

```markdown
### Step 2.5 – Verify Backups

After creating backups, verify they're valid:

```bash
# Verify file backup exists and has content
ls -lh backups/$(date +%Y_%m_%d)_$CHANGE_NAME/

# Verify git backup branch exists
git branch -r | grep backup/$(date +%Y-%m-%d)-$CHANGE_NAME

# Verify git tag (if created)
git tag | grep vBACKUP-$(date +%Y-%m-%d)

# Optional: Verify file integrity
diff -r README.md backups/$(date +%Y_%m_%d)_$CHANGE_NAME/README.md
# (Should show no differences if backup is correct)
```
```

### Modification 4: Add Section 11 (Emergency Procedures)

```markdown
## 11. Emergency Change Procedures

For production emergencies or hotfixes where time is critical:

### Expedited Backup Process

1. **Minimum required:** Create git backup branch
   ```bash
   git checkout -b backup/$(date +%Y-%m-%d)-$CHANGE_NAME
   git add .
   git commit -m "Emergency backup before $CHANGE_NAME"
   git push origin backup/$(date +%Y-%m-%d)-$CHANGE_NAME
   ```

2. **Implement the fix** in a separate branch

3. **Post-change:** Complete file-level backup and tag retroactively
   ```bash
   # After fix is deployed
   git checkout backup/$(date +%Y-%m-%d)-$CHANGE_NAME
   mkdir -p backups/$(date +%Y_%m_%d)_$CHANGE_NAME
   cp -r [affected-files] backups/$(date +%Y_%m_%d)_$CHANGE_NAME/
   git tag -a vBACKUP-$(date +%Y-%m-%d) -m "Emergency backup before $CHANGE_NAME"
   ```

4. **Document in PR:** State that emergency procedure was used and why
```

### Modification 5: Add Section 12 (Backup Retention)

```markdown
## 12. Backup Retention & Cleanup

### Retention Policy

- **File-level backups (`backups/`):** Keep for 90 days, then archive or delete
- **Git backup branches:** Keep indefinitely (lightweight, no cleanup needed)
- **Git tags:** Keep indefinitely

### Cleanup Process

**Quarterly cleanup (manual or automated):**

```bash
# List backups older than 90 days
find backups/ -type d -mtime +90

# Archive old backups (optional)
tar -czf backups_archive_$(date +%Y_%m).tar.gz backups/2024_* backups/2025_01_* backups/2025_02_*

# Remove archived backups
rm -rf backups/2024_* backups/2025_01_* backups/2025_02_*
```

**Note:** Git branches and tags require no cleanup and provide permanent history.
```

---

## 🛠️ Suggested Automation Script

Create `scripts/backup_before_change.sh`:

```bash
#!/bin/bash
# backup_before_change.sh - Automated backup creation per policy

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <CHANGE_NAME> [--tag] [--files FILE1 FILE2 ...]"
    echo "Example: $0 readme_restructure --tag --files README.md master_docs/"
    exit 1
fi

CHANGE_NAME="$1"
DATE=$(date +%Y_%m_%d)
DATE_DASH=$(date +%Y-%m-%d)
BACKUP_DIR="backups/${DATE}_${CHANGE_NAME}"
CREATE_TAG=false
FILES_TO_BACKUP=()

# Parse arguments
shift
while [[ $# -gt 0 ]]; do
    case $1 in
        --tag)
            CREATE_TAG=true
            shift
            ;;
        --files)
            shift
            while [[ $# -gt 0 ]] && [[ ! "$1" =~ ^-- ]]; do
                FILES_TO_BACKUP+=("$1")
                shift
            done
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Default files if none specified
if [ ${#FILES_TO_BACKUP[@]} -eq 0 ]; then
    FILES_TO_BACKUP=("README.md" "master_docs/")
fi

echo "🔒 Creating backups for change: $CHANGE_NAME"

# Layer 1: File-level backup
echo "📁 Creating file-level backup..."
mkdir -p "$BACKUP_DIR"
for file in "${FILES_TO_BACKUP[@]}"; do
    if [ -e "$file" ]; then
        echo "  Copying $file..."
        cp -r "$file" "$BACKUP_DIR/"
    else
        echo "  ⚠️  Warning: $file does not exist, skipping"
    fi
done

# Layer 2: Git backup branch
echo "🌿 Creating git backup branch..."
if git rev-parse --verify "backup/${DATE_DASH}-${CHANGE_NAME}" >/dev/null 2>&1; then
    echo "  ⚠️  Warning: Branch backup/${DATE_DASH}-${CHANGE_NAME} already exists"
else
    git checkout -b "backup/${DATE_DASH}-${CHANGE_NAME}"
    git add .
    git commit -m "Backup before ${CHANGE_NAME}" || echo "  ℹ️  No changes to commit"
    git push -u origin "backup/${DATE_DASH}-${CHANGE_NAME}" || echo "  ⚠️  Warning: Could not push branch"
    echo "  ✅ Backup branch created: backup/${DATE_DASH}-${CHANGE_NAME}"
fi

# Layer 3: Git tag (optional)
if [ "$CREATE_TAG" = true ]; then
    echo "🏷️  Creating git tag..."
    TAG_NAME="vBACKUP-${DATE_DASH}"
    if git rev-parse "$TAG_NAME" >/dev/null 2>&1; then
        echo "  ⚠️  Warning: Tag $TAG_NAME already exists"
    else
        git tag -a "$TAG_NAME" -m "Backup before ${CHANGE_NAME}"
        git push origin "$TAG_NAME" || echo "  ⚠️  Warning: Could not push tag"
        echo "  ✅ Tag created: $TAG_NAME"
    fi
fi

# Verification
echo ""
echo "✅ Backup Summary:"
echo "  📁 File backup: $BACKUP_DIR"
echo "  🌿 Git branch: backup/${DATE_DASH}-${CHANGE_NAME}"
if [ "$CREATE_TAG" = true ]; then
    echo "  🏷️  Git tag: vBACKUP-${DATE_DASH}"
fi
echo ""
echo "📋 Copy this summary to your PR description:"
echo "---"
echo "Backups created per PROJECT_BACKUP_AND_VERSIONING_POLICY.md:"
echo "- File-level backup: \`$BACKUP_DIR\`"
echo "- Git backup branch: \`backup/${DATE_DASH}-${CHANGE_NAME}\`"
if [ "$CREATE_TAG" = true ]; then
    echo "- Git tag: \`vBACKUP-${DATE_DASH}\`"
fi
echo "---"
```

---

## 📝 PR Template Addition

Add to `.github/pull_request_template.md` (or create if doesn't exist):

```markdown
## Backup Confirmation

- [ ] File-level backup created: `backups/YYYY_MM_DD_CHANGE_NAME/`
- [ ] Git backup branch created: `backup/YYYY-MM-DD-CHANGE_NAME`
- [ ] Git tag created (if major change): `vBACKUP-YYYY-MM-DD`
- [ ] Backups verified (files exist, branch pushed, tag pushed if applicable)

**Backup Summary:**
- File backup location: `backups/...`
- Backup branch: `backup/...`
- Tag (if applicable): `vBACKUP-...`
```

---

## ✅ Implementation Checklist

Before executing the policy:

- [ ] Add `backups/` to `.gitignore` (with `.gitkeep` exception)
- [ ] Create `scripts/backup_before_change.sh` automation script
- [ ] Add database migration backup section (4.4)
- [ ] Add verification step (2.5)
- [ ] Add emergency procedures section (11)
- [ ] Add backup retention section (12)
- [ ] Create/update PR template with backup checklist
- [ ] Test automation script with a dummy change
- [ ] Document integration with existing backup scripts (`scripts/backups/`)
- [ ] Review and approve final policy document

---

## 🎯 Conclusion

The policy is **solid and ready for implementation** after addressing the critical gaps above. The most important additions are:

1. **Git strategy for `backups/` folder** (critical)
2. **Database migration backup guidance** (critical)
3. **Backup verification step** (critical)
4. **Emergency procedures** (important)
5. **Automation script** (highly recommended)

Once these are addressed, the policy will be production-ready and provide comprehensive protection for all changes.

---

**Next Steps:**
1. Review this gap analysis
2. Implement recommended modifications
3. Create automation script
4. Test with a small change
5. Finalize and commit policy document

