#!/usr/bin/env bash
set -euo pipefail

GRAFANA_URL="${GRAFANA_URL:-http://127.0.0.1:9001}"
LOKI_READY="${LOKI_READY:-http://127.0.0.1:3200/ready}"
PROM_HEALTHY="${PROM_HEALTHY:-http://127.0.0.1:9004/-/healthy}"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 2; }

curl -fsS "$LOKI_READY" >/dev/null && pass "Loki ready" || fail "Loki not ready"
curl -fsS "$PROM_HEALTHY" >/dev/null && pass "Prometheus healthy" || fail "Prometheus not healthy"

sudo /usr/local/bin/logging-e2e-check.sh >/tmp/logging-e2e.out 2>&1 || {
  cat /tmp/logging-e2e.out >&2
  fail "E2E script failed"
}
rg -q "PASS: marker found in Loki" /tmp/logging-e2e.out && pass "E2E marker found in Loki" || {
  cat /tmp/logging-e2e.out >&2
  fail "E2E marker not found"
}

if curl -fsS "$GRAFANA_URL/api/health" >/dev/null; then
  pass "Grafana API reachable"
else
  echo "WARN: Grafana API /api/health not reachable without auth (expected in some setups)" >&2
fi

echo "EVIDENCE (last 40 lines of E2E):"
tail -n 40 /tmp/logging-e2e.out
