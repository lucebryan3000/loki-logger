#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: evidence.sh

Generate a cryptographically verifiable evidence archive for the
observability stack. Used for audit/compliance proof of stack operation.

Output:
  temp/codex-sprint/   NDJSON indexes (state, history, runs, artifacts, catalog)
  /tmp/codex-sprint-work/<run-key>/   Ephemeral work directory (auto-cleaned)

Evidence includes:
  - Stack state and health check results
  - Loki query proofs with labels
  - Config file SHA256 hashes
  - Run metadata and timestamps

Security:
  - Never includes secrets from .env
  - Work directory is mode 700
  - Ephemeral workdir cleaned on exit (set CODEX_SPRINT_KEEP_WORK=1 to retain)

Environment:
  CODEX_PROMPT_NAME       Override prompt name (default: prism)
  CODEX_SPRINT_KEEP_WORK  Set to 1 to retain ephemeral work directory
  REPO_ROOT               Override repo root (default: cwd)

Provides shell functions for use by other scripts:
  prism_init              Initialize evidence run
  prism_event <type>      Record NDJSON event
  prism_cmd <desc> -- <cmd>  Run command with timing/rc capture
  prism_hash <file...>    Hash files into evidence index
  prism_store_update      Update state/catalog indexes
  prism_append_artifact   Register artifact in index
EOF
  exit 0
fi

# Evidence v5 (flat codex-sprint indexes):
#   temp/codex-sprint/state.jsonl
#   temp/codex-sprint/state.latest.json
#   temp/codex-sprint/history.jsonl
#   temp/codex-sprint/runs.jsonl
#   temp/codex-sprint/artifacts.jsonl
#   temp/codex-sprint/catalog.json
#
# Runtime workdir is ephemeral by default:
#   /tmp/codex-sprint-work/<prompt-slug>--<rNNNN>/

_prism_slug() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g'
}

prism_store_update() {
  local status="${1:-running}"

  python3 - \
    "${PRISM_STATE_JSONL}" \
    "${PRISM_STATE_LATEST_JSON}" \
    "${PRISM_HISTORY_JSONL}" \
    "${PRISM_RUNS_JSONL}" \
    "${PRISM_CATALOG_JSON}" \
    "${CODEX_PROMPT_SLUG}" \
    "${CODEX_PROMPT_NAME}" \
    "${RUN_ID}" \
    "${RUN_SEQ}" \
    "${RUN_KEY}" \
    "${RUN_REF}" \
    "${PRISM_EVID_DIR}" \
    "${RUN_UTC}" \
    "${RUN_LOCAL_LABEL}" \
    "${status}" <<'PY'
import json
import sys
from pathlib import Path

(
    state_jsonl,
    state_latest_json,
    history_jsonl,
    runs_jsonl,
    catalog_json,
    prompt_slug,
    prompt_name,
    run_id,
    run_seq_raw,
    run_key,
    run_ref,
    run_work_dir,
    run_utc,
    run_local,
    status,
) = sys.argv[1:16]

run_seq = int(run_seq_raw) if run_seq_raw.isdigit() else 0
record = {
    "prompt_slug": prompt_slug,
    "prompt_name": prompt_name,
    "run_id": run_id,
    "run_seq": run_seq,
    "run_key": run_key,
    "run_ref": run_ref,
    "run_work_dir": run_work_dir,
    "run_utc": run_utc,
    "run_local": run_local,
    "status": status,
}


def append_jsonl(path: str, obj: dict) -> None:
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    with p.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(obj, ensure_ascii=True, sort_keys=True) + "\n")


append_jsonl(state_jsonl, {"event": "state_update", **record})
append_jsonl(history_jsonl, {"event": "run_recorded", **record})
append_jsonl(runs_jsonl, record)

latest_path = Path(state_latest_json)
latest_path.parent.mkdir(parents=True, exist_ok=True)
if latest_path.is_file():
    try:
        latest = json.loads(latest_path.read_text(encoding="utf-8"))
        if not isinstance(latest, dict):
            latest = {}
    except Exception:
        latest = {}
else:
    latest = {}

prompts_latest = latest.get("prompts")
if not isinstance(prompts_latest, dict):
    prompts_latest = {}
