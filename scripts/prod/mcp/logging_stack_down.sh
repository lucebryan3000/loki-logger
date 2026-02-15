#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: logging_stack_down.sh

Stop the observability stack and remove all volumes.

WARNING: This destroys all Loki logs, Prometheus metrics, and Grafana
data (dashboards, users). Provisioned dashboards and data sources
will be recreated on next deploy.

Runs: docker compose down -v

See also:
  logging_stack_up.sh     Start the stack
  logging_stack_health.sh Quick health check
EOF
  exit 0
fi

ENV_FILE=".env"
OBS="infra/logging/docker-compose.observability.yml"

# shellcheck disable=SC1090
set -a
. "$ENV_FILE"
set +a

export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-logging}"
docker compose -p "$COMPOSE_PROJECT_NAME" --env-file "$ENV_FILE" -f "$OBS" down -v
