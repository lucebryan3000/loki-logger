---
codex_reviewed_utc: '2026-02-12T00:00:00Z'
codex_revision: 2
codex_ready_to_execute: "yes"
codex_kind: task
codex_scope: multi-file
codex_targets:
  - .gitignore
  - .claudeignore
  - scripts/prism/evidence.sh
  - _build/Sprint-1/validation/artifacts/EVIDENCE_V2.md
codex_autocommit: "yes"
codex_move_to_completed: "yes"
codex_warn_gate: "yes"
codex_warn_mode: ask
codex_allow_noncritical: "yes"
codex_prompt_sha256_mode: "none"
codex_reason: "Move PRISM evidence defaults to temp/.artifacts, add ignore rules, and consolidate one-line evidence into NDJSON registry via scripts/prism/evidence.sh."
codex_last_run_utc: '20260212T224848Z'
codex_last_run_dir: '/home/luce/apps/loki-logging/scripts/prompt-exec/evidence/Loki-prompt-7/20260212T224848Z'
codex_last_run_status: 'failed'
codex_last_run_git_head: '068b9b3aa704adbcd05fa5b92949e866d854cad8'
codex_last_run_warning_count: '0'
codex_last_run_failed_block: 'block002'
codex_last_run_last_ok_block: '1'
codex_last_run_prompt_sha256: '363ace48c1c364992bc6fade2d9a3f67830db9a04b1f80c4e4c9452b449f17b9'
---

# PHASE — Evidence v2: temp/.artifacts + NDJSON Registry + Migration

## Objective
- Move default PRISM evidence location under `temp/.artifacts/prism/evidence`.
- Add ignore rules for `temp/` and `.artifacts/`.
- Introduce a reusable NDJSON evidence library at `scripts/prism/evidence.sh`.
- Preserve legacy evidence by migrating existing `.artifacts/prism/evidence` into timestamped legacy folder under `temp/.artifacts/...`.

## Affects
- `.gitignore`
- `.claudeignore`
- `scripts/prism/evidence.sh`
- `_build/Sprint-1/validation/artifacts/EVIDENCE_V2.md`

## Conflict Report
- `CONFLICT`: Prior draft said "do not touch .gitignore/.claudeignore" while also requiring ignore-line updates to those files.
- `RESOLUTION`: This prompt explicitly allows edits to those two files only for required ignore entries.
- `OK`: Evidence target path `temp/.artifacts/prism/evidence/<RUN_UTC>` is repo-local and deterministic.
- `OK`: Migration uses `rsync --remove-source-files` plus empty-dir cleanup.

## Phase 0 — Preflight Gate (STOP if any FAIL)

```bash
set -euo pipefail

REPO="/home/luce/apps/loki-logging"
cd "$REPO"

FAIL=0

check_cmd() {
  local c="$1"
  if command -v "$c" >/dev/null 2>&1; then
    echo "PASS: command '$c' found"
  else
    echo "FAIL: command '$c' missing"
    FAIL=1
  fi
}

check_file() {
  local f="$1"
  if [ -f "$f" ]; then
    echo "PASS: file exists: $f"
  else
    echo "FAIL: missing file: $f"
    FAIL=1
  fi
}

check_cmd git
check_cmd rsync
check_cmd sha256sum
check_cmd awk
check_cmd sed

check_file "$REPO/.gitignore"
check_file "$REPO/.claudeignore"

if [ "$FAIL" -ne 0 ]; then
  echo "PRECHECK_FAIL"
  exit 1
fi

echo "PRECHECK_OK"
```

## Phase 1 — Execute Evidence v2 Migration + Library

