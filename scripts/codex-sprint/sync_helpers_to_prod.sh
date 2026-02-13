#!/usr/bin/env bash
set -euo pipefail

# Sync codex-sprint helper scripts from dev (`scripts/codex-sprint`) into
# runtime/prod (`temp/codex-sprint`) and write a checksum manifest.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd -P)"
PROD_ROOT="${REPO_ROOT}/temp/codex-sprint"
DEV_DIR="${REPO_ROOT}/scripts/codex-sprint"
ALLOWLIST_PATH="${DEV_DIR}/sync.allowlist"
MODE="all"
PRUNE=1

usage() {
  cat <<'EOF'
Usage: sync_helpers_to_prod.sh [options]

Copy codex-sprint scripts from dev to prod and write `helpers.manifest.json`.

Options:
  --repo-root <path>   Repository root (default: inferred from script location)
  --prod-root <path>   Destination root (default: <repo>/temp/codex-sprint)
  --allowlist <path>   Canonical file allowlist (default: scripts/codex-sprint/sync.allowlist)
  --mode helpers|all   Sync mode:
                         all     = files from allowlist (default)
                         helpers = recall/search helper scripts only
  --no-prune           Keep extra old script/readme files in prod root (default: prune stale)
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
    --allowlist)
      [[ $# -ge 2 ]] || { echo "--allowlist requires a value" >&2; exit 2; }
      ALLOWLIST_PATH="${2:-}"
      shift 2
      ;;
    --mode)
      [[ $# -ge 2 ]] || { echo "--mode requires a value" >&2; exit 2; }
      MODE="${2:-}"
      shift 2
      ;;
    --no-prune)
      PRUNE=0
      shift
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
ALLOWLIST_PATH="$(realpath -m "${ALLOWLIST_PATH}")"

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

copy_readme() {
  local src="$1"
  local dst="$2"
  install -m 0644 "${src}" "${dst}"
}

copy_data() {
  local src="$1"
  local dst="$2"
  install -m 0644 "${src}" "${dst}"
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
    if [[ ! -f "${ALLOWLIST_PATH}" ]]; then
      echo "missing allowlist file: ${ALLOWLIST_PATH}" >&2
      return 2
    fi
    awk '
      {
        gsub(/^[ \t]+|[ \t]+$/, "", $0);
        if ($0 == "" || $0 ~ /^#/) next;
        print $0;
      }
    ' "${ALLOWLIST_PATH}" | sort -u
  fi
}

mapfile -t FILE_LIST < <(collect_sources)
[[ "${#FILE_LIST[@]}" -gt 0 ]] || { echo "no files selected for sync" >&2; exit 2; }
for name in "${FILE_LIST[@]}"; do
  [[ -n "${name}" ]] || continue
  [[ -f "${DEV_DIR}/${name}" ]] || { echo "allowlisted file missing in dev dir: ${DEV_DIR}/${name}" >&2; exit 2; }
  if [[ "${name}" == "README.md" ]]; then
    copy_readme "${DEV_DIR}/${name}" "${PROD_ROOT}/${name}"
  elif [[ "${name}" == *.py || "${name}" == *.sh ]]; then
    copy_exec "${DEV_DIR}/${name}" "${PROD_ROOT}/${name}"
  else
    copy_data "${DEV_DIR}/${name}" "${PROD_ROOT}/${name}"
  fi
done

if [[ "${PRUNE}" -eq 1 ]]; then
  # Remove stale top-level script/readme files so deprecated names do not persist.
  mapfile -t PROD_TOP_LEVEL < <(find "${PROD_ROOT}" -maxdepth 1 -type f \( -name "*.py" -o -name "*.sh" -o -name "README.md" \) -printf "%f\n" | sort)
  for pname in "${PROD_TOP_LEVEL[@]}"; do
    keep=0
    for expected in "${FILE_LIST[@]}"; do
      if [[ "${pname}" == "${expected}" ]]; then
        keep=1
        break
      fi
    done
    if [[ "${keep}" -eq 0 ]]; then
      rm -f "${PROD_ROOT}/${pname}"
    fi
  done
fi

python3 - <<'PY' "${REPO_ROOT}" "${PROD_ROOT}" "${MODE}" "${PRUNE}" "${DEV_DIR}" "${ALLOWLIST_PATH}" "${FILE_LIST[@]}"
import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

repo_root = Path(sys.argv[1])
prod_root = Path(sys.argv[2])
mode = sys.argv[3]
prune = sys.argv[4] == "1"
dev_dir = Path(sys.argv[5])
allowlist_path = Path(sys.argv[6])
names = sys.argv[7:]

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
    "prune": prune,
    "allowlist": str(allowlist_path),
    "repo_root": str(repo_root),
    "prod_root": str(prod_root),
    "files": rows,
}
(prod_root / "helpers.manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
PY

printf 'synced %s file(s) to %s (mode=%s prune=%s)\n' "${#FILE_LIST[@]}" "${PROD_ROOT}" "${MODE}" "${PRUNE}"
