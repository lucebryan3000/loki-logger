#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: logging_stack_up.sh

Start the observability stack (Grafana, Loki, Prometheus, Alloy,
Node Exporter, cAdvisor). Validates .env before deploying.

Steps:
  1. Validates .env via validate_env.sh
  2. Sources .env to export variables
  3. Runs docker compose up -d

Requires:
  .env file at repo root with valid credentials and paths
  Docker and Docker Compose v2

See also:
  logging_stack_down.sh   Stop the stack
  logging_stack_health.sh Quick health check
EOF
  exit 0
fi

ENV_FILE=".env"
OBS="infra/logging/docker-compose.observability.yml"

scripts/prod/mcp/validate_env.sh "$ENV_FILE"

# shellcheck disable=SC1090
set -a
. "$ENV_FILE"
set +a

export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-logging}"
docker compose --env-file "$ENV_FILE" -f "$OBS" up -d
