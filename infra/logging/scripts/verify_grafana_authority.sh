#!/usr/bin/env bash
set -euo pipefail

GRAFANA_URL="${GRAFANA_URL:-http://127.0.0.1:9001}"
GRAFANA_USER="${GRAFANA_USER:-admin}"
LOKI_READY="${LOKI_READY:-http://127.0.0.1:3200/ready}"
PROM_HEALTHY="${PROM_HEALTHY:-http://127.0.0.1:9004/-/healthy}"
ART_DIR="/home/luce/apps/loki-logging/_build/logging"
ART_PATH="$ART_DIR/verify_grafana_authority_latest.json"

mkdir -p "$ART_DIR"

CHECK_LOKI=0
CHECK_PROM=0
CHECK_E2E=0
CHECK_RULES=0
CHECK_TIMER=0

write_artifact() {
  local pass_flag="$1"
  python3 - <<PY
import json, time
out={
  "ts_utc": int(time.time()),
  "pass": bool(int($pass_flag)),
  "checks": {
    "loki_ready": bool(int($CHECK_LOKI)),
    "prom_healthy": bool(int($CHECK_PROM)),
    "e2e_pass": bool(int($CHECK_E2E)),
    "grafana_rules_present": bool(int($CHECK_RULES)),
    "timer_freshness_ok": bool(int($CHECK_TIMER))
  }
}
with open("$ART_PATH","w") as f:
  json.dump(out,f,indent=2)
print("ARTIFACT_WRITTEN=$ART_PATH")
PY
}

pass_msg() { echo "PASS: $*"; }
fail_msg() {
  echo "FAIL: $*" >&2
  write_artifact 0
  exit 2
}

curl -fsS "$LOKI_READY" >/dev/null || fail_msg "Loki not ready"
CHECK_LOKI=1
pass_msg "Loki ready"

curl -fsS "$PROM_HEALTHY" >/dev/null || fail_msg "Prometheus not healthy"
CHECK_PROM=1
pass_msg "Prometheus healthy"

sudo /usr/local/bin/logging-e2e-check.sh >/tmp/logging-e2e.out 2>&1 || { cat /tmp/logging-e2e.out >&2; fail_msg "E2E script failed"; }
rg -q "PASS: marker found in Loki" /tmp/logging-e2e.out || { cat /tmp/logging-e2e.out >&2; fail_msg "E2E marker not found"; }
CHECK_E2E=1
pass_msg "E2E marker found in Loki"

if journalctl -u logging-e2e-check.service --since "2 hours ago" --no-pager 2>/dev/null | rg -q "PASS: marker found in Loki"; then
  CHECK_TIMER=1
  pass_msg "E2E timer freshness OK (PASS within 2h)"
else
  fail_msg "E2E timer freshness FAIL (no PASS within 2h)"
fi

if [ -z "${GRAFANA_PASS:-}" ]; then
  GRAFANA_PASS="$(docker inspect logging-grafana-1 --format "{{range .Config.Env}}{{println .}}{{end}}" | rg "^GF_SECURITY_ADMIN_PASSWORD=" | sed "s/^GF_SECURITY_ADMIN_PASSWORD=//")"
fi
[ -n "${GRAFANA_PASS:-}" ] || fail_msg "Grafana auth missing"

rules_json=$(curl -fsS -u "${GRAFANA_USER}:${GRAFANA_PASS}" "$GRAFANA_URL/api/ruler/grafana/api/v1/rules" || true)
echo "$rules_json" | rg -q "logging-e2e-marker-missing" || fail_msg "Grafana rule UID missing: logging-e2e-marker-missing"
echo "$rules_json" | rg -q "logging-total-ingest-down" || fail_msg "Grafana rule UID missing: logging-total-ingest-down"
CHECK_RULES=1
pass_msg "Grafana alert rule UIDs present"

if curl -fsS "$GRAFANA_URL/api/health" >/dev/null; then
  pass_msg "Grafana API reachable"
else
  echo "WARN: Grafana API /api/health not reachable without auth (expected in some setups)" >&2
fi

write_artifact 1

echo "EVIDENCE (last 40 lines of E2E):"
tail -n 40 /tmp/logging-e2e.out
