#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit
IFS=$'\n\t'

# garbage-cleanup.sh — Companion script for garbage-cleanup.md playbook
# Version: 1.0
# Generated: 2026-02-13
# Delegates: Data collection, file scanning, reference counting
# Playbook handles: Classification, scoring, judgment, approval gates

readonly SCRIPT_VERSION="1.0"

# ============================================================================
# DEFAULTS
# ============================================================================

PROJECT="${PROJECT:-$(pwd)}"
FORMAT="${FORMAT:-tsv}"
OUT="${OUT:-/dev/stdout}"
META="${META:-false}"
MAX_FILES="${MAX_FILES:-0}"
DRY_RUN="${DRY_RUN:-true}"

# Configuration from playbook
TEMP_STALE_DAYS="${TEMP_STALE_DAYS:-7}"
EVIDENCE_STALE_DAYS="${EVIDENCE_STALE_DAYS:-30}"
LARGE_FILE_MB="${LARGE_FILE_MB:-10}"
REPORT_LIMIT="${REPORT_LIMIT:-20}"
CLEANUP_MODE="${CLEANUP_MODE:-report}"
TRASH_DIR="${TRASH_DIR:-.cleanup-trash}"

# ============================================================================
# STANDARD EXCLUDES
# ============================================================================

readonly -a STANDARD_EXCLUDES=(
  '.git'
  '.svn'
  '.hg'
  'CVS'
)

# Protected directories — never flag for deletion
readonly -a PROTECTED_DIRS=(
  '.git'
  '.protected'
  'node_modules'  # when package.json exists in parent
  '.venv'
  'venv'
  'env'
)

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

die() {
  printf '%s\n' "$1" >&2
  exit "${2:-1}"
}

info() {
  if [[ "${VERBOSE:-false}" == "true" ]]; then
    printf '[INFO] %s\n' "$1" >&2
  fi
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || die "$1 not found (required)" 3
}

# Build find exclude arguments from array
_build_find_excludes() {
  local -a excludes=()
  for exc in "${STANDARD_EXCLUDES[@]}"; do
    excludes+=(-path "*/$exc" -prune -o -path "*/$exc/*" -prune -o)
  done
  printf '%s ' "${excludes[@]}"
}

# Wrapper for find with standard excludes
run_find() {
  local path="${1:?path required}"
  shift
  # shellcheck disable=SC2046
  find "$path" $(_build_find_excludes) "$@"
}

# Check if directory is protected
is_protected() {
  local dir="${1:?dir required}"

  # Check for .protected marker
  [[ -f "$dir/.protected" ]] && return 0

  # Check if it's a node_modules with package.json in parent
  if [[ "$(basename "$dir")" == "node_modules" ]]; then
    [[ -f "$(dirname "$dir")/package.json" ]] && return 0
  fi

  # Check if it's a venv with pyvenv.cfg
  [[ -f "$dir/pyvenv.cfg" ]] && return 0

  # Check if it's in protected list
  local protected_name
  for protected_name in "${PROTECTED_DIRS[@]}"; do
    [[ "$dir" == *"/$protected_name" ]] || [[ "$dir" == "$protected_name" ]] && return 0
  done

  return 1
}

# Emit TSV or sections output
emit_output() {
  if [[ "$FORMAT" == "tsv" ]]; then
    cat
  elif [[ "$FORMAT" == "md" ]]; then
    tsv_to_md
  elif [[ "$FORMAT" == "json" ]]; then
    tsv_to_ndjson
  else
    cat
  fi
}

# Convert TSV to markdown table
tsv_to_md() {
  awk -F'\t' '
    NR==1 {
      for (i=1; i<=NF; i++) printf "| %s ", $i
      print "|"
      for (i=1; i<=NF; i++) printf "|---"
      print "|"
      next
    }
    {
      for (i=1; i<=NF; i++) printf "| %s ", $i
      print "|"
    }
  '
}

