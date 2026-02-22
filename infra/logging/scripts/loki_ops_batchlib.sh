#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/luce/apps/loki-logging"
STATE="$ROOT/_build/loki-ops"
LOG="$STATE/runtime.log"
TRACKING="$STATE/TRACKING.md"
NODRIFT_HELPER="$ROOT/infra/logging/scripts/no_drift_print.sh"

TOK_ONE="$(printf '%s%s' '@' 'filename')"
TOK_TWO="$(printf '%s %s %s' 'Write' 'tests' 'for')"
TOK_THREE="$(printf '%s for %s' '?' 'shortcuts')"

now_utc(){ date -u +%Y-%m-%dT%H:%M:%SZ; }

log(){
  mkdir -p "$STATE"
  printf "%s %s\n" "$(now_utc)" "$*" >> "$LOG"
}

guard_message(){
  local line="$*"
  if [[ -x "$NODRIFT_HELPER" ]]; then
    if ! "$NODRIFT_HELPER" "$line" >/dev/null 2>&1; then
      log "DRIFT_GUARD_BLOCKED"
      return 99
    fi
    return 0
  fi

  if [[ "$line" == *"$TOK_ONE"* || "$line" == *"$TOK_TWO"* || "$line" == *"$TOK_THREE"* ]]; then
    log "DRIFT_GUARD_BLOCKED"
    return 99
  fi

  return 0
}

pipe(){
  local line="$*"
  guard_message "$line" || return 99
  log "PIPE: $line"
  printf "PIPE: %s\n" "$line" >> "$TRACKING"
}

scan_file_for_drift(){
  local file="$1"
  [[ -f "$file" ]] || return 0

  if grep -Fq "$TOK_ONE" "$file" || grep -Fq "$TOK_TWO" "$file" || grep -Fq "$TOK_THREE" "$file"; then
    log "DRIFT_GUARD_FILE_HIT file=$file"
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
    pipe "⛔ BLOCK | reason=hard_gates_failed | gaps=unexpected_empty_or_verify | next=stop" || true
    return 2
  fi

  pipe "🧾 EVIDENCE hard_gates | state=ok | summary=unexpected=0 verify=true | canonical=audit+verifier" || true
  return 0
}

update_memory_runner_state(){
  local mem="$1"
  local idx="$2"
  local ts="$3"
  local mode="$4"
  local total="$5"
  local run_name="$6"
  local checkpoint_hash="$7"

  local tmp
  tmp=$(mktemp)

  if [[ -s "$mem" ]] && jq -e . "$mem" >/dev/null 2>&1; then
    jq \
      --argjson idx "$idx" \
      --arg ts "$ts" \
      --arg mode "$mode" \
      --argjson total "$total" \
      --arg run "$run_name" \
      --arg chk "$checkpoint_hash" \
      '.runner = ((.runner // {}) + {active_run:$run, mode:$mode, target_items:$total, last_completed_item:$idx, last_updated:$ts, last_checkpoint_hash:$chk, dry_run:false})' \
      "$mem" > "$tmp"
  else
    jq -n \
      --argjson idx "$idx" \
      --arg ts "$ts" \
      --arg mode "$mode" \
      --argjson total "$total" \
      --arg run "$run_name" \
      --arg chk "$checkpoint_hash" \
      '{runner:{active_run:$run, mode:$mode, target_items:$total, last_completed_item:$idx, last_updated:$ts, last_checkpoint_hash:$chk, dry_run:false}}' > "$tmp"
  fi

  mv "$tmp" "$mem"
}

queue_update_item(){
  local qjson="$1"
  local idx="$2"
  local status="$3"
  local attempt="$4"
  local notes="$5"
  local started_at="$6"
  local ended_at="$7"

  python3 - "$qjson" "$idx" "$status" "$attempt" "$notes" "$started_at" "$ended_at" <<'PY'
import json,sys
p,idx,status,attempt,notes,started,ended=sys.argv[1:]
idx=int(idx); attempt=int(attempt)
obj=json.load(open(p))
for it in obj.get("items",[]):
    if int(it.get("idx",-1))==idx:
        it["status"]=status
        it["attempt"]=attempt
        it["notes"]=notes
        if started:
            it["started_at"]=started
        if ended:
            it["ended_at"]=ended
        break
json.dump(obj,open(p,"w"),indent=2)
PY
}

queue_write_markdown(){
  local qjson="$1"
  local qmd="$2"
  python3 - "$qjson" "$qmd" <<'PY'
import json,sys
q=json.load(open(sys.argv[1]))
out=sys.argv[2]
lines=[]
lines.append(f"# Loki-Ops Queue — {q.get('run','run')}")
lines.append("")
lines.append(f"- total: {q.get('total',0)}")
lines.append(f"- continue_on_fail: {str(q.get('continue_on_fail', True)).lower()}")
lines.append("")
lines.append("| idx | id | type | status | attempt | target |")
lines.append("|---:|---|---|---|---:|---|")
for it in q.get("items",[]):
    lines.append(f"| {it.get('idx')} | {it.get('id')} | {it.get('type')} | {it.get('status')} | {it.get('attempt',0)} | {it.get('target','')} |")
open(out,"w").write("\n".join(lines)+"\n")
PY
}
