#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: logging_stack_up.sh

Start the observability stack (Grafana, Loki, Prometheus, Alloy,
Node Exporter, cAdvisor). Validates .env and core configs before deploying.

Steps:
  1. Validates .env via validate_env.sh
  2. Renders compose config (`docker compose ... config`)
  3. Validates Loki config (`loki -verify-config=true`)
  4. Validates Alloy config (containerized startup parse gate)
  5. Runs docker compose up -d

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
ALLOY_CFG="infra/logging/alloy-config.alloy"
LOKI_CFG="infra/logging/loki-config.yml"

scripts/prod/mcp/validate_env.sh "$ENV_FILE"

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-logging}"

command -v docker >/dev/null
command -v timeout >/dev/null

# Preflight 1: compose config render
docker compose -p "$COMPOSE_PROJECT_NAME" --env-file "$ENV_FILE" -f "$OBS" config >/dev/null

# Preflight 2: Loki config validation (fail closed on invalid keys/values)
LOKI_IMAGE="${LOKI_IMAGE:-grafana/loki:3.0.0}"
docker run --rm \
  -v "$PWD/$LOKI_CFG:/etc/loki/loki-config.yml:ro" \
  "$LOKI_IMAGE" \
  -config.file=/etc/loki/loki-config.yml \
  -verify-config=true >/dev/null

# Preflight 3: Alloy config parse gate.
# `alloy run` exits immediately on config errors; a healthy run is bounded by timeout.
ALLOY_IMAGE="${ALLOY_IMAGE:-grafana/alloy:v1.2.1}"
alloy_preflight_log="$(mktemp)"
set +e
timeout 8s docker run --rm \
  -v "$PWD/$ALLOY_CFG:/etc/alloy/config.alloy:ro" \
  "$ALLOY_IMAGE" \
  run \
  --server.http.listen-addr=127.0.0.1:12345 \
  /etc/alloy/config.alloy >"$alloy_preflight_log" 2>&1
alloy_ec=$?
set -e
if [[ "$alloy_ec" -ne 0 && "$alloy_ec" -ne 124 ]]; then
  echo "alloy_preflight=fail" >&2
  sed -n '1,40p' "$alloy_preflight_log" >&2
  rm -f "$alloy_preflight_log"
  exit 1
fi
rm -f "$alloy_preflight_log"

docker compose -p "$COMPOSE_PROJECT_NAME" --env-file "$ENV_FILE" -f "$OBS" up -d