# Convert TSV to NDJSON
tsv_to_ndjson() {
  awk -F'\t' '
    NR==1 { for (i=1; i<=NF; i++) header[i]=$i; next }
    {
      printf "{"
      for (i=1; i<=NF; i++) {
        printf "\"%s\":\"%s\"", header[i], $i
        if (i<NF) printf ","
      }
      print "}"
    }
  '
}

# Calculate age in days
age_in_days() {
  local file="${1:?file required}"
  local now
  now=$(date +%s)
  local mtime
  mtime=$(stat -c%Y "$file" 2>/dev/null || stat -f%m "$file" 2>/dev/null || echo "$now")
  echo $(( (now - mtime) / 86400 ))
}

# Format size
format_size() {
  local bytes="${1:-0}"
  if (( bytes > 1073741824 )); then
    printf "%.1f GB" "$(bc -l <<< "scale=1; $bytes/1073741824")"
  elif (( bytes > 1048576 )); then
    printf "%.1f MB" "$(bc -l <<< "scale=1; $bytes/1048576")"
  elif (( bytes > 1024 )); then
    printf "%.1f KB" "$(bc -l <<< "scale=1; $bytes/1024")"
  else
    printf "%d B" "$bytes"
  fi
}

# ============================================================================
# SUBCOMMAND FUNCTIONS
# ============================================================================

# Extracted from: Prerequisites validation
# I/O contract: Checks required/optional tools, outputs check/status/detail
fn_validate() {
  [[ "$META" == "true" ]] && printf '# validate | %s | %s\n' "$(date -Iseconds)" "$PROJECT"

  printf 'check\tstatus\tdetail\n'

  # Check git repository
  if git -C "$PROJECT" rev-parse --git-dir >/dev/null 2>&1; then
    printf 'git-repo\tPASS\t%s\n' "$PROJECT"
  else
    printf 'git-repo\tFAIL\tNot a git repository\n'
    return 1
  fi

  # Check if at repo root
  local repo_root
  repo_root=$(git -C "$PROJECT" rev-parse --show-toplevel 2>/dev/null || echo "")
  if [[ "$PROJECT" == "$repo_root" ]]; then
    printf 'repo-root\tPASS\tat root\n'
  else
    printf 'repo-root\tWARN\tnot at root (currently: %s, root: %s)\n' "$PROJECT" "$repo_root"
  fi

  # Check required tools
  local required_tools=(find git du sort xargs sha256sum grep awk)
  local tool
  for tool in "${required_tools[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
      printf 'tool:%s\tPASS\tfound\n' "$tool"
    else
      printf 'tool:%s\tFAIL\tnot found\n' "$tool"
      return 1
    fi
  done

  # Check optional tools
  local optional_tools=(rsync git-filter-repo bfg bc)
  for tool in "${optional_tools[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
      printf 'optional:%s\tPASS\tfound\n' "$tool"
    else
      printf 'optional:%s\tINFO\tnot found (optional)\n' "$tool"
    fi
  done

  return 0
}

# Extracted from: Phase 0 - git repository maintenance
# I/O contract: Runs git gc, outputs sections with health metrics
fn_git_health() {
  info "Running git health checks..."

  # Run in subshell to avoid changing parent directory
  (
    cd "$PROJECT" || die "Cannot cd to $PROJECT"

    # Capture before state
    local before_count
    before_count=$(git count-objects -v 2>/dev/null || echo "count: 0")

  printf '## GIT_HEALTH_BEFORE\n'
  echo "$before_count"
  printf '\n'

  # Prune remote references
  printf '## PRUNE_REFS\n'
  git fetch --prune --prune-tags 2>&1 | grep -E '(Pruning|pruned)' || echo "No refs pruned"
  printf '\n'

  # Garbage collection
  printf '## GC_OUTPUT\n'
  git gc --aggressive --prune=now 2>&1
  printf '\n'

  # After state
  printf '## GIT_HEALTH_AFTER\n'
  git count-objects -v
  printf '\n'

  # Large objects (>5MB)
  printf '## LARGE_OBJECTS\n'
  printf 'size_bytes\tpath\n'
  git rev-list --objects --all | \
    git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' | \
    awk '/^blob/ {if ($3 > 5242880) print $3 "\t" $4}' | \
    sort -rn | \
    head -20
  printf '\n'
  )

  return 0
}

