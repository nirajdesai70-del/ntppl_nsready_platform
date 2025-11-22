#!/bin/bash
# backup_before_change.sh - Automated backup creation per PROJECT_BACKUP_AND_VERSIONING_POLICY.md
#
# Usage:
#   ./scripts/backup_before_change.sh <CHANGE_NAME> [--tag] [--files FILE1 FILE2 ...]
#
# Examples:
#   ./scripts/backup_before_change.sh readme_restructure
#   ./scripts/backup_before_change.sh readme_restructure --tag --files README.md master_docs/
#   ./scripts/backup_before_change.sh db_migration_150 --files db/migrations/
#
# This script implements the three-layer backup model:
#   1. File-level backup in backups/ folder
#   2. Git backup branch
#   3. Git tag (optional)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }

# Check if CHANGE_NAME is provided
if [ -z "$1" ]; then
    error "CHANGE_NAME is required"
    echo ""
    echo "Usage: $0 <CHANGE_NAME> [--tag] [--files FILE1 FILE2 ...]"
    echo ""
    echo "Examples:"
    echo "  $0 readme_restructure"
    echo "  $0 readme_restructure --tag --files README.md master_docs/"
    echo "  $0 db_migration_150 --files db/migrations/"
    echo ""
    echo "Options:"
    echo "  --tag              Create a git tag (vBACKUP-YYYY-MM-DD)"
    echo "  --files FILE ...   Specific files/folders to backup (default: README.md master_docs/)"
    echo ""
    exit 1
fi

CHANGE_NAME="$1"
DATE=$(date +%Y_%m_%d)
DATE_DASH=$(date +%Y-%m-%d)
BACKUP_DIR="backups/${DATE}_${CHANGE_NAME}"
BACKUP_BRANCH="backup/${DATE_DASH}-${CHANGE_NAME}"
TAG_NAME="vBACKUP-${DATE_DASH}"
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
            error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Default files if none specified
