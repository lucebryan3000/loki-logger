#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
umask 022
source "/home/luce/apps/loki-logging/scripts/prompt-exec/evidence/Loki-prompt-7/20260212T224848Z/env.sh"
if [ -n "${REPO_ROOT:-}" ]; then cd "$REPO_ROOT"; else cd "$PROMPT_DIR"; fi
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

git add .gitignore .claudeignore scripts/prism/evidence.sh _build/Sprint-1/validation/artifacts/EVIDENCE_V2.md
git commit -m "Evidence v2: temp/.artifacts default + NDJSON registry library"

echo "EVIDENCE_V2_OK RUN_UTC=${RUN_UTC}"
