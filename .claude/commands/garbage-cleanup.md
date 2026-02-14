# garbage-cleanup playbook

Repo-wide scan for deletable artifacts. Output is a **delete-only report** — do not list files to keep.

## --help

```
Usage: /garbage-cleanup [options]

Scans the repository for unused, stale, and redundant files, then produces
a markdown report of delete candidates. No files are modified unless you
explicitly set CLEANUP_MODE=move or CLEANUP_MODE=delete with DRY_RUN=false.

Phases:
  0  Git repository maintenance (prune, gc, large-object scan)
  1  Empty directories (empty or gitkeep-only)
  2  Build artifacts and temp files (__pycache__, dist/, *.log, etc.)
  3  One-time scripts (unreferenced setup/migration scripts)
  4  Stale generated output (orphaned state files, old evidence)
  5  Large gitignored artifacts (>10 MB on disk, never committed)
  6  Duplicate/redundant content (sha256 matches across locations)
  7  Secrets safety scan (flags accidental secrets in candidates)

Options (set as variables in the configuration section):
  CLEANUP_MODE    report (default) | move | delete
  DRY_RUN         true (default) | false
  TEMP_STALE_DAYS Days before temp files are flagged (default: 7)
  EVIDENCE_STALE_DAYS Days before evidence bundles are flagged (default: 30)
  LARGE_FILE_MB   Size threshold for gitignored artifacts (default: 10)
  REPORT_LIMIT    Max items in gitignored artifacts list (default: 20)
  TRASH_DIR       Move target for CLEANUP_MODE=move (default: .cleanup-trash)

Output:
  Single markdown report with tables per phase, sorted by disk impact.
  Only lists delete candidates — files to keep are never shown.

Examples:
  /garbage-cleanup                  Run default scan, report only
  /garbage-cleanup CLEANUP_MODE=move DRY_RUN=false   Move candidates to trash
```

## configuration

```bash
TEMP_STALE_DAYS=7           # Age threshold for temp/tmp directories
EVIDENCE_STALE_DAYS=30      # Age threshold for evidence bundles
LARGE_FILE_MB=10            # Size threshold for gitignored artifacts
REPORT_LIMIT=20             # Max items to show in gitignored artifacts list
CLEANUP_MODE=report         # report | move | delete (default: report)
TRASH_DIR=.cleanup-trash    # Move target when CLEANUP_MODE=move
DRY_RUN=true                # Preview operations without applying (true | false)
```

## execution modes

1. **report** (default): Generate report only, no file operations
2. **move**: Move files to `.cleanup-trash/` instead of deleting (allows undo)
3. **delete**: Permanent deletion (use with extreme caution)

**Dry-run mode**: When `DRY_RUN=true` (default), all operations are previewed without applying. Set `DRY_RUN=false` to execute.

**Interactive confirmation**: Before executing move/delete operations, display:
- Total files to affect
- Total disk space to recover
- Confirmation prompt: "Proceed with cleanup? [y/N]"

**Rollback from move mode**:
```bash
# Restore all items from last cleanup
rsync -av .cleanup-trash/<timestamp>/ ./

# Restore specific file
cp .cleanup-trash/<timestamp>/path/to/file ./path/to/file
```

Each move operation creates a manifest at `.cleanup-trash/<timestamp>/manifest.json` with original paths and restoration commands.

## prerequisites

Before running, verify:

- **Required tools**: `find`, `git`, `du`, `sort`, `xargs`, `sha256sum`, `grep`, `awk`
- **Optional tools**: `rsync` (for rollback), `git-filter-repo` or `bfg` (for secrets removal)
- **Git repository**: Run from the root of a git repository
- **Permissions**: May require `sudo` for root-owned files (will be noted in report)

**Validation**:
```bash
# Verify in git repo
git rev-parse --git-dir >/dev/null 2>&1 || { echo "Error: Not a git repository"; exit 1; }

# Verify at repo root
[ "$(git rev-parse --show-toplevel)" = "$(pwd)" ] || echo "Warning: Not at repo root"

# Check required commands
for cmd in find git du sort xargs sha256sum grep awk; do
  command -v $cmd >/dev/null 2>&1 || { echo "Error: $cmd not found"; exit 1; }
done

# Check optional commands
for cmd in rsync git-filter-repo bfg; do
  command -v $cmd >/dev/null 2>&1 || echo "Info: $cmd not found (optional)"
done
```

## scan phases

Run all phases. Collect findings into a single report at the end.

### phase 0: git repository maintenance (optional)

Perform git-specific cleanup and generate repository health metrics. This phase improves git performance but does not delete user files.

