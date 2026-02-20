---
chatgpt_scoping_kind: task
chatgpt_scoping_scope: single-file
chatgpt_scoping_targets_root: _build/Sprint-3/prompts/
chatgpt_scoping_targets: Loki-prompt-UAT-Outcome-Validation.md
codex_preflight_kind: task
codex_preflight_scope: single-file
codex_preflight_targets_root: _build/Sprint-3/prompts/
codex_preflight_targets: Loki-prompt-UAT-Outcome-Validation.md
codex_preflight_ready: 'yes'
codex_preflight_reason: ''
codex_preflight_reviewed_local: 1:41 PM - 14-02-2026
codex_preflight_revision: 6
codex_preflight_autocommit: 'yes'
codex_preflight_autopush: 'yes'
codex_preflight_move_to_completed: 'yes'
codex_preflight_warn_gate: 'yes'
codex_preflight_warn_mode: ask
codex_preflight_allow_noncritical: 'yes'
codex_preflight_retry_max: '1'
prompt_flow:
  version: v1
  stages:
    draft:
      source: chatgpt
      status: drafted
      updated_utc: '2026-02-14T19:41:18Z'
      scoping:
        kind: task
        scope: single-file
        targets_root: _build/Sprint-3/prompts/
        targets:
        - Loki-prompt-UAT-Outcome-Validation.md
      next_stage: preflight
    preflight:
      source: prompt-preflight
      status: ready
      ready: 'yes'
      reason: ''
      reviewed_local: 1:41 PM - 14-02-2026
      revision: 6
      kind: task
      scope: single-file
      targets_root: _build/Sprint-3/prompts/
      targets:
      - Loki-prompt-UAT-Outcome-Validation.md
      policy:
        autocommit: 'yes'
        autopush: 'yes'
        move_to_completed: 'yes'
        warn_gate: 'yes'
        warn_mode: ask
        allow_noncritical: 'yes'
        retry_max: '1'
      updated_utc: '2026-02-14T19:41:18Z'
      next_stage: exec
    exec:
      source: prompt-exec
    pipeline:
      source: prompt-pipeline
---

# Loki-prompt-UAT-Outcome-Validation — Sprint-3 Native Contract Validation

## Scope
Validate Sprint-3 outcomes from native system sources only:
- Runtime health via Grafana/Prometheus/Loki APIs
- Prometheus rule/query contract (`sprint3:*` recording rules + minimum alerts)
- Dashboard contract (datasource names + canonical query usage)
- Alloy ingest contract (docker allowlist + logging stack drop + label schema)
- Redaction behavior using deterministic synthetic marker in Loki
- Retention/runtime contract via Prometheus flags and Loki scrape health

Outputs:
- `_build/Sprint-3/reference/uat_outcome_report.json`
- `_build/Sprint-3/reference/uat_outcome_report.md`
- `_build/Sprint-3/reference/uat_native/*`

## Affects
- Read-only checks on runtime APIs and config files
- Append-only synthetic redaction line to `/home/luce/_logs/loki-logging-smoke.log`
- Evidence files under `_build/Sprint-3/reference/`

## Guardrails
- No service restarts.
- No manual UI actions.
- No secret material (synthetic tokens only).
- Hard timeouts for all network calls.

## Preconditions (hard gates)
STOP unless:
- `infra/logging/docker-compose.observability.yml` exists
- `infra/logging/prometheus/rules/loki_logging_rules.yml` exists
- `infra/logging/prometheus/rules/sprint3_minimum_alerts.yml` exists
- `infra/logging/alloy-config.alloy` exists
- `docker`, `curl`, `python3`, `jq`, `timeout` available

## Steps
- Run the command block below and stop on first failure.

## Acceptance Proofs
- `uat_outcome_report.json` has `"PASS": true`
- `uat_outcome_report.md` shows all checks `PASS`
- `uat_native/prom_rules.json`, `uat_native/prom_targets.json`, `uat_native/loki_ready.txt` exist

## Done Criteria
- Native contract checks all PASS.

## Operator Checkpoint
Proceed to run Phase 0 (Preflight Gate) only? (yes/no)

