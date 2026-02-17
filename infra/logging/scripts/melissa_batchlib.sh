#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/luce/apps/loki-logging"
STATE="$ROOT/_build/melissa"
LOG="$STATE/runtime.log"
TRACKING="$STATE/TRACKING.md"
DRIFT_RE='@filename|Write tests for|\? for shortcuts'

now_utc(){ date -u +%Y-%m-%dT%H:%M:%SZ; }

log(){
  mkdir -p "$STATE"
  printf "%s %s\n" "$(now_utc)" "$*" >> "$LOG"
}

pipe(){
  local line="$*"
  case "$line" in
    *"@filename"*|*"Write tests for"*|*"? for shortcuts"*)
      log "DRIFT_TRIGGER_DETECTED line=$(printf '%s' "$line" | tr '\n' ' ' | cut -c1-200)"
      exit 99
      ;;
  esac
  log "PIPE: $line"
  printf "PIPE: %s\n" "$line" >> "$TRACKING"
}

scan_file_for_drift(){
  local file="$1"
  if [[ -f "$file" ]] && rg -n "$DRIFT_RE" "$file" >/dev/null 2>&1; then
    log "DRIFT_TRIGGER_DETECTED file=$file"
    return 99
  fi
  return 0
}

derive_grafana_pass(){
  docker inspect logging-grafana-1 --format '{{range .Config.Env}}{{println .}}{{end}}' | rg '^GF_SECURITY_ADMIN_PASSWORD=' | sed 's/^GF_SECURITY_ADMIN_PASSWORD=//'
}

require_endpoints(){
  curl -fsS http://127.0.0.1:3200/ready >/dev/null
  curl -fsS http://127.0.0.1:9004/-/healthy >/dev/null
  local gp
  gp="$(derive_grafana_pass)"
  test -n "$gp"
  curl -fsS -u "admin:$gp" http://127.0.0.1:9001/api/health >/dev/null
}

hard_gates(){
  (cd "$ROOT" && bash infra/logging/scripts/dashboard_query_audit.sh >/dev/null)
  (cd "$ROOT" && bash infra/logging/scripts/verify_grafana_authority.sh >/dev/null)

  local unexpected pass
  unexpected=$(jq -r '.summary.unexpected_empty_panels' "$ROOT/_build/logging/dashboard_audit_latest.json")
  pass=$(jq -r '.pass' "$ROOT/_build/logging/verify_grafana_authority_latest.json")

  if [[ "$unexpected" != "0" || "$pass" != "true" ]]; then
    pipe "⛔ BLOCK | reason=hard_gates_failed | unexpected=$unexpected verify_pass=$pass | next=stop"
    return 2
  fi

  pipe "🧾 EVIDENCE hard_gates | state=ok | summary=unexpected_empty_panels=$unexpected verify_pass=$pass | canonical=audit+verifier"
  return 0
}

update_memory_runner_state(){
  local mem="$1"
  local batch_idx="$2"
  local ts="$3"
  local mode="$4"
  local total="$5"
  local run_name="$6"
  local tmp

  tmp=$(mktemp)
  if [[ -f "$mem" ]]; then
    jq \
      --argjson idx "$batch_idx" \
      --arg ts "$ts" \
      --arg mode "$mode" \
      --argjson total "$total" \
      --arg run "$run_name" \
      '.runner = ((.runner // {}) + {active_run:$run, mode:$mode, target_batches:$total, last_completed_batch:$idx, last_updated:$ts, dry_run:false})' \
      "$mem" > "$tmp"
  else
    jq -n \
      --argjson idx "$batch_idx" \
      --arg ts "$ts" \
      --arg mode "$mode" \
      --argjson total "$total" \
      --arg run "$run_name" \
      '{runner:{active_run:$run, mode:$mode, target_batches:$total, last_completed_batch:$idx, last_updated:$ts, dry_run:false}}' > "$tmp"
  fi
  mv "$tmp" "$mem"
}

checkpoint_if_needed(){
  local checkpoint_every="$1"
  local idx="$2"
  local run_name="$3"

  if (( checkpoint_every <= 0 )) || (( idx % checkpoint_every != 0 )); then
    return 0
  fi

  if ! hard_gates; then
    return 2
  fi

  local files
  files=$(git -C "$ROOT" status --porcelain=v1 | awk '{print $2}' | rg '^infra/logging/grafana/dashboards/sources/codeswarm-src-.*\.json$' || true)
  if [[ -z "$files" ]]; then
    pipe "🧾 EVIDENCE checkpoint | state=skip | summary=no_dashboard_changes | canonical=allowlist"
    return 0
  fi

  git -C "$ROOT" reset >/dev/null
  git -C "$ROOT" add $files

  local bad
  bad=$(git -C "$ROOT" diff --name-only --cached | rg -v '^infra/logging/grafana/dashboards/sources/codeswarm-src-.*\.json$' || true)
  if [[ -n "$bad" ]]; then
    git -C "$ROOT" reset >/dev/null
    pipe "⛔ BLOCK | reason=checkpoint_bad_staged | gaps=allowlist_violation | next=stop"
    return 4
  fi

  if git -C "$ROOT" diff --cached --quiet; then
    pipe "🧾 EVIDENCE checkpoint | state=skip | summary=staged_empty | canonical=allowlist"
    return 0
  fi

  git -C "$ROOT" commit -m "ops: melissa checkpoint $run_name batch-$idx" >/dev/null
  local hash
  hash=$(git -C "$ROOT" rev-parse --short HEAD)
  pipe "🧾 EVIDENCE checkpoint | state=commit | summary=hash=$hash batch=$idx | canonical=allowlist"
  return 0
}
