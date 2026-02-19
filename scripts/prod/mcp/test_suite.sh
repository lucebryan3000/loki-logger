#!/usr/bin/env bash
# test_suite.sh — Automated validation of the loki-logging observability stack.
#
# Runs static config checks always; runtime checks only when the stack is up.
# Exit 0 if all tests pass, exit 1 if any FAIL.
#
# Usage: ./test_suite.sh [--help]

set -euo pipefail
set -o noclobber

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
INFRA_DIR="${REPO_ROOT}/infra/logging"
SCRIPTS_MCP="${REPO_ROOT}/scripts/prod/mcp"

# ---------------------------------------------------------------------------
# Optional: source .env for Grafana credentials (runtime auth)
# ---------------------------------------------------------------------------
if [[ -f "${REPO_ROOT}/.env" ]]; then
  # shellcheck source=/dev/null
  set +u
  source "${REPO_ROOT}/.env"
  set -u
fi

GRAFANA_ADMIN_USER="${GRAFANA_ADMIN_USER:-admin}"
GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD:-}"
GRAFANA_PORT="${GRAFANA_PORT:-9001}"
PROM_PORT="${PROM_PORT:-9004}"
LOKI_PORT="${LOKI_PORT:-3200}"

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<EOF
test_suite.sh — Loki-logging observability stack test suite

USAGE
  ./test_suite.sh [--help]

SECTIONS
  1. Static config validation  (always runs; no stack required)
  2. Script shellcheck lint    (runs if shellcheck is installed)
  3. Runtime health checks     (runs only if stack containers are up)

EXIT CODES
  0  All executed tests passed (SKIPs do not count as failures)
  1  One or more tests FAILED

OPTIONS
  --help, -h   Print this message and exit
EOF
  exit 0
fi

# ---------------------------------------------------------------------------
# Counters and color helpers
# ---------------------------------------------------------------------------
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
RESET='\033[0m'

pass() {
  local label="$1"
  PASS_COUNT=$(( PASS_COUNT + 1 ))
  printf "${GREEN}[PASS]${RESET} %s\n" "${label}"
}

fail() {
  local label="$1"
  local detail="${2:-}"
  FAIL_COUNT=$(( FAIL_COUNT + 1 ))
  printf "${RED}[FAIL]${RESET} %s\n" "${label}"
  if [[ -n "${detail}" ]]; then
    printf "       %s\n" "${detail}"
  fi
}

skip() {
  local label="$1"
  local reason="${2:-}"
  SKIP_COUNT=$(( SKIP_COUNT + 1 ))
  printf "${YELLOW}[SKIP]${RESET} %s" "${label}"
  if [[ -n "${reason}" ]]; then
    printf " (%s)" "${reason}"
  fi
  printf "\n"
}

section() {
  printf "\n=== %s ===\n" "$1"
}

# ---------------------------------------------------------------------------
# Helper: grep check with optional "note" semantics (PASS even if missing)
# ---------------------------------------------------------------------------
check_grep() {
  local label="$1"
  local pattern="$2"
  local file="$3"
  local required="${4:-true}"   # "true" = FAIL if missing; "false" = note only

  if [[ ! -f "${file}" ]]; then
    fail "${label}" "file not found: ${file}"
    return
  fi
  if grep -qE "${pattern}" "${file}"; then
    pass "${label}"
  else
    if [[ "${required}" == "true" ]]; then
      fail "${label}" "pattern '${pattern}' not found in ${file}"
    else
      # Treat as a non-blocking note — still PASS, but print note
      pass "${label} (pattern absent — noted)"
    fi
  fi
}

check_file_exists() {
  local label="$1"
  local file="$2"
  if [[ -f "${file}" ]]; then
    pass "${label}"
  else
    fail "${label}" "file not found: ${file}"
  fi
}

# ---------------------------------------------------------------------------
# SECTION 1: Static config validation
# ---------------------------------------------------------------------------
section "Static config validation"

# --- alloy-config.alloy ---
ALLOY_CFG="${INFRA_DIR}/alloy-config.alloy"
check_grep "alloy: loki.write endpoint block present" \
  'loki\.write' "${ALLOY_CFG}"

check_grep "alloy: loki push URL present" \
  'loki/api/v1/push' "${ALLOY_CFG}"

# backoff and external_labels are optional/advisory — note if absent
check_grep "alloy: backoff params present (advisory)" \
  'backoff' "${ALLOY_CFG}" "false"

check_grep "alloy: external_labels present (advisory)" \
  'external_labels' "${ALLOY_CFG}" "false"

