# Backend Test & Documentation Collection for GPT Review

## Purpose

This folder is for exporting backend test scripts and related markdown documentation (README / process docs) so ChatGPT can review them.

The collection process:
1. **Collects test files** (Bucket A) - Test markdown files and test shell scripts
2. **Collects documentation** (Bucket B) - README files and process/guide documentation
3. **Creates a combined bundle** - All files in one markdown file for easy upload to ChatGPT
4. **Copies individual files** - Each file is also copied with a type label (TEST/DOC/TEST+DOC)

## How to Run

```bash
cd /path/to/ntppl_nsready_platform
python gpt_review/collect_backend_tests.py
```

## Outputs

The script generates:

1. **`gpt_review/backend_tests_bundle.md`** - Combined view for upload to ChatGPT
   - Contains all test files (Section A)
   - Contains all README/process docs (Section B)
   - Structured for easy review

2. **`gpt_review/backend_tests/`** - Individual copies of each TEST/DOC file
   - Naming format: `<index>__<TYPE>__<path_with_slashes_as__>`
   - Example: `001__TEST__tests__backend__test_api.md`
   - Example: `012__DOC__docs__NSReady_Dashboard__04_Deployment_and_Startup_Manual.md`

## What Gets Collected

### Bucket A - Test Files

**Test Markdown Files:**
- `tests/**/*.md` - All markdown files under tests/
- `docs/**/*test*.md` - Test-related docs in docs/
- `**/test*.md` - Any markdown file starting with "test"
- `**/*_test.md` - Any markdown file ending with "_test.md"

**Test Shell Scripts:**
- `**/test*.sh` - Shell scripts starting with "test"
- `**/*_test.sh` - Shell scripts ending with "_test.sh"
- `scripts/**/*.sh` - **Filtered** to only include scripts with test-related keywords:
  - Contains: `test`, `check`, `health`, or `verify`

### Bucket B - README / Process Docs

**README Files:**
- Any file matching `README*.md` anywhere in the repo (except excluded folders)

**Process/Guide Documentation:**
- Any `.md` file under `docs/` where path or filename contains:
  - `process`, `procedure`, `howto`, `how_to`, `guide`, `runbook`
  - `ops`, `operation`, `deploy`, `deployment`, `setup`, `install`, `usage`
  - `backend`, `collector`, `data-collection`, `nsready`, `ns_ready`

## File Type Labels

Files are labeled based on which bucket(s) they match:

- **`TEST`** - Only matches Bucket A (test files)
- **`DOC`** - Only matches Bucket B (README/process docs)
- **`TEST+DOC`** - Matches both buckets (e.g., a test guide that's also documentation)

## Exclusions

The script skips files under:

- `.git` - Git repository files
- `node_modules` - Node.js dependencies
- `.venv`, `venv`, `env` - Python virtual environments
- `.idea`, `.vscode` - IDE configuration
- `dist`, `build` - Build output directories
- `gpt_review` - This folder itself (prevents recursion)
- Any hidden folder (starting with `.`)

## Notes

- **Idempotent**: Re-running the script overwrites the bundle and refreshes individual file copies
- **No modifications**: The script does not modify any original files; it only reads and exports them
- **Encoding**: Uses UTF-8 for reading files; falls back to latin-1 if UTF-8 fails
- **Standard library only**: Uses only Python standard library (`pathlib`, `os`, `fnmatch`, `shutil`)

## Usage with ChatGPT

Once the script has generated `backend_tests_bundle.md`:

1. **Upload the bundle** to ChatGPT for review
2. **Request specific analysis**, for example:
   - "Identify outdated instructions vs new docker layout"
   - "Standardize all procedures into one master test doc"
   - "Check which tests are outdated vs new docker structure"

ChatGPT can then:
- Read all test + README/process docs together
- Mark what is current vs outdated
- Propose clean, upgraded versions that can be pasted back into the codebase

---

**Last Updated**: 2025-01-XX


