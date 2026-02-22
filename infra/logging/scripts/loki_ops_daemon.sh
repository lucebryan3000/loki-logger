#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/luce/apps/loki-logging"
STATE="$ROOT/_build/loki-ops"
LOG="$STATE/runtime.log"
ERR="$STATE/daemon.stderr.log"
MANIFEST="$STATE/batch_manifest.json"

TOK_ONE="$(printf '%s%s' '@' 'filename')"
TOK_TWO="$(printf '%s %s %s' 'Write' 'tests' 'for')"
TOK_THREE="$(printf '%s for %s' '?' 'shortcuts')"

mkdir -p "$STATE"
: >> "$LOG"
: >> "$ERR"

stamp(){ date -u +%Y-%m-%dT%H:%M:%SZ; }
log_file(){ printf "%s %s\n" "$(stamp)" "$*" >> "$LOG"; }
log_journal(){ logger -t loki-ops "$*"; }

has_drift(){
  local file
  for file in "$LOG" "$STATE/TRACKING.md" "$ERR"; do
    [[ -f "$file" ]] || continue
    if grep -Fq "$TOK_ONE" "$file" || grep -Fq "$TOK_TWO" "$file" || grep -Fq "$TOK_THREE" "$file"; then
      return 0
    fi
  done
  return 1
}

log_file "DAEMON_START"
log_journal "DAEMON_START"

while true; do
  log_file "DAEMON_CYCLE_START"
  log_journal "DAEMON_CYCLE_START"

  rc=0
  if ! /bin/bash "$ROOT/infra/logging/scripts/loki_ops_longrun.sh" >> "$LOG" 2>> "$ERR"; then
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

  if has_drift; then
    log_file "DAEMON_STOP drift_guard_hit"
    log_journal "DAEMON_STOP drift_guard_hit"
    exit 99
  fi

  if [[ ! -f "$MANIFEST" ]]; then
    log_file "DAEMON_STOP manifest_missing"
    log_journal "DAEMON_STOP manifest_missing"
    exit 3
  fi
done
