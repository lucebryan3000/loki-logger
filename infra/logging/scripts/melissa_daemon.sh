#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/luce/apps/loki-logging"
STATE="$ROOT/_build/melissa"
LOG="$STATE/runtime.log"
ERR="$STATE/daemon.stderr.log"
MANIFEST="$STATE/batch_manifest.json"

mkdir -p "$STATE"
: >> "$LOG"
: >> "$ERR"

printf "%s %s\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "DAEMON_START" >> "$LOG"

while true; do
  cycle_start="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf "%s %s\n" "$cycle_start" "DAEMON_CYCLE_START" >> "$LOG"

  rc=0
  if ! /bin/bash "$ROOT/infra/logging/scripts/melissa_longrun.sh" >> "$LOG" 2>> "$ERR"; then
    rc=$?
  fi

  if [[ $rc -eq 0 ]]; then
    printf "%s %s\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "DAEMON_CYCLE_OK" >> "$LOG"
    sleep 10
  else
    printf "%s %s\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "DAEMON_CYCLE_FAIL exit=$rc" >> "$LOG"
    sleep 30
  fi

  # drift stop condition: if trigger strings appear, stop daemon loop fail-closed
  if rg -n '@filename|Write tests for|\? for shortcuts' "$LOG" "$STATE/TRACKING.md" "$ERR" >/dev/null 2>&1; then
    printf "%s %s\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "DAEMON_STOP drift_tokens_detected" >> "$LOG"
    exit 99
  fi

  # health sanity between cycles
  if [[ ! -f "$MANIFEST" ]]; then
    printf "%s %s\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "DAEMON_STOP manifest_missing" >> "$LOG"
    exit 3
  fi

done