**Operations**:
```bash
# Remove stale remote branch references
git fetch --prune --prune-tags

# Garbage collection with aggressive optimization
git gc --aggressive --prune=now

# Repository size analysis
git count-objects -v

# Identify large objects in history (>5MB)
git rev-list --objects --all | \
  git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' | \
  awk '/^blob/ {if ($3 > 5242880) print $3, $4}' | \
  sort -rn | head -20
```

**Output**: Repository health summary with:
- Disk usage before/after gc
- Count of pruned references
- List of large objects in history (candidates for BFG Repo-Cleaner if needed)

**Note**: This phase only optimizes the `.git/` directory. It does not delete working tree files.

### phase 1: empty directories

Find directories that are empty or contain only `.gitkeep`. Include directories owned by root (note permission requirement). Exclude `.git/` internals.

```
find <repo> -type d -not -path '*/.git/*' -exec sh -c '
  files=$(find "$1" -maxdepth 1 -not -name ".gitkeep" -not -name "." -not -type d | head -1)
  subdirs=$(find "$1" -mindepth 1 -type d | head -1)
  [ -z "$files" ] && [ -z "$subdirs" ]
' _ {} \; -print
```

### phase 2: build artifacts and temp files

Scan for patterns that indicate build/temp output. Check each match — only flag if not referenced by active code.

**Versioning check for build directories**: Before flagging `dist/`, `build/`, `out/` directories, verify they are safe to delete:

```bash
# Check if directory is gitignored (safe to delete)
git check-ignore -q <directory> && echo "gitignored (safe)" || echo "versioned (SKIP)"

# For versioned build directories, flag as MANUAL_REVIEW instead of auto-delete
```

**patterns:**
- `__pycache__/`, `*.pyc`, `*.pyo`
- `node_modules/` outside of active project roots (see protected directories)
- `*.egg-info/` (safe - always gitignored)
- `dist/`, `build/`, `out/` — **verify gitignored first** (may be intentional distribution artifacts)
- `.mypy_cache/`, `.pytest_cache/`, `.ruff_cache/`
- `coverage/`, `.coverage`, `htmlcov/`
- `*.log` files not under version control
- `*.bak`, `*.orig`, `*.swp`, `*~`
- `temp/` or `tmp/` directories that contain only stale artifacts (>$TEMP_STALE_DAYS days old)
- Compiled binaries in directories with `Makefile` or `CMakeLists.txt` if gitignored

### phase 3: one-time scripts

Identify scripts that were used during initial setup or one-time migration and are no longer referenced.

**heuristics:**
- scripts not called by any other script:
  ```bash
  grep -rE '(\.|source|bash|sh|exec)\s+<scriptname>' --exclude-dir=.git --exclude='*.md' .
  ```
  (If no matches, script is not referenced by active code)
- scripts with names suggesting one-time use: `*migrate*`, `*setup*`, `*init*`, `*seed*`, `*fix-*`, `*patch-*`, `*one-time*`, `*hotfix*`
- scripts under `_build/Sprint-*/` or similar sprint/phase directories that are complete
- scripts with hardcoded absolute paths to this machine
- verify each candidate is not imported, sourced, or exec'd by anything active

### phase 4: stale generated output

- generated docs that duplicate or conflict with newer versions
- duplicate config files (same content, different locations)
- orphaned state files (`*.json`, `*.jsonl`) not read by any script
- evidence bundles older than $EVIDENCE_STALE_DAYS days

### phase 5: git-ignored but present

Check `.gitignore` patterns against what exists on disk. Flag large (>$LARGE_FILE_MB MB) gitignored artifacts that are consuming disk but will never be committed.

```bash
git ls-files --others --ignored --exclude-standard | xargs du -sh 2>/dev/null | sort -rh | head -$REPORT_LIMIT
```

### phase 6: duplicate/redundant content

Identify files with identical content (sha256 match) in different locations. Use auto-selection rules to recommend which copy to keep.

**Auto-selection priority** (keep the file matching highest priority rule):

1. **Folder priority**: Prefer files in production/source directories over backups
   - Keep: `src/`, `lib/`, `app/`, `main/`, `core/`
   - Delete: `backup/`, `old/`, `archive/`, `copy/`, `bak/`, `tmp/`

2. **Path depth**: Prefer shallower paths (fewer subdirectories)
   - Keep: `./config.json` over `./backup/old/archive/config.json`

3. **Naming convention**: Prefer clean names over timestamped/suffixed
   - Keep: `config.json` over `config-2026-01-15.json` or `config.bak`

4. **Modification time**: Prefer most recently modified (if all other rules tie)