# --- loki-config.yml ---
LOKI_CFG="${INFRA_DIR}/loki-config.yml"
check_grep "loki: ingestion_rate_mb present" \
  'ingestion_rate_mb' "${LOKI_CFG}"

check_grep "loki: retention_period present" \
  'retention_period' "${LOKI_CFG}"

check_grep "loki: compactor block present" \
  '^compactor:' "${LOKI_CFG}"

check_grep "loki: auth_enabled setting present" \
  'auth_enabled' "${LOKI_CFG}"

# --- prometheus/prometheus.yml ---
PROM_CFG="${INFRA_DIR}/prometheus/prometheus.yml"
check_grep "prometheus: scrape_interval present" \
  'scrape_interval' "${PROM_CFG}"

check_grep "prometheus: evaluation_interval present" \
  'evaluation_interval' "${PROM_CFG}"

check_grep "prometheus: rule_files entry present" \
  'rule_files' "${PROM_CFG}"

# --- prometheus/rules/loki_logging_rules.yml ---
RULES_CFG="${INFRA_DIR}/prometheus/rules/loki_logging_rules.yml"
check_grep "prometheus rules: recording rules present (record:)" \
  '^\s+- record:' "${RULES_CFG}"

check_grep "prometheus rules: alerting rules present (alert:)" \
  '^\s+- alert:' "${RULES_CFG}"

# ADR-146: 'or vector(0)' pattern guards recording rules against no-data gaps.
# Absence is noted but not a hard failure (rules work without it).
check_grep "prometheus rules: ADR-146 'or vector(0)' guard present (advisory)" \
  'or vector\(0\)' "${RULES_CFG}" "false"

# --- grafana/provisioning/alerting/logging-pipeline-rules.yml ---
ALERT_CFG="${INFRA_DIR}/grafana/provisioning/alerting/logging-pipeline-rules.yml"
check_grep "grafana alerting: noDataState present" \
  'noDataState' "${ALERT_CFG}"

check_grep "grafana alerting: for: duration present" \
  '^        for:' "${ALERT_CFG}"

# --- .env.example required keys ---
ENV_EXAMPLE="${REPO_ROOT}/.env.example"
check_grep "env.example: GRAFANA_ADMIN_USER key present" \
  'GRAFANA_ADMIN_USER' "${ENV_EXAMPLE}"

check_grep "env.example: GRAFANA_ADMIN_PASSWORD key present" \
  'GRAFANA_ADMIN_PASSWORD' "${ENV_EXAMPLE}"

check_grep "env.example: GRAFANA_SECRET_KEY key present" \
  'GRAFANA_SECRET_KEY' "${ENV_EXAMPLE}"

# --- docker-compose.observability.yml: all 6 services ---
COMPOSE_FILE="${INFRA_DIR}/docker-compose.observability.yml"
for svc in grafana loki prometheus alloy host-monitor docker-metrics; do
  check_grep "compose: service '${svc}' defined" \
    "^  ${svc}:" "${COMPOSE_FILE}"
done

# --- Backup/restore scripts exist ---
check_file_exists "scripts: backup_volumes.sh exists" \
  "${SCRIPTS_MCP}/backup_volumes.sh"

check_file_exists "scripts: restore_volumes.sh exists" \
  "${SCRIPTS_MCP}/restore_volumes.sh"

# ---------------------------------------------------------------------------
# SECTION 2: Script shellcheck lint
# ---------------------------------------------------------------------------
section "Script shellcheck lint"

if ! command -v shellcheck &>/dev/null; then
  skip "shellcheck lint of scripts/prod/mcp/" "shellcheck not installed"
else
  SHELLCHECK_FAILED=0
  while IFS= read -r -d '' script_file; do
    label="shellcheck: $(basename "${script_file}")"
    sc_output="$(shellcheck --shell=bash --severity=warning "${script_file}" 2>&1)" || true
    if [[ -z "${sc_output}" ]]; then
      pass "${label}"
    else
      fail "${label}" "${sc_output}"
      SHELLCHECK_FAILED=$(( SHELLCHECK_FAILED + 1 ))
    fi
  done < <(find "${SCRIPTS_MCP}" -maxdepth 1 -name "*.sh" -print0)
fi

# ---------------------------------------------------------------------------
# SECTION 3: Runtime checks (only if stack is up)
# ---------------------------------------------------------------------------
section "Runtime health checks"

# Detect whether stack containers are running
STACK_UP=false
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q 'logging-grafana-1'; then
  STACK_UP=true
fi

