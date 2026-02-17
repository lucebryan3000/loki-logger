#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/luce/apps/loki-logging"
OUTDIR="$ROOT/_build/logging"
mkdir -p "$OUTDIR"
MD="$OUTDIR/dashboard_audit_latest.md"
JS="$OUTDIR/dashboard_audit_latest.json"

GRAFANA_URL="${GRAFANA_URL:-http://127.0.0.1:9001}"
PROM_URL="${PROM_URL:-http://127.0.0.1:9004/api/v1/query}"
LOKI_URL="${LOKI_URL:-http://127.0.0.1:3200/loki/api/v1/query_range}"
GRAFANA_USER="${GRAFANA_USER:-admin}"

if [ -z "${GRAFANA_PASS:-}" ]; then
  GRAFANA_PASS="$(docker inspect logging-grafana-1 --format '{{range .Config.Env}}{{println .}}{{end}}' | rg '^GF_SECURITY_ADMIN_PASSWORD=' | sed 's/^GF_SECURITY_ADMIN_PASSWORD=//' || true)"
fi
if [ -z "$GRAFANA_PASS" ]; then
  echo "FAIL: unable to derive Grafana credentials" >&2
  exit 2
fi

start_ns=$((($(date +%s)-1800)*1000000000))
end_ns=$((($(date +%s)+60)*1000000000))

idx_json=$(curl -fsS -u "$GRAFANA_USER:$GRAFANA_PASS" "$GRAFANA_URL/api/search?type=dash-db&limit=500")

python3 - "$idx_json" "$GRAFANA_URL" "$GRAFANA_USER" "$GRAFANA_PASS" "$PROM_URL" "$LOKI_URL" "$start_ns" "$end_ns" "$MD" "$JS" <<'PY'
import base64
import json
import re
import sys
import time
import urllib.parse
import urllib.request

idx_json, grafana_url, g_user, g_pass, prom_url, loki_url, start_ns, end_ns, md_path, js_path = sys.argv[1:]
idx = json.loads(idx_json)

headers = {
    "Authorization": "Basic " + base64.b64encode(f"{g_user}:{g_pass}".encode()).decode(),
}


def http_json(url: str, timeout: int = 20, retries: int = 5):
    last = None
    for attempt in range(1, retries + 1):
        try:
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.loads(r.read().decode())
        except Exception as exc:
            last = exc
            if attempt < retries:
                time.sleep(1)
    raise RuntimeError(f"http_json_failed url={url} err={last}")


def prom_count(expr: str, retries: int = 4):
    q = urllib.parse.urlencode({"query": expr})
    url = prom_url + "?" + q
    last = None
    for attempt in range(1, retries + 1):
        try:
            with urllib.request.urlopen(url, timeout=15) as r:
                data = json.loads(r.read().decode())
            return len(data.get("data", {}).get("result", []))
        except Exception as exc:
            last = exc
            if attempt < retries:
                time.sleep(1)
    raise RuntimeError(f"prom_query_failed expr={expr} err={last}")


def loki_count(expr: str, retries: int = 4):
    q = urllib.parse.urlencode(
        {
            "query": expr,
            "start": start_ns,
            "end": end_ns,
            "limit": 5,
            "direction": "BACKWARD",
        }
    )
    url = loki_url + "?" + q
    last = None
    for attempt in range(1, retries + 1):
        try:
            with urllib.request.urlopen(url, timeout=15) as r:
                data = json.loads(r.read().decode())
            return len(data.get("data", {}).get("result", []))
        except Exception as exc:
            last = exc
            if attempt < retries:
                time.sleep(1)
    raise RuntimeError(f"loki_query_failed expr={expr} err={last}")


def vars_map_for_dashboard(dashboard: dict):
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
        else:
            if isinstance(cur, list):
                out[name] = "|".join(str(x) for x in cur if x)
            else:
                out[name] = str(cur)
    return out


