#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd -P)"
ROOT_DEFAULT="${REPO_ROOT}/temp/codex-sprint"
PY_HELPER="${SCRIPT_DIR}/codex_sprint_recall.py"

usage() {
  cat <<'EOF'
Usage: codex_sprint_recall.sh <command> [args...]

Commands:
  summary [--root <path>]
  latest [--root <path>] [--prompt <slug-substring>] [--limit <n>]
  runs [--root <path>] [--prompt <slug-substring>] [--run <run-substring>] [--status <status>] [--limit <n>]
  artifacts [--root <path>] [--prompt <slug-substring>] [--file <file-substring>] [--run <run-substring>] [--limit <n>]
  find [--root <path>] --index state|history|runs|artifacts|all [filters]

Examples:
  codex_sprint_recall.sh summary
  codex_sprint_recall.sh latest --prompt loki-prompt-13
  codex_sprint_recall.sh runs --prompt loki-prompt-22 --status failed
  codex_sprint_recall.sh artifacts --prompt loki-prompt-22 --file manifest.txt
EOF
}

[ $# -gt 0 ] || { usage; exit 2; }

cmd="$1"
shift

root="${ROOT_DEFAULT}"
pass=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      root="${2:-}"
      shift 2
      ;;
    *)
      pass+=("$1")
      shift
      ;;
  esac
done

case "${cmd}" in
  summary)
    python3 "${PY_HELPER}" --root "${root}" summary
    ;;
  latest)
    python3 "${PY_HELPER}" --root "${root}" latest "${pass[@]}"
    ;;
  runs)
    python3 "${PY_HELPER}" --root "${root}" find --index runs "${pass[@]}"
    ;;
  artifacts)
    python3 "${PY_HELPER}" --root "${root}" find --index artifacts "${pass[@]}"
    ;;
  find)
    python3 "${PY_HELPER}" --root "${root}" find "${pass[@]}"
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    echo "unknown command: ${cmd}" >&2
    usage
    exit 2
    ;;
esac
