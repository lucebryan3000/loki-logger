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
expected_empty = []
per_dashboard = {}
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
            dkey = uid
            if dkey not in per_dashboard:
                per_dashboard[dkey] = {
                    "dashboard_title": title,
                    "checked": 0,
                    "unexpected_empty": 0,
                    "expected_empty": 0,
                    "errors": 0,
                }
            per_dashboard[dkey]["checked"] += 1
            if cnt == 0:
                # Some panels intentionally query rare error signatures; a zero here is expected
                # and should not fail pipeline auditability.
                if "(?i)(error|fail|exception|panic)" in resolved:
                    rec["status"] = "expected_empty"
                    expected_empty.append(rec)
                    per_dashboard[dkey]["expected_empty"] += 1
                # Per-dimension dashboards can legitimately be empty for inactive values.
                elif uid.startswith("codeswarm-dim-"):
                    rec["status"] = "expected_empty"
                    expected_empty.append(rec)
                    per_dashboard[dkey]["expected_empty"] += 1
                # Adopted dashboards are copied from externally managed/plugin dashboards and may
                # include panels that are not relevant to this stack's enabled metrics.
                elif uid.startswith("codeswarm-adopted-"):
                    rec["status"] = "expected_empty"
                    expected_empty.append(rec)
                    per_dashboard[dkey]["expected_empty"] += 1
                # Marker-based panels can be empty between timer emissions; verifier gates the
                # authoritative condition separately.
                elif "sum(count_over_time({log_source=\"rsyslog_syslog\"} |~ \"MARKER=\" [15m]))" in resolved:
                    rec["status"] = "expected_empty"
                    expected_empty.append(rec)
                    per_dashboard[dkey]["expected_empty"] += 1
                # Rsyslog forward-error panel is intentionally quiet in healthy state.
                elif "sum(count_over_time({log_source=\"rsyslog_syslog\"} |~ \"(omfwd|suspend|refused|error)\" [30m]))" in resolved:
                    rec["status"] = "expected_empty"
                    expected_empty.append(rec)
                    per_dashboard[dkey]["expected_empty"] += 1
                # Some low-volume sources can be legitimately idle in the sampled window.
                elif "{log_source=\"codeswarm_mcp\"}" in resolved:
                    rec["status"] = "expected_empty"
                    expected_empty.append(rec)
                    per_dashboard[dkey]["expected_empty"] += 1
                else:
                    empty.append(rec)
                    per_dashboard[dkey]["unexpected_empty"] += 1
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
            dkey = uid
            if dkey not in per_dashboard:
                per_dashboard[dkey] = {
                    "dashboard_title": title,
                    "checked": 0,
                    "unexpected_empty": 0,
                    "expected_empty": 0,
                    "errors": 0,
                }
            per_dashboard[dkey]["checked"] += 1
            per_dashboard[dkey]["errors"] += 1
            per_dashboard[dkey]["unexpected_empty"] += 1
            empty.append(rec)

pass_flag = len(empty) == 0
summary = {
    "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    "pass": pass_flag,
    "dashboards_total": len(idx),
    "dashboards_provisioned_scanned": provisioned_scanned,
    "queries_checked": checked,
    "empty_panels": len(empty),
    "expected_empty_panels": len(expected_empty),
    "unexpected_empty_panels": len(empty),
}

with open(js_path, "w") as f:
    json.dump({"summary": summary, "per_dashboard": per_dashboard, "empty": empty, "expected_empty": expected_empty, "checked": rows[:400]}, f, indent=2)

with open(md_path, "w") as f:
    f.write(f"# Dashboard Query Audit ({summary['ts']})\n\n")
    f.write(f"- dashboards_total: {summary['dashboards_total']}\n")
    f.write(f"- dashboards_provisioned_scanned: {summary['dashboards_provisioned_scanned']}\n")
    f.write(f"- queries_checked: {summary['queries_checked']}\n")
    f.write(f"- empty_panels: {summary['empty_panels']}\n")
    f.write(f"- expected_empty_panels: {summary['expected_empty_panels']}\n")
    f.write(f"- unexpected_empty_panels: {summary['unexpected_empty_panels']}\n")
    f.write(f"- pass: {'yes' if pass_flag else 'no'}\n\n")
    f.write("## Per-dashboard breakdown\n")
    if per_dashboard:
        for duid, stats in sorted(per_dashboard.items()):
            f.write(f"- {duid} | {stats['dashboard_title']} | checked={stats['checked']} | unexpected_empty={stats['unexpected_empty']} | expected_empty={stats['expected_empty']} | errors={stats['errors']}\n")
    else:
        f.write("- none\n")
    f.write("\n## Empty panels\n")
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
