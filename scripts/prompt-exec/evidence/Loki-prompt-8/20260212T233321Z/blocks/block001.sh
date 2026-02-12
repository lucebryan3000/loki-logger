#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
umask 022
source "/home/luce/apps/loki-logging/scripts/prompt-exec/evidence/Loki-prompt-8/20260212T233321Z/env.sh"
if [ -n "${REPO_ROOT:-}" ]; then cd "$REPO_ROOT"; else cd "$PROMPT_DIR"; fi
set -euo pipefail

REPO="/home/luce/apps/loki-logging"
cd "$REPO"

FAIL=0

need_cmd() {
  local c="$1"
  if command -v "$c" >/dev/null 2>&1; then
    echo "PASS: command '$c' found"
  else
    echo "FAIL: command '$c' missing"
    FAIL=1
  fi
}

need_file() {
  local f="$1"
  if [ -f "$f" ]; then
    echo "PASS: file exists: $f"
  else
    echo "FAIL: missing file: $f"
    FAIL=1
  fi
}

need_cmd docker
need_cmd python3
need_cmd git
need_cmd awk
need_cmd sha256sum

need_file "$REPO/scripts/prism/evidence.sh"
need_file "$REPO/infra/logging/alloy-config.alloy"
need_file "$REPO/infra/logging/docker-compose.observability.yml"

if [ "$FAIL" -ne 0 ]; then
  echo "PRECHECK_FAIL"
  exit 1
fi

echo "PRECHECK_OK"
