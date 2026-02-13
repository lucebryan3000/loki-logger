#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd -P)"
PROD_ROOT="${REPO_ROOT}/temp/codex-sprint"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      REPO_ROOT="${2:-}"
      shift 2
      ;;
    --prod-root)
      PROD_ROOT="${2:-}"
      shift 2
      ;;
    -h|--help)
      cat <<'EOF'
Usage: sync_helpers_to_prod.sh [--repo-root <path>] [--prod-root <path>]
Copies codex-sprint helper scripts from dev (scripts/codex-sprint/) to prod (temp/codex-sprint/).
EOF
      exit 0
      ;;
    *)
      echo "unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

mkdir -p "${PROD_ROOT}"

copy_exec() {
  local src="$1"
  local dst="$2"
  install -m 0755 "${src}" "${dst}"
}

DEV_DIR="${REPO_ROOT}/scripts/codex-sprint"

copy_exec "${DEV_DIR}/codex_sprint_recall.py" "${PROD_ROOT}/codex_sprint_recall.py"
copy_exec "${DEV_DIR}/codex_sprint_recall.sh" "${PROD_ROOT}/codex_sprint_recall.sh"
copy_exec "${DEV_DIR}/search_records.py" "${PROD_ROOT}/search_records.py"
copy_exec "${DEV_DIR}/search_artifacts.py" "${PROD_ROOT}/search_artifacts.py"

python3 - <<'PY' "${REPO_ROOT}" "${PROD_ROOT}"
import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

repo_root = Path(sys.argv[1])
prod_root = Path(sys.argv[2])

files = [
    (repo_root / "scripts/codex-sprint/codex_sprint_recall.py", prod_root / "codex_sprint_recall.py"),
    (repo_root / "scripts/codex-sprint/codex_sprint_recall.sh", prod_root / "codex_sprint_recall.sh"),
    (repo_root / "scripts/codex-sprint/search_records.py", prod_root / "search_records.py"),
    (repo_root / "scripts/codex-sprint/search_artifacts.py", prod_root / "search_artifacts.py"),
]

rows = []
for dev, prod in files:
    h = hashlib.sha256(dev.read_bytes()).hexdigest() if dev.is_file() else ""
    rows.append({
        "name": dev.name,
        "dev": str(dev),
        "prod": str(prod),
        "sha256": h,
    })

manifest = {
    "synced_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "repo_root": str(repo_root),
    "prod_root": str(prod_root),
    "files": rows,
}
(prod_root / "helpers.manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
PY

printf 'synced helper scripts to %s\n' "${PROD_ROOT}"
