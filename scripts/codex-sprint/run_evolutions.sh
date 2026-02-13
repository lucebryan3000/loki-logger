#!/usr/bin/env bash
set -euo pipefail

# Execute three codex-sprint evolution phases via one canonical builder:
# 1) v1 copy-oriented layout
# 2) v2 flattened-blob layout
# 3) v4-flat single-file-index layout (final output kept)
#
# The script also captures per-phase logs and snapshots to
# `temp/codex-sprint-phases/`, then syncs helper scripts into final output.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd -P)"
OUT_DIR="${REPO_ROOT}/temp/codex-sprint"
PHASE_LOG_DIR="${REPO_ROOT}/temp/codex-sprint-phases"
SKIP_SYNC=0

usage() {
  cat <<'EOF'
Usage: run_evolutions.sh [options]

Run codex-sprint phase builders (v1 -> v2 -> v4-flat), replacing output each phase.
Uses single canonical script: `scripts/codex-sprint/evolve.py`.
Final retained output is from phase 3 at `--out-dir`.

Options:
  --repo-root <path>      Repository root (default: inferred from script location)
  --out-dir <path>        Final codex-sprint output root (default: <repo>/temp/codex-sprint)
  --phase-log-dir <path>  Where phase logs/summaries are written (default: <repo>/temp/codex-sprint-phases)
  --skip-sync             Skip helper sync from scripts/codex-sprint to <out-dir>
  -h, --help              Show this help and exit

Outputs:
  <phase-log-dir>/baseline_metrics.json
  <phase-log-dir>/phaseN.run.log
  <phase-log-dir>/phaseN.summary.json
  <phase-log-dir>/phaseN.dirs.txt
  <phase-log-dir>/phaseN.files.txt

Examples:
  scripts/codex-sprint/run_evolutions.sh
  scripts/codex-sprint/run_evolutions.sh --out-dir /tmp/codex-sprint
  scripts/codex-sprint/run_evolutions.sh --repo-root /home/luce/apps/loki-logging --skip-sync
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      [[ $# -ge 2 ]] || { echo "--repo-root requires a value" >&2; exit 2; }
      REPO_ROOT="${2:-}"
      shift 2
      ;;
    --out-dir)
      [[ $# -ge 2 ]] || { echo "--out-dir requires a value" >&2; exit 2; }
      OUT_DIR="${2:-}"
      shift 2
      ;;
    --phase-log-dir)
      [[ $# -ge 2 ]] || { echo "--phase-log-dir requires a value" >&2; exit 2; }
      PHASE_LOG_DIR="${2:-}"
      shift 2
      ;;
    --skip-sync)
      SKIP_SYNC=1
      shift
      ;;
    -h|--help|help)
      usage
      exit 0
      ;;
    *)
      echo "unknown arg: $1" >&2
      usage
      exit 2
      ;;
  esac
done

REPO_ROOT="$(cd "${REPO_ROOT}" && pwd -P)"
OUT_DIR="$(realpath -m "${OUT_DIR}")"
PHASE_LOG_DIR="$(realpath -m "${PHASE_LOG_DIR}")"

mkdir -p "${PHASE_LOG_DIR}"

write_baseline_metrics() {
  # Capture footprint before phase runs for side-by-side comparisons.
  PYTHONPATH="${SCRIPT_DIR}:${PYTHONPATH:-}" REPO_ROOT="${REPO_ROOT}" PHASE_LOG_DIR="${PHASE_LOG_DIR}" python3 - <<'PY'
import os
from pathlib import Path
from common import tree_metrics, write_json

repo_root = Path(os.environ["REPO_ROOT"])
phase_log_dir = Path(os.environ["PHASE_LOG_DIR"])
payload = {
    "legacy": {
        "temp/codex": tree_metrics(repo_root / "temp" / "codex").to_dict(),
        "temp/.artifacts": tree_metrics(repo_root / "temp" / ".artifacts").to_dict(),
    }
}
write_json(phase_log_dir / "baseline_metrics.json", payload)
PY
}

run_phase() {
  local phase="$1"
  local script="${SCRIPT_DIR}/evolve.py"

  echo "== codex-sprint phase ${phase} =="
  rm -rf "${OUT_DIR}"
  python3 "${script}" --phase "${phase}" --repo-root "${REPO_ROOT}" --out "${OUT_DIR}" \
    | tee "${PHASE_LOG_DIR}/phase${phase}.run.log"

  cp "${OUT_DIR}/SUMMARY.json" "${PHASE_LOG_DIR}/phase${phase}.summary.json"
  find "${OUT_DIR}" -maxdepth 3 -type d | sort > "${PHASE_LOG_DIR}/phase${phase}.dirs.txt"
  find "${OUT_DIR}" -type f | sort > "${PHASE_LOG_DIR}/phase${phase}.files.txt"
}

write_baseline_metrics

run_phase 1
run_phase 2
run_phase 3

SYNC_HELPERS_SH="${SCRIPT_DIR}/sync_helpers_to_prod.sh"
if [[ "${SKIP_SYNC}" -eq 0 && -x "${SYNC_HELPERS_SH}" ]]; then
  "${SYNC_HELPERS_SH}" --repo-root "${REPO_ROOT}" --prod-root "${OUT_DIR}" >/dev/null
fi

echo "completed all phases; final output retained at ${OUT_DIR}"
