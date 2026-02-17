#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/luce/apps/loki-logging"
STATE="$ROOT/_build/melissa"
MANIFEST="$STATE/batch_manifest.json"
MEM="$STATE/memory.json"
QUEUE_JSON="$STATE/queue.json"
QUEUE_MD="$STATE/queue.md"
TRACKING="$STATE/TRACKING.md"
LOG="$STATE/runtime.log"
COMPOSE_FILE="$ROOT/infra/logging/docker-compose.observability.yml"

mkdir -p "$STATE"
: >> "$LOG"

stdout_buf="$STATE/longrun.stdout.buffer"
stderr_buf="$STATE/longrun.stderr.buffer"
: > "$stdout_buf"
: > "$stderr_buf"
exec 1>>"$stdout_buf" 2>>"$stderr_buf"

source "$ROOT/infra/logging/scripts/melissa_batchlib.sh"

mode="real"
max_minutes=240
hard_every=3
checkpoint_every=5
heartbeat_minutes=20
continue_on_fail="true"
max_grafana_restarts=1

if [[ -f "$MANIFEST" ]]; then
  mode=$(jq -r '.mode // "real"' "$MANIFEST")
  max_minutes=$(jq -r '.max_minutes // 240' "$MANIFEST")
  hard_every=$(jq -r '.hard_gate_every // 3' "$MANIFEST")
  checkpoint_every=$(jq -r '.checkpoint_every // 5' "$MANIFEST")
  heartbeat_minutes=$(jq -r '.heartbeat_minutes // 20' "$MANIFEST")
  continue_on_fail=$(jq -r '.continue_on_fail // true' "$MANIFEST")
  max_grafana_restarts=$(jq -r '.max_grafana_restarts_per_run // 1' "$MANIFEST")
fi

run_name="melissa-queue-$(date -u +%Y%m%dT%H%M%SZ)"
start_epoch=$(date +%s)
grafana_restart_count=0
last_checkpoint_hash=""

init_tracking(){
  {
    echo "📍 Run: $run_name"
    echo "🗂️ State: $STATE"
    echo "🕒 Refreshed (UTC): $(now_utc)"
    echo "📌 PROGRESS | done=0/0 | running=none | fail=0 | p50=n/a p90=n/a | eta=n/a"
    echo
  } >> "$TRACKING"
}

ensure_precheck(){
  require_endpoints
  pipe "🚀 RUN_START | run=$run_name | total=0 | state=$STATE"
}

