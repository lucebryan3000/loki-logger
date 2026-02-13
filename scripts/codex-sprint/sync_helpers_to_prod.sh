#!/usr/bin/env bash
set -euo pipefail

# Sync codex-sprint helper scripts from dev (`scripts/codex-sprint`) into
# runtime/prod (`temp/codex-sprint`) and write a checksum manifest.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd -P)"
PROD_ROOT="${REPO_ROOT}/temp/codex-sprint"
DEV_DIR="${REPO_ROOT}/scripts/codex-sprint"
MODE="all"

usage() {
  cat <<'EOF'
Usage: sync_helpers_to_prod.sh [options]

Copy codex-sprint scripts from dev to prod and write `helpers.manifest.json`.

Options:
  --repo-root <path>   Repository root (default: inferred from script location)
  --prod-root <path>   Destination root (default: <repo>/temp/codex-sprint)
  --mode helpers|all   Sync mode:
                         all     = all top-level *.py and *.sh under scripts/codex-sprint (default)
                         helpers = recall/search helper scripts only
  -h, --help           Show this help and exit

Examples:
  scripts/codex-sprint/sync_helpers_to_prod.sh
  scripts/codex-sprint/sync_helpers_to_prod.sh --mode all
  scripts/codex-sprint/sync_helpers_to_prod.sh --repo-root /home/luce/apps/loki-logging --prod-root /tmp/codex-sprint
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      [[ $# -ge 2 ]] || { echo "--repo-root requires a value" >&2; exit 2; }
      REPO_ROOT="${2:-}"
      shift 2
      ;;
    --prod-root)
      [[ $# -ge 2 ]] || { echo "--prod-root requires a value" >&2; exit 2; }
      PROD_ROOT="${2:-}"
      shift 2
      ;;
    --mode)
      [[ $# -ge 2 ]] || { echo "--mode requires a value" >&2; exit 2; }
      MODE="${2:-}"
      shift 2
      ;;
    -h|--help)
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
PROD_ROOT="$(realpath -m "${PROD_ROOT}")"
DEV_DIR="${REPO_ROOT}/scripts/codex-sprint"

case "${MODE}" in
  helpers|all) ;;
  *)
    echo "invalid --mode value: ${MODE}" >&2
    usage
    exit 2
    ;;
esac

[[ -d "${DEV_DIR}" ]] || { echo "missing dev dir: ${DEV_DIR}" >&2; exit 2; }
mkdir -p "${PROD_ROOT}"

copy_exec() {
  # Install scripts executable to keep behavior consistent in prod root.
  local src="$1"
  local dst="$2"
  install -m 0755 "${src}" "${dst}"
}

collect_sources() {
  if [[ "${MODE}" == "helpers" ]]; then
    cat <<'EOF'
codex_sprint_recall.py
codex_sprint_recall.sh
search_records.py
search_artifacts.py
EOF
  else
    find "${DEV_DIR}" -maxdepth 1 -type f \( -name "*.py" -o -name "*.sh" \) -printf "%f\n" | sort
  fi
}

mapfile -t FILE_LIST < <(collect_sources)
for name in "${FILE_LIST[@]}"; do
  [[ -n "${name}" ]] || continue
  copy_exec "${DEV_DIR}/${name}" "${PROD_ROOT}/${name}"
done

python3 - <<'PY' "${REPO_ROOT}" "${PROD_ROOT}" "${MODE}" "${DEV_DIR}" "${FILE_LIST[@]}"
import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

repo_root = Path(sys.argv[1])
prod_root = Path(sys.argv[2])
mode = sys.argv[3]
dev_dir = Path(sys.argv[4])
names = sys.argv[5:]

rows = []
for name in names:
    dev = dev_dir / name
    prod = prod_root / name
    h = hashlib.sha256(dev.read_bytes()).hexdigest() if dev.is_file() else ""
    rows.append(
        {
            "name": dev.name,
            "dev": str(dev),
            "prod": str(prod),
            "sha256": h,
        }
    )

manifest = {
    "synced_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "mode": mode,
    "repo_root": str(repo_root),
    "prod_root": str(prod_root),
    "files": rows,
}
(prod_root / "helpers.manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
PY

printf 'synced %s script(s) to %s (mode=%s)\n' "${#FILE_LIST[@]}" "${PROD_ROOT}" "${MODE}"