# Extracted from: Phase 1 - empty directories
# I/O contract: Finds empty directories, outputs path/notes
fn_empty_dirs() {
  [[ "$META" == "true" ]] && printf '# empty-dirs | %s | %s\n' "$(date -Iseconds)" "$PROJECT"

  info "Scanning for empty directories..."

  printf 'path\tnotes\n'

  run_find "$PROJECT" -type d -print0 2>/dev/null | while IFS= read -r -d '' dir; do
    # Skip if protected
    is_protected "$dir" && continue

    # Check if empty or gitkeep-only
    local files subdirs
    files=$(find "$dir" -maxdepth 1 -not -name ".gitkeep" -not -name "." -not -type d 2>/dev/null | head -1)
    subdirs=$(find "$dir" -mindepth 1 -type d 2>/dev/null | head -1)

    if [[ -z "$files" ]] && [[ -z "$subdirs" ]]; then
      local notes="empty"
      [[ -f "$dir/.gitkeep" ]] && notes="gitkeep-only"

      # Check if root-owned
      local owner
      owner=$(stat -c%U "$dir" 2>/dev/null || stat -f%Su "$dir" 2>/dev/null || echo "unknown")
      [[ "$owner" == "root" ]] && notes="$notes, root-owned"

      # Make path relative
      local relpath="${dir#"$PROJECT"/}"
      printf '%s\t%s\n' "$relpath" "$notes"
    fi

    # Apply max files limit if set
    if [[ "$MAX_FILES" -gt 0 ]]; then
      local count
      count=$(wc -l < <(printf '%s\n' "$relpath") || echo 0)
      if [[ "$count" -ge "$MAX_FILES" ]]; then
        break
      fi
    fi
  done | sort

  return 0
}

# Extracted from: Phase 2 - build artifacts
# I/O contract: Finds build artifacts, checks if gitignored, outputs path/size/reason
fn_build_artifacts() {
  [[ "$META" == "true" ]] && printf '# build-artifacts | %s | %s\n' "$(date -Iseconds)" "$PROJECT"

  info "Scanning for build artifacts..."

  printf 'path\tsize\treason\n'

  local -a patterns=(
    '__pycache__'
    '*.pyc'
    '*.pyo'
    'node_modules'
    '*.egg-info'
    'dist'
    'build'
    'out'
    '.mypy_cache'
    '.pytest_cache'
    '.ruff_cache'
    'coverage'
    '.coverage'
    'htmlcov'
    '*.log'
    '*.bak'
    '*.orig'
    '*.swp'
    '*~'
    'temp'
    'tmp'
  )

  local pattern
  for pattern in "${patterns[@]}"; do
    run_find "$PROJECT" -name "$pattern" -print0 2>/dev/null | while IFS= read -r -d '' item; do
      # Skip if protected
      is_protected "$item" && continue

      # Check if gitignored
      local is_gitignored="false"
      git -C "$PROJECT" check-ignore -q "$item" 2>/dev/null && is_gitignored="true"

      # Skip versioned build dirs
      if [[ "$pattern" == "dist" ]] || [[ "$pattern" == "build" ]] || [[ "$pattern" == "out" ]]; then
        [[ "$is_gitignored" == "false" ]] && continue
      fi

      # Get size
      local size_bytes
      if [[ -d "$item" ]]; then
        size_bytes=$(du -sb "$item" 2>/dev/null | awk '{print $1}' || echo 0)
      else
        size_bytes=$(stat -c%s "$item" 2>/dev/null || stat -f%z "$item" 2>/dev/null || echo 0)
      fi

      local size_fmt
      size_fmt=$(format_size "$size_bytes")

      # Determine reason
      local reason=""
      case "$pattern" in
        __pycache__|*.pyc|*.pyo) reason="python bytecode cache" ;;
        node_modules) reason="npm dependencies (orphaned)" ;;
        *.egg-info) reason="python package metadata" ;;
        dist|build|out) reason="build output (gitignored)" ;;
        .mypy_cache|.pytest_cache|.ruff_cache) reason="tool cache" ;;
        coverage|.coverage|htmlcov) reason="coverage reports" ;;
        *.log) reason="log file" ;;
        *.bak|*.orig) reason="backup file" ;;
        *.swp|*~) reason="editor temp" ;;
        temp|tmp)
          local age
          age=$(age_in_days "$item")
          if (( age > TEMP_STALE_DAYS )); then
            reason="temp directory (${age}d old, threshold: ${TEMP_STALE_DAYS}d)"
          else
            continue  # Skip recent temp dirs
          fi
          ;;
        *) reason="build artifact" ;;
      esac

      # Make path relative
      local relpath="${item#"$PROJECT"/}"
      printf '%s\t%s\t%s\n' "$relpath" "$size_fmt" "$reason"
    done
  done | sort -t$'\t' -k2 -rh | head -n "${REPORT_LIMIT}"

  return 0
}

