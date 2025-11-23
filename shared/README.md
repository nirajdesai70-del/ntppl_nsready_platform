# Shared Resources

This folder contains shared artifacts used across NSReady and NSWare platforms.

## Structure

- **`contracts/`** - Shared data contracts and schemas
  - Data contracts used by both NSReady and NSWare
  - API contracts and interfaces

- **`docs/`** - User-facing documentation
  - User manuals, guides, and tutorials
  - API documentation
  - User guides

- **`master_docs/`** - High-level design documents
  - Architecture specifications
  - Design documents
  - Policies and procedures
  - Project status and completion summaries
  - Execution plans and reviews

- **`deploy/`** - Deployment configurations
  - Kubernetes configurations
  - Helm charts
  - Docker Compose configurations
  - Traefik configurations
  - NATS JetStream configurations
  - Monitoring configurations

- **`scripts/`** - Utility scripts
  - Backup automation (`backup_before_change.sh`)
  - Cleanup scripts (`cleanup_old_backups.sh`)
  - Import/export utilities
  - Testing utilities

## Backup Script

The backup script is located at `shared/scripts/backup_before_change.sh`.

Run from repository root:
```bash
./shared/scripts/backup_before_change.sh <CHANGE_NAME> [--tag] [--files FILE1 FILE2 ...]
```

**Examples:**
```bash
# Basic backup
./shared/scripts/backup_before_change.sh my_change

# With tag and specific files
./shared/scripts/backup_before_change.sh my_change --tag --files README.md shared/master_docs/
```

See `shared/master_docs/PROJECT_BACKUP_AND_VERSIONING_POLICY.md` for backup policy details.

## Documentation

- **Backup Policy:** `shared/master_docs/PROJECT_BACKUP_AND_VERSIONING_POLICY.md`
- **Project Status:** `shared/master_docs/PROJECT_STATUS_AND_COMPLETION_SUMMARY.md`
- **Dashboard Clarification:** `shared/master_docs/NSREADY_VS_NSWARE_DASHBOARD_CLARIFICATION.md`
- **Execution Plans:** See `shared/master_docs/REPO_REORG_*.md` files

## Notes

- All shared resources are used by both NSReady and NSWare
- Documentation is organized by audience: `docs/` for users, `master_docs/` for developers/architects
- Scripts should be run from the repository root, not from within this folder


