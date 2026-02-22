#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/luce/apps/loki-logging"
OUTDIR="$ROOT/_build/logging"
mkdir -p "$OUTDIR" 2>/dev/null || true
if ! touch "$OUTDIR/.reconcile_write_test" 2>/dev/null; then
  OUTDIR="/tmp/logging-artifacts"
  mkdir -p "$OUTDIR"
else
  rm -f "$OUTDIR/.reconcile_write_test"
fi
OUT_JSON="$OUTDIR/dashboard_reconciliation_latest.json"
OUT_MD="$OUTDIR/dashboard_reconciliation_latest.md"

GRAFANA_URL="${GRAFANA_URL:-http://127.0.0.1:9001}"
GRAFANA_USER="${GRAFANA_USER:-admin}"
MODE="${1:-strict}"

if [[ "${MODE}" == "--help" || "${MODE}" == "-h" ]]; then
  cat <<'EOF'
Usage: reconcile_dashboards.sh [strict|soft]

Reconcile file-provisioned dashboard expressions against live Grafana state.

Modes:
  strict (default): exit non-zero on drift/missing dashboards
  soft:             always exit zero, still writes artifacts

Artifacts:
  _build/logging/dashboard_reconciliation_latest.json
  _build/logging/dashboard_reconciliation_latest.md

Checks:
  - gpu-overview
  - pipeline-health
  - top-errors-log-explorer
EOF
  exit 0
fi

if [[ -z "${GRAFANA_PASS:-}" ]]; then
  GRAFANA_PASS="$(docker inspect logging-grafana-1 --format '{{range .Config.Env}}{{println .}}{{end}}' | rg '^GF_SECURITY_ADMIN_PASSWORD=' | sed 's/^GF_SECURITY_ADMIN_PASSWORD=//' || true)"
fi

if [[ -z "${GRAFANA_PASS:-}" ]]; then
  echo "FAIL: unable to derive Grafana credentials" >&2
  exit 2
fi

# Ensure Grafana re-reads file-provisioned dashboards before drift comparison.
curl -fsS -u "${GRAFANA_USER}:${GRAFANA_PASS}" -X POST \
  "${GRAFANA_URL}/api/admin/provisioning/dashboards/reload" >/dev/null

python3 - "$ROOT" "$GRAFANA_URL" "$GRAFANA_USER" "$GRAFANA_PASS" "$OUT_JSON" "$OUT_MD" "$MODE" <<'PY'
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request

root, grafana_url, user, password, out_json, out_md, mode = sys.argv[1:]

critical = [
    ("gpu_overview_v1", os.path.join(root, "infra/logging/grafana/dashboards/gpu-overview.json")),
    ("pipeline-health", os.path.join(root, "infra/logging/grafana/dashboards/pipeline-health.json")),
    ("top-errors-log-explorer", os.path.join(root, "infra/logging/grafana/dashboards/top-errors-log-explorer.json")),
]

auth = base64.b64encode(f"{user}:{password}".encode()).decode()
headers = {"Authorization": f"Basic {auth}"}


def walk_panels(panels):
    for panel in panels or []:
        if panel.get("type") == "row":
            yield from walk_panels(panel.get("panels") or [])
            continue
        yield panel


def extract_expr_map(dashboard):
    out = {}
    for panel in walk_panels(dashboard.get("panels") or []):
        panel_id = panel.get("id", "na")
        panel_title = panel.get("title", "(no-title)")
        for idx, target in enumerate(panel.get("targets") or []):
            expr = target.get("expr") or target.get("expression")
            if not isinstance(expr, str) or not expr.strip():
                continue
            ref = target.get("refId") or str(idx)
            key = f"{panel_id}:{panel_title}:{ref}"
            out[key] = expr.strip()
    return out


def fetch_live(uid):
    req = urllib.request.Request(f"{grafana_url}/api/dashboards/uid/{uid}", headers=headers)
    with urllib.request.urlopen(req, timeout=20) as resp:
        return json.loads(resp.read().decode())


rows = []
drift_count = 0
missing_live = 0
missing_local = 0

for uid, path in critical:
    rec = {
        "uid": uid,
        "local_path": path,
        "status": "in_sync",
        "local_expr_count": 0,
        "live_expr_count": 0,
        "mismatched_keys": [],
    }

    if not os.path.exists(path):
        rec["status"] = "missing_local"
        missing_local += 1
        rows.append(rec)
        continue

    local_payload = json.load(open(path))
    local_map = extract_expr_map(local_payload)
    rec["local_expr_count"] = len(local_map)

    try:
        live_payload = fetch_live(uid)
    except urllib.error.HTTPError as exc:
        rec["status"] = "missing_live"
        rec["http_status"] = exc.code
        missing_live += 1
        rows.append(rec)
        continue
    except Exception as exc:
        rec["status"] = "missing_live"
        rec["error"] = str(exc)
        missing_live += 1
        rows.append(rec)
        continue

    live_dash = live_payload.get("dashboard", {})
    live_map = extract_expr_map(live_dash)
    rec["live_expr_count"] = len(live_map)

    mismatched = []
    for key in sorted(set(local_map) | set(live_map)):
        if local_map.get(key) != live_map.get(key):
            mismatched.append(key)
            if len(mismatched) >= 50:
                break

    if mismatched:
        rec["status"] = "drift"
        rec["mismatched_keys"] = mismatched
        drift_count += 1

    rows.append(rec)

pass_flag = drift_count == 0 and missing_live == 0 and missing_local == 0

artifact = {
    "timestamp_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    "pass": pass_flag,
    "summary": {
        "checked": len(rows),
        "in_sync": sum(1 for r in rows if r["status"] == "in_sync"),
        "drift": drift_count,
        "missing_live": missing_live,
        "missing_local": missing_local,
    },
    "dashboards": rows,
}

with open(out_json, "w") as fh:
    json.dump(artifact, fh, indent=2)

with open(out_md, "w") as fh:
    fh.write(f"# Dashboard Reconciliation\\n\\n")
    fh.write(f"- timestamp_utc: {artifact['timestamp_utc']}\\n")
    fh.write(f"- pass: {artifact['pass']}\\n")
    fh.write(f"- checked: {artifact['summary']['checked']}\\n")
    fh.write(f"- in_sync: {artifact['summary']['in_sync']}\\n")
    fh.write(f"- drift: {artifact['summary']['drift']}\\n")
    fh.write(f"- missing_live: {artifact['summary']['missing_live']}\\n")
    fh.write(f"- missing_local: {artifact['summary']['missing_local']}\\n\\n")
    fh.write("| UID | Status | Local Expr | Live Expr |\\n")
    fh.write("|-----|--------|------------|-----------|\\n")
    for row in rows:
        fh.write(f"| {row['uid']} | {row['status']} | {row.get('local_expr_count', 0)} | {row.get('live_expr_count', 0)} |\\n")

print(f"RECONCILIATION_JSON={out_json}")
print(f"RECONCILIATION_MD={out_md}")
print(f"RECONCILIATION_PASS={str(pass_flag).lower()}")

if not pass_flag and mode != "soft":
    raise SystemExit(1)
PY
