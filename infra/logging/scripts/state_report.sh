#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/luce/apps/loki-logging"
OUTDIR="$ROOT/_build/logging"
mkdir -p "$OUTDIR"
MD="$OUTDIR/state_report_latest.md"
JS="$OUTDIR/state_report_latest.json"
ts=$(date -u +%Y%m%dT%H%M%SZ)

unknown(){ printf 'UNKNOWN — %s — %s' "$1" "$2"; }

GRAFANA_URL="http://127.0.0.1:9001"
GRAFANA_USER="admin"
GRAFANA_PASS="$(docker inspect logging-grafana-1 --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | rg '^GF_SECURITY_ADMIN_PASSWORD=' | sed 's/^GF_SECURITY_ADMIN_PASSWORD=//' || true)"

loki_ok="no"
curl -fsS http://127.0.0.1:3200/ready >/dev/null 2>&1 && loki_ok="yes"

prom_ok="no"
curl -fsS http://127.0.0.1:9004/-/healthy >/dev/null 2>&1 && prom_ok="yes"

grafana_ok="unknown"
grafana_evidence="$(unknown 'grafana auth missing' 'docker inspect logging-grafana-1 env')"
if [[ -n "$GRAFANA_PASS" ]]; then
  if curl -fsS -u "$GRAFANA_USER:$GRAFANA_PASS" "$GRAFANA_URL/api/health" >/tmp/state_report_grafana_health.json 2>/dev/null; then
    grafana_ok="yes"
    grafana_evidence='curl -u admin:*** /api/health => ok'
  else
    grafana_ok="no"
    grafana_evidence='curl -u admin:*** /api/health => failed'
  fi
fi

dashboards_present="unknown"
dashboards_evidence="$(unknown 'grafana unavailable' 'curl /api/search?query=')"
rules_present="unknown"
rules_evidence="$(unknown 'grafana unavailable' 'curl /api/ruler/grafana/api/v1/rules')"
provisioning_evidence="unknown"

if [[ "$grafana_ok" == "yes" ]]; then
  ds=$(curl -fsS -u "$GRAFANA_USER:$GRAFANA_PASS" "$GRAFANA_URL/api/search?query=" 2>/dev/null || true)
  if echo "$ds" | rg -q '"uid":"pipeline-health"' && echo "$ds" | rg -q '"uid":"host-container-overview"'; then
    dashboards_present="yes"
  else
    dashboards_present="no"
  fi
  dashboards_evidence='curl -u admin:*** /api/search => pipeline-health, host-container-overview'

  rr=$(curl -fsS -u "$GRAFANA_USER:$GRAFANA_PASS" "$GRAFANA_URL/api/ruler/grafana/api/v1/rules" 2>/dev/null || true)
  if echo "$rr" | rg -q 'logging-e2e-marker-missing' && echo "$rr" | rg -q 'logging-total-ingest-down'; then
    rules_present="yes"
  else
    rules_present="no"
  fi
  rules_evidence='curl -u admin:*** /api/ruler/grafana/api/v1/rules => required UIDs present'

  if echo "$rr" | rg -q '"provenance":"file"'; then
    provisioning_evidence="api"
  else
    provisioning_evidence="none"
  fi
fi

timer_enabled="no"
systemctl is-enabled logging-e2e-check.timer >/dev/null 2>&1 && timer_enabled="yes"

cat > "$MD" <<MD
# State Report — Grafana as Authority ($ts)
- grafana_ok: $grafana_ok (evidence: $grafana_evidence)
- loki_ok: $loki_ok (evidence: curl -fsS http://127.0.0.1:3200/ready => $loki_ok)
- prom_ok: $prom_ok (evidence: curl -fsS http://127.0.0.1:9004/-/healthy => $prom_ok)
- dashboards_present: $dashboards_present (evidence: $dashboards_evidence)
- rules_present: $rules_present (evidence: $rules_evidence)
- provisioning_evidence: $provisioning_evidence (evidence: curl -u admin:*** /api/ruler/grafana/api/v1/rules => provenance=file check)
- timer_enabled: $timer_enabled (evidence: systemctl is-enabled logging-e2e-check.timer => $timer_enabled)
MD

python3 - <<JSON
import json
out = {
  "ts": "$ts",
  "grafana_ok": "$grafana_ok",
  "loki_ok": "$loki_ok",
  "prom_ok": "$prom_ok",
  "dashboards_present": "$dashboards_present",
  "rules_present": "$rules_present",
  "provisioning_evidence": "$provisioning_evidence",
  "timer_enabled": "$timer_enabled",
  "evidence": {
    "grafana": "$grafana_evidence",
    "loki": "curl -fsS http://127.0.0.1:3200/ready",
    "prom": "curl -fsS http://127.0.0.1:9004/-/healthy",
    "dashboards": "$dashboards_evidence",
    "rules": "$rules_evidence"
  }
}
with open("$JS", "w") as f:
  json.dump(out, f, indent=2)
print("WROTE_MD=$MD")
print("WROTE_JSON=$JS")
JSON
