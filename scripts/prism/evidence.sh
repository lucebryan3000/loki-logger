#!/usr/bin/env bash
set -euo pipefail

# Evidence v4 (repo-owned, compact codex-sprint layout):
#   temp/codex-sprint/
#     state/<prompt-slug>.jsonl
#     state/<prompt-slug>.latest.json
#     history/<prompt-slug>.jsonl
#     history/all-runs.jsonl
#     runs/<prompt-slug>--<rNNNN>/
#     catalog/prompts.json
#
# Environment:
#   REPO_ROOT (required by callers; defaults to pwd)
#   CODEX_PROMPT_NAME (optional; defaults "prism")

_prism_slug() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g'
}

prism_store_update() {
  local status="${1:-running}"

  python3 - \
    "${PRISM_STATE_LOG}" \
    "${PRISM_STATE_LATEST}" \
    "${PRISM_HISTORY_LOG}" \
    "${PRISM_ALL_HISTORY_LOG}" \
    "${PRISM_CATALOG_JSON}" \
    "${CODEX_PROMPT_SLUG}" \
    "${CODEX_PROMPT_NAME}" \
    "${RUN_ID}" \
    "${RUN_SEQ}" \
    "${RUN_KEY}" \
    "${PRISM_EVID_DIR}" \
    "${RUN_UTC}" \
    "${RUN_LOCAL_LABEL}" \
    "${status}" <<'PY'
import json
import sys
from pathlib import Path

(
    state_log,
    state_latest,
    history_log,
    all_history_log,
    catalog_json,
    prompt_slug,
    prompt_name,
    run_id,
    run_seq_raw,
    run_key,
    run_dir,
    run_utc,
    run_local,
    status,
) = sys.argv[1:15]

run_seq = int(run_seq_raw) if run_seq_raw.isdigit() else 0
record = {
    "prompt_slug": prompt_slug,
    "prompt_name": prompt_name,
    "run_id": run_id,
    "run_seq": run_seq,
    "run_key": run_key,
    "run_dir": run_dir,
    "run_utc": run_utc,
    "run_local": run_local,
    "status": status,
}


def append_jsonl(path: str, obj: dict) -> None:
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    with p.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(obj, ensure_ascii=True, sort_keys=True) + "\n")


append_jsonl(state_log, record)
append_jsonl(history_log, record)
append_jsonl(all_history_log, record)
Path(state_latest).write_text(json.dumps(record, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")

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
entry["last_run_utc"] = run_utc
entry["last_status"] = status
entry["last_run_dir"] = run_dir
prompts[prompt_slug] = entry

catalog["version"] = "codex-sprint-v3"
catalog["updated_utc"] = run_utc
catalog["prompt_count"] = len(prompts)
catalog["prompts"] = {k: prompts[k] for k in sorted(prompts.keys())}
catalog_path.write_text(json.dumps(catalog, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")
PY
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

  # Store full UTC in data; folder naming uses short per-prompt run ids.
  export RUN_UTC
  RUN_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  export CODEX_SPRINT_ROOT
  CODEX_SPRINT_ROOT="${REPO_ROOT}/temp/codex-sprint"
  mkdir -p \
    "${CODEX_SPRINT_ROOT}/state" \
    "${CODEX_SPRINT_ROOT}/history" \
    "${CODEX_SPRINT_ROOT}/runs" \
    "${CODEX_SPRINT_ROOT}/catalog"

  export PRISM_STATE_LOG="${CODEX_SPRINT_ROOT}/state/${CODEX_PROMPT_SLUG}.jsonl"
  export PRISM_STATE_LATEST="${CODEX_SPRINT_ROOT}/state/${CODEX_PROMPT_SLUG}.latest.json"
  export PRISM_HISTORY_LOG="${CODEX_SPRINT_ROOT}/history/${CODEX_PROMPT_SLUG}.jsonl"
  export PRISM_ALL_HISTORY_LOG="${CODEX_SPRINT_ROOT}/history/all-runs.jsonl"
  export PRISM_CATALOG_JSON="${CODEX_SPRINT_ROOT}/catalog/prompts.json"
  export PRISM_ARTIFACTS_JSONL="${CODEX_SPRINT_ROOT}/artifacts.jsonl"

  export RUN_SEQ
  RUN_SEQ="$(python3 - "${PRISM_STATE_LATEST}" <<'PY'
import json
import sys
from pathlib import Path

p = Path(sys.argv[1])
if not p.is_file():
    print("1")
    raise SystemExit(0)
try:
    obj = json.loads(p.read_text(encoding="utf-8"))
    seq = int(obj.get("run_seq", 0)) + 1
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

  export CODEX_EVIDENCE_ROOT
  CODEX_EVIDENCE_ROOT="${CODEX_SPRINT_ROOT}"

  export PRISM_EVID_DIR
  PRISM_EVID_DIR="${CODEX_SPRINT_ROOT}/runs/${RUN_KEY}"
  mkdir -p "${PRISM_EVID_DIR}"
  chmod 700 "${PRISM_EVID_DIR}" || true

  export PRISM_EXEC_LOG="${PRISM_EVID_DIR}/exec.log"
  export PRISM_EVENTS="${PRISM_EVID_DIR}/events.ndjson"

  # redirect stdout/stderr into exec.log (tee to console)
  exec > >(tee -a "${PRISM_EXEC_LOG}") 2> >(tee -a "${PRISM_EXEC_LOG}" >&2)

  prism_event init \
    run_id="${RUN_ID}" \
    run_seq="${RUN_SEQ}" \
    run_key="${RUN_KEY}" \
    run_local_label="${RUN_LOCAL_LABEL}" \
    run_utc="${RUN_UTC}" \
    evid_dir="${PRISM_EVID_DIR}" \
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
    run_dir,
    run_utc,
    file_path,
    sha,
) = sys.argv[1:11]

run_seq = int(run_seq_raw) if run_seq_raw.isdigit() else 0
p = Path(file_path)
run_dir_path = Path(run_dir)

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
    "run_dir": run_dir,
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

# Hashes appended into events.ndjson (no separate hash files)
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
