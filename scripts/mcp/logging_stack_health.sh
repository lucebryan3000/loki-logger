#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
ENV_FILE=".env"
OBS="infra/logging/docker-compose.observability.yml"

# shellcheck disable=SC1090
set -a
. "$ENV_FILE"
set +a

export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-infra_observability}"
docker compose --env-file "$ENV_FILE" -f "$OBS" ps

# loopback checks
curl -sf --connect-timeout 5 --max-time 20 "http://${GRAFANA_HOST:-127.0.0.1}:${GRAFANA_PORT:-9001}/api/health" >/dev/null && echo "grafana_ok=1" || { echo "grafana_ok=0"; exit 1; }
curl -sf --connect-timeout 5 --max-time 20 "http://${PROM_HOST:-127.0.0.1}:${PROM_PORT:-9004}/-/ready" | grep -q "Ready" && echo "prometheus_ok=1" || { echo "prometheus_ok=0"; exit 1; }
