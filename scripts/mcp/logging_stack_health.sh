#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
export COMPOSE_PROJECT_NAME=infra_observability

docker compose -f infra/logging/docker-compose.observability.yml ps

# loopback checks
curl -sf --connect-timeout 5 --max-time 20 http://127.0.0.1:9001/api/health >/dev/null && echo "grafana_ok=1" || { echo "grafana_ok=0"; exit 1; }
curl -sf --connect-timeout 5 --max-time 20 http://127.0.0.1:9004/-/ready | grep -q "Ready" && echo "prometheus_ok=1" || { echo "prometheus_ok=0"; exit 1; }
