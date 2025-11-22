# NSReady / NSWare – Project Backup & Versioning Policy  

**Version:** 1.1  
**Status:** Approved  
**Last Updated:** 2025-11-22

---

## 1. Purpose

This policy defines the **standard backup and versioning process** for all work under the NSReady / NSWare platform, including:

- Documentation (READMEs, design docs, manuals)
- Source code (backend, frontend, scripts, tests)
- Infrastructure definitions (Docker, K8s, deployment configs)
- Database migrations (`db/migrations/*.sql`)
- Architecture and security specifications

The objective is to ensure:

- No accidental data or history loss  
- Every significant change is reversible  
- Changes are traceable and auditable  
- The same safe process is followed for **NSReady** and **NSWare** work.

---

## 2. Scope

This policy applies to:

- All repositories under `ntppl_nsready_platform` and related NSReady/NSWare repos.
- All contributors (internal or external) making changes to:
  - Core code
  - Documentation
  - Architecture diagrams
  - Security/tenant model specifications
  - CI/CD pipelines
  - Database migrations
  - Module structures and README restructuring

**Default rule:**  
If a change is more than a one-line typo fix, this policy applies.

---

## 3. Key Concepts

### 3.1 CHANGE_NAME

For every work item, define a short, meaningful identifier:

**Examples:**
- `readme_restructure`
- `nsready_tenant_model_update`
- `nsware_dashboard_layout_v2`
- `module_m03_mapserver_architecture`
- `db_migration_150_parent_customer`

This will be used in:
- Backup folder names  
- Git branch names  
- Commit messages  
- Tags (optional)

---

## 4. Backup Layers (Three-Layer Safety Model)

Each significant change must be protected with **three layers of backup**:

1. **File-level backup inside `backups/`**  
2. **Git backup branch**  
3. **(Optional but recommended) Git tag**

### 4.1 Layer 1 – File-Level Backup (`backups/`)

A dedicated backup folder is kept **inside the repository**:

```text
backups/
    YYYY_MM_DD_CHANGE_NAME/
        README.md
        master_docs/
        [any other impacted files or folders]

Example:
backups/
    2025_11_22_readme_restructure/
        README.md
        master_docs/
```

**Command template:**

```bash
CHANGE_NAME="readme_restructure"
mkdir -p backups/$(date +%Y_%m_%d)_$CHANGE_NAME
cp README.md backups/$(date +%Y_%m_%d)_$CHANGE_NAME/
cp -r master_docs backups/$(date +%Y_%m_%d)_$CHANGE_NAME/
# Add more cp commands here if other files/folders will be modified
```

**Rule:**  
Back up every file/folder that will be touched in the change.

#### 4.1.1 Git Strategy for `backups/` Folder

The `backups/` folder is **excluded from git** (via `.gitignore`) because:
- File-level backups are local safety nets, not long-term archival
- Git branches and tags provide permanent versioning
- Prevents repository bloat

To preserve folder structure:
```bash
touch backups/.gitkeep
git add backups/.gitkeep
```

**Important:** File-level backups are temporary (30-90 day retention). For permanent archival, rely on git branches and tags.

#### 4.1.2 Large File Handling

For large files or generated content:
- Files >10MB: Consider git LFS or external storage
- Generated files (`node_modules/`, build artifacts): Exclude from backups (already in `.gitignore`)
- If backup >100MB: Use selective backup (only changed files, not entire directories)

---

### 4.2 Layer 2 – Git Backup Branch

Before editing anything, create a backup branch:

**Naming convention:**
```
backup/YYYY-MM-DD-CHANGE_NAME
```

**Example:**

```bash
CHANGE_NAME="readme_restructure"
git checkout -b backup/$(date +%Y-%m-%d)-$CHANGE_NAME
git add .
git commit -m "Backup before $CHANGE_NAME"
git push origin backup/$(date +%Y-%m-%d)-$CHANGE_NAME
```

This branch acts as a permanent snapshot before the change.

---

### 4.3 Layer 3 – Git Tag (Optional but Recommended)

For major changes (e.g., README restructure, tenant model update, module release), create a tag:

**Example:**

```bash
git tag -a vBACKUP-2025-11-22 -m "Backup before README restructure"
git push --tags
```

Tags make it easy to jump back to a known-safe point.

