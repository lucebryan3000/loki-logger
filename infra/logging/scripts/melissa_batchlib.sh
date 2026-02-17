#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/luce/apps/loki-logging"
STATE="$ROOT/_build/melissa"
LOG="$STATE/runtime.log"
DRIFT_RE='@filename|Write tests for|\? for shortcuts'

now_utc(){ date -u +%Y-%m-%dT%H:%M:%SZ; }

log(){
  mkdir -p "$STATE"
  printf "%s %s\n" "$(now_utc)" "$*" >> "$LOG"
}

# Never print to stdout; only log. Exit 99 if suspicious tokens appear.
safe_echo(){
  local s="$*"
  case "$s" in
    *"@filename"*|*"Write tests for"*|*"? for shortcuts"*)
      log "DRIFT_TRIGGER_DETECTED msg=$(printf '%s' "$s" | tr '\n' ' ' | cut -c1-200)"
      exit 99
      ;;
  esac
  log "STDOUT_SUPPRESSED msg=$(printf '%s' "$s" | tr '\n' ' ' | cut -c1-200)"
}

scan_file_for_drift(){
  local file="$1"
  if [[ -f "$file" ]] && rg -n "$DRIFT_RE" "$file" >/dev/null 2>&1; then
    log "DRIFT_TRIGGER_DETECTED file=$file"
    return 99
  fi
  return 0
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
  local start_ns end_ns q resp count

  start_ns=$((($(date +%s)-21600)*1000000000))
  end_ns=$((($(date +%s)+60)*1000000000))
  q='topk(50, sum by (log_source) (count_over_time({log_source=~".+"}[6h])))'
  resp=$(curl -fsS "$lokiqr" --get --data-urlencode "query=$q" --data-urlencode "start=$start_ns" --data-urlencode "end=$end_ns" --data-urlencode "limit=50" --data-urlencode "direction=BACKWARD")

  printf "%s" "$resp" > "$qr"
  printf "%s" "$resp" | jq -r '.data.result[].metric.log_source' | sort -u > "$out"
  count=$(wc -l < "$out" | tr -d ' ')
  log "ACTIVE_6H_COUNT=$count"
}

micro_gates(){
  require_endpoints
  log "MICRO_GATES_OK=yes"
}

hard_gates(){
  (cd "$ROOT" && bash infra/logging/scripts/dashboard_query_audit.sh >/dev/null)
  (cd "$ROOT" && bash infra/logging/scripts/verify_grafana_authority.sh >/dev/null)

  local unexpected pass
  unexpected=$(jq -r '.summary.unexpected_empty_panels' "$ROOT/_build/logging/dashboard_audit_latest.json")
  pass=$(jq -r '.pass' "$ROOT/_build/logging/verify_grafana_authority_latest.json")

  if [[ "$unexpected" != "0" || "$pass" != "true" ]]; then
    log "HARD_GATES_OK=no unexpected=$unexpected verify_pass=$pass"
    return 2
  fi
  log "HARD_GATES_OK=yes unexpected=$unexpected verify_pass=$pass"
  return 0
}

update_memory_runner_state(){
  local mem="$1"
  local batch="$2"
  local ts="$3"
  local dry="$4"
  local mode="$5"
  local target_batches="$6"
  local tmp

  tmp=$(mktemp)
  if [[ -f "$mem" ]]; then
    jq \
      --argjson b "$batch" \
      --arg ts "$ts" \
      --argjson dry "$dry" \
      --arg mode "$mode" \
      --argjson target "$target_batches" \
      '.runner = ((.runner // {}) + {active_run:"melissa_longrun", mode:$mode, target_batches:$target, last_completed_batch:$b, last_updated:$ts, dry_run:$dry})' \
      "$mem" > "$tmp"
  else
    jq -n \
      --argjson b "$batch" \
      --arg ts "$ts" \
      --argjson dry "$dry" \
      --arg mode "$mode" \
      --argjson target "$target_batches" \
      '{runner:{active_run:"melissa_longrun", mode:$mode, target_batches:$target, last_completed_batch:$b, last_updated:$ts, dry_run:$dry}}' > "$tmp"
  fi
  mv "$tmp" "$mem"
}

checkpoint_commit_if_needed(){
  local dry="$1"
  local checkpoint_id="$2"

  if [[ "$dry" == "true" ]]; then
    log "CHECKPOINT_ELIGIBLE=no reason=dry_run id=$checkpoint_id"
    return 0
  fi

  local files
  files=$(git -C "$ROOT" status --porcelain=v1 | awk '{print $2}' | rg '^infra/logging/grafana/dashboards/sources/codeswarm-src-.*\.json$' || true)
  if [[ -z "$files" ]]; then
    log "CHECKPOINT_ELIGIBLE=no reason=no_dashboard_changes id=$checkpoint_id"
    return 0
  fi

  if ! hard_gates; then
    log "CHECKPOINT_ABORTED reason=hard_gates_failed id=$checkpoint_id"
    return 2
  fi

  git -C "$ROOT" reset >/dev/null
  git -C "$ROOT" add $files
  local bad
  bad=$(git -C "$ROOT" diff --name-only --cached | rg -v '^infra/logging/grafana/dashboards/sources/codeswarm-src-.*\.json$' || true)
  if [[ -n "$bad" ]]; then
    log "CHECKPOINT_ABORTED reason=bad_staged id=$checkpoint_id bad=$(printf '%s' "$bad" | tr '\n' ',')"
    git -C "$ROOT" reset >/dev/null
    return 4
  fi

  if git -C "$ROOT" diff --cached --quiet; then
    log "CHECKPOINT_ELIGIBLE=no reason=staged_empty id=$checkpoint_id"
    return 0
  fi

  git -C "$ROOT" commit -m "grafana: checkpoint source dashboards batch ${checkpoint_id}" >/dev/null
  local h
  h=$(git -C "$ROOT" rev-parse --short HEAD)
  log "CHECKPOINT_COMMIT=yes id=$checkpoint_id hash=$h"
  return 0
}
