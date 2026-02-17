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
import json, sys, urllib.parse, urllib.request, time

idx_json, grafana_url, g_user, g_pass, prom_url, loki_url, start_ns, end_ns, md_path, js_path = sys.argv[1:]
idx = json.loads(idx_json)

headers = {"Authorization": "Basic " + __import__("base64").b64encode(f"{g_user}:{g_pass}".encode()).decode()}

def http_json(url):
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.loads(r.read().decode())

def prom_count(expr):
    q = urllib.parse.urlencode({"query": expr})
    with urllib.request.urlopen(prom_url + "?" + q, timeout=20) as r:
        data = json.loads(r.read().decode())
    return len(data.get("data", {}).get("result", []))

def loki_count(expr):
    q = urllib.parse.urlencode({"query": expr, "start": start_ns, "end": end_ns, "limit": 5, "direction": "BACKWARD"})
    with urllib.request.urlopen(loki_url + "?" + q, timeout=20) as r:
        data = json.loads(r.read().decode())
    return len(data.get("data", {}).get("result", []))

rows=[]
empty=[]
checked=0
for d in idx:
    uid=d.get("uid")
    title=d.get("title","")
    if not uid:
        continue
    dash = http_json(f"{grafana_url}/api/dashboards/uid/{uid}")
    panels = dash.get("dashboard", {}).get("panels", [])

    def walk(ps):
        for p in ps or []:
            if p.get("type") == "row" and p.get("panels"):
                yield from walk(p.get("panels"))
                continue
            ptitle=p.get("title","(no-title)")
            pds=p.get("datasource")
            for t in p.get("targets") or []:
                expr=t.get("expr") or t.get("expression")
                if not isinstance(expr,str) or not expr.strip():
                    continue
                tds=t.get("datasource")
                ds=tds if isinstance(tds,dict) else (pds if isinstance(pds,dict) else {})
                ds_uid=ds.get("uid")
                yield ptitle, ds_uid, expr.strip()

    local=0
    for ptitle, ds_uid, expr in walk(panels):
        if ds_uid not in ("PBFA97CFB590B2093","P8E80F9AEF21F6940"):
            continue
        local += 1
        checked += 1
        try:
            cnt = prom_count(expr) if ds_uid == "PBFA97CFB590B2093" else loki_count(expr)
            rows.append({"dashboard_uid":uid,"dashboard_title":title,"panel":ptitle,"datasource_uid":ds_uid,"expr":expr,"count":cnt})
            if cnt == 0:
                empty.append({"dashboard_uid":uid,"dashboard_title":title,"panel":ptitle,"datasource_uid":ds_uid,"expr":expr})
        except Exception as e:
            empty.append({"dashboard_uid":uid,"dashboard_title":title,"panel":ptitle,"datasource_uid":ds_uid,"expr":expr,"error":str(e)})
    if local == 0:
        rows.append({"dashboard_uid":uid,"dashboard_title":title,"panel":"(none)","datasource_uid":"unknown","expr":"(none)","count":"unknown"})

pass_flag = len(empty) == 0
summary = {
    "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    "pass": pass_flag,
    "dashboards_scanned": len(idx),
    "queries_checked": checked,
    "empty_panels": len(empty),
}

with open(js_path, "w") as f:
    json.dump({"summary": summary, "empty": empty, "checked": rows[:200]}, f, indent=2)

with open(md_path, "w") as f:
    f.write(f"# Dashboard Query Audit ({summary['ts']})\n\n")
    f.write(f"- dashboards_scanned: {summary['dashboards_scanned']}\n")
    f.write(f"- queries_checked: {summary['queries_checked']}\n")
    f.write(f"- empty_panels: {summary['empty_panels']}\n")
    f.write(f"- pass: {'yes' if pass_flag else 'no'}\n\n")
    f.write("## Empty panels\n")
    if not empty:
        f.write("- none\n")
    else:
        for e in empty[:100]:
            f.write(f"- {e['dashboard_uid']} | {e['panel']} | {e['datasource_uid']} | {e['expr']}\n")

print(f"WROTE_MD={md_path}")
print(f"WROTE_JSON={js_path}")
print(f"AUDIT_PASS={'yes' if pass_flag else 'no'}")
print(f"EMPTY_PANELS={len(empty)}")
PY
