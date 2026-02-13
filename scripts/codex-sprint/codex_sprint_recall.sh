#!/usr/bin/env bash
set -euo pipefail

# Thin shell wrapper around `codex_sprint_recall.py`.
# This keeps a stable operator-friendly CLI while delegating data logic to Python.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd -P)"
ROOT_DEFAULT="${REPO_ROOT}/temp/codex-sprint"
PY_HELPER="${SCRIPT_DIR}/codex_sprint_recall.py"

usage() {
  cat <<'EOF'
Usage: codex_sprint_recall.sh <command> [args...]

Convenience wrapper for searching/summarizing flat codex-sprint indexes.
Global option `--root` can appear before or after the command.

Commands:
  summary
      Show index paths + quick counts/sizes.

  latest [--prompt <slug-substring>] [--limit <n>]
      Show latest state rows from state.latest.json.

  runs [--prompt <slug-substring>] [--run <run-substring>] [--status <status>] [--limit <n>]
      Shortcut for: find --index runs ...

  artifacts [--prompt <slug-substring>] [--file <file-substring>] [--run <run-substring>] [--limit <n>]
      Shortcut for: find --index artifacts ...

  find --index state|history|runs|artifacts|all [--prompt <q>] [--run <q>] [--file <q>] [--status <status>] [--limit <n>]
      Generic query across one or all indexes.

Global options:
  --root <path>   codex-sprint root (default: <repo>/temp/codex-sprint)
  -h, --help      show this help and exit

Examples:
  codex_sprint_recall.sh --root /home/luce/apps/loki-logging/temp/codex-sprint summary
  codex_sprint_recall.sh latest --prompt loki-prompt-13
  codex_sprint_recall.sh runs --prompt loki-prompt-22 --status failed --limit 20
  codex_sprint_recall.sh artifacts --prompt loki-prompt-22 --file manifest.txt
  codex_sprint_recall.sh find --index all --run r0007 --file completion_gate.json
EOF
}

[ $# -gt 0 ] || { usage; exit 0; }

root="${ROOT_DEFAULT}"
cmd=""
pass=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      [[ $# -ge 2 ]] || { echo "--root requires a value" >&2; exit 2; }
      root="${2:-}"
      shift 2
      ;;
    -h|--help|help)
      usage
      exit 0
      ;;
    summary|latest|runs|artifacts|find)
      [[ -z "${cmd}" ]] || { pass+=("$1"); shift; continue; }
      cmd="$1"
      shift
      ;;
    *)
      if [[ -z "${cmd}" ]]; then
        echo "unknown command: $1" >&2
        usage
        exit 2
      fi
      pass+=("$1")
      shift
      ;;
  esac
done

[[ -n "${cmd}" ]] || { echo "missing command" >&2; usage; exit 2; }

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
  *)
    echo "unknown command: ${cmd}" >&2
    usage
    exit 2
    ;;
esac