```bash
set -euo pipefail
IFS=$'\n\t'

REPO="/home/luce/apps/loki-logging"
cd "$REPO"

command -v docker >/dev/null
command -v curl >/dev/null
command -v python3 >/dev/null
command -v jq >/dev/null
command -v timeout >/dev/null

OBS="infra/logging/docker-compose.observability.yml"
RULE_MAIN="infra/logging/prometheus/rules/loki_logging_rules.yml"
RULE_MIN="infra/logging/prometheus/rules/sprint3_minimum_alerts.yml"
ALLOY_CFG="infra/logging/alloy-config.alloy"
test -f "$OBS"
test -f "$RULE_MAIN"
test -f "$RULE_MIN"
test -f "$ALLOY_CFG"

PROJECT="logging"
EVID="_build/Sprint-3/reference"
UAT_DIR="$EVID/uat_native"
mkdir -p "$UAT_DIR"

GRAFANA_CID="$(docker compose -p "$PROJECT" -f "$OBS" ps -q grafana)"
PROM_CID="$(docker compose -p "$PROJECT" -f "$OBS" ps -q prometheus)"
LOKI_CID="$(docker compose -p "$PROJECT" -f "$OBS" ps -q loki)"
ALLOY_CID="$(docker compose -p "$PROJECT" -f "$OBS" ps -q alloy)"
test -n "$GRAFANA_CID"; test -n "$PROM_CID"; test -n "$LOKI_CID"; test -n "$ALLOY_CID"

# ---------- Runtime health ----------
curl --retry 5 --retry-delay 2 --retry-connrefused -sf "http://127.0.0.1:9001/api/health" > "$UAT_DIR/grafana_health.json"
curl --retry 5 --retry-delay 2 --retry-connrefused -sf "http://127.0.0.1:9004/-/ready" > "$UAT_DIR/prom_ready.txt"
curl --retry 5 --retry-delay 2 --retry-connrefused -sf "http://127.0.0.1:9004/api/v1/targets" > "$UAT_DIR/prom_targets.json"
timeout 300 docker exec "$LOKI_CID" sh -lc "wget -qO- http://127.0.0.1:3100/ready" > "$UAT_DIR/loki_ready.txt"

# ---------- Prometheus rule/query contract ----------
curl --retry 5 --retry-delay 2 --retry-connrefused -sf "http://127.0.0.1:9004/api/v1/rules" > "$UAT_DIR/prom_rules.json"
curl --retry 5 --retry-delay 2 --retry-connrefused -sf "http://127.0.0.1:9004/api/v1/status/flags" > "$UAT_DIR/prom_flags.json"

prom_query() {
  local query="$1"
  local out="$2"
  curl --retry 5 --retry-delay 2 --retry-connrefused -sfG --connect-timeout 5 --max-time 20 \
    --data-urlencode "query=${query}" \
    "http://127.0.0.1:9004/api/v1/query" > "$out"
}

prom_query 'sprint3:targets_up:count' "$UAT_DIR/query_targets_up.json"
prom_query 'sprint3:targets_down:count' "$UAT_DIR/query_targets_down.json"
prom_query 'sprint3:prometheus_scrape_failures:rate5m' "$UAT_DIR/query_scrape_fail_rate.json"
prom_query 'sprint3:host_cpu_usage_percent' "$UAT_DIR/query_host_cpu.json"
prom_query 'sprint3:host_memory_usage_percent' "$UAT_DIR/query_host_mem.json"
prom_query 'sprint3:host_disk_usage_percent' "$UAT_DIR/query_host_disk.json"
prom_query 'count(sprint3:container_cpu_usage_cores:rate5m)' "$UAT_DIR/query_container_cpu_count.json"
prom_query 'count(sprint3:container_memory_workingset_bytes)' "$UAT_DIR/query_container_mem_count.json"
prom_query 'up{job="loki"}' "$UAT_DIR/query_up_loki.json"
prom_query 'count(loki_build_info)' "$UAT_DIR/query_loki_build_info_count.json"

# ---------- Dashboard contract (repo-authoritative JSON) ----------
python3 - <<'PY' "$UAT_DIR/dashboard_contract_eval.json"
import json, sys
from pathlib import Path

out = Path(sys.argv[1])
root = Path("infra/logging/grafana/dashboards")

contract = {
    "prometheus-health.json": {
        "datasource": "Prometheus",
        "must_expr": [
            "sprint3:targets_up:count",
            "sprint3:prometheus_scrape_failures:rate5m",
            "sprint3:loki_ingestion_errors:rate5m",
        ],
    },
    "host_overview.json": {
        "datasource": "Prometheus",
        "must_expr": [
            "sprint3:host_cpu_usage_percent",
            "sprint3:host_memory_usage_percent",
            "sprint3:host_disk_usage_percent",
        ],
    },
    "containers_overview.json": {
        "datasource": "Prometheus",
        "must_expr": [
            "topk(10, sprint3:container_cpu_usage_cores:rate5m)",
            "topk(10, sprint3:container_memory_workingset_bytes)",
        ],
    },
    "loki-health.json": {
        "datasource": "Loki",
    },
    "alloy-health.json": {
        "datasource": "Loki",
    },
    "gpu-overview.json": {
        "datasource": "Loki",
    },
}

issues = []
for fname, spec in contract.items():
    p = root / fname
    if not p.is_file():
        issues.append({"file": fname, "issue": "missing_dashboard"})
        continue
    obj = json.loads(p.read_text(encoding="utf-8"))
    panels = obj.get("panels", [])
    ds_expected = spec["datasource"]
    exprs = []
    for panel in panels:
        ds = panel.get("datasource")
        ds_name = ds.get("name") if isinstance(ds, dict) else ds
        if ds_name != ds_expected:
            issues.append({"file": fname, "issue": "datasource_mismatch", "expected": ds_expected, "observed": ds_name})
        for t in panel.get("targets", []):
            expr = t.get("expr")
            if isinstance(expr, str):
                exprs.append(expr)
    for required in spec.get("must_expr", []):
        if required not in exprs:
            issues.append({"file": fname, "issue": "missing_expr", "expr": required})

payload = {
    "PASS": len(issues) == 0,
    "issues": issues,
}
out.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
if issues:
    raise SystemExit(2)
PY

# ---------- Alloy ingest contract (allowlist/drop/schema) ----------
python3 - <<'PY' "$ALLOY_CFG" "$UAT_DIR/alloy_contract_eval.json"
import json, re, sys
from pathlib import Path

cfg = Path(sys.argv[1]).read_text(encoding="utf-8", errors="ignore")
out = Path(sys.argv[2])

checks = {
    "docker_allowlist_keep": bool(re.search(r'com_docker_compose_project"\]\s*\n\s*regex\s*=\s*"\^\(vllm\|hex\)\$"', cfg)),
    "docker_drop_logging_stack": bool(re.search(r'action\s*=\s*"drop"[\s\S]*?regex\s*=\s*"\^logging\$"', cfg)),
    "label_stack_present": "target_label  = \"stack\"" in cfg,
    "label_service_present": "target_label  = \"service\"" in cfg,
    "label_source_type_present": "target_label  = \"source_type\"" in cfg,
}

payload = {"PASS": all(checks.values()), "checks": checks}
out.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
if not payload["PASS"]:
    raise SystemExit(2)
PY

# ---------- Redaction behavior (native synthetic proof) ----------
MARKER="uat-redaction-$(date -u +%Y%m%dT%H%M%SZ)"
RAW_BEARER="UATBEARER_${MARKER}"
RAW_COOKIE="UATCOOKIE_${MARKER}"
RAW_APIKEY="UATAPIKEY_${MARKER}"
SMOKE_FILE="/home/luce/_logs/loki-logging-smoke.log"
printf '%s\n' "${MARKER} bearer ${RAW_BEARER} cookie=${RAW_COOKIE} api_key=${RAW_APIKEY}" >> "$SMOKE_FILE"

NOW_NS="$(date +%s%N)"
FROM_NS="$((NOW_NS-10*60*1000000000))"

loki_query() {
  local query="$1"
  local out="$2"
  docker network inspect obs >/dev/null 2>&1 || { echo "missing docker network: obs" >&2; exit 1; }
  timeout 300 docker run --rm --network obs curlimages/curl:8.6.0 sh -lc "
    curl --retry 5 --retry-delay 2 --retry-connrefused -sfG --connect-timeout 5 --max-time 20 \\
      --data-urlencode 'query=${query}' \\
      --data-urlencode 'start=${FROM_NS}' \\
      --data-urlencode 'end=${NOW_NS}' \\
      --data-urlencode 'limit=50' \\
      --data-urlencode 'direction=BACKWARD' \\
      http://loki:3100/loki/api/v1/query_range
  " > "$out"
}

# Wait briefly for ingestion so redaction checks are deterministic.
marker_seen=0
for _attempt in $(seq 1 20); do
  NOW_NS="$(date +%s%N)"
  FROM_NS="$((NOW_NS-10*60*1000000000))"
  loki_query "{env=~\".+\"} |= \"${MARKER}\"" "$UAT_DIR/redaction_marker_any.json"
  marker_count="$(jq -r '.data.result | length' "$UAT_DIR/redaction_marker_any.json" 2>/dev/null || echo 0)"
  if [[ "$marker_count" =~ ^[0-9]+$ ]] && (( marker_count > 0 )); then
    marker_seen=1
    break
  fi
  sleep 2
done

# Capture final queries for redaction evaluation.
NOW_NS="$(date +%s%N)"
FROM_NS="$((NOW_NS-10*60*1000000000))"
loki_query "{env=~\".+\"} |= \"${MARKER}\"" "$UAT_DIR/redaction_marker_any.json"
loki_query "{env=~\".+\"} |= \"${MARKER}\" |= \"${RAW_BEARER}\"" "$UAT_DIR/redaction_marker_raw_bearer.json"
loki_query "{env=~\".+\"} |= \"${MARKER}\" |= \"${RAW_COOKIE}\"" "$UAT_DIR/redaction_marker_raw_cookie.json"
loki_query "{env=~\".+\"} |= \"${MARKER}\" |= \"${RAW_APIKEY}\"" "$UAT_DIR/redaction_marker_raw_apikey.json"
loki_query "{env=~\".+\"} |= \"${MARKER}\" |= \"[REDACTED]\"" "$UAT_DIR/redaction_marker_redacted.json"

# ---------- Final native verdict ----------
python3 - <<'PY' "$EVID" "$UAT_DIR" "$EVID/uat_outcome_report.json" "$EVID/uat_outcome_report.md"
import json, re, sys
from pathlib import Path
from datetime import datetime, timezone

evid = Path(sys.argv[1])
uat = Path(sys.argv[2])
outj = Path(sys.argv[3])
outm = Path(sys.argv[4])


def now():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="ignore") if path.is_file() else ""


def read_json(path: Path):
    try:
        return json.loads(read(path))
    except Exception:
        return None

checks = []


def add(name, ok, bucket, evidence, next_action, detail=""):
    checks.append({
        "name": name,
        "ok": bool(ok),
        "bucket": bucket,
        "evidence": evidence,
        "next_action": next_action,
        "detail": detail,
    })

# Runtime
health = read_json(uat / "grafana_health.json")
add("Grafana health OK", isinstance(health, dict) and str(health.get("database", "")).lower() == "ok", "RUNTIME", str(uat / "grafana_health.json"), "Inspect grafana /api/health + logs", detail=f"database={health.get('database') if isinstance(health, dict) else 'missing'}")

prom_ready_txt = read(uat / "prom_ready.txt")
add("Prometheus ready", "Ready" in prom_ready_txt, "RUNTIME", str(uat / "prom_ready.txt"), "Inspect prometheus /-/ready + logs")

prom_targets = read_json(uat / "prom_targets.json")
prom_targets_ok = False
prom_targets_detail = "missing"
if isinstance(prom_targets, dict) and prom_targets.get("status") == "success":
    ats = prom_targets.get("data", {}).get("activeTargets", [])
    downs = [t for t in ats if isinstance(t, dict) and t.get("health") != "up"]
    prom_targets_ok = isinstance(ats, list) and len(ats) > 0 and len(downs) == 0
    prom_targets_detail = f"active={len(ats)} down={len(downs)}"
add("Prometheus targets all UP", prom_targets_ok, "RUNTIME", str(uat / "prom_targets.json"), "Inspect /api/v1/targets", detail=prom_targets_detail)

add("Loki ready", "ready" in read(uat / "loki_ready.txt").lower(), "RUNTIME", str(uat / "loki_ready.txt"), "Inspect loki /ready + logs")

# Prom rules + query contract
rules = read_json(uat / "prom_rules.json")
rule_names = []
group_names = []
if isinstance(rules, dict):
    for g in rules.get("data", {}).get("groups", []):
        if isinstance(g, dict):
            group_names.append(g.get("name", ""))
            for r in g.get("rules", []):
                if isinstance(r, dict):
                    rule_names.append(r.get("name", ""))

required_groups = {"loki_logging_v1", "sprint3_minimum_v1"}
required_rules = {
    "sprint3:targets_up:count",
    "sprint3:targets_down:count",
    "sprint3:host_cpu_usage_percent",
    "sprint3:host_memory_usage_percent",
    "sprint3:host_disk_usage_percent",
    "PrometheusScrapeFailure",
    "PrometheusTargetDown",
    "LokiIngestionErrors",
}
add("Prometheus rule groups loaded", required_groups.issubset(set(group_names)), "CONTRACT", str(uat / "prom_rules.json"), "Reload/promtool check rule files", detail=f"groups={sorted(set(group_names))}")
add("Prometheus required rules loaded", required_rules.issubset(set(rule_names)), "CONTRACT", str(uat / "prom_rules.json"), "Ensure sprint3 rule names exist", detail=f"rule_count={len(set(rule_names))}")


def q_value(path: str):
    obj = read_json(uat / path)
    if not isinstance(obj, dict) or obj.get("status") != "success":
        return None
    res = obj.get("data", {}).get("result", [])
    if not res:
        return None
    val = res[0].get("value", [None, None])[1]
    try:
        return float(val)
    except Exception:
        return None


def q_stream_count(path: str):
    obj = read_json(uat / path)
    if not isinstance(obj, dict) or obj.get("status") != "success":
        return None
    res = obj.get("data", {}).get("result", [])
    if not isinstance(res, list):
        return None
    return float(len(res))

v_targets_up = q_value("query_targets_up.json")
v_targets_down = q_value("query_targets_down.json")
v_host_cpu = q_value("query_host_cpu.json")
v_host_mem = q_value("query_host_mem.json")
v_host_disk = q_value("query_host_disk.json")
v_loki_up = q_value("query_up_loki.json")
v_loki_build = q_value("query_loki_build_info_count.json")

add("Query contract: targets_up", v_targets_up is not None and v_targets_up > 0, "CONTRACT", str(uat / "query_targets_up.json"), "Validate recording rule evaluation")
add("Query contract: targets_down zero", v_targets_down is not None and abs(v_targets_down) < 1e-9, "CONTRACT", str(uat / "query_targets_down.json"), "Investigate down targets")
add("Query contract: host cpu", v_host_cpu is not None, "CONTRACT", str(uat / "query_host_cpu.json"), "Validate host CPU recording rule")
add("Query contract: host memory", v_host_mem is not None, "CONTRACT", str(uat / "query_host_mem.json"), "Validate host memory recording rule")
add("Query contract: host disk", v_host_disk is not None, "CONTRACT", str(uat / "query_host_disk.json"), "Validate host disk recording rule")
add("Loki metrics scraped", v_loki_up is not None and v_loki_up >= 1 and v_loki_build is not None and v_loki_build >= 1, "CONTRACT", str(uat / "query_up_loki.json"), "Inspect prometheus scrape config for loki")

# Dashboard and Alloy contracts
dash_eval = read_json(uat / "dashboard_contract_eval.json")
add("Dashboard contract PASS", isinstance(dash_eval, dict) and dash_eval.get("PASS") is True, "CONFIG", str(uat / "dashboard_contract_eval.json"), "Fix datasource/expr contract mismatches")

alloy_eval = read_json(uat / "alloy_contract_eval.json")
add("Alloy allowlist/schema contract PASS", isinstance(alloy_eval, dict) and alloy_eval.get("PASS") is True, "CONFIG", str(uat / "alloy_contract_eval.json"), "Fix allowlist/drop/source_type labels in alloy config")

# Redaction native proof
raw_bearer = q_stream_count("redaction_marker_raw_bearer.json")
raw_cookie = q_stream_count("redaction_marker_raw_cookie.json")
raw_apikey = q_stream_count("redaction_marker_raw_apikey.json")
redacted = q_stream_count("redaction_marker_redacted.json")
marker_any = q_stream_count("redaction_marker_any.json")

raw_absent = all(v is not None and abs(v) < 1e-9 for v in [raw_bearer, raw_cookie, raw_apikey])
redacted_present = redacted is not None and redacted >= 1
marker_present = marker_any is not None and marker_any >= 1
add(
    "Redaction native proof",
    marker_present and raw_absent and redacted_present,
    "SECURITY",
    str(uat / "redaction_marker_redacted.json"),
    "Fix Alloy stage.replace redaction pipeline",
    detail=f"marker={marker_any} raw_bearer={raw_bearer} raw_cookie={raw_cookie} raw_apikey={raw_apikey} redacted={redacted}",
)

# Retention runtime from Prom flags
flags = read_json(uat / "prom_flags.json")
ret = ""
if isinstance(flags, dict):
    ret = str(flags.get("data", {}).get("storage.tsdb.retention.time", ""))
add("Prometheus retention=15d", ret == "15d", "RELIABILITY", str(uat / "prom_flags.json"), "Set --storage.tsdb.retention.time=15d in compose", detail=f"retention={ret}")

overall_ok = all(c["ok"] for c in checks)
payload = {
    "generated_utc": now(),
    "PASS": overall_ok,
    "checks": checks,
    "evidence_root": str(evid),
}
outj.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")

lines = []
lines.append("# Sprint-3 Outcome UAT Report (Native Contract)")
lines.append("")
lines.append(f"Generated: {payload['generated_utc']}")
lines.append(f"- PASS: `{payload['PASS']}`")
lines.append("")
lines.append("| Check | PASS | Bucket | Evidence | Detail | Next action |")
lines.append("|---|---:|---|---|---|---|")
for c in checks:
    lines.append(f"| {c['name']} | {'PASS' if c['ok'] else 'FAIL'} | {c['bucket']} | `{c['evidence']}` | {c.get('detail','')} | {c['next_action']} |")
outm.write_text("\n".join(lines) + "\n", encoding="utf-8")

if not overall_ok:
    raise SystemExit(2)
PY

echo "UAT_NATIVE_CONTRACT_VALIDATION_OK"

# preflight auto-heal: API semantic status checks
python3 - <<'PY' "$UAT_DIR/grafana_health.json"
import json, sys
from pathlib import Path
obj = json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'))
if isinstance(obj, dict) and 'status' in obj and str(obj.get('status')).lower() not in {'success', 'ok', 'ready'}:
    raise SystemExit(2)
PY
python3 - <<'PY' "$UAT_DIR/prom_targets.json"
import json, sys
from pathlib import Path
obj = json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'))
if isinstance(obj, dict) and 'status' in obj and str(obj.get('status')).lower() not in {'success', 'ok', 'ready'}:
    raise SystemExit(2)
PY
python3 - <<'PY' "$UAT_DIR/prom_rules.json"
import json, sys
from pathlib import Path
obj = json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'))
if isinstance(obj, dict) and 'status' in obj and str(obj.get('status')).lower() not in {'success', 'ok', 'ready'}:
    raise SystemExit(2)
PY
python3 - <<'PY' "$UAT_DIR/prom_flags.json"
import json, sys
from pathlib import Path
obj = json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'))
if isinstance(obj, dict) and 'status' in obj and str(obj.get('status')).lower() not in {'success', 'ok', 'ready'}:
    raise SystemExit(2)
PY
```

## Host Path Mapping
- Host-bound paths are intentional for this environment.
- Detected host paths: `/home/luce/apps/loki-logging`, `/home/luce/_logs/loki-logging-smoke.log`.