if [ ${#FILES_TO_BACKUP[@]} -eq 0 ]; then
    FILES_TO_BACKUP=("README.md" "shared/master_docs/")
    info "No files specified, using defaults: ${FILES_TO_BACKUP[*]}"
fi

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    error "Not in a git repository. Please run this script from the repository root."
    exit 1
fi

# Check if we have uncommitted changes (warn but don't fail)
if ! git diff-index --quiet HEAD --; then
    warning "You have uncommitted changes. They will be included in the backup branch."
    git status --short | head -10
    echo ""
    read -p "Continue? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Aborted by user"
        exit 0
    fi
fi

echo ""
info "🔒 Creating backups for change: ${CHANGE_NAME}"
echo ""

# Ensure backups directory exists
mkdir -p backups
if [ ! -f "backups/.gitkeep" ]; then
    touch backups/.gitkeep
fi

# Layer 1: File-level backup
info "📁 Creating file-level backup..."
mkdir -p "$BACKUP_DIR"

BACKUPED_COUNT=0
SKIPPED_COUNT=0
BACKUPED_FILES=()

for file in "${FILES_TO_BACKUP[@]}"; do
    # Check if file exists (as file or directory)
    if [ -e "$file" ] || [ -f "$file" ] || [ -d "$file" ]; then
        info "  Copying $file..."
        # Try to copy, handle both files and directories
        if cp -r "$file" "$BACKUP_DIR/" 2>/dev/null; then
            BACKUPED_COUNT=$((BACKUPED_COUNT + 1))
            BACKUPED_FILES+=("$file")
        elif cp "$file" "$BACKUP_DIR/" 2>/dev/null; then
            BACKUPED_COUNT=$((BACKUPED_COUNT + 1))
            BACKUPED_FILES+=("$file")
        else
            warning "  Failed to copy $file"
            SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        fi
    else
        warning "  $file does not exist, skipping"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    fi
done

if [ $BACKUPED_COUNT -eq 0 ]; then
    error "No files were backed up. Please check file paths."
    error "Attempted to backup: ${FILES_TO_BACKUP[*]}"
    exit 1
fi

success "File backup created: $BACKUP_DIR ($BACKUPED_COUNT file(s))"
if [ $SKIPPED_COUNT -gt 0 ]; then
    warning "$SKIPPED_COUNT file(s) were skipped (not found)"
fi

# Verify file backup
info "Verifying file backup..."
if [ ! -d "$BACKUP_DIR" ]; then
    error "File backup directory was not created"
    exit 1
fi

if [ -z "$(ls -A "$BACKUP_DIR")" ]; then
    error "File backup directory is empty"
    exit 1
fi

# Show what was backed up
info "Backed up files:"
for file in "${BACKUPED_FILES[@]}"; do
    if [ -d "$BACKUP_DIR/$(basename "$file")" ] || [ -f "$BACKUP_DIR/$(basename "$file")" ]; then
        size=$(du -sh "$BACKUP_DIR/$(basename "$file")" 2>/dev/null | cut -f1 || echo "unknown")
        echo "  ✅ $(basename "$file") ($size)"
    fi
done

success "File backup verified"

# Layer 2: Git backup branch
info ""
info "🌿 Creating git backup branch..."

# Get current branch to return to later
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "main")

# Check if branch already exists
if git rev-parse --verify "$BACKUP_BRANCH" >/dev/null 2>&1; then
    warning "Branch $BACKUP_BRANCH already exists"
    read -p "Use existing branch or create new one with timestamp? (e/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ee]$ ]]; then
        info "Using existing branch: $BACKUP_BRANCH"
        git checkout "$BACKUP_BRANCH"
    else
        BACKUP_BRANCH="${BACKUP_BRANCH}-$(date +%H%M%S)"
        info "Creating new branch with timestamp: $BACKUP_BRANCH"
        git checkout -b "$BACKUP_BRANCH"
    fi
else
    # Create backup branch
    git checkout -b "$BACKUP_BRANCH"
    success "Backup branch created: $BACKUP_BRANCH"
fi

# Stage all changes
git add .

# Commit if there are changes
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    git commit -m "Backup before ${CHANGE_NAME}" || {
        error "Failed to create commit"
        git checkout "$CURRENT_BRANCH" 2>/dev/null || true
        exit 1
    }
    success "Committed backup state"
else
    info "No changes to commit (working tree clean)"
fi

# Push branch
info "Pushing backup branch to remote..."
if git push -u origin "$BACKUP_BRANCH" 2>/dev/null; then
    success "Backup branch pushed: $BACKUP_BRANCH"
else
    warning "Could not push branch (remote may not be configured or accessible)"
    warning "Branch exists locally: $BACKUP_BRANCH"
fi

# Return to original branch if it exists
if [ -n "$CURRENT_BRANCH" ] && git rev-parse --verify "$CURRENT_BRANCH" >/dev/null 2>&1; then
    git checkout "$CURRENT_BRANCH" >/dev/null 2>&1 || true
fi

# Layer 3: Git tag (optional)
if [ "$CREATE_TAG" = true ]; then
    info ""
    info "🏷️  Creating git tag..."
    
    if git rev-parse "$TAG_NAME" >/dev/null 2>&1; then
        warning "Tag $TAG_NAME already exists"
        read -p "Overwrite existing tag? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git tag -d "$TAG_NAME" 2>/dev/null || true
            git push origin ":refs/tags/$TAG_NAME" 2>/dev/null || true
        else
            info "Skipping tag creation"
            CREATE_TAG=false
        fi
    fi
    
    if [ "$CREATE_TAG" = true ]; then
        git tag -a "$TAG_NAME" -m "Backup before ${CHANGE_NAME}"
        success "Tag created: $TAG_NAME"
        
        info "Pushing tag to remote..."
        if git push origin "$TAG_NAME" 2>/dev/null; then
            success "Tag pushed: $TAG_NAME"
        else
            warning "Could not push tag (remote may not be configured or accessible)"
            warning "Tag exists locally: $TAG_NAME"
        fi
    fi
fi

# Summary
echo ""
success "═══════════════════════════════════════════════════════════"
success "✅ Backup Summary"
success "═══════════════════════════════════════════════════════════"
echo ""
info "📁 File backup:     $BACKUP_DIR"
info "🌿 Git branch:      $BACKUP_BRANCH"
if [ "$CREATE_TAG" = true ]; then
    info "🏷️  Git tag:         $TAG_NAME"
fi
echo ""

# Generate PR description snippet
info "📋 Copy this summary to your PR description:"
echo ""
echo "---"
echo "**Backups created per PROJECT_BACKUP_AND_VERSIONING_POLICY.md:**"
echo ""
echo "- ✅ File-level backup: \`$BACKUP_DIR\`"
echo "- ✅ Git backup branch: \`$BACKUP_BRANCH\`"
if [ "$CREATE_TAG" = true ]; then
    echo "- ✅ Git tag: \`$TAG_NAME\`"
fi
echo ""
echo "**Files backed up:**"
for file in "${BACKUPED_FILES[@]}"; do
    echo "- \`$file\`"
done
echo "---"
echo ""

success "Backup process completed successfully! 🎉"
