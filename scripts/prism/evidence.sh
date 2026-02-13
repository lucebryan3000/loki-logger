#!/usr/bin/env bash
set -euo pipefail

# Evidence v3 (repo-owned):
#   temp/codex/evidence/<prompt-name>/<run-id-local>/
# Files per run:
#   exec.log (combined stdout/stderr)
#   events.ndjson (append-only structured registry)
#
# Environment:
#   REPO_ROOT (required by callers; defaults to pwd)
#   CODEX_PROMPT_NAME (optional; defaults "prism")

prism_init() {
  : "${REPO_ROOT:=$(pwd)}"
  : "${CODEX_PROMPT_NAME:=prism}"

  # directory-safe local run id + human label
  export RUN_LOCAL_ID
  RUN_LOCAL_ID="$(date +%Y%m%dT%H%M%S)"
  export RUN_LOCAL_LABEL
  RUN_LOCAL_LABEL="$(date '+%I:%M %p - %d-%m-%Y')"

  # keep UTC only as data inside events
  export RUN_UTC
  RUN_UTC="$(date -u +%Y%m%dT%H%M%SZ)"

  export CODEX_EVIDENCE_ROOT
  CODEX_EVIDENCE_ROOT="${REPO_ROOT}/temp/codex/evidence"

  export PRISM_EVID_DIR
  PRISM_EVID_DIR="${CODEX_EVIDENCE_ROOT}/${CODEX_PROMPT_NAME}/${RUN_LOCAL_ID}"
  mkdir -p "${PRISM_EVID_DIR}"
  chmod 700 "${PRISM_EVID_DIR}" || true

  export PRISM_EXEC_LOG="${PRISM_EVID_DIR}/exec.log"
  export PRISM_EVENTS="${PRISM_EVID_DIR}/events.ndjson"

  # redirect stdout/stderr into exec.log (tee to console)
  exec > >(tee -a "${PRISM_EXEC_LOG}") 2> >(tee -a "${PRISM_EXEC_LOG}" >&2)

  prism_event init \
    run_local_id="${RUN_LOCAL_ID}" \
    run_local_label="${RUN_LOCAL_LABEL}" \
    run_utc="${RUN_UTC}" \
    evid_dir="${PRISM_EVID_DIR}" \
    prompt_name="${CODEX_PROMPT_NAME}"
}

# Append JSON object per line (NDJSON). Avoid jq dependency.
prism_event() {
  local type="$1"; shift
  local ts_utc; ts_utc="$(date -u --iso-8601=seconds 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)"
  local kv_json=""
  for kv in "$@"; do
    local k="${kv%%=*}"
    local v="${kv#*=}"
    v="${v//\\/\\\\}"; v="${v//\"/\\\"}"
    kv_json="${kv_json}\"${k}\":\"${v}\","
  done
  kv_json="${kv_json%,}"
  if [ -n "$kv_json" ]; then
    printf '{"ts_utc":"%s","type":"%s",%s}\n' "$ts_utc" "$type" "$kv_json" >> "${PRISM_EVENTS}"
  else
    printf '{"ts_utc":"%s","type":"%s"}\n' "$ts_utc" "$type" >> "${PRISM_EVENTS}"
  fi
}

# Run a command and record rc + timing in NDJSON (stdout/stderr remain in exec.log)
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

# Hashes appended into events.ndjson (no separate hash files)
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
