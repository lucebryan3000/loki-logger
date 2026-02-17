#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/luce/apps/loki-logging"
STATE="$ROOT/_build/melissa"
MANIFEST="$STATE/batch_manifest.json"
MEM="$STATE/memory.json"

mkdir -p "$STATE"
: >> "$STATE/runtime.log"

source "$ROOT/infra/logging/scripts/melissa_batchlib.sh"

if [[ ! -f "$MANIFEST" ]]; then
  log "MANIFEST_MISSING path=$MANIFEST"
  exit 3
fi

max_minutes=$(jq -r '.max_minutes // 90' "$MANIFEST")
hard_every=$(jq -r '.hard_gate_every // 3' "$MANIFEST")
checkpoint_every=$(jq -r '.checkpoint_every // 0' "$MANIFEST")
dry_batches=$(jq -r '.dry_run_batches // 1' "$MANIFEST")
real_batches=$(jq -r '.real_run_batches // 1' "$MANIFEST")

mode="${MELISSA_MODE:-dry}"
if [[ "$mode" == "real" ]]; then
  target_batches="$real_batches"
  dry_bool=false
else
  target_batches="$dry_batches"
  dry_bool=true
fi

if [[ -n "${MELISSA_BATCHES:-}" ]]; then
  target_batches="$MELISSA_BATCHES"
fi
if ! [[ "$target_batches" =~ ^[0-9]+$ ]] || [[ "$target_batches" -lt 1 ]]; then
  log "RUNNER_CONFIG_INVALID target_batches=$target_batches"
  exit 4
fi

start_ts=$(date +%s)
log "RUNNER_START mode=$mode max_minutes=$max_minutes hard_every=$hard_every checkpoint_every=$checkpoint_every target_batches=$target_batches"

last_done=0
if [[ -f "$MEM" ]]; then
  last_done=$(jq -r '.runner.last_completed_batch // 0' "$MEM" 2>/dev/null || echo 0)
fi
if ! [[ "$last_done" =~ ^[0-9]+$ ]]; then
  last_done=0
fi

stdout_buf="$STATE/longrun.stdout.buffer"
stderr_buf="$STATE/longrun.stderr.buffer"
: > "$stdout_buf"
: > "$stderr_buf"
exec 1>>"$stdout_buf" 2>>"$stderr_buf"

if ! get_active_sources_6h; then
  log "RUNNER_ABORT reason=active_sources_failed"
  exit 5
fi

b=0
while [[ $b -lt $target_batches ]]; do
  b=$((b+1))
  now=$(date +%s)
  mins=$(((now-start_ts)/60))
  if [[ $mins -ge $max_minutes ]]; then
    log "TIMEBOX_REACHED mins=$mins"
    break
  fi

  id=$((last_done+b))
  log "BATCH_START id=$id mode=$mode"

  if ! micro_gates; then
    log "BATCH_FAIL id=$id phase=micro_gates"
    exit 2
  fi

  if (( hard_every > 0 )) && (( b % hard_every == 0 )); then
    if ! hard_gates; then
      log "BATCH_FAIL id=$id phase=hard_gates"
      exit 2
    fi
  fi

  ts=$(now_utc)
  update_memory_runner_state "$MEM" "$id" "$ts" "$dry_bool" "$mode" "$target_batches"
  log "BATCH_DONE id=$id"

  if (( checkpoint_every > 0 )) && (( b % checkpoint_every == 0 )); then
    if ! checkpoint_commit_if_needed "$dry_bool" "$id"; then
      log "BATCH_FAIL id=$id phase=checkpoint"
      exit 6
    fi
  fi

done

if ! hard_gates; then
  log "RUNNER_FAIL phase=final_hard_gates"
  exit 2
fi

if ! scan_file_for_drift "$stdout_buf"; then
  exit 99
fi
if ! scan_file_for_drift "$stderr_buf"; then
  exit 99
fi

log "RUNNER_DONE"
exit 0
