#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
ENV_FILE=".env"
OBS="infra/logging/docker-compose.observability.yml"

# shellcheck disable=SC1090
set -a
. "$ENV_FILE"
set +a

export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-logging}"
docker compose --env-file "$ENV_FILE" -f "$OBS" down -v