if [[ "${STACK_UP}" != "true" ]]; then
  skip "Grafana health endpoint" "stack not running"
  skip "Prometheus ready endpoint" "stack not running"
  skip "Loki ready endpoint" "stack not running"
  skip "Prometheus targets up (count >= 6)" "stack not running"
  skip "Loki env label present" "stack not running"
  skip "Grafana dashboard count (>= 20)" "stack not running"
else
  GRAFANA_BASE="http://127.0.0.1:${GRAFANA_PORT}"
  PROM_BASE="http://127.0.0.1:${PROM_PORT}"
  LOKI_BASE="http://127.0.0.1:${LOKI_PORT}"

  # Grafana health
  label="Grafana health endpoint (${GRAFANA_BASE}/api/health)"
  if curl -sf "${GRAFANA_BASE}/api/health" &>/dev/null; then
    pass "${label}"
  else
    fail "${label}" "curl returned non-zero; Grafana may be starting or misconfigured"
  fi

  # Prometheus ready
  label="Prometheus ready endpoint (${PROM_BASE}/-/ready)"
  if curl -sf "${PROM_BASE}/-/ready" &>/dev/null; then
    pass "${label}"
  else
    fail "${label}" "Prometheus not ready"
  fi

  # Loki ready
  label="Loki ready endpoint (${LOKI_BASE}/ready)"
  if curl -sf "${LOKI_BASE}/ready" &>/dev/null; then
    pass "${label}"
  else
    fail "${label}" "Loki not ready"
  fi

  # Prometheus targets up: expect >= 6
  label="Prometheus targets up (count >= 6)"
  UP_RESULT="$(curl -sf "${PROM_BASE}/api/v1/query?query=up" 2>/dev/null)" || UP_RESULT=""
  if [[ -n "${UP_RESULT}" ]]; then
    UP_COUNT="$(printf '%s' "${UP_RESULT}" | python3 -c \
      "import sys,json; d=json.load(sys.stdin); print(len(d.get('data',{}).get('result',[])))" 2>/dev/null)" || UP_COUNT=0
    if [[ "${UP_COUNT}" -ge 6 ]]; then
      pass "${label} (found ${UP_COUNT})"
    else
      fail "${label}" "found ${UP_COUNT} targets, expected >= 6"
    fi
  else
    fail "${label}" "could not query Prometheus /api/v1/query"
  fi

  # Loki labels: confirm env label
  label="Loki env label present"
  LOKI_LABELS="$(curl -sf "${LOKI_BASE}/loki/api/v1/labels" 2>/dev/null)" || LOKI_LABELS=""
  if [[ -n "${LOKI_LABELS}" ]]; then
    if printf '%s' "${LOKI_LABELS}" | python3 -c \
        "import sys,json; d=json.load(sys.stdin); assert 'env' in d.get('data',[])" 2>/dev/null; then
      pass "${label}"
    else
      fail "${label}" "env label not found in Loki labels response"
    fi
  else
    fail "${label}" "could not query Loki /loki/api/v1/labels"
  fi

  # Grafana dashboard count >= 20
  label="Grafana dashboard count (>= 20)"
  GRAFANA_AUTH="${GRAFANA_ADMIN_USER}:${GRAFANA_ADMIN_PASSWORD}"
  if [[ -z "${GRAFANA_ADMIN_PASSWORD}" ]]; then
    skip "${label}" "GRAFANA_ADMIN_PASSWORD not set; source .env to enable"
  else
    DASH_RESULT="$(curl -sf -u "${GRAFANA_AUTH}" "${GRAFANA_BASE}/api/search?type=dash-db" 2>/dev/null)" || DASH_RESULT=""
    if [[ -n "${DASH_RESULT}" ]]; then
      DASH_COUNT="$(printf '%s' "${DASH_RESULT}" | python3 -c \
        "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null)" || DASH_COUNT=0
      if [[ "${DASH_COUNT}" -ge 20 ]]; then
        pass "${label} (found ${DASH_COUNT})"
      else
        fail "${label}" "found ${DASH_COUNT} dashboards, expected >= 20"
      fi
    else
      fail "${label}" "could not query Grafana /api/search"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
TOTAL=$(( PASS_COUNT + FAIL_COUNT + SKIP_COUNT ))
printf "\n--- Summary ---\n"
printf "Total: %d  |  " "${TOTAL}"
printf "${GREEN}Passed: %d${RESET}  |  " "${PASS_COUNT}"
printf "${RED}Failed: %d${RESET}  |  " "${FAIL_COUNT}"
printf "${YELLOW}Skipped: %d${RESET}\n" "${SKIP_COUNT}"

if [[ "${FAIL_COUNT}" -gt 0 ]]; then
  exit 1
fi
exit 0