# Extracted from: Phase 3 - one-time scripts
# I/O contract: Finds unreferenced scripts with one-time patterns, outputs path/size/reason
fn_one_time_scripts() {
  [[ "$META" == "true" ]] && printf '# one-time-scripts | %s | %s\n' "$(date -Iseconds)" "$PROJECT"

  info "Scanning for one-time scripts..."

  printf 'path\tsize\treason\n'

  # Find shell scripts
  run_find "$PROJECT" -type f \( -name "*.sh" -o -name "*.bash" \) -print0 2>/dev/null | while IFS= read -r -d '' script; do
    local basename
    basename=$(basename "$script")

    # Check for one-time patterns in name
    if [[ "$basename" =~ (migrate|setup|init|seed|fix-|patch-|one-time|hotfix) ]]; then
      # Check if referenced anywhere
      local refs
      refs=$(grep -rE "(\.|source|bash|sh|exec)\s+.*${basename}" "$PROJECT" \
        --exclude-dir=.git \
        --exclude='*.md' \
        --exclude="$basename" \
        2>/dev/null | wc -l)

      if (( refs == 0 )); then
        local size_bytes
        size_bytes=$(stat -c%s "$script" 2>/dev/null || stat -f%z "$script" 2>/dev/null || echo 0)
        local size_fmt
        size_fmt=$(format_size "$size_bytes")

        local reason="one-time pattern in name, not referenced"

        # Check for hardcoded absolute paths
        if grep -qE '^[^#]*(/home/[a-z]+|/Users/[a-zA-Z]+)' "$script" 2>/dev/null; then
          reason="$reason, hardcoded absolute paths"
        fi

        local relpath="${script#"$PROJECT"/}"
        printf '%s\t%s\t%s\n' "$relpath" "$size_fmt" "$reason"
      fi
    fi
  done | sort

  return 0
}

