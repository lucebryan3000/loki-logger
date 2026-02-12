#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
export COMPOSE_PROJECT_NAME=infra_observability
docker compose -f infra/logging/docker-compose.observability.yml up -d
