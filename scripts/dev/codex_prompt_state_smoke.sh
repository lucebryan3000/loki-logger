#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
PROMPTS_DIR="${REPO_ROOT}/_build/Sprint-3/prompts/codex-prompt-state-tests"
STORE_ROOT="${REPO_ROOT}/temp/codex-prompt-state"
OUT_DIR="${REPO_ROOT}/temp/codex-prompt-state-tests/output"
PROMPT_EXEC_BIN="${PROMPT_EXEC_BIN:-$(command -v prompt-exec || true)}"
CPS_BIN="${CPS_BIN:-$(command -v codex-prompt-state || true)}"

if [[ -z "${PROMPT_EXEC_BIN}" ]]; then
  PROMPT_EXEC_BIN="/home/luce/.local/bin/prompt-exec"
fi
if [[ ! -x "${PROMPT_EXEC_BIN}" ]]; then
  echo "prompt-exec binary not found: ${PROMPT_EXEC_BIN}" >&2
  exit 2
fi

mkdir -p "${OUT_DIR}"

if [[ -n "${CPS_BIN}" && -x "${CPS_BIN}" ]]; then
  "${CPS_BIN}" doctor \
    --repo-root "${REPO_ROOT}" \
    --prompt-dir "${PROMPTS_DIR}" \
    --prompt-path "${PROMPTS_DIR}/cps-01-success.md" >/dev/null
fi

run_prompt() {
  local prompt_name="$1"
  local expected_rc="$2"
  shift 2
  local prompt_path="${PROMPTS_DIR}/${prompt_name}"
  local log_path="${OUT_DIR}/${prompt_name}.smoke.log"

  set +e
  if [[ "$#" -gt 0 ]]; then
    env "$@" "${PROMPT_EXEC_BIN}" "${prompt_path}" >"${log_path}" 2>&1
  else
    "${PROMPT_EXEC_BIN}" "${prompt_path}" >"${log_path}" 2>&1
  fi
  local rc=$?
  set -e

  echo "${prompt_name} rc=${rc} expected=${expected_rc}"
  if [[ "${rc}" != "${expected_rc}" ]]; then
    echo "rc mismatch for ${prompt_name}; see ${log_path}" >&2
    exit 1
  fi
}

run_prompt "cps-01-success.md" "0"
run_prompt "cps-02-fail-fast.md" "0"
run_prompt "cps-03-noncritical.md" "0"
run_prompt "cps-04-completion-gate-fail.md" "0"
# Strict probe: ensure warning halt still blocks without allowlist.
run_prompt "cps-05-warning-halt.md" "2" "PROMPT_EXEC_WARN_ALLOW_REGEX=(?!)"
# Remediated path: scoped allowlist from frontmatter allows execution.
run_prompt "cps-05-warning-halt.md" "0"

export REPO_ROOT
python3 - <<'PY'
import json
import os
from pathlib import Path

repo = Path(os.environ['REPO_ROOT'])
store = repo / 'temp/codex-prompt-state'
runs = store / 'runs.jsonl'
latest = store / 'state.latest.json'

expected = {
    'cps-01-success': 'success',
    'cps-02-fail-fast': 'success',
    'cps-03-noncritical': 'success',
    'cps-04-completion-gate-fail': 'success',
    'cps-05-warning-halt': 'success',
}

if not runs.is_file():
    raise SystemExit('missing runs.jsonl')
if not latest.is_file():
    raise SystemExit('missing state.latest.json')

latest_obj = json.loads(latest.read_text(encoding='utf-8'))
latest_prompts = latest_obj.get('prompts', {}) if isinstance(latest_obj.get('prompts', {}), dict) else {}

for slug, want in expected.items():
    row = latest_prompts.get(slug)
    if not isinstance(row, dict):
        raise SystemExit(f'missing latest row for {slug}')
    got = row.get('status')
    print(f'{slug}: status={got} expected={want}')
    if got != want:
        raise SystemExit(f'status mismatch for {slug}: got={got} want={want}')

print('codex_prompt_state_smoke=PASS')
PY