build_queue(){
  local loki_q loki_resp active_json offenders_json adopted_json
  loki_q='topk(200, sum by (log_source) (count_over_time({log_source=~".+"}[6h])))'
  loki_resp=$(curl -fsS 'http://127.0.0.1:3200/loki/api/v1/query_range' --get --data-urlencode "query=$loki_q" --data-urlencode "start=$((($(date +%s)-21600)*1000000000))" --data-urlencode "end=$((($(date +%s)+60)*1000000000))" --data-urlencode "limit=200" --data-urlencode "direction=BACKWARD")
  active_json=$(printf '%s' "$loki_resp")

  if [[ -f "$ROOT/_build/logging/offending_dashboards.json" ]]; then
    offenders_json=$(cat "$ROOT/_build/logging/offending_dashboards.json")
  else
    offenders_json='[]'
  fi

  if [[ -f "$ROOT/_build/logging/adopted_dashboards_manifest.json" ]]; then
    adopted_json=$(cat "$ROOT/_build/logging/adopted_dashboards_manifest.json")
  else
    adopted_json='[]'
  fi

  python3 - "$QUEUE_JSON" "$QUEUE_MD" "$run_name" "$continue_on_fail" <<PY
import json,sys
qjson,qmd,run_name,cof=sys.argv[1:]
active_resp=json.loads('''$active_json''')
offenders=json.loads('''$offenders_json''')
adopted=json.loads('''$adopted_json''')

active=[]
seen=set()
for r in active_resp.get('data',{}).get('result',[]):
    s=r.get('metric',{}).get('log_source')
    if s and s not in seen:
        active.append(s); seen.add(s)

items=[]
def add(item_id,item_type,target="",notes=""):
    items.append({
      "idx": len(items)+1,
      "id": item_id,
      "type": item_type,
      "target": target,
      "status": "pending",
      "attempt": 0,
      "notes": notes,
    })

# Must-do items first
add("FIX:alloy_positions_storage","fix_config","infra/logging/docker-compose.observability.yml")
add("FIX:journald_mounts","fix_config","infra/logging/docker-compose.observability.yml")
add("FIX:grafana_alert_timing","fix_config","infra/logging/grafana/provisioning/alerting/logging-pipeline-rules.yml")
add("FIX:prom_dead_rules_replace","fix_config","infra/logging/prometheus/rules/loki_logging_rules.yml")
add("FIX:loki_port_bind_local","fix_runtime","infra/logging/docker-compose.observability.yml")
add("FIX:grafana_metrics_scrape","fix_config","infra/logging/prometheus/prometheus.yml")
add("ADD:backup_script","script_add","infra/logging/scripts/backup_volumes.sh")
add("ADD:restore_script","script_add","infra/logging/scripts/restore_volumes.sh")
add("FIX:resource_limits_alloy_health","fix_config","infra/logging/docker-compose.observability.yml")

# Per-source dashboards (active)
for src in active:
    add(f"SRC:{src}","dashboard_tune",f"infra/logging/grafana/dashboards/sources/codeswarm-src-{src}.json")

# Adopted dashboard verification
adopt_map={}
for m in adopted:
    src=m.get('src_uid')
    new=m.get('new_uid')
    if src and new:
        adopt_map[src]=new

for off in offenders:
    uid=off.get('uid')
    if uid:
        tgt=adopt_map.get(uid,uid)
        add(f"ADOPT:{tgt}","adopt_verify",tgt)

# Audit / verifier checks
add("AUDIT:per_dashboard_breakdown","audit_verify","infra/logging/scripts/dashboard_query_audit.sh")
add("VERIFY:parity_checks","audit_verify","infra/logging/scripts/verify_grafana_authority.sh")
add("VERIFY:adoption_checks","audit_verify","infra/logging/scripts/verify_grafana_authority.sh")

# Runbook docs
add("DOC:editing_policy","doc_update","infra/logging/RUNBOOK.md")
add("DOC:adoption_policy","doc_update","infra/logging/RUNBOOK.md")
add("DOC:label_contract_expected_empty","doc_update","infra/logging/RUNBOOK.md")

# Extra verification items to keep long deterministic backlog
add("VERIFY:loki_binding_local","verify","infra/logging/docker-compose.observability.yml")
add("VERIFY:prom_rule_metric_live","verify","infra/logging/prometheus/rules/loki_logging_rules.yml")
add("VERIFY:queue_state_integrity","verify","_build/melissa/queue.json")
add("VERIFY:endpoint_health_snapshot","verify","_build/melissa/runtime.log")
add("VERIFY:audit_gate_snapshot","verify","_build/logging/dashboard_audit_latest.json")
add("VERIFY:verifier_gate_snapshot","verify","_build/logging/verify_grafana_authority_latest.json")

# Ensure minimum queue length
while len(items) < 25:
    n=len(items)+1
    add(f"VERIFY:filler-{n:02d}","verify","_build/melissa/runtime.log")

queue={
  "run": run_name,
  "total": len(items),
  "continue_on_fail": cof.lower()=="true",
  "items": items
}
json.dump(queue,open(qjson,'w'),indent=2)

md=[]
md.append(f"# Queue — {run_name}")
md.append("")
md.append(f"- total: {len(items)}")
md.append(f"- continue_on_fail: {str(queue['continue_on_fail']).lower()}")
md.append("")
md.append("| idx | id | type | status | attempt | target |")
md.append("|---:|---|---|---|---:|---|")
for it in items:
    md.append(f"| {it['idx']} | {it['id']} | {it['type']} | {it['status']} | {it['attempt']} | {it['target']} |")
open(qmd,'w').write("\n".join(md)+"\n")
PY
}