---

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
   # Dry-run validation (if psql supports it)
   psql --dry-run -f db/migrations/NEW_MIGRATION.sql
   # Or use a test database
   ```

**Note:** For database data backups (not schema), see:
- `scripts/backups/backup_pg.sh` - PostgreSQL data backup
- `scripts/backups/backup_jetstream.sh` - NATS JetStream backup
- `RUNBOOK_Restore.md` - Restore procedures

---

## 5. Versioning Rules

### 5.1 Git Versioning (Primary)

All repositories use Git as the source of truth:

- Work is done in feature/chore branches.
- Backups are done in backup branches.
- Releases or milestones can be marked with tags.

**Example branch types:**

```
backup/2025-11-22-readme_restructure      # Pre-change backup
chore/2025-11-22-readme_restructure       # Actual implementation branch
feature/nsware-dashboard-v2               # New feature
fix/nsready-ingestion-bug-123             # Bugfix
```

---

### 5.2 Documentation Versioning

Every major document (especially in `master_docs/` and core READMEs) should include:

```
Version: X.Y
Status: Draft / Approved / Deprecated
Last Updated: YYYY-MM-DD
```

**Example:**

```markdown
# NSReady Tenant Model – Design Overview  

Version: 1.1  
Status: Approved  
Last Updated: 2025-11-22
```

**Simple semantic versioning guideline:**

- `X.0` – Major restructure or conceptual change
- `X.Y` – Increment for each approved refinement
- `Deprecated` – When document is no longer current, but kept for history

---

### 5.3 README Version Tag (Optional)

For critical READMEs (root, module index, architecture overview), you may add a non-rendered comment:

```html
<!-- Version: README restructure v1.0 (2025-11-22) -->
```

This helps to track which iteration is currently deployed.

---

## 6. Standard Workflow (Applies to NSReady & NSWare)

This workflow must be followed for all major changes, including but not limited to:

- NSReady backend changes (admin_tool, collector_service, db)
- NSWare frontend changes (frontend_dashboard)
- Documentation restructures (root README, module docs)
- Architecture diagrams and security specs
- CI/CD or deployment changes
- Database migrations

---

### Step 1 – Define the Change

Set:

```bash
CHANGE_NAME="<short-descriptor>"
```

**Examples:**
- `readme_restructure`
- `nsready_security_docs_v1`
- `nsware_kpi_dashboard_layout`
- `db_migration_150_parent_customer`

---

### Step 2 – Create File-Level Backup

```bash
mkdir -p backups/$(date +%Y_%m_%d)_$CHANGE_NAME
cp README.md backups/$(date +%Y_%m_%d)_$CHANGE_NAME/
cp -r master_docs backups/$(date +%Y_%m_%d)_$CHANGE_NAME/
# Add additional cp commands for any other impacted folders
# (e.g., docs/, deploy/, frontend_dashboard/, db/migrations/, etc.)
```

**For database migrations, also:**
```bash
cp -r db/migrations backups/$(date +%Y_%m_%d)_$CHANGE_NAME/db_migrations
```

**Or use the automation script:**
```bash
./scripts/backup_before_change.sh $CHANGE_NAME --files README.md master_docs/
```

---

### Step 2.5 – Verify Backups

After creating backups, verify they're valid:

```bash
# Verify file backup exists and has content
ls -lh backups/$(date +%Y_%m_%d)_$CHANGE_NAME/

# Verify files were copied correctly (should show no differences)
diff -r README.md backups/$(date +%Y_%m_%d)_$CHANGE_NAME/README.md || echo "Files match"

# For database migrations, verify SQL files exist
if [ -d "db/migrations" ]; then
    ls -lh backups/$(date +%Y_%m_%d)_$CHANGE_NAME/db_migrations/
fi
```

---

### Step 3 – Create Git Backup Branch

```bash
git checkout -b backup/$(date +%Y-%m-%d)-$CHANGE_NAME
git add .
git commit -m "Backup before $CHANGE_NAME"
git push origin backup/$(date +%Y-%m-%d)-$CHANGE_NAME
```

**Verify branch was created:**
```bash
git branch -r | grep backup/$(date +%Y-%m-%d)-$CHANGE_NAME
```

**(Optional) Tag:**

```bash
git tag -a vBACKUP-$(date +%Y-%m-%d) -m "Backup before $CHANGE_NAME"
git push --tags
```

**Verify tag:**
```bash
git tag | grep vBACKUP-$(date +%Y-%m-%d)
```

**Or use the automation script:**
```bash
./scripts/backup_before_change.sh $CHANGE_NAME --tag
```

---

### Step 4 – Create Working Branch

This is where the actual change is implemented.

```bash
git checkout -b chore/$(date +%Y-%m-%d)-$CHANGE_NAME
```

(Or use `feature/` or `fix/` as appropriate.)

---

### Step 5 – Implement the Change

- Edit documentation
- Modify code
- Update architecture diagrams
- Adjust CI/CD configs
- Add database migrations (if applicable)

Always reference the change name in comments/headers when helpful.

---

### Step 6 – Run Validation Checklist

Before committing, validate:

- All folder names referenced in docs exist (no typos).
- All links in README/docs are valid.
- Heading levels are consistent (only one `#` at top, others `##`/`###`).
- No references to non-existent files (e.g., planned docs without neutral phrasing).
- Build/tests run where applicable (for code changes).
- For structure changes, AI tools (e.g., Cursor) can still navigate correctly.
- **For database migrations:** SQL syntax is valid, migration is idempotent (uses `IF NOT EXISTS`), and migration number follows sequence.

