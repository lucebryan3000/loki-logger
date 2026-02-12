#!/usr/bin/env bash
set -euo pipefail
umask 022
source "/home/luce/apps/loki-logging/scripts/prompt-exec/evidence/Loki-prompt-1/20260212T112400Z/env.sh"
if [ -n "${REPO_ROOT:-}" ]; then cd "$REPO_ROOT"; else cd "$PROMPT_DIR"; fi
set -euo pipefail
cd /home/luce/apps/loki-logging
export COMPOSE_PROJECT_NAME=infra_observability

docker compose -f infra/logging/docker-compose.observability.yml pull | tee "$EVID/docker_pull.txt"
docker compose -f infra/logging/docker-compose.observability.yml up -d | tee "$EVID/docker_up.txt"

docker compose -f infra/logging/docker-compose.observability.yml ps | tee "$EVID/compose_ps.txt"

# Wait for loopback endpoints
for i in $(seq 1 60); do
  if curl -sf --connect-timeout 5 --max-time 20 http://127.0.0.1:9001/api/health >/dev/null && curl -sf --connect-timeout 5 --max-time 20 http://127.0.0.1:9004/-/ready | grep -q "Ready"; then
    echo "ready=1 after ${i}s" | tee "$EVID/ready_wait.txt"
    break
  fi
  sleep 1
done
test -f "$EVID/ready_wait.txt" || { echo "FAIL: services not ready within 60s"; exit 1; }

# Prometheus targets (record response)
curl -sf --connect-timeout 5 --max-time 20 "http://127.0.0.1:9004/api/v1/targets" | tee "$EVID/prom_targets.json" >/dev/null

# Loki readiness from inside the network
GRAFANA_CID="$(docker compose -f infra/logging/docker-compose.observability.yml ps -q grafana)"
docker exec "$GRAFANA_CID" wget -qO- http://loki:3100/ready | tee "$EVID/loki_ready.txt"

# Stimulate at least one docker log line (local) by writing to /home/luce/_logs and waiting for tail ship
echo "{\"ts\":\"$(date -u --iso-8601=seconds)\",\"source\":\"smoke\",\"msg\":\"loki-logging v1 smoke\"}" >> /home/luce/_logs/loki-logging-smoke.log
sleep 5

# Query Loki for the smoke line (from inside grafana container)
docker exec "$GRAFANA_CID" wget -qO- \
  --post-data='{"query":"{env=\"sandbox\"} |= \"loki-logging v1 smoke\"","limit":20,"direction":"BACKWARD"}' \
  --header='Content-Type: application/json' \
  http://loki:3100/loki/api/v1/query | tee "$EVID/loki_query_smoke.json" >/dev/null

# Record logs (last 200 lines) for debugging (no secrets expected in logs)
for svc in grafana loki prometheus alloy node_exporter cadvisor; do
  CID="$(docker compose -f infra/logging/docker-compose.observability.yml ps -q "$svc")"
  echo "=== $svc ===" >> "$EVID/container_logs_tail.txt"
  docker logs --tail 200 "$CID" >> "$EVID/container_logs_tail.txt" 2>&1 || true
done
