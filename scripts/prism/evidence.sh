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