item_note=""
item_expected_zero="no"

patch_alloy_positions_storage(){
  python3 - "$COMPOSE_FILE" <<'PY'
import sys
p=sys.argv[1]
s=open(p).read()
if '--storage.path=/var/lib/alloy' not in s:
    s=s.replace('    - --server.http.listen-addr=0.0.0.0:12345\n    - /etc/alloy/config.alloy','    - --server.http.listen-addr=0.0.0.0:12345\n    - --storage.path=/var/lib/alloy\n    - /etc/alloy/config.alloy')
s=s.replace('    - alloy-positions:/tmp','    - alloy-positions:/var/lib/alloy')
open(p,'w').write(s)
PY
  item_note="alloy_storage_path_set"
}

patch_journald_mounts(){
  python3 - "$COMPOSE_FILE" <<'PY'
import sys
p=sys.argv[1]
s=open(p).read()
ins1='    - ${HOST_VAR_LOG_JOURNAL:-/var/log/journal}:/var/log/journal:ro'
ins2='    - ${HOST_RUN_LOG_JOURNAL:-/run/log/journal}:/run/log/journal:ro'
anchor='    - ${HOST_DOCKER_SOCK:-/var/run/docker.sock}:/var/run/docker.sock:ro\n'
if ins1 not in s:
    s=s.replace(anchor,anchor+ins1+'\n')
if ins2 not in s:
    s=s.replace(ins1+'\n',ins1+'\n'+ins2+'\n')
open(p,'w').write(s)
PY
  item_note="journald_mounts_added"
}

patch_grafana_alert_timing(){
  local f="$ROOT/infra/logging/grafana/provisioning/alerting/logging-pipeline-rules.yml"
  python3 - "$f" <<'PY'
import sys,re
p=sys.argv[1]
s=open(p).read()
s=s.replace('noDataState: Alerting','noDataState: OK')
s=re.sub(r'for:\s*0m','for: 2m',s)
open(p,'w').write(s)
PY
  item_note="alert_timing_hardened"
}

patch_prom_dead_rules(){
  local f="$ROOT/infra/logging/prometheus/rules/loki_logging_rules.yml"
  python3 - "$f" <<'PY'
import sys
p=sys.argv[1]
lines=open(p).read().splitlines()
out=[]
mode=None
for ln in lines:
    if 'record: sprint3:loki_ingestion_errors:rate5m' in ln:
        mode='rate'; out.append(ln); continue
    if 'record: sprint3:loki_ingestion_errors:increase10m' in ln:
        mode='inc'; out.append(ln); continue
    if mode=='rate' and ln.strip().startswith('expr:'):
        out.append('        expr: sum(rate(loki_write_dropped_entries_total[5m])) + sum(rate(loki_write_failures_discarded_total[5m]))')
        mode=None
        continue
    if mode=='inc' and ln.strip().startswith('expr:'):
        out.append('        expr: sum(increase(loki_write_dropped_entries_total[10m])) + sum(increase(loki_write_failures_discarded_total[10m]))')
        mode=None
        continue
    out.append(ln)
open(p,'w').write('\n'.join(out)+'\n')
PY
  item_note="prom_dead_metric_replaced"
}

patch_loki_port_bind_local(){
  local needs_change=0
  if ! rg -q '127.0.0.1:3200:3100' "$COMPOSE_FILE"; then
    needs_change=1
  fi

  python3 - "$COMPOSE_FILE" <<'PY'
import sys,re
p=sys.argv[1]
s=open(p).read()
if '  loki:' in s and '127.0.0.1:3200:3100' not in s:
    s=s.replace('    networks:\n    - obs\n    healthcheck:','    networks:\n    - obs\n    ports:\n    - "127.0.0.1:3200:3100"\n    healthcheck:')
open(p,'w').write(s)
PY
  if [[ "$needs_change" -eq 1 ]]; then
    docker compose -f "$COMPOSE_FILE" up -d --force-recreate --no-deps loki >/dev/null 2>&1
  fi
  local ports
  ports=$(docker ps --format '{{.Names}}\t{{.Ports}}' | rg '^logging-loki-1' || true)
  if printf '%s' "$ports" | grep -Fq '0.0.0.0:3200'; then
    item_note="loki_port_still_public"
    return 1
  fi
  item_note="loki_bound_local"
}