```bash
set -euo pipefail

RUN_UTC="$(date -u +%Y%m%dT%H%M%SZ)"
REPO="/home/luce/apps/loki-logging"
cd "$REPO"

TEMP_DIR="$REPO/temp"
NEW_ART="$TEMP_DIR/.artifacts"
NEW_PRISM="$NEW_ART/prism"
NEW_EVID="$NEW_PRISM/evidence"

mkdir -p "$NEW_EVID" "$NEW_PRISM"
chmod 700 "$TEMP_DIR" "$NEW_ART" "$NEW_PRISM" || true

# Guardrail: only touch files listed in ## Affects.
echo "GUARDRAIL: editing only listed target files" 

ensure_ignore_line() {
  local file="$1"
  local line="$2"
  test -f "$file" || touch "$file"
  grep -qxF "$line" "$file" || printf "\n%s\n" "$line" >> "$file"
}

ensure_ignore_line ".gitignore" "temp/"
ensure_ignore_line ".gitignore" ".artifacts/"
ensure_ignore_line ".claudeignore" "temp/"
ensure_ignore_line ".claudeignore" ".artifacts/"

LEGACY_ROOT="$REPO/.artifacts/prism/evidence"
if [ -d "$LEGACY_ROOT" ]; then
  DEST="$NEW_EVID/legacy_${RUN_UTC}"
  mkdir -p "$DEST"
  rsync -a --remove-source-files "$LEGACY_ROOT/" "$DEST/" || true
  find "$REPO/.artifacts" -type d -empty -delete || true
fi

mkdir -p scripts/prism
cat > scripts/prism/evidence.sh <<'BASH'
#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   source scripts/prism/evidence.sh
#   prism_init
#   prism_event phase_ok phase=telemetry
#   prism_cmd "curl grafana health" -- curl -sf http://127.0.0.1:9001/api/health

prism_init() {
  : "${REPO_ROOT:=$(pwd)}"
  : "${RUN_UTC:=$(date -u +%Y%m%dT%H%M%SZ)}"
  : "${PRISM_EVID_BASE:=${REPO_ROOT}/temp/.artifacts/prism/evidence}"

  export RUN_UTC PRISM_EVID_BASE
  export PRISM_EVID_DIR="${PRISM_EVID_BASE}/${RUN_UTC}"
  mkdir -p "${PRISM_EVID_DIR}"
  chmod 700 "${PRISM_EVID_DIR}" || true

  export PRISM_EXEC_LOG="${PRISM_EVID_DIR}/exec.log"
  export PRISM_EVENTS="${PRISM_EVID_DIR}/events.ndjson"

  exec > >(tee -a "${PRISM_EXEC_LOG}") 2> >(tee -a "${PRISM_EXEC_LOG}" >&2)
  prism_event init run_utc="${RUN_UTC}" evid_dir="${PRISM_EVID_DIR}"
}

prism_event() {
  local type="$1"; shift
  local ts
  ts="$(date -u --iso-8601=seconds 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)"

  local kv_json=""
  for kv in "$@"; do
    local k="${kv%%=*}"
    local v="${kv#*=}"
    v="${v//\\/\\\\}"
    v="${v//\"/\\\"}"
    kv_json="${kv_json}\"${k}\":\"${v}\","
  done
  kv_json="${kv_json%,}"

  if [ -n "$kv_json" ]; then
    printf '{"ts":"%s","type":"%s",%s}\n' "$ts" "$type" "$kv_json" >> "${PRISM_EVENTS}"
  else
    printf '{"ts":"%s","type":"%s"}\n' "$ts" "$type" >> "${PRISM_EVENTS}"
  fi
}

prism_cmd() {
  local desc="$1"; shift
  test "${1:-}" = "--" || { echo "prism_cmd: expected --"; return 2; }
  shift

  local start_ns end_ns rc
  start_ns="$(date +%s%N)"
  set +e
  "$@"
  rc=$?
  set -e
  end_ns="$(date +%s%N)"

  prism_event cmd desc="$desc" rc="$rc" start_ns="$start_ns" end_ns="$end_ns"
  return "$rc"
}

prism_hash() {
  for f in "$@"; do
    if [ -f "$f" ]; then
      local h
      h="$(sha256sum "$f" | awk '{print $1}')"
      prism_event sha file="$f" sha256="$h"
    else
      prism_event sha_missing file="$f"
    fi
  done
}
BASH
chmod +x scripts/prism/evidence.sh

mkdir -p _build/Sprint-1/validation/artifacts
cat > _build/Sprint-1/validation/artifacts/EVIDENCE_V2.md <<EOF2
# Evidence v2 (NDJSON + temp/.artifacts)
Run UTC: ${RUN_UTC}

## New location
- temp/.artifacts/prism/evidence/<RUN_UTC>/

## Files per run
- exec.log
- events.ndjson
- optional large artifacts (json/yml snapshots)

## Prompt pattern
\`\`\`bash
source scripts/prism/evidence.sh
prism_init
prism_event phase_start phase=X
prism_cmd "check grafana" -- curl --connect-timeout 5 --max-time 20 -sf http://127.0.0.1:9001/api/health
prism_event phase_ok phase=X
\`\`\`
EOF2

git add .gitignore .claudeignore scripts/prism/evidence.sh
git add -f _build/Sprint-1/validation/artifacts/EVIDENCE_V2.md
git commit -m "Evidence v2: temp/.artifacts default + NDJSON registry library"

echo "EVIDENCE_V2_OK RUN_UTC=${RUN_UTC}"
```

## Acceptance
- Ignore rules include `temp/` and `.artifacts/` in both `.gitignore` and `.claudeignore`.
- `scripts/prism/evidence.sh` exists and is executable.
- Legacy evidence (if present) is migrated under `temp/.artifacts/prism/evidence/legacy_<RUN_UTC>/`.
- Commit succeeds with only listed target files.