prompts_latest[prompt_slug] = {
    "prompt_slug": prompt_slug,
    "prompt_name": prompt_name,
    "run_id": run_id,
    "run_seq": run_seq,
    "run_key": run_key,
    "run_ref": run_ref,
    "status": status,
    "updated_utc": run_utc,
}
latest["updated_utc"] = run_utc
latest["prompts"] = {k: prompts_latest[k] for k in sorted(prompts_latest.keys())}
latest_path.write_text(json.dumps(latest, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")

catalog_path = Path(catalog_json)
catalog_path.parent.mkdir(parents=True, exist_ok=True)
if catalog_path.is_file():
    try:
        catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
        if not isinstance(catalog, dict):
            catalog = {}
    except Exception:
        catalog = {}
else:
    catalog = {}

prompts = catalog.get("prompts")
if not isinstance(prompts, dict):
    prompts = {}

entry = prompts.get(prompt_slug)
if not isinstance(entry, dict):
    entry = {"prompt_slug": prompt_slug, "prompt_name": prompt_name, "run_count": 0}

entry["prompt_slug"] = prompt_slug
entry["prompt_name"] = prompt_name
entry["run_count"] = int(entry.get("run_count", 0)) + 1
entry["last_run_id"] = run_id
entry["last_run_seq"] = run_seq
entry["last_run_key"] = run_key
entry["last_run_ref"] = run_ref
entry["last_run_utc"] = run_utc
entry["last_status"] = status
prompts[prompt_slug] = entry

catalog["version"] = "codex-sprint-v4-flat"
catalog["updated_utc"] = run_utc
catalog["prompt_count"] = len(prompts)
catalog["layout"] = {
    "state_log": "state.jsonl",
    "state_latest": "state.latest.json",
    "history_log": "history.jsonl",
    "runs_log": "runs.jsonl",
    "artifact_index": "artifacts.jsonl",
    "catalog": "catalog.json",
}
catalog["prompts"] = {k: prompts[k] for k in sorted(prompts.keys())}
catalog_path.write_text(json.dumps(catalog, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")
PY
}

prism_append_artifact() {
  local f="$1"
  local sha="${2:-}"
  [ -f "${f}" ] || return 0

  python3 - \
    "${PRISM_ARTIFACTS_JSONL}" \
    "${CODEX_PROMPT_SLUG}" \
    "${CODEX_PROMPT_NAME}" \
    "${RUN_ID}" \
    "${RUN_SEQ}" \
    "${RUN_KEY}" \
    "${RUN_REF}" \
    "${PRISM_EVID_DIR}" \
    "${RUN_UTC}" \
    "${f}" \
    "${sha}" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

(
    index_path,
    prompt_slug,
    prompt_name,
    run_id,
    run_seq_raw,
    run_key,
    run_ref,
    run_work_dir,
    run_utc,
    file_path,
    sha,
) = sys.argv[1:12]

run_seq = int(run_seq_raw) if run_seq_raw.isdigit() else 0
p = Path(file_path)
run_dir_path = Path(run_work_dir)

try:
    rel = p.resolve().relative_to(run_dir_path.resolve()).as_posix()
except Exception:
    rel = str(p)

if not sha:
    h = hashlib.sha256()
    with p.open("rb") as fh:
        while True:
            chunk = fh.read(1024 * 1024)
            if not chunk:
                break
            h.update(chunk)
    sha = h.hexdigest()

row = {
    "prompt_slug": prompt_slug,
    "prompt_name": prompt_name,
    "run_id": run_id,
    "run_seq": run_seq,
    "run_key": run_key,
    "run_ref": run_ref,
    "run_work_dir": run_work_dir,
    "run_utc": run_utc,
    "file_name": p.name,
    "rel_path": rel,
    "bytes": p.stat().st_size,
    "sha256": sha,
}

idx = Path(index_path)
idx.parent.mkdir(parents=True, exist_ok=True)
with idx.open("a", encoding="utf-8") as fh:
    fh.write(json.dumps(row, ensure_ascii=True, sort_keys=True) + "\n")
PY
}

prism_cleanup_workdir() {
  if [[ "${CODEX_SPRINT_KEEP_WORK:-0}" == "1" ]]; then
    return
  fi
  [[ -n "${PRISM_EVID_DIR:-}" ]] || return
  rm -rf "${PRISM_EVID_DIR}" 2>/dev/null || true
}

prism_init() {
  : "${REPO_ROOT:=$(pwd)}"
  : "${CODEX_PROMPT_NAME:=prism}"

  export CODEX_PROMPT_SLUG
  CODEX_PROMPT_SLUG="$(_prism_slug "${CODEX_PROMPT_NAME}")"
  if [ -z "${CODEX_PROMPT_SLUG}" ]; then
    CODEX_PROMPT_SLUG="prism"
  fi

  export RUN_LOCAL_LABEL
  RUN_LOCAL_LABEL="$(date '+%I:%M %p - %d-%m-%Y')"

  export RUN_UTC
  RUN_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  export CODEX_SPRINT_ROOT
  CODEX_SPRINT_ROOT="${REPO_ROOT}/temp/codex-sprint"
  mkdir -p "${CODEX_SPRINT_ROOT}"

  export PRISM_STATE_JSONL="${CODEX_SPRINT_ROOT}/state.jsonl"
  export PRISM_STATE_LATEST_JSON="${CODEX_SPRINT_ROOT}/state.latest.json"
  export PRISM_HISTORY_JSONL="${CODEX_SPRINT_ROOT}/history.jsonl"
  export PRISM_RUNS_JSONL="${CODEX_SPRINT_ROOT}/runs.jsonl"
  export PRISM_CATALOG_JSON="${CODEX_SPRINT_ROOT}/catalog.json"
  export PRISM_ARTIFACTS_JSONL="${CODEX_SPRINT_ROOT}/artifacts.jsonl"

  export RUN_SEQ
  RUN_SEQ="$(python3 - "${PRISM_STATE_LATEST_JSON}" "${CODEX_PROMPT_SLUG}" <<'PY'
import json
import sys
from pathlib import Path

p = Path(sys.argv[1])
prompt_slug = sys.argv[2]
if not p.is_file():
    print("1")
    raise SystemExit(0)
try:
    obj = json.loads(p.read_text(encoding="utf-8"))
    if not isinstance(obj, dict):
        obj = {}
    prompts = obj.get("prompts")
    if not isinstance(prompts, dict):
        prompts = {}
    cur = prompts.get(prompt_slug)
    if not isinstance(cur, dict):
        cur = {}
    seq = int(cur.get("run_seq", 0)) + 1
    print(str(seq if seq > 0 else 1))
except Exception:
    print("1")
PY
)"
  if ! [[ "${RUN_SEQ}" =~ ^[0-9]+$ ]]; then
    RUN_SEQ="1"
  fi

  export RUN_ID
  RUN_ID="$(printf 'r%04d' "${RUN_SEQ}")"

  export RUN_KEY
  RUN_KEY="${CODEX_PROMPT_SLUG}--${RUN_ID}"

  export RUN_REF
  RUN_REF="${CODEX_SPRINT_ROOT}/runs.jsonl#${RUN_KEY}"

  export CODEX_EVIDENCE_ROOT
  CODEX_EVIDENCE_ROOT="${CODEX_SPRINT_ROOT}"

  export PRISM_EVID_DIR
  PRISM_EVID_DIR="${TMPDIR:-/tmp}/codex-sprint-work/${RUN_KEY}"
  mkdir -p "${PRISM_EVID_DIR}"
  chmod 700 "${PRISM_EVID_DIR}" || true

  export PRISM_EXEC_LOG="${PRISM_EVID_DIR}/exec.log"
  export PRISM_EVENTS="${PRISM_EVID_DIR}/events.ndjson"

  trap prism_cleanup_workdir EXIT

  # redirect stdout/stderr into exec.log (tee to console)
  exec > >(tee -a "${PRISM_EXEC_LOG}") 2> >(tee -a "${PRISM_EXEC_LOG}" >&2)

  prism_event init \
    run_id="${RUN_ID}" \
    run_seq="${RUN_SEQ}" \
    run_key="${RUN_KEY}" \
    run_ref="${RUN_REF}" \
    run_local_label="${RUN_LOCAL_LABEL}" \
    run_utc="${RUN_UTC}" \
    work_dir="${PRISM_EVID_DIR}" \
    prompt_name="${CODEX_PROMPT_NAME}" \
    prompt_slug="${CODEX_PROMPT_SLUG}"

  prism_store_update "running"
  prism_append_artifact "${PRISM_EXEC_LOG}" ""
  prism_append_artifact "${PRISM_EVENTS}" ""
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

# Hashes appended into events.ndjson and artifacts.jsonl
prism_hash() {
  for f in "$@"; do
    if [ -f "$f" ]; then
      local h
      h="$(sha256sum "$f" | awk '{print $1}')"
      prism_event sha file="$f" sha256="$h"
      prism_append_artifact "$f" "$h"
    else
      prism_event sha_missing file="$f"
    fi
  done
}
