#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/luce/apps/loki-logging"
STATE="$ROOT/_build/melissa"
MANIFEST="$STATE/batch_manifest.json"
MEM="$STATE/memory.json"
QUEUE_JSON="$STATE/queue.json"
TRACKING="$STATE/TRACKING.md"
LOG="$STATE/runtime.log"

mkdir -p "$STATE"
: >> "$LOG"

# Silence runner stdout/stderr by default
stdout_buf="$STATE/longrun.stdout.buffer"
stderr_buf="$STATE/longrun.stderr.buffer"
: > "$stdout_buf"
: > "$stderr_buf"
exec 1>>"$stdout_buf" 2>>"$stderr_buf"

source "$ROOT/infra/logging/scripts/melissa_batchlib.sh"

if [[ ! -f "$MANIFEST" ]]; then
  log "MANIFEST_MISSING path=$MANIFEST"
  exit 3
fi

mode=$(jq -r '.mode // "real"' "$MANIFEST")
max_minutes=$(jq -r '.max_minutes // 60' "$MANIFEST")
hard_every=$(jq -r '.hard_gate_every // 2' "$MANIFEST")
checkpoint_every=$(jq -r '.checkpoint_every // 2' "$MANIFEST")
heartbeat_minutes=$(jq -r '.heartbeat_minutes // 20' "$MANIFEST")
heal_max_attempts=$(jq -r '.heal_max_attempts // 2' "$MANIFEST")

run_name="melissa-longrun-$(date -u +%Y%m%dT%H%M%SZ)"
start_ts=$(date +%s)

# Initialize tracking (overwrite per run)
{
  echo "📍 Run: ${run_name}"
  echo "🗂️ State: ${STATE}"
  echo "🕒 Refreshed (UTC): $(now_utc)"
  echo "📌 PROGRESS | done=0/0 | running=none | fail=0 | p50=n/a p90=n/a | eta=n/a"
  echo
} > "$TRACKING"

require_endpoints

# Resolve deterministic queue once
LOKIQR="http://127.0.0.1:3200/loki/api/v1/query_range"
start_ns=$((($(date +%s)-21600)*1000000000))
end_ns=$((($(date +%s)+60)*1000000000))
q='topk(200, sum by (log_source) (count_over_time({log_source=~".+"}[6h])))'
resp=$(curl -fsS "$LOKIQR" --get --data-urlencode "query=$q" --data-urlencode "start=$start_ns" --data-urlencode "end=$end_ns" --data-urlencode "limit=200" --data-urlencode "direction=BACKWARD")

source_order_json=$(jq -c '.source_order // []' "$MANIFEST")
python3 - <<PY > "$QUEUE_JSON"
import json
active_resp=json.loads('''$resp''')
source_order=json.loads('''$source_order_json''')
active=sorted({r.get('metric',{}).get('log_source') for r in active_resp.get('data',{}).get('result',[]) if r.get('metric',{}).get('log_source')})
ordered=[]
seen=set()
for s in source_order:
    if s in active and s not in seen:
        ordered.append(s); seen.add(s)
for s in active:
    if s not in seen:
        ordered.append(s); seen.add(s)
queue=[{"idx":i+1,"source":s} for i,s in enumerate(ordered)]
print(json.dumps({"run":"$run_name","resolved_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","total":len(queue),"active":active,"queue":queue},indent=2))
PY

N=$(jq -r '.total' "$QUEUE_JSON")
if ! [[ "$N" =~ ^[0-9]+$ ]]; then
  log "QUEUE_INVALID total=$N"
  exit 4
fi

last_done=0
if [[ -f "$MEM" ]]; then
  last_done=$(jq -r '.runner.last_completed_batch // 0' "$MEM" 2>/dev/null || echo 0)
fi
if ! [[ "$last_done" =~ ^[0-9]+$ ]]; then
  last_done=0
fi
if (( N > 0 && last_done >= N )); then
  last_done=0
  pipe "🧾 EVIDENCE resume | state=reset | summary=pointer_exceeded_queue | canonical=last_completed_batch"
fi

pipe "🚀 RUN_START | run=$run_name | total=$N | state=$STATE | mode=$mode"

