#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: logging_stack_down.sh [--purge]

Stop the observability stack.

Default mode keeps data volumes.

Use --purge to destroy all Loki logs, Prometheus metrics, and Grafana
data (dashboards, users). Provisioned dashboards and data sources
will be recreated on next deploy.

Runs:
  default: docker compose down
  purge:   docker compose down -v

See also:
  logging_stack_up.sh     Start the stack
  logging_stack_health.sh Quick health check
EOF
  exit 0
fi

PURGE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --purge)
      PURGE=1
      ;;
    *)
      echo "unknown_arg=$1" >&2
      echo "try: logging_stack_down.sh --help" >&2
      exit 2
      ;;
  esac
  shift
done

ENV_FILE=".env"
OBS="infra/logging/docker-compose.observability.yml"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "missing_env_file=$ENV_FILE" >&2
  exit 1
fi

# shellcheck disable=SC1090
set -a
. "$ENV_FILE"
set +a

export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-logging}"
if [[ "$PURGE" -eq 1 ]]; then
  docker compose -p "$COMPOSE_PROJECT_NAME" --env-file "$ENV_FILE" -f "$OBS" down -v
else
  docker compose -p "$COMPOSE_PROJECT_NAME" --env-file "$ENV_FILE" -f "$OBS" down
fi