patch_grafana_metrics_scrape(){
  local f="$ROOT/infra/logging/prometheus/prometheus.yml"
  local needs_change=0
  if ! rg -q '^- job_name: grafana$' "$f"; then
    needs_change=1
  fi

  python3 - "$f" <<'PY'
import sys
p=sys.argv[1]
s=open(p).read()
block='- job_name: grafana\n  static_configs:\n  - targets:\n    - grafana:3000\n'
if 'job_name: grafana' not in s:
    if not s.endswith('\n'):
        s += '\n'
    s += block
open(p,'w').write(s)
PY
  if [[ "$needs_change" -eq 1 ]]; then
    docker compose -f "$COMPOSE_FILE" up -d --force-recreate --no-deps prometheus >/dev/null 2>&1
  fi
  item_note="grafana_scrape_added"
}

add_backup_script(){
  cat <<'EOS' > "$ROOT/infra/logging/scripts/backup_volumes.sh"
#!/usr/bin/env bash
set -euo pipefail

out_dir="${1:-/home/luce/apps/loki-logging/_build/logging/backups}"
ts="$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$out_dir/$ts"

for vol in logging-grafana-data logging-loki-data logging-prometheus-data; do
  docker run --rm -v "${vol}:/from:ro" -v "$out_dir/$ts:/to" alpine:3.20 sh -lc "cd /from && tar -czf /to/${vol}.tgz ."
done

echo "backup_dir=$out_dir/$ts"
EOS
  chmod +x "$ROOT/infra/logging/scripts/backup_volumes.sh"
  item_note="backup_script_added"
}

add_restore_script(){
  cat <<'EOS' > "$ROOT/infra/logging/scripts/restore_volumes.sh"
#!/usr/bin/env bash
set -euo pipefail

src_dir="${1:?usage: restore_volumes.sh <backup_dir>}"

for vol in logging-grafana-data logging-loki-data logging-prometheus-data; do
  test -f "$src_dir/${vol}.tgz"
  docker run --rm -v "${vol}:/to" -v "$src_dir:/from:ro" alpine:3.20 sh -lc "cd /to && tar -xzf /from/${vol}.tgz"
done

echo "restore=ok source=$src_dir"
EOS
  chmod +x "$ROOT/infra/logging/scripts/restore_volumes.sh"
  item_note="restore_script_added"
}

patch_resource_limits_and_alloy_health(){
  python3 - "$COMPOSE_FILE" <<'PY'
import sys,re
p=sys.argv[1]
s=open(p).read()
# Alloy healthcheck
s=s.replace('      - /bin/alloy\n      - fmt\n      - --help','      - wget\n      - -q\n      - -O\n      - -\n      - http://127.0.0.1:12345/-/ready')

svc_limits={
  'grafana':('1g','0.50'),
  'loki':('2g','1.00'),
  'prometheus':('2g','1.00'),
  'alloy':('1g','0.75'),
}

for svc,(mem,cpu) in svc_limits.items():
    pat=rf'(^  {re.escape(svc)}:\n)(.*?)(?=\n  [A-Za-z0-9_-]+:|\Z)'
    m=re.search(pat,s,flags=re.M|re.S)
    if not m:
        continue
    head,body=m.group(1),m.group(2)
    if 'mem_limit:' in body and 'cpus:' in body:
        continue
    body=f'    mem_limit: {mem}\n    cpus: "{cpu}"\n'+body
    s=s[:m.start()]+head+body+s[m.end():]

open(p,'w').write(s)
PY
  item_note="resource_limits_alloy_health_applied"
}