# Extracted from: Phase 4 - stale generated output
# I/O contract: Finds stale state files and evidence bundles, outputs path/size/age/reason
fn_stale_output() {
  [[ "$META" == "true" ]] && printf '# stale-output | %s | %s\n' "$(date -Iseconds)" "$PROJECT"

  info "Scanning for stale output..."

  printf 'path\tsize\tage\treason\n'

  # Find state files (*.json, *.jsonl) not read by any script
  run_find "$PROJECT" -type f \( -name "*.json" -o -name "*.jsonl" \) -print0 2>/dev/null | while IFS= read -r -d '' file; do
    local basename
    basename=$(basename "$file")

    # Skip if referenced
    local refs
    refs=$(grep -rF "$basename" "$PROJECT" \
      --include='*.sh' \
      --include='*.bash' \
      --include='*.py' \
      --exclude-dir=.git \
      2>/dev/null | grep -vc "^${file}:" || echo 0)

    [[ "$refs" -gt 0 ]] && continue

    # Check age
    local age
    age=$(age_in_days "$file")

    # Skip recent files
    [[ "$age" -lt "$EVIDENCE_STALE_DAYS" ]] && continue

    local size_bytes
    size_bytes=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo 0)
    local size_fmt
    size_fmt=$(format_size "$size_bytes")

    local relpath="${file#"$PROJECT"/}"
    printf '%s\t%s\t%dd\torphaned state file, not referenced\n' "$relpath" "$size_fmt" "$age"
  done | sort -t$'\t' -k3 -rn

  return 0
}

# Extracted from: Phase 5 - large gitignored artifacts
# I/O contract: Lists gitignored files >LARGE_FILE_MB, outputs path/size/reason
fn_gitignored_artifacts() {
  [[ "$META" == "true" ]] && printf '# gitignored-artifacts | %s | %s\n' "$(date -Iseconds)" "$PROJECT"

  info "Scanning for large gitignored artifacts..."

  printf 'path\tsize\treason\n'

  local large_bytes=$((LARGE_FILE_MB * 1048576))

  # Run git commands in subshell to avoid changing parent directory
  (
    cd "$PROJECT" || die "Cannot cd to $PROJECT"

    git ls-files --others --ignored --exclude-standard -z 2>/dev/null | while IFS= read -r -d '' file; do
    [[ ! -e "$file" ]] && continue

    local size_bytes
    if [[ -d "$file" ]]; then
      size_bytes=$(du -sb "$file" 2>/dev/null | awk '{print $1}' || echo 0)
    else
      size_bytes=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo 0)
    fi

    # Only report if exceeds threshold
    if (( size_bytes >= large_bytes )); then
      local size_fmt
      size_fmt=$(format_size "$size_bytes")
      printf '%s\t%s\tgitignored, large artifact\n' "$file" "$size_fmt"
    fi
    done | sort -t$'\t' -k2 -rh | head -n "${REPORT_LIMIT}"
  )

  return 0
}