---

### Step 7 – Commit & Push

```bash
git add .
git commit -m "docs: <short description> (vX.Y)"   # Or "feat:", "fix:", etc.
git push origin chore/$(date +%Y-%m-%d)-$CHANGE_NAME
```

---

### Step 8 – Open Pull Request

PR description should include:

- What changed (summary)
- Which parts of the repo are affected
- **Confirmation that backups were taken:**
  - `backups/YYYY_MM_DD_CHANGE_NAME/` created
  - `backup/YYYY-MM-DD-CHANGE_NAME` branch pushed
  - Tag created (if applicable)
- Any additional validation performed

**Use the PR template** (see Section 13) to ensure all backup confirmations are included.

---

### Step 9 – Review & Merge

- At least one reviewer (where possible)
- Ensure validation checklist passed
- Verify backup confirmations in PR
- Merge via standard GitHub flow

---

### Step 10 – Tag the Change (for major changes)

```bash
git tag -a vX.Y-change-name -m "Description of change"
git push --tags
```

**Example:**

```bash
git tag -a v1.0-readme-restructure -m "NSReady/NSWare README split and repo structure documentation"
git push --tags
```

---

## 7. Rollback Procedure

If an issue is found after merging, you have multiple rollback options.

### 7.1 Restore From `backups/` Folder

**Example:**

```bash
cp backups/2025_11_22_readme_restructure/README.md README.md
cp -r backups/2025_11_22_readme_restructure/master_docs master_docs
```

Then commit & push.

---

### 7.2 Restore From Git Backup Branch

```bash
git checkout backup/2025-11-22-readme_restructure
# Inspect or cherry-pick as needed
```

You can cherry-pick or reset using this branch as a safe reference.

---

### 7.3 Restore From Tag

```bash
git checkout vBACKUP-2025-11-22
# Or compare diffs
```

---

### 7.4 Restore Database Migrations

If database migration needs rollback:

1. **Restore migration files:**
   ```bash
   cp -r backups/2025_11_22_CHANGE_NAME/db_migrations/*.sql db/migrations/
   ```

2. **Create rollback migration** (if schema was already applied):
   ```sql
   -- db/migrations/151_rollback_CHANGE_NAME.sql
   -- Rollback changes from migration 150
   ```

3. **Apply rollback migration** (see `RUNBOOK_Restore.md` for database restore procedures)

---

## 8. Responsibilities

### Change Owner

- Defines `CHANGE_NAME`
- Ensures all three backup layers (folder, branch, tag) are applied as required
- Follows validation checklist
- Prepares PR with backup confirmations

### Reviewer

- Confirms backup steps were followed (checks PR template)
- Checks structure, links, and consistency
- Verifies that README/docs/code still align with repository reality
- For database migrations: Verifies SQL syntax and migration sequence

### Admin / Maintainer

- Periodically reviews `backups/` for pruning/archival (see Section 12)
- Ensures tags and backup branches are documented or archived as needed
- Maintains backup automation scripts

---

## 9. When This Policy MUST Be Used

- README restructures (root or major module READMEs)
- NSReady core changes (admin_tool, collector_service, db)
- NSWare dashboard or core architectural changes
- Tenant model changes
- Security model changes
- Major CI/CD pipeline updates
- Any significant restructure of `docs/` or `master_docs/`
- **Database migration changes** (`db/migrations/*.sql`)

Minor typo fixes or single-line label changes may be exempt, but any doubt means the policy should be applied.

---

## 10. Policy Change Management

Any change to this policy itself (this file):

- Must follow this same policy (backup + branch + PR).
- Must include a Version bump at the top.
- Should be recorded in a change log at the end of this document:

**Change Log**

- `v1.1` – 2025-11-22 – Added database migration backups, verification steps, emergency procedures, retention policy, and automation guidance
- `v1.0` – 2025-11-22 – Initial policy defined for NSReady / NSWare backup and versioning

