#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/luce/apps/loki-logging"
OUTDIR="$ROOT/_build/logging"
mkdir -p "$OUTDIR" 2>/dev/null || true
if ! touch "$OUTDIR/.dashboard_mutation_preflight_write_test" 2>/dev/null; then
  OUTDIR="/tmp/logging-artifacts"
  mkdir -p "$OUTDIR"
else
  rm -f "$OUTDIR/.dashboard_mutation_preflight_write_test"
fi

OUT_JSON="$OUTDIR/dashboard_mutation_preflight_latest.json"
OUT_MD="$OUTDIR/dashboard_mutation_preflight_latest.md"

DASH_PATH="$ROOT/infra/logging/grafana/dashboards/top-errors-log-explorer.json"
DASH_UID="top-errors-log-explorer"
PANEL_IDS="4,7,12,13,14,16"
MODE="strict"
GRAFANA_URL="${GRAFANA_URL:-http://127.0.0.1:9001}"
GRAFANA_USER="${GRAFANA_USER:-admin}"

usage() {
  cat <<'EOF'
Usage: dashboard_mutation_preflight.sh [options]

Fail-closed preflight for dashboard mutations. Verifies panel IDs exist and
validates Loki query expressions (with template substitution) before any live save.

Options:
  --dashboard <path>   Dashboard JSON file path
  --uid <uid>          Grafana dashboard UID to compare live panel IDs
  --panels <csv>       Required panel IDs (comma-separated integers)
  --strict             Exit non-zero on any failure (default)
  --soft               Always exit zero; still writes artifact
  -h, --help           Show help

Artifacts:
  _build/logging/dashboard_mutation_preflight_latest.json
  _build/logging/dashboard_mutation_preflight_latest.md
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dashboard)
      [[ $# -ge 2 ]] || { echo "missing_value_for=$1" >&2; exit 2; }
      DASH_PATH="$2"
      shift 2
      ;;
    --uid)
      [[ $# -ge 2 ]] || { echo "missing_value_for=$1" >&2; exit 2; }
      DASH_UID="$2"
      shift 2
      ;;
    --panels)
      [[ $# -ge 2 ]] || { echo "missing_value_for=$1" >&2; exit 2; }
      PANEL_IDS="$2"
      shift 2
      ;;
    --strict)
      MODE="strict"
      shift
      ;;
    --soft)
      MODE="soft"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown_arg=$1" >&2
      echo "try: dashboard_mutation_preflight.sh --help" >&2
      exit 2
      ;;
  esac
done

if [[ -z "${GRAFANA_PASS:-}" ]]; then
  GRAFANA_PASS="$(docker inspect logging-grafana-1 --format '{{range .Config.Env}}{{println .}}{{end}}' | rg '^GF_SECURITY_ADMIN_PASSWORD=' | sed 's/^GF_SECURITY_ADMIN_PASSWORD=//' || true)"
fi

python3 - "$DASH_PATH" "$DASH_UID" "$PANEL_IDS" "$GRAFANA_URL" "$GRAFANA_USER" "${GRAFANA_PASS:-}" "$OUT_JSON" "$OUT_MD" "$MODE" <<'PY'
import base64
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

dash_path, dash_uid, panel_ids_csv, grafana_url, user, password, out_json, out_md, mode = sys.argv[1:]

LOKI_UIDS = {"P8E80F9AEF21F6940"}
LOKI_URL = "http://127.0.0.1:3200/loki/api/v1/query"

try:
    req_ids = [int(x.strip()) for x in panel_ids_csv.split(",") if x.strip()]
except ValueError:
    print("invalid_panel_ids_csv", file=sys.stderr)
    raise SystemExit(2)

if not os.path.exists(dash_path):
    print(f"missing_dashboard_file={dash_path}", file=sys.stderr)
    raise SystemExit(2)

with open(dash_path) as fh:
    local_dash = json.load(fh)


def walk_panels(panels):
    for p in panels or []:
        if p.get("type") == "row":
            yield from walk_panels(p.get("panels") or [])
            continue
        yield p


def panel_index(dashboard):
    out = {}
    for p in walk_panels(dashboard.get("panels") or []):
        pid = p.get("id")
        if isinstance(pid, int):
            out[pid] = p
    return out


def vars_map_for_dashboard(dashboard):
    out = {}
    for v in (dashboard.get("templating", {}) or {}).get("list", []) or []:
        if not isinstance(v, dict):
            continue
        name = v.get("name")
        if not isinstance(name, str) or not name:
            continue
        all_value = v.get("allValue") or ".+"
        cur = (v.get("current") or {}).get("value")
        if cur in (None, "", "$__all", "All"):
            out[name] = all_value
        elif isinstance(cur, list):
            out[name] = "|".join(str(x) for x in cur if x)
        else:
            out[name] = str(cur)
    return out


def substitute_vars(expr, vmap):
    out = expr
    for k, v in vmap.items():
        out = out.replace("${" + k + "}", v)
    for k, v in sorted(vmap.items(), key=lambda kv: len(kv[0]), reverse=True):
        out = re.sub(r"\$" + re.escape(k) + r"\b", v, out)
    out = out.replace("${__range}", "5m").replace("$__range", "5m")
    out = out.replace("${__interval}", "30s").replace("$__interval", "30s")
    out = out.replace("${__rate_interval}", "1m").replace("$__rate_interval", "1m")
    out = out.replace("${__range_s}", "300").replace("$__range_s", "300")
    out = out.replace("${__range_ms}", "300000").replace("$__range_ms", "300000")
    out = out.replace("${__interval_ms}", "30000").replace("$__interval_ms", "30000")
    return out


def loki_query(expr):
    q = urllib.parse.urlencode({"query": expr})
    url = LOKI_URL + "?" + q
    req = urllib.request.Request(url)
    with urllib.request.urlopen(req, timeout=20) as resp:
        payload = json.loads(resp.read().decode())
    if payload.get("status") != "success":
        raise RuntimeError(payload.get("error") or "loki_non_success")
    return len(payload.get("data", {}).get("result", []))


local_map = panel_index(local_dash)
missing_local = [pid for pid in req_ids if pid not in local_map]

live_missing = []
live_present = []
live_fetch_error = ""
if dash_uid and password:
    auth = base64.b64encode(f"{user}:{password}".encode()).decode()
    headers = {"Authorization": f"Basic {auth}"}
    req = urllib.request.Request(f"{grafana_url}/api/dashboards/uid/{dash_uid}", headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            live_payload = json.loads(resp.read().decode())
        live_map = panel_index(live_payload.get("dashboard", {}))
        live_missing = [pid for pid in req_ids if pid not in live_map]
        live_present = [pid for pid in req_ids if pid in live_map]
    except Exception as exc:
        live_fetch_error = str(exc)
elif dash_uid and not password:
    live_fetch_error = "missing_grafana_password"

vmap = vars_map_for_dashboard(local_dash)
checked = []
errors = []

for pid in req_ids:
    p = local_map.get(pid)
    if not p:
        continue
    pds = p.get("datasource")
    ptitle = p.get("title", "(no-title)")
    for idx, tgt in enumerate(p.get("targets") or []):
        expr = tgt.get("expr") or tgt.get("expression")
        if not isinstance(expr, str) or not expr.strip():
            continue
        tds = tgt.get("datasource")
        ds = tds if isinstance(tds, dict) else (pds if isinstance(pds, dict) else {})
        ds_uid = ds.get("uid")
        if ds_uid not in LOKI_UIDS:
            continue
        resolved = substitute_vars(expr.strip(), vmap)
        row = {
            "panel_id": pid,
            "panel_title": ptitle,
            "target_index": idx,
            "datasource_uid": ds_uid,
            "expr": expr.strip(),
            "expr_resolved": resolved,
        }
        try:
            row["result_series"] = loki_query(resolved)
            checked.append(row)
        except Exception as exc:
            row["error"] = str(exc)
            errors.append(row)

pass_flag = (
    len(missing_local) == 0
    and len(live_missing) == 0
    and live_fetch_error in ("", "missing_grafana_password")
    and len(errors) == 0
    and len(checked) > 0
)

artifact = {
    "timestamp_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    "pass": pass_flag,
    "dashboard_path": dash_path,
    "dashboard_uid": dash_uid,
    "required_panel_ids": req_ids,
    "summary": {
        "required_panels": len(req_ids),
        "missing_local": len(missing_local),
        "missing_live": len(live_missing),
        "checked_targets": len(checked),
        "error_targets": len(errors),
    },
    "missing_local_panel_ids": missing_local,
    "missing_live_panel_ids": live_missing,
    "live_present_panel_ids": live_present,
    "live_fetch_error": live_fetch_error,
    "checked": checked[:200],
    "errors": errors[:200],
}

with open(out_json, "w") as fh:
    json.dump(artifact, fh, indent=2)

with open(out_md, "w") as fh:
    fh.write("# Dashboard Mutation Preflight\n\n")
    fh.write(f"- timestamp_utc: {artifact['timestamp_utc']}\n")
    fh.write(f"- pass: {artifact['pass']}\n")
    fh.write(f"- dashboard_path: {dash_path}\n")
    fh.write(f"- dashboard_uid: {dash_uid}\n")
    fh.write(f"- required_panel_ids: {','.join(str(x) for x in req_ids)}\n")
    fh.write(f"- missing_local_panel_ids: {missing_local}\n")
    fh.write(f"- missing_live_panel_ids: {live_missing}\n")
    fh.write(f"- checked_targets: {len(checked)}\n")
    fh.write(f"- error_targets: {len(errors)}\n")
    if live_fetch_error:
        fh.write(f"- live_fetch_error: {live_fetch_error}\n")
    fh.write("\n## Errors\n")
    if errors:
        for e in errors:
            fh.write(f"- panel_id={e['panel_id']} title={e['panel_title']} target={e['target_index']} error={e['error']}\n")
    else:
        fh.write("- none\n")

print(f"PREFLIGHT_JSON={out_json}")
print(f"PREFLIGHT_MD={out_md}")
print(f"PREFLIGHT_PASS={str(pass_flag).lower()}")

if not pass_flag and mode != "soft":
    raise SystemExit(1)
PY