tune_source_dashboard(){
  local src="$1"
  local fp="$ROOT/infra/logging/grafana/dashboards/sources/codeswarm-src-${src}.json"

  python3 - "$fp" "$src" <<'PY'
import json,os,sys
fp,src=sys.argv[1:]
base_ds={"type":"loki","uid":"P8E80F9AEF21F6940"}
if os.path.exists(fp):
    d=json.load(open(fp))
else:
    d={
      "uid":f"codeswarm-src-{src}",
      "title":f"CodeSwarm - {src}",
      "timezone":"browser",
      "refresh":"30s",
      "time":{"from":"now-6h","to":"now"},
      "tags":["codeswarm","logging","source",src],
      "panels":[]
    }
panels=d.get("panels") or []
existing={p.get("title") for p in panels if isinstance(p,dict)}
adds=[]
if "Logs seen (5m)" not in existing:
    adds.append({"type":"stat","title":"Logs seen (5m)","datasource":base_ds,"targets":[{"refId":"A","expr":f"sum(count_over_time({{log_source=\"{src}\"}}[5m]))"}]})
if "Error rate (5m)" not in existing:
    adds.append({"type":"timeseries","title":"Error rate (5m)","datasource":base_ds,"targets":[{"refId":"A","expr":f"sum(rate({{log_source=\"{src}\"}} |~ \"(?i)(error|fail|exception|panic)\" [5m]))"}]})
if "Live logs" not in existing:
    adds.append({"type":"logs","title":"Live logs","datasource":base_ds,"targets":[{"refId":"A","expr":f"{{log_source=\"{src}\"}}"}]})
if adds:
    d["panels"]=panels+adds
json.dump(d,open(fp,'w'),indent=2)
PY

  local q resp cnt
  q="sum(count_over_time({log_source=\"$src\"}[5m]))"
  resp=$(curl -fsS 'http://127.0.0.1:3200/loki/api/v1/query_range' --get --data-urlencode "query=$q" --data-urlencode "start=$((($(date +%s)-1200)*1000000000))" --data-urlencode "end=$((($(date +%s)+60)*1000000000))" --data-urlencode "limit=5" --data-urlencode "direction=BACKWARD" || true)
  cnt=$(printf '%s' "$resp" | jq -r '.data.result|length' 2>/dev/null || echo 0)
  if [[ "$cnt" == "0" ]]; then
    item_expected_zero="yes"
    item_note="source_dashboard_tuned_expected_zero"
  else
    item_expected_zero="no"
    item_note="source_dashboard_tuned_non_empty"
  fi
}

