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
  safe_echo "MANIFEST_MISSING=$MANIFEST"
  exit 3
fi

max_minutes=$(jq -r '.max_minutes' "$MANIFEST")
hard_every=$(jq -r '.hard_gate_every' "$MANIFEST")
dry_batches=$(jq -r '.dry_run_batches' "$MANIFEST")

start_ts=$(date +%s)
log "RUNNER_START max_minutes=$max_minutes hard_every=$hard_every dry_batches=$dry_batches"

last_done=0
if [[ -f "$MEM" ]]; then
  last_done=$(jq -r '.runner.last_completed_batch // 0' "$MEM" 2>/dev/null || echo 0)
fi
if ! [[ "$last_done" =~ ^[0-9]+$ ]]; then
  last_done=0
fi

get_active_sources_6h >/tmp/melissa_longrun_active.out

b=0
while [[ $b -lt $dry_batches ]]; do
  b=$((b+1))
  now=$(date +%s)
  mins=$(((now-start_ts)/60))
  if [[ $mins -ge $max_minutes ]]; then
    log "TIMEBOX_REACHED mins=$mins"
    break
  fi

  id=$((last_done+b))
  log "BATCH_START id=$id mode=dry"
  micro_gates >/tmp/melissa_longrun_micro.out

  if (( b % hard_every == 0 )); then
    hard_gates >/tmp/melissa_longrun_hard.out
  fi

  ts=$(now_utc)
  update_memory_runner_state "$MEM" "$id" "$ts" true
  log "BATCH_DONE id=$id"
done

hard_gates >/tmp/melissa_longrun_hard_final.out
log "RUNNER_DONE"
safe_echo "RUN_DONE_OK=yes"
