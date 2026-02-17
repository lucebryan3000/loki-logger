#!/usr/bin/env bash
set -euo pipefail

GRAFANA_URL="${GRAFANA_URL:-http://127.0.0.1:9001}"
GRAFANA_USER="${GRAFANA_USER:-admin}"
if [ -z "${GRAFANA_PASS:-}" ]; then
  GRAFANA_PASS="$(docker inspect logging-grafana-1 --format '{{range .Config.Env}}{{println .}}{{end}}' | rg '^GF_SECURITY_ADMIN_PASSWORD=' | sed 's/^GF_SECURITY_ADMIN_PASSWORD=//')"
fi
[ -n "${GRAFANA_PASS:-}" ] || { echo "FAIL: no grafana password" >&2; exit 2; }

IN="${1:-_build/logging/offending_dashboards.json}"
OUTDIR="${2:-infra/logging/grafana/dashboards/adopted}"
MANIFEST="${3:-_build/logging/adopted_dashboards_manifest.json}"
mkdir -p "$OUTDIR" "$(dirname "$MANIFEST")"

export GRAFANA_URL GRAFANA_USER GRAFANA_PASS IN OUTDIR MANIFEST
python3 - <<'PY'
import base64
import json
import os
import re
import urllib.request

grafana_url = os.environ["GRAFANA_URL"]
user = os.environ["GRAFANA_USER"]
password = os.environ["GRAFANA_PASS"]
input_path = os.environ["IN"]
out_dir = os.environ["OUTDIR"]
manifest_path = os.environ["MANIFEST"]

inventory = json.load(open(input_path))
auth = base64.b64encode(f"{user}:{password}".encode()).decode()
out = []

def slug(value: str) -> str:
    value = (value or "").strip().lower()
    value = re.sub(r"[^a-z0-9]+", "-", value).strip("-")
    return value[:48] if value else "dashboard"

for row in inventory:
    source_uid = row.get("uid")
    source_title = row.get("title") or source_uid
    req = urllib.request.Request(
        f"{grafana_url}/api/dashboards/uid/{source_uid}",
        headers={"Authorization": f"Basic {auth}"},
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            payload = json.loads(resp.read().decode())
    except Exception as exc:
        out.append(
            {
                "src_uid": source_uid,
                "status": "export_failed",
                "error": str(exc),
            }
        )
        continue

    dashboard = payload.get("dashboard", {})
    for key in ("id", "version", "uid", "iteration"):
        dashboard.pop(key, None)

    new_uid = f"codeswarm-adopted-{slug(source_uid)}"
    out_file = f"codeswarm-adopted-{slug(source_uid)}.json"

    dashboard["uid"] = new_uid
    dashboard["title"] = f"CodeSwarm — {source_title}"
    dashboard["editable"] = True
    tags = set(dashboard.get("tags") or [])
    tags.update({"codeswarm", "adopted"})
    dashboard["tags"] = sorted(tags)

    output_path = os.path.join(out_dir, out_file)
    with open(output_path, "w") as fh:
        json.dump(dashboard, fh, indent=2)

    out.append(
        {
            "src_uid": source_uid,
            "src_title": source_title,
            "new_uid": new_uid,
            "file": f"adopted/{out_file}",
            "status": "adopted",
        }
    )

with open(manifest_path, "w") as fh:
    json.dump(out, fh, indent=2)

print("ADOPTED_COUNT=" + str(sum(1 for x in out if x.get("status") == "adopted")))
print("MANIFEST=" + manifest_path)
PY