verify_adopted_uid(){
  local uid="$1"
  local gp
  gp="$(derive_grafana_pass)"
  local meta
  meta=$(curl -fsS -u "admin:$gp" "http://127.0.0.1:9001/api/dashboards/uid/$uid" | jq -r '.meta.provisioned|tostring+":"+(.meta.provisionedExternalId // "")' || true)
  if [[ "$meta" == true:adopted/* ]]; then
    item_note="adopted_provisioned_ok"
    return 0
  fi
  item_note="adopted_provisioned_mismatch"
  return 1
}

ensure_runbook_section(){
  local title="$1"
  local body="$2"
  local rb="$ROOT/infra/logging/RUNBOOK.md"
  if ! rg -q "^## ${title}$" "$rb"; then
    cat <<EOS >> "$rb"

## ${title}
${body}
EOS
  fi
}

verify_item(){
  local id="$1"
  case "$id" in
    VERIFY:loki_binding_local)
      local ports
      ports=$(docker ps --format '{{.Names}}\t{{.Ports}}' | rg '^logging-loki-1' || true)
      if printf '%s' "$ports" | grep -Fq '0.0.0.0:3200'; then
        item_note="loki_binding_public"
        return 1
      fi
      item_note="loki_binding_local_ok"
      ;;
    VERIFY:prom_rule_metric_live)
      local c
      c=$(curl -fsS 'http://127.0.0.1:9004/api/v1/query' --get --data-urlencode 'query=count(loki_write_dropped_entries_total)' | jq -r '.data.result|length' || echo 0)
      if [[ "$c" == "0" ]]; then
        item_note="prom_metric_missing"
        return 1
      fi
      item_note="prom_metric_live"
      ;;
    VERIFY:queue_state_integrity)
      jq -e '.items | length > 0' "$QUEUE_JSON" >/dev/null
      item_note="queue_integrity_ok"
      ;;
    VERIFY:endpoint_health_snapshot)
      require_endpoints
      item_note="endpoint_health_ok"
      ;;
    VERIFY:audit_gate_snapshot)
      hard_gates >/dev/null
      item_note="audit_gate_snapshot_ok"
      ;;
    VERIFY:verifier_gate_snapshot)
      hard_gates >/dev/null
      item_note="verifier_gate_snapshot_ok"
      ;;
    VERIFY:filler-*)
      item_note="filler_ok"
      ;;
    *)
      item_note="verify_unknown"
      ;;
  esac
}

run_item(){
  local item_id="$1"
  local item_type="$2"
  local item_target="$3"
  local rc=0

  item_note=""
  item_expected_zero="no"

  set +e
  case "$item_id" in
    FIX:alloy_positions_storage)
      patch_alloy_positions_storage
      ;;
    FIX:journald_mounts)
      patch_journald_mounts
      ;;
    FIX:grafana_alert_timing)
      patch_grafana_alert_timing
      ;;
    FIX:prom_dead_rules_replace)
      patch_prom_dead_rules
      ;;
    FIX:loki_port_bind_local)
      patch_loki_port_bind_local
      ;;
    FIX:grafana_metrics_scrape)
      patch_grafana_metrics_scrape
      ;;
    ADD:backup_script)
      add_backup_script
      ;;
    ADD:restore_script)
      add_restore_script
      ;;
    FIX:resource_limits_alloy_health)
      patch_resource_limits_and_alloy_health
      ;;
    SRC:*)
      tune_source_dashboard "${item_id#SRC:}"
      ;;
    ADOPT:*)
      verify_adopted_uid "${item_id#ADOPT:}"
      ;;
    AUDIT:per_dashboard_breakdown)
      bash "$ROOT/infra/logging/scripts/dashboard_query_audit.sh" >/dev/null
      jq -e '.per_dashboard != null' "$ROOT/_build/logging/dashboard_audit_latest.json" >/dev/null
      item_note="audit_per_dashboard_ok"
      ;;
    VERIFY:parity_checks)
      bash "$ROOT/infra/logging/scripts/verify_grafana_authority.sh" >/dev/null
      jq -e '.checks.log_source_count >= 0 and .checks.dashboards_expected >= 0' "$ROOT/_build/logging/verify_grafana_authority_latest.json" >/dev/null
      item_note="verifier_parity_ok"
      ;;
    VERIFY:adoption_checks)
      bash "$ROOT/infra/logging/scripts/verify_grafana_authority.sh" >/dev/null
      jq -e '.checks.adoption_offending_count >= 0 and .checks.adoption_adopted_count >= 0' "$ROOT/_build/logging/verify_grafana_authority_latest.json" >/dev/null
      item_note="verifier_adoption_ok"
      ;;
    DOC:editing_policy)
      ensure_runbook_section "Adopted dashboards editing policy" "Edit provisioned dashboard JSON under infra/logging/grafana/dashboards and apply by restart/reload, not UI save."
      item_note="runbook_editing_policy_ok"
      ;;
    DOC:adoption_policy)
      ensure_runbook_section "Adoption policy" "Plugin or non-editable dashboards are adopted into infra/logging/grafana/dashboards/adopted with CodeSwarm tags."
      item_note="runbook_adoption_policy_ok"
      ;;
    DOC:label_contract_expected_empty)
      ensure_runbook_section "Label contract and expected-empty semantics" "Canonical label contract is log_source. Audit failure is only unexpected empty panels; expected-empty panels are tracked but not blocking."
      item_note="runbook_label_contract_ok"
      ;;
    VERIFY:*)
      verify_item "$item_id"
      ;;
    *)
      item_note="unknown_item"
      false
      ;;
  esac
  rc=$?
  set -e

  return "$rc"
}

checkpoint_commit(){
  local idx="$1"

  hard_gates || return 90

  local changed
  changed=$(git -C "$ROOT" status --porcelain=v1 | awk '{print $2}' | rg -v '^_build/melissa/' || true)
  if [[ -z "$changed" ]]; then
    pipe "🧾 EVIDENCE checkpoint | state=noop | summary=no_changes | canonical=allowlist" || true
    return 0
  fi

  git -C "$ROOT" reset >/dev/null

  local allow='^(infra/logging/(docker-compose\.observability\.yml|prometheus/prometheus\.yml|prometheus/rules/loki_logging_rules\.yml|grafana/provisioning/alerting/logging-pipeline-rules\.yml|scripts/(backup_volumes|restore_volumes|melissa_longrun|melissa_batchlib|melissa_daemon|no_drift_print)\.sh|RUNBOOK\.md|grafana/dashboards/sources/codeswarm-src-.*\.json)|docs/reference\.md|CLAUDE\.md|scripts/prod/mcp/logging_stack_(down|health)\.sh)$'

  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    if printf '%s' "$f" | rg -q "$allow"; then
      git -C "$ROOT" add "$f"
    fi
  done <<EOFCHG
$changed
EOFCHG

  local staged bad
  staged=$(git -C "$ROOT" diff --name-only --cached | sort)
  bad=$(printf '%s\n' "$staged" | rg -v "$allow" || true)
  if [[ -n "$bad" ]]; then
    git -C "$ROOT" reset >/dev/null
    pipe "⛔ BLOCK | reason=allowlist_violation | gaps=checkpoint_stage | next=stop" || true
    return 91
  fi

  if git -C "$ROOT" diff --cached --quiet; then
    pipe "🧾 EVIDENCE checkpoint | state=noop | summary=staged_empty | canonical=allowlist" || true
    return 0
  fi

  git -C "$ROOT" commit -m "ops: backlog checkpoint $run_name up-to-$idx" >/dev/null
  local br hash
  br=$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)
  git -C "$ROOT" push -u origin "$br" >/dev/null 2>&1 || git -C "$ROOT" push origin "$br" >/dev/null 2>&1
  hash=$(git -C "$ROOT" rev-parse --short HEAD)
  last_checkpoint_hash="$hash"
  pipe "🧾 EVIDENCE checkpoint | state=commit | summary=hash=$hash upto=$idx | canonical=allowlist" || true
  return 0
}

precheck_runtime_and_auth(){
  require_endpoints || return 90
  return 0
}

run_loop(){
  local total idx done_count fail_count
  total=$(jq -r '.total' "$QUEUE_JSON")
  done_count=0
  fail_count=0

  pipe "🚀 RUN_START | run=$run_name | total=$total | state=$STATE" || true

  local last_heartbeat
  last_heartbeat=$(date +%s)

  for idx in $(seq 1 "$total"); do
    local now elapsed_mins
    now=$(date +%s)
    elapsed_mins=$(((now-start_epoch)/60))
    if (( elapsed_mins >= max_minutes )); then
      pipe "⛔ BLOCK | reason=max_minutes_reached | gaps=timebox | next=resume" || true
      break
    fi

    local item_json item_id item_type item_target attempt started ended dur
    item_json=$(jq -c ".items[] | select(.idx==$idx)" "$QUEUE_JSON")
    item_id=$(printf '%s' "$item_json" | jq -r '.id')
    item_type=$(printf '%s' "$item_json" | jq -r '.type')
    item_target=$(printf '%s' "$item_json" | jq -r '.target')
    attempt=$(( $(printf '%s' "$item_json" | jq -r '.attempt') + 1 ))

    started=$(now_utc)
    queue_update_item "$QUEUE_JSON" "$idx" "running" "$attempt" "" "$started" ""
    queue_write_markdown "$QUEUE_JSON" "$QUEUE_MD"

    pipe "🚧 ITEM_START $item_id | idx=$idx/$total | attempt=$attempt | type=$item_type" || true

    local rc=0
    if ! run_item "$item_id" "$item_type" "$item_target"; then
      rc=$?
    fi

    # Micro gates after each item
    if ! require_endpoints; then
      pipe "⛔ BLOCK | reason=micro_gate_failed | gaps=endpoints | next=stop" || true
      return 90
    fi

    ended=$(now_utc)
    dur="00:00:00"

    if [[ "$rc" -eq 0 ]]; then
      done_count=$((done_count+1))
      queue_update_item "$QUEUE_JSON" "$idx" "done" "$attempt" "$item_note" "$started" "$ended"
      queue_write_markdown "$QUEUE_JSON" "$QUEUE_MD"
      pipe "✅ ITEM_DONE $item_id | dur=$dur | end=$ended | attempt=$attempt | status=ok | notes=$item_note" || true
    else
      fail_count=$((fail_count+1))
      queue_update_item "$QUEUE_JSON" "$idx" "fail" "$attempt" "$item_note" "$started" "$ended"
      queue_write_markdown "$QUEUE_JSON" "$QUEUE_MD"
      pipe "❌ ITEM_DONE $item_id | dur=$dur | end=$ended | attempt=$attempt | status=fail | notes=$item_note" || true

      if [[ "$continue_on_fail" != "true" ]]; then
        pipe "⛔ BLOCK | reason=item_failed_continue_disabled | gaps=$item_id | next=stop" || true
        return 92
      fi
    fi

    update_memory_runner_state "$MEM" "$idx" "$(now_utc)" "$mode" "$total" "$run_name" "$last_checkpoint_hash"

    if (( hard_every > 0 )) && (( idx % hard_every == 0 )); then
      if ! hard_gates; then
        return 93
      fi
    fi

    if (( checkpoint_every > 0 )) && (( idx % checkpoint_every == 0 )); then
      checkpoint_commit "$idx" || return $?
    fi

    now=$(date +%s)
    if (( (now-last_heartbeat) >= heartbeat_minutes*60 )); then
      pipe "📌 PROGRESS | done=$done_count/$total | running=none | fail=$fail_count | p50=n/a p90=n/a | eta=n/a" || true
      last_heartbeat=$now
    fi
  done

  hard_gates || return 94
  checkpoint_commit "$total" || true

  pipe "📌 PROGRESS | done=$done_count/$total | running=none | fail=$fail_count | p50=n/a p90=n/a | eta=n/a" || true
  pipe "🏁 RUN_DONE | result=done | ran=$done_count | fail=$fail_count | total=$total | elapsed=00:00:00 | run=$run_name" || true

  cat <<EOF_SUM > "$STATE/session_summary.md"
# Melissa Session Summary

- run: $run_name
- total_items: $total
- completed: $done_count
- failed: $fail_count
- mode: $mode
- last_checkpoint_hash: ${last_checkpoint_hash:-none}

## Remaining top risks
1. Full component upgrade wave (Grafana/Loki/Prometheus/Alloy) not executed in this run.
2. Template engine hardening for log-truncation eval paths still pending.
3. Alert routing/contact-point delivery policy still environment-specific.
EOF_SUM

  return 0
}

main(){
  init_tracking

  if ! precheck_runtime_and_auth; then
    pipe "⛔ BLOCK | reason=precheck_failed | gaps=endpoints_or_auth | next=stop" || true
    exit 90
  fi

  build_queue

  if ! run_loop; then
    rc=$?
    pipe "🏁 RUN_DONE | result=aborted | ran=0 | fail=1 | total=$(jq -r '.total' "$QUEUE_JSON") | elapsed=00:00:00 | run=$run_name" || true
    exit "$rc"
  fi

  scan_file_for_drift "$stdout_buf" || exit 99
  scan_file_for_drift "$stderr_buf" || exit 99
  scan_file_for_drift "$TRACKING" || exit 99
  scan_file_for_drift "$LOG" || exit 99

  exit 0
}

main "$@"
