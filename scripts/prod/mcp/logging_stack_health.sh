#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../../.."

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: logging_stack_health.sh

Native quick health check for the observability stack.

Checks:
  1. docker compose service status (canonical project/file)
  2. Grafana /api/health (database=ok)
  3. Prometheus /-/ready
  4. Prometheus /api/v1/targets (all active targets up)
  5. Loki /ready via container exec

Output:
  grafana_ok=1|0
  prometheus_ready_ok=1|0
  prometheus_targets_ok=1|0
  loki_ready_ok=1|0
  overall=pass|fail

Exit codes:
  0  All checks passed
  1  One or more checks failed
EOF
  exit 0
fi

OBS="infra/logging/docker-compose.observability.yml"
PROJECT="${COMPOSE_PROJECT_NAME:-logging}"

test -f "$OBS"
command -v docker >/dev/null
command -v curl >/dev/null
command -v python3 >/dev/null

docker compose -p "$PROJECT" -f "$OBS" ps

ok=1

if curl -sf --connect-timeout 5 --max-time 20 "http://127.0.0.1:9001/api/health" \
  | python3 -c 'import json,sys; obj=json.load(sys.stdin); raise SystemExit(0 if str(obj.get("database","")).lower()=="ok" else 1)'; then
  echo "grafana_ok=1"
else
  echo "grafana_ok=0"
  ok=0
fi

if curl -sf --connect-timeout 5 --max-time 20 "http://127.0.0.1:9004/-/ready" | rg -q "Ready"; then
  echo "prometheus_ready_ok=1"
else
  echo "prometheus_ready_ok=0"
  ok=0
fi

if curl -sf --connect-timeout 5 --max-time 20 "http://127.0.0.1:9004/api/v1/targets" \
  | python3 -c 'import json,sys; obj=json.load(sys.stdin); data=obj.get("data",{}).get("activeTargets",[]); bad=[t for t in data if t.get("health")!="up"]; raise SystemExit(0 if obj.get("status")=="success" and len(data)>0 and not bad else 1)'; then
  echo "prometheus_targets_ok=1"
else
  echo "prometheus_targets_ok=0"
  ok=0
fi

LOKI_CID="$(docker compose -p "$PROJECT" -f "$OBS" ps -q loki)"
if [[ -n "$LOKI_CID" ]] && docker exec "$LOKI_CID" sh -lc 'wget -qO- http://127.0.0.1:3100/ready' | rg -qi '^ready$'; then
  echo "loki_ready_ok=1"
else
  echo "loki_ready_ok=0"
  ok=0
fi

if [[ "$ok" -eq 1 ]]; then
  echo "overall=pass"
  exit 0
fi

echo "overall=fail"
exit 1
