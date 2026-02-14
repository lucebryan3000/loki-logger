#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: validate_env.sh [--example] [env-path]

Validate an .env file for the observability stack.

Arguments:
  --example   Skip secret-value checks (allow CHANGE_ME placeholders).
              Use this to validate .env.example files.
  env-path    Path to .env file (default: .env)

Validates:
  - Required keys present and non-empty:
    GRAFANA_HOST, GRAFANA_PORT, PROM_HOST, PROM_PORT,
    COMPOSE_PROJECT_NAME, HOST_HOME, HOST_LOGS, HOST_TELEMETRY,
    HOST_VLLM, GRAFANA_ADMIN_USER, GRAFANA_ADMIN_PASSWORD,
    GRAFANA_SECRET_KEY, GF_SECURITY_*
  - Port values are valid (1-65535)
  - Host paths are absolute (start with /)
  - Secrets are not placeholder values (skipped with --example)

Exit codes:
  0  Validation passed
  1  Validation failed (details on stderr)

Examples:
  validate_env.sh                   Validate .env
  validate_env.sh .env.example      Validate example file (fails on CHANGE_ME)
  validate_env.sh --example .env.example  Validate structure only
EOF
  exit 0
fi

MODE="local"
if [[ "${1:-}" == "--example" ]]; then
  MODE="example"
  shift
fi

ENV_PATH="${1:-.env}"

if [[ ! -f "$ENV_PATH" ]]; then
  echo "env_validate=fail reason=missing_env path=$ENV_PATH" >&2
  exit 1
fi

# shellcheck disable=SC1090
set -a
. "$ENV_PATH"
set +a

required_keys=(
  GRAFANA_HOST
  GRAFANA_PORT
  PROM_HOST
  PROM_PORT
  COMPOSE_PROJECT_NAME
  HOST_HOME
  HOST_LOGS
  HOST_TELEMETRY
  HOST_VLLM
  GRAFANA_ADMIN_USER
  GRAFANA_ADMIN_PASSWORD
  GRAFANA_SECRET_KEY
  GF_SECURITY_ADMIN_USER
  GF_SECURITY_ADMIN_PASSWORD
  GF_SECURITY_SECRET_KEY
)

fail_count=0

for key in "${required_keys[@]}"; do
  val="${!key-}"
  if [[ -z "$val" ]]; then
    echo "missing_or_empty=$key" >&2
    fail_count=$((fail_count + 1))
  fi
done

is_valid_port() {
  local p="$1"
  [[ "$p" =~ ^[0-9]+$ ]] || return 1
  (( p >= 1 && p <= 65535 ))
}

if ! is_valid_port "${GRAFANA_PORT:-}"; then
  echo "invalid_port=GRAFANA_PORT" >&2
  fail_count=$((fail_count + 1))
fi
if ! is_valid_port "${PROM_PORT:-}"; then
  echo "invalid_port=PROM_PORT" >&2
  fail_count=$((fail_count + 1))
fi

for pkey in HOST_HOME HOST_LOGS HOST_TELEMETRY HOST_VLLM; do
  pval="${!pkey-}"
  if [[ -n "$pval" && "$pval" != /* ]]; then
    echo "path_not_absolute=$pkey" >&2
    fail_count=$((fail_count + 1))
  fi
done

if [[ "$MODE" == "local" ]]; then
  if [[ "${GRAFANA_ADMIN_PASSWORD:-}" == "CHANGE_ME" || "${GRAFANA_ADMIN_PASSWORD:-}" == "" ]]; then
    echo "invalid_secret=GRAFANA_ADMIN_PASSWORD" >&2
    fail_count=$((fail_count + 1))
  fi
  if [[ "${GRAFANA_SECRET_KEY:-}" == "CHANGE_ME" || "${GRAFANA_SECRET_KEY:-}" == "" ]]; then
    echo "invalid_secret=GRAFANA_SECRET_KEY" >&2
    fail_count=$((fail_count + 1))
  fi
  if [[ "${GF_SECURITY_ADMIN_PASSWORD:-}" == "CHANGE_ME" || "${GF_SECURITY_ADMIN_PASSWORD:-}" == "" ]]; then
    echo "invalid_secret=GF_SECURITY_ADMIN_PASSWORD" >&2
    fail_count=$((fail_count + 1))
  fi
  if [[ "${GF_SECURITY_SECRET_KEY:-}" == "CHANGE_ME" || "${GF_SECURITY_SECRET_KEY:-}" == "" ]]; then
    echo "invalid_secret=GF_SECURITY_SECRET_KEY" >&2
    fail_count=$((fail_count + 1))
  fi
fi

if (( fail_count > 0 )); then
  echo "env_validate=fail path=$ENV_PATH mode=$MODE fail_count=$fail_count" >&2
  exit 1
fi

echo "env_validate=ok path=$ENV_PATH mode=$MODE"
