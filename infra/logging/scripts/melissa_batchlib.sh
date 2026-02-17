#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/luce/apps/loki-logging"
STATE="$ROOT/_build/melissa"
LOG="$STATE/runtime.log"

now_utc(){ date -u +%Y-%m-%dT%H:%M:%SZ; }

log(){
  mkdir -p "$STATE"
  printf "%s %s\n" "$(now_utc)" "$*" >> "$LOG"
}

safe_echo(){
  local s="$*"
  case "$s" in
    *"@filename"*|*"Write tests for"*|*"? for shortcuts"*)
      log "DRIFT_TRIGGER_DETECTED msg=$(printf '%s' "$s" | tr '\n' ' ' | cut -c1-200)"
      exit 99
      ;;
  esac
  printf "%s\n" "$s"
}

require_endpoints(){
  curl -fsS http://127.0.0.1:3200/ready >/dev/null
  curl -fsS http://127.0.0.1:9004/-/healthy >/dev/null
  local gp
  gp="$(docker inspect logging-grafana-1 --format '{{range .Config.Env}}{{println .}}{{end}}' | rg '^GF_SECURITY_ADMIN_PASSWORD=' | sed 's/^GF_SECURITY_ADMIN_PASSWORD=//')"
  test -n "$gp"
  curl -fsS -u "admin:$gp" http://127.0.0.1:9001/api/health >/dev/null
}

get_active_sources_6h(){
  local out="$STATE/log_source_values_active_6h.txt"
  local qr="$STATE/log_source_top_6h.json"
  local lokiqr="http://127.0.0.1:3200/loki/api/v1/query_range"
  local start_ns end_ns q resp
  start_ns=$((($(date +%s)-21600)*1000000000))
  end_ns=$((($(date +%s)+60)*1000000000))
  q='topk(50, sum by (log_source) (count_over_time({log_source=~".+"}[6h])))'
  resp=$(curl -fsS "$lokiqr" --get --data-urlencode "query=$q" --data-urlencode "start=$start_ns" --data-urlencode "end=$end_ns" --data-urlencode "limit=50" --data-urlencode "direction=BACKWARD")
  printf "%s" "$resp" > "$qr"
  printf "%s" "$resp" | jq -r '.data.result[].metric.log_source' | sort -u > "$out"
  safe_echo "ACTIVE_6H_COUNT=$(wc -l < "$out" | tr -d ' ')"
}

micro_gates(){
  require_endpoints
  safe_echo "MICRO_GATES_OK=yes"
}

hard_gates(){
  (cd "$ROOT" && bash infra/logging/scripts/dashboard_query_audit.sh >/dev/null)
  (cd "$ROOT" && bash infra/logging/scripts/verify_grafana_authority.sh >/dev/null)
  local unexpected pass
  unexpected=$(jq -r '.summary.unexpected_empty_panels' "$ROOT/_build/logging/dashboard_audit_latest.json")
  pass=$(jq -r '.pass' "$ROOT/_build/logging/verify_grafana_authority_latest.json")
  if [[ "$unexpected" != "0" || "$pass" != "true" ]]; then
    safe_echo "HARD_GATES_OK=no"
    exit 2
  fi
  safe_echo "HARD_GATES_OK=yes"
}

update_memory_runner_state(){
  local mem="$1"
  local batch="$2"
  local ts="$3"
  local dry="$4"
  local tmp
  tmp=$(mktemp)
  if [[ -f "$mem" ]]; then
    jq \
      --argjson b "$batch" \
      --arg ts "$ts" \
      --argjson dry "$dry" \
      '.runner = ((.runner // {}) + {active_run:"melissa_longrun", last_completed_batch:$b, last_updated:$ts, dry_run:$dry})' \
      "$mem" > "$tmp"
  else
    jq -n \
      --argjson b "$batch" \
      --arg ts "$ts" \
      --argjson dry "$dry" \
      '{runner:{active_run:"melissa_longrun", last_completed_batch:$b, last_updated:$ts, dry_run:$dry}}' > "$tmp"
  fi
  mv "$tmp" "$mem"
}