---

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
   git push --tags
   ```

4. **Document in PR:** State that emergency procedure was used and why

---

## 12. Backup Retention & Cleanup

### Retention Policy

- **File-level backups (`backups/`):** Keep for 90 days, then archive or delete
- **Git backup branches:** Keep indefinitely (lightweight, no cleanup needed)
- **Git tags:** Keep indefinitely

### Cleanup Process

**Quarterly cleanup (manual or automated):**

Use the cleanup script:
```bash
# Dry run to see what would be deleted
./scripts/cleanup_old_backups.sh --dry-run

# Remove backups older than 90 days
./scripts/cleanup_old_backups.sh

# Remove only test backups
./scripts/cleanup_old_backups.sh --test-only

# Archive before deleting
./scripts/cleanup_old_backups.sh --archive
```

**Manual cleanup:**

```bash
# List backups older than 90 days
find backups/ -type d -mtime +90

# Archive old backups (optional)
tar -czf backups_archive_$(date +%Y_%m).tar.gz backups/2024_* backups/2025_01_* backups/2025_02_*

# Remove archived backups (after verifying archive is valid)
rm -rf backups/2024_* backups/2025_01_* backups/2025_02_*
```

**Note:** Git branches and tags require no cleanup and provide permanent history.

---

## 13. Automation & Tools

### 13.1 Automated Backup Script

Use `scripts/backup_before_change.sh` to automate backup creation:

```bash
# Basic usage
./scripts/backup_before_change.sh readme_restructure

# With tag and specific files
./scripts/backup_before_change.sh readme_restructure --tag --files README.md master_docs/

# For database migrations
./scripts/backup_before_change.sh db_migration_150 --files db/migrations/
```

See `scripts/backup_before_change.sh` for full documentation.

### 13.2 Cleanup Script

Use `scripts/cleanup_old_backups.sh` to safely remove old backups:

```bash
# Dry run to preview
./scripts/cleanup_old_backups.sh --dry-run

# Remove backups older than 90 days (default)
./scripts/cleanup_old_backups.sh

# Remove only test backups
./scripts/cleanup_old_backups.sh --test-only

# Archive before deleting
./scripts/cleanup_old_backups.sh --archive --days 90
```

### 13.3 Integration with Existing Backup Scripts

This policy covers **code and documentation** backups. For **data backups**, use:

- `scripts/backups/backup_pg.sh` - PostgreSQL data backup
- `scripts/backups/backup_jetstream.sh` - NATS JetStream backup
- `RUNBOOK_Restore.md` - Complete restore procedures

### 13.4 PR Template

Use the PR template (`.github/pull_request_template.md`) which includes a backup confirmation checklist.

---

## 14. Cross-Repository Coordination

If changes span multiple repositories (e.g., NSReady backend + NSWare frontend):

1. **Use the same `CHANGE_NAME`** across all affected repos
2. **Create backup branches in all repos** with the same naming pattern
3. **Link PRs** in PR descriptions:
   ```
   Related PRs:
   - NSReady backend: #123
   - NSWare frontend: #124
   ```
4. **Coordinate merge timing** if changes are interdependent

---

## 15. Change Impact Assessment

Before starting a change, assess:

- **Which services are affected?** (admin_tool, collector_service, frontend_dashboard, db)
- **Which environments?** (dev, staging, prod)
- **Rollback complexity?** (simple file restore vs. database migration rollback)
- **Dependencies?** (other repos, external services)

Document this assessment in the PR description.

---

## Appendix A: Quick Reference

### Backup Creation (Manual)

```bash
CHANGE_NAME="your_change_name"
DATE=$(date +%Y_%m_%d)
DATE_DASH=$(date +%Y-%m-%d)

# File backup
mkdir -p backups/${DATE}_${CHANGE_NAME}
cp [files] backups/${DATE}_${CHANGE_NAME}/

# Git branch
git checkout -b backup/${DATE_DASH}-${CHANGE_NAME}
git add . && git commit -m "Backup before ${CHANGE_NAME}"
git push origin backup/${DATE_DASH}-${CHANGE_NAME}

# Tag (optional)
git tag -a vBACKUP-${DATE_DASH} -m "Backup before ${CHANGE_NAME}"
git push --tags
```

### Backup Creation (Automated)

```bash
./scripts/backup_before_change.sh your_change_name --tag
```

### Verification

```bash
# Check file backup
ls -lh backups/$(date +%Y_%m_%d)_CHANGE_NAME/

# Check git branch
git branch -r | grep backup/$(date +%Y-%m-%d)-CHANGE_NAME

# Check tag
git tag | grep vBACKUP-$(date +%Y-%m-%d)
```

### Cleanup

```bash
# Preview what would be deleted
./scripts/cleanup_old_backups.sh --dry-run

# Remove old backups
./scripts/cleanup_old_backups.sh

# Remove test backups only
./scripts/cleanup_old_backups.sh --test-only
```

---

**End of Policy Document**