if (( N == 0 )); then
  if ! hard_gates; then
    exit 2
  fi
  pipe "🏁 RUN_DONE | result=done | ran=0 | fail=0 | total=0 | elapsed=$(( $(date +%s)-start_ts ))s | state=$STATE | run=$run_name"
  if ! scan_file_for_drift "$stdout_buf"; then exit 99; fi
  if ! scan_file_for_drift "$stderr_buf"; then exit 99; fi
  exit 0
fi

fail_count=0
done_count=0
last_heartbeat=$start_ts

run_batch(){
  local src="$1"
  local idx="$2"
  local attempts=0

  while (( attempts < heal_max_attempts )); do
    attempts=$((attempts+1))
    pipe "🚧 BATCH_START $src | idx=$idx/$N | attempt=$attempts | status=run"

    if ! require_endpoints; then
      pipe "🛠️ HEAL | class=endpoints | action=retry | result=fail | next=retry"
      continue
    fi

    local dash="$ROOT/infra/logging/grafana/dashboards/sources/codeswarm-src-${src}.json"
    if [[ ! -f "$dash" ]]; then
      mkdir -p "$(dirname "$dash")"
      cat > "$dash" <<JSON
{
  "uid": "codeswarm-src-${src}",
  "title": "CodeSwarm - ${src}",
  "timezone": "browser",
  "refresh": "30s",
  "time": {"from":"now-6h","to":"now"},
  "tags": ["codeswarm","logging","source","${src}"],
  "editable": true,
  "panels": [
    {"type":"logs","title":"Live logs","datasource":{"type":"loki","uid":"P8E80F9AEF21F6940"},"targets":[{"refId":"A","expr":"{log_source=\"${src}\"}"}]}
  ]
}
JSON
      pipe "🛠️ HEAL | class=missing_dashboard | action=create_minimal | result=ok | next=continue"
    fi

    if (( hard_every > 0 )) && (( idx % hard_every == 0 )); then
      if ! hard_gates; then
        pipe "🛠️ HEAL | class=hard_gates | action=retry | result=fail | next=retry"
        continue
      fi
    fi

    if ! checkpoint_if_needed "$checkpoint_every" "$idx" "$run_name"; then
      pipe "🛠️ HEAL | class=checkpoint | action=retry | result=fail | next=retry"
      continue
    fi

    pipe "✅ BATCH_DONE $src | dur=n/a | end=$(now_utc) | attempt=$attempts | status=ok"
    return 0
  done

  return 1
}

for idx in $(seq $((last_done+1)) "$N"); do
  now=$(date +%s)
  mins=$(((now-start_ts)/60))
  if (( mins >= max_minutes )); then
    pipe "⛔ BLOCK | reason=timebox_reached | gaps=n/a | next=resume"
    break
  fi

  src=$(jq -r ".queue[] | select(.idx==${idx}) | .source" "$QUEUE_JSON")
  if [[ -z "$src" || "$src" == "null" ]]; then
    pipe "⛔ BLOCK | reason=queue_resolution_failed | gaps=missing_source_idx_${idx} | next=stop"
    exit 5
  fi

  if run_batch "$src" "$idx"; then
    done_count="$idx"
    update_memory_runner_state "$MEM" "$idx" "$(now_utc)" "$mode" "$N" "$run_name"
  else
    fail_count=$((fail_count+1))
    pipe "⛔ BLOCK | reason=batch_failed | gaps=source_${src} | next=stop"
    exit 6
  fi

  now=$(date +%s)
  if (( (now-last_heartbeat) >= (heartbeat_minutes*60) )); then
    pipe "📌 PROGRESS | done=$done_count/$N | running=none | fail=$fail_count | p50=n/a p90=n/a | eta=n/a"
    last_heartbeat=$now
  fi

done

if ! hard_gates; then
  exit 2
fi

pipe "📌 PROGRESS | done=$done_count/$N | running=none | fail=$fail_count | p50=n/a p90=n/a | eta=n/a"
pipe "🏁 RUN_DONE | result=done | ran=$done_count | fail=$fail_count | total=$N | elapsed=$(( $(date +%s)-start_ts ))s | state=$STATE | run=$run_name"

if ! scan_file_for_drift "$stdout_buf"; then
  exit 99
fi
if ! scan_file_for_drift "$stderr_buf"; then
  exit 99
fi
if ! scan_file_for_drift "$TRACKING"; then
  exit 99
fi
if ! scan_file_for_drift "$LOG"; then
  exit 99
fi

exit 0