def substitute_vars(expr: str, vmap: dict):
    out = expr
    # ${var}
    for k, v in vmap.items():
        out = out.replace("${" + k + "}", v)
    # $var boundary-safe
    for k, v in sorted(vmap.items(), key=lambda kv: len(kv[0]), reverse=True):
        out = re.sub(r"\$" + re.escape(k) + r"\b", v, out)
    return out


rows = []
empty = []
checked = 0
provisioned_scanned = 0

for d in idx:
    uid = d.get("uid")
    if not uid:
        continue

    dash_payload = http_json(f"{grafana_url}/api/dashboards/uid/{uid}")
    meta = dash_payload.get("meta", {})
    if not bool(meta.get("provisioned")):
        continue

    dashboard = dash_payload.get("dashboard", {})
    title = dashboard.get("title", "")
    provisioned_scanned += 1
    vmap = vars_map_for_dashboard(dashboard)

    def walk(ps):
        for p in ps or []:
            if p.get("type") == "row" and p.get("panels"):
                yield from walk(p.get("panels"))
                continue
            ptitle = p.get("title", "(no-title)")
            pds = p.get("datasource")
            for t in p.get("targets") or []:
                expr = t.get("expr") or t.get("expression")
                if not isinstance(expr, str) or not expr.strip():
                    continue
                tds = t.get("datasource")
                ds = tds if isinstance(tds, dict) else (pds if isinstance(pds, dict) else {})
                ds_uid = ds.get("uid")
                yield ptitle, ds_uid, expr.strip()

    for ptitle, ds_uid, expr in walk(dashboard.get("panels", [])):
        if ds_uid not in ("PBFA97CFB590B2093", "P8E80F9AEF21F6940"):
            continue
        checked += 1
        resolved = substitute_vars(expr, vmap)
        try:
            cnt = prom_count(resolved) if ds_uid == "PBFA97CFB590B2093" else loki_count(resolved)
            rec = {
                "dashboard_uid": uid,
                "dashboard_title": title,
                "panel": ptitle,
                "datasource_uid": ds_uid,
                "expr": expr,
                "expr_resolved": resolved,
                "count": cnt,
                "status": "ok" if cnt > 0 else "empty",
            }
            rows.append(rec)
            if cnt == 0:
                empty.append(rec)
        except Exception as exc:
            rec = {
                "dashboard_uid": uid,
                "dashboard_title": title,
                "panel": ptitle,
                "datasource_uid": ds_uid,
                "expr": expr,
                "expr_resolved": resolved,
                "count": 0,
                "status": "error",
                "error": str(exc),
            }
            rows.append(rec)
            empty.append(rec)

pass_flag = len(empty) == 0
summary = {
    "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    "pass": pass_flag,
    "dashboards_total": len(idx),
    "dashboards_provisioned_scanned": provisioned_scanned,
    "queries_checked": checked,
    "empty_panels": len(empty),
}

with open(js_path, "w") as f:
    json.dump({"summary": summary, "empty": empty, "checked": rows[:400]}, f, indent=2)

with open(md_path, "w") as f:
    f.write(f"# Dashboard Query Audit ({summary['ts']})\n\n")
    f.write(f"- dashboards_total: {summary['dashboards_total']}\n")
    f.write(f"- dashboards_provisioned_scanned: {summary['dashboards_provisioned_scanned']}\n")
    f.write(f"- queries_checked: {summary['queries_checked']}\n")
    f.write(f"- empty_panels: {summary['empty_panels']}\n")
    f.write(f"- pass: {'yes' if pass_flag else 'no'}\n\n")
    f.write("## Empty panels\n")
    if not empty:
        f.write("- none\n")
    else:
        for e in empty[:200]:
            f.write(
                f"- {e['dashboard_uid']} | {e['panel']} | {e['datasource_uid']} | {e['expr']} | resolved={e['expr_resolved']}"
                + (f" | error={e['error']}" if 'error' in e else "")
                + "\n"
            )

print(f"WROTE_MD={md_path}")
print(f"WROTE_JSON={js_path}")
print(f"AUDIT_PASS={'yes' if pass_flag else 'no'}")
print(f"EMPTY_PANELS={len(empty)}")
PY
