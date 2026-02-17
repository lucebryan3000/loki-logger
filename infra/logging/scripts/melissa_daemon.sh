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

stamp(){ date -u +%Y-%m-%dT%H:%M:%SZ; }
log_file(){ printf "%s %s\n" "$(stamp)" "$*" >> "$LOG"; }
log_journal(){ logger -t melissa-longrun "$*"; }

log_file "DAEMON_START"
log_journal "DAEMON_START"

while true; do
  log_file "DAEMON_CYCLE_START"
  log_journal "DAEMON_CYCLE_START"

  rc=0
  if ! /bin/bash "$ROOT/infra/logging/scripts/melissa_longrun.sh" >> "$LOG" 2>> "$ERR"; then
    rc=$?
  fi

  if [[ $rc -eq 0 ]]; then
    log_file "DAEMON_CYCLE_OK"
    log_journal "DAEMON_CYCLE_OK"
    sleep 10
  else
    log_file "DAEMON_CYCLE_FAIL exit=$rc"
    log_journal "DAEMON_CYCLE_FAIL exit=$rc"
    sleep 30
  fi

  if rg -n '@filename|Write tests for|\? for shortcuts' "$LOG" "$STATE/TRACKING.md" "$ERR" >/dev/null 2>&1; then
    log_file "DAEMON_STOP drift_tokens_detected"
    log_journal "DAEMON_STOP drift_tokens_detected"
    exit 99
  fi

  if [[ ! -f "$MANIFEST" ]]; then
    log_file "DAEMON_STOP manifest_missing"
    log_journal "DAEMON_STOP manifest_missing"
    exit 3
  fi
done
