#!/usr/bin/env bash
set -euo pipefail
umask 022
source "/home/luce/apps/loki-logging/scripts/prompt-exec/evidence/Loki-prompt-1/20260212T112400Z/env.sh"
if [ -n "${REPO_ROOT:-}" ]; then cd "$REPO_ROOT"; else cd "$PROMPT_DIR"; fi
cd /home/luce/apps/loki-logging
export COMPOSE_PROJECT_NAME=infra_observability

docker compose -f infra/logging/docker-compose.observability.yml ps

curl -sf --connect-timeout 5 --max-time 20 http://127.0.0.1:9001/api/health
curl -sf --connect-timeout 5 --max-time 20 http://127.0.0.1:9004/-/ready

curl -sf --connect-timeout 5 --max-time 20 http://127.0.0.1:9004/api/v1/targets | grep -E '"health":"up"' || true

GRAFANA_CID="$(docker compose -f infra/logging/docker-compose.observability.yml ps -q grafana)"
docker exec "$GRAFANA_CID" wget -qO- http://loki:3100/ready