**Output format for duplicates**:
```
| file a (KEEP) | file b (DELETE) | size | sha256 | reason |
|---------------|-----------------|------|--------|--------|
| src/main.py | backup/main.py | 4 KB | a1b2c3d4 | folder priority |
| ./cfg.json | ./old/cfg.json | 1 KB | b2c3d4e5 | path depth |
```

Also scan for:
- scripts that do the same thing under different names (compare first 50 lines, exclude shebangs/comments)
- README/doc files that describe the same system redundantly (compare after markdown normalization)

### phase 7: secrets scan (safety check)

Before finalizing the report, scan all flagged files for accidentally committed secrets. If found, remove from cleanup report and flag separately for secure handling.

**Secrets patterns to detect**:
```bash
# API keys, tokens, passwords
grep -rE '(api[_-]?key|token|password|secret|credentials?).*[=:]\s*["\047][a-zA-Z0-9_-]{20,}["\047]' <flagged-files>

# AWS keys
grep -rE 'AKIA[0-9A-Z]{16}' <flagged-files>

# Private keys
grep -l 'BEGIN (RSA |EC )?PRIVATE KEY' <flagged-files>

# Hardcoded passwords
grep -rE '(password|passwd|pwd)\s*=\s*["\047][^"\047]{8,}["\047]' <flagged-files>
```

**If secrets detected**:
1. Remove file from cleanup report
2. Add to separate "SECURITY: Secrets Detected" section with file path only (no content)
3. Recommend using `git filter-repo` or BFG Repo-Cleaner for secure removal
4. Do NOT include file content or secret values in any report

## report format

Output a single markdown report. **Only include items recommended for deletion.** Do not list files that should be kept.

```markdown
# garbage cleanup report

**scan date:** YYYY-MM-DD
**repo:** <repo path>
**mode:** report | move | delete (dry-run: yes/no)
**total candidates:** N
**estimated disk recoverable:** X MB

## git repository health (phase 0)

| metric | before | after |
|--------|--------|-------|
| disk usage | 500 MB | 450 MB |
| pruned refs | - | 15 |
| large objects (>5MB) | 3 | 3 |

## empty directories (N)

| path | notes |
|------|-------|
| path/to/dir/ | empty / gitkeep-only / root-owned |

## build artifacts (N)

| path | size | reason |
|------|------|--------|
| path/__pycache__/ | 2.1 MB | python bytecode cache |

## one-time scripts (N)

| path | size | reason |
|------|------|--------|
| scripts/migrate-foo.sh | 1.2 KB | not referenced by any active code |

## stale output (N)

| path | size | age | reason |
|------|------|-----|--------|
| temp/old-run/ | 50 KB | 14d | orphaned evidence bundle |

## large gitignored artifacts (N)

| path | size | reason |
|------|------|--------|
| _build/foo/ | 500 MB | git clone not needed for deployment |

## duplicates (N)

| file a (KEEP) | file b (DELETE) | size | sha256 (first 8) | reason |
|---------------|-----------------|------|-------------------|--------|
| src/main.py | backup/main.py | 4 KB | a1b2c3d4 | folder priority |

## SECURITY: secrets detected (N)

**CRITICAL**: The following files contain potential secrets and should NOT be deleted via standard cleanup. Use `git filter-repo` or BFG Repo-Cleaner for secure removal.

| path | type | recommendation |
|------|------|----------------|
| old/config.bak | API key pattern | Use git filter-repo to remove from history |
| temp/creds.txt | Private key | Revoke key, then use BFG Repo-Cleaner |
```

## protected directories

Never flag these directories for deletion, even if they appear to match cleanup criteria:

- `.git/` — git object store and internals
- `node_modules/` in directories with `package.json` in parent or ancestor (active project)
- Virtual environments with `pyvenv.cfg` (active python venv)
- Directories containing a `.protected` marker file
- `.venv/`, `venv/`, `env/` with `bin/activate` or `Scripts/activate.bat` present
- Directories referenced in:
  - `docker-compose.yml`, `docker-compose.*.yml`
  - `package.json` (scripts, workspaces)
  - `tsconfig.json`, `pyproject.toml`, `Cargo.toml`
  - `.gitmodules` (git submodules)

**Protection test**: Before flagging a directory, check if it or any ancestor contains these indicators.

## rules

- **never delete without listing first** — this playbook produces a report, not deletions
- **skip `.git/` internals** — never touch git object store (enforced by protected directories)
- **skip active config** — files referenced in docker-compose, package.json, tsconfig, etc. are not candidates
- **skip secrets** — never list `.env`, credentials, keys in the report
- **flag root-owned items** — note when `sudo` is required for deletion
- **verify before flagging** — grep/search for references before calling something unused
- **size matters** — prioritize large items in the report; sort sections by disk impact descending
- **relative paths** — use paths relative to repo root in the report