# Extracted from: Phase 6 - duplicates (requires implementation)
# I/O contract: Finds duplicate files by sha256, applies auto-selection rules, outputs keep/delete/size/sha/reason
fn_duplicates() {
  [[ "$META" == "true" ]] && printf '# duplicates | %s | %s\n' "$(date -Iseconds)" "$PROJECT"

  info "Scanning for duplicate files..."

  printf 'keep\tdelete\tsize\tsha256\treason\n'

  # Find all files and compute sha256
  local tmpfile
  tmpfile=$(mktemp)
  trap 'rm -f "$tmpfile"' EXIT

  run_find "$PROJECT" -type f -print0 2>/dev/null | while IFS= read -r -d '' file; do
    # Skip protected
    is_protected "$(dirname "$file")" && continue

    # Skip very large files (>100MB) to avoid slowdown
    local size_bytes
    size_bytes=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo 0)
    [[ "$size_bytes" -gt 104857600 ]] && continue

    # Compute hash
    local hash
    hash=$(sha256sum "$file" 2>/dev/null | awk '{print $1}')
    printf '%s\t%s\t%d\n' "$hash" "$file" "$size_bytes"
  done > "$tmpfile"

  # Find duplicates
  awk -F'\t' '{
    hash=$1; file=$2; size=$3
    hashes[hash] = hashes[hash] ? hashes[hash] "\t" file "\t" size : file "\t" size
    count[hash]++
  }
  END {
    for (h in count) {
      if (count[h] > 1) {
        print h "\t" hashes[h]
      }
    }
  }' "$tmpfile" | while IFS=$'\t' read -r hash files_data; do
    # Parse files
    local -a files=()
    local -a sizes=()
    local i=0
    while read -r file; do
      read -r size
      files[i]="$file"
      sizes[i]="$size"
      ((i++))
    done < <(echo "$files_data" | tr '\t' '\n')

    # Apply auto-selection rules
    # Priority 1: Folder priority
    local keep_idx=0
    local max_priority=-1
    for ((i=0; i<${#files[@]}; i++)); do
      local priority=0
      case "${files[$i]}" in
        */src/*|*/lib/*|*/app/*|*/main/*|*/core/*) priority=4 ;;
        */backup/*|*/old/*|*/archive/*|*/copy/*|*/bak/*|*/tmp/*) priority=1 ;;
        *) priority=2 ;;
      esac

      if (( priority > max_priority )); then
        max_priority=$priority
        keep_idx=$i
      fi
    done

    # Output keep vs delete
    local size_fmt
    size_fmt=$(format_size "${sizes[$keep_idx]}")
    local short_hash="${hash:0:8}"

    for ((i=0; i<${#files[@]}; i++)); do
      if (( i != keep_idx )); then
        local keep_rel="${files[$keep_idx]#$PROJECT/}"
        local delete_rel="${files[$i]#$PROJECT/}"
        printf '%s\t%s\t%s\t%s\tfolder priority\n' "$keep_rel" "$delete_rel" "$size_fmt" "$short_hash"
      fi
    done
  done | head -n "${REPORT_LIMIT}"

  return 0
}

# Extracted from: Phase 7 - secrets scan
# I/O contract: Scans files for secrets patterns, outputs path/type/recommendation
fn_secrets_scan() {
  [[ "$META" == "true" ]] && printf '# secrets-scan | %s | %s\n' "$(date -Iseconds)" "$PROJECT"

  info "Scanning for secrets..."

  printf 'path\ttype\trecommendation\n'

  # API keys, tokens, passwords
  grep -rE '(api[_-]?key|token|password|secret|credentials?).*[=:]\s*["\047][a-zA-Z0-9_-]{20,}["\047]' "$PROJECT" \
    --exclude-dir=.git \
    --exclude='*.md' \
    -l 2>/dev/null | while IFS= read -r file; do
    local relpath="${file#"$PROJECT"/}"
    printf '%s\tAPI key pattern\tUse git filter-repo to remove from history\n' "$relpath"
  done

  # AWS keys
  grep -rE 'AKIA[0-9A-Z]{16}' "$PROJECT" \
    --exclude-dir=.git \
    -l 2>/dev/null | while IFS= read -r file; do
    local relpath="${file#"$PROJECT"/}"
    printf '%s\tAWS access key\tRevoke key, use git filter-repo\n' "$relpath"
  done

  # Private keys
  grep -rl 'BEGIN (RSA |EC )?PRIVATE KEY' "$PROJECT" \
    --exclude-dir=.git \
    2>/dev/null | while IFS= read -r file; do
    local relpath="${file#"$PROJECT"/}"
    printf '%s\tPrivate key\tRevoke key, use BFG Repo-Cleaner\n' "$relpath"
  done

  # Hardcoded passwords
  grep -rE '(password|passwd|pwd)\s*=\s*["\047][^"\047]{8,}["\047]' "$PROJECT" \
    --exclude-dir=.git \
    --exclude='*.md' \
    -l 2>/dev/null | while IFS= read -r file; do
    local relpath="${file#"$PROJECT"/}"
    printf '%s\tHardcoded password\tRotate credential, use git filter-repo\n' "$relpath"
  done | sort -u

  return 0
}

# ============================================================================
# HELP & DISPATCHER
# ============================================================================

show_help() {
  cat <<HELPEOF
garbage-cleanup.sh v${SCRIPT_VERSION} — Companion script for garbage-cleanup playbook

USAGE:
  ./garbage-cleanup.sh SUBCOMMAND [OPTIONS]

SUBCOMMANDS:
  validate                 Validate prerequisites (tools, git repo)
  git-health              Run git maintenance and report health metrics
  empty-dirs              Find empty directories
  build-artifacts         Find build artifacts and temp files
  one-time-scripts        Find unreferenced one-time scripts
  stale-output            Find stale state files and evidence bundles
  gitignored-artifacts    Find large gitignored files
  duplicates              Find duplicate files with auto-selection rules
  secrets-scan            Scan for accidentally committed secrets
  help                    Show this help

GLOBAL OPTIONS:
  --project PATH          Project root (default: current directory)
  --format FORMAT         Output format: tsv|md|json (default: tsv)
  --out FILE              Output file (default: stdout)
  --meta                  Include metadata comment in output
  --max-files N           Limit output to N files (0=unlimited, default: 0)
  --verbose               Show progress info on stderr
  --dry-run BOOL          Preview mode (default: true)

CONFIGURATION (via environment):
  TEMP_STALE_DAYS         Age threshold for temp dirs (default: 7)
  EVIDENCE_STALE_DAYS     Age threshold for evidence (default: 30)
  LARGE_FILE_MB           Size threshold for gitignored (default: 10)
  REPORT_LIMIT            Max items per section (default: 20)
  CLEANUP_MODE            report|move|delete (default: report)
  TRASH_DIR               Move target (default: .cleanup-trash)

EXAMPLES:
  ./garbage-cleanup.sh validate
  ./garbage-cleanup.sh empty-dirs --project /path/to/repo
  ./garbage-cleanup.sh build-artifacts --format md --meta
  ./garbage-cleanup.sh secrets-scan --verbose

EXIT CODES:
  0  Success
  1  General error
  2  Usage error
  3  Missing required tool
HELPEOF
}

# ============================================================================
# OPTION PARSING
# ============================================================================

# Parse global options
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)
      PROJECT="${2:?--project requires argument}"
      shift 2
      ;;
    --format)
      FORMAT="${2:?--format requires argument}"
      shift 2
      ;;
    --out)
      OUT="${2:?--out requires argument}"
      shift 2
      ;;
    --meta)
      META=true
      shift
      ;;
    --max-files)
      MAX_FILES="${2:?--max-files requires argument}"
      shift 2
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --dry-run)
      DRY_RUN="${2:?--dry-run requires argument}"
      shift 2
      ;;
    --help|-h|help)
      show_help
      exit 0
      ;;
    -*)
      die "Unknown option: $1" 2
      ;;
    *)
      # First non-option is subcommand
      break
      ;;
  esac
done

# ============================================================================
# DISPATCHER
# ============================================================================

main() {
  local subcommand="${1:-help}"
  shift || true

  # Validate project exists
  [[ -d "$PROJECT" ]] || die "Project directory does not exist: $PROJECT" 1

  case "$subcommand" in
    validate)
      fn_validate "$@" | emit_output > "$OUT"
      ;;
    git-health)
      fn_git_health "$@" > "$OUT"
      ;;
    empty-dirs)
      fn_empty_dirs "$@" | emit_output > "$OUT"
      ;;
    build-artifacts)
      fn_build_artifacts "$@" | emit_output > "$OUT"
      ;;
    one-time-scripts)
      fn_one_time_scripts "$@" | emit_output > "$OUT"
      ;;
    stale-output)
      fn_stale_output "$@" | emit_output > "$OUT"
      ;;
    gitignored-artifacts)
      fn_gitignored_artifacts "$@" | emit_output > "$OUT"
      ;;
    duplicates)
      fn_duplicates "$@" | emit_output > "$OUT"
      ;;
    secrets-scan)
      fn_secrets_scan "$@" | emit_output > "$OUT"
      ;;
    help|--help|-h)
      show_help
      exit 0
      ;;
    *)
      die "Unknown subcommand: $subcommand (try 'help')" 2
      ;;
  esac
}

main "$@"
