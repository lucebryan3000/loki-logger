#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: logging_stack_health.sh

Quick health check for the observability stack.

Checks:
  1. docker compose ps (list running services)
  2. Grafana /api/health endpoint
  3. Prometheus /-/ready endpoint

Output:
  grafana_ok=1|0
  prometheus_ok=1|0

Exit codes:
  0  All checks passed
  1  One or more checks failed

See also:
  logging_stack_audit.sh  Deep audit with JSON report
EOF
  exit 0
fi

ENV_FILE=".env"
OBS="infra/logging/docker compose -p logging.observability.yml"

# shellcheck disable=SC1090
set -a
. "$ENV_FILE"
set +a

export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-logging}"
docker compose --env-file "$ENV_FILE" -f "$OBS" ps

# loopback checks
curl -sf --connect-timeout 5 --max-time 20 "http://${GRAFANA_HOST:-127.0.0.1}:${GRAFANA_PORT:-9001}/api/health" >/dev/null && echo "grafana_ok=1" || { echo "grafana_ok=0"; exit 1; }
curl -sf --connect-timeout 5 --max-time 20 "http://${PROM_HOST:-127.0.0.1}:${PROM_PORT:-9004}/-/ready" | grep -q "Ready" && echo "prometheus_ok=1" || { echo "prometheus_ok=0"; exit 1; }
