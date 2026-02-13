#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd -P)"
OUT_DIR="${REPO_ROOT}/temp/codex-sprint"
PHASE_LOG_DIR="${REPO_ROOT}/temp/codex-sprint-phases"

mkdir -p "${PHASE_LOG_DIR}"

PYTHONPATH="${SCRIPT_DIR}:${PYTHONPATH:-}" REPO_ROOT="${REPO_ROOT}" python3 - <<'PY'
import os
from pathlib import Path
from common import tree_metrics, write_json

repo_root = Path(os.environ["REPO_ROOT"])
payload = {
    "legacy": {
        "temp/codex": tree_metrics(repo_root / "temp" / "codex").to_dict(),
        "temp/.artifacts": tree_metrics(repo_root / "temp" / ".artifacts").to_dict(),
    }
}
write_json(repo_root / "temp" / "codex-sprint-phases" / "baseline_metrics.json", payload)
PY

run_phase() {
  local phase="$1"
  local script="${SCRIPT_DIR}/evolve_v${phase}.py"

  echo "== codex-sprint phase ${phase} =="
  rm -rf "${OUT_DIR}"
  python3 "${script}" --repo-root "${REPO_ROOT}" --out "${OUT_DIR}" | tee "${PHASE_LOG_DIR}/phase${phase}.run.log"

  cp "${OUT_DIR}/SUMMARY.json" "${PHASE_LOG_DIR}/phase${phase}.summary.json"
  find "${OUT_DIR}" -maxdepth 3 -type d | sort > "${PHASE_LOG_DIR}/phase${phase}.dirs.txt"
  find "${OUT_DIR}" -type f | sort > "${PHASE_LOG_DIR}/phase${phase}.files.txt"
}

run_phase 1
run_phase 2
run_phase 3

echo "completed all phases; final output retained at ${OUT_DIR}"
