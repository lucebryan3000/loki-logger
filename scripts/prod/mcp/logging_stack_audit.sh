#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: logging_stack_audit.sh [output-path]

Deep health audit of the observability stack. Produces a structured
JSON report with pass/fail/warn results for each check.

Arguments:
  output-path   Where to write JSON report
                (default: temp/codex/monitoring/health-<timestamp>.json)

Checks (8 categories):
  1. Compose services running (all 6 required)
  2. Endpoint readiness (Grafana, Prometheus, Loki)
  3. Prometheus targets and up query
  4. Retention flags and rule groups
  5. Compose and promtool config validation
  6. End-to-end ingest proof via Loki query
  7. Container restart counters and disk free space
  8. UFW firewall status

Requires: jq, docker, curl

Exit codes:
  0  All critical checks passed
  1  One or more critical checks failed
  2  Missing dependencies (jq)

Output format:
  { timestamp_utc, project, overall, summary: {total,pass,warn,fail}, checks: [...] }

See also:
  logging_stack_health.sh  Quick health check (faster, fewer checks)
EOF
  exit 0
fi

export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-logging}"
OBS="infra/logging/docker-compose.observability.yml"
ENV_FILE=".env"

# shellcheck disable=SC1090
set -a
. "$ENV_FILE"
set +a

OUT="${1:-temp/codex/monitoring/health-$(date -u +%Y%m%dT%H%M%SZ).json}"
mkdir -p "$(dirname "$OUT")"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 2
fi

CHECKS_NDJSON="$(mktemp)"
trap 'rm -f "$CHECKS_NDJSON"' EXIT

add_result() {
  local name="$1" status="$2" severity="$3" detail="$4"
  jq -nc \
    --arg name "$name" \
    --arg status "$status" \
    --arg severity "$severity" \
    --arg detail "$detail" \
    '{name:$name,status:$status,severity:$severity,detail:$detail}' >> "$CHECKS_NDJSON"
}

pass() { add_result "$1" pass "$2" "$3"; }
fail() { add_result "$1" fail "$2" "$3"; }
warn() { add_result "$1" warn "$2" "$3"; }

required_services=(grafana loki prometheus alloy host-monitor docker-metrics)

# 1) Compose services running
running_services="$(docker compose --env-file "$ENV_FILE" -f "$OBS" ps --services --status running | sort || true)"
missing=()
for s in "${required_services[@]}"; do
  if ! grep -qx "$s" <<<"$running_services"; then
    missing+=("$s")
  fi
done
if (( ${#missing[@]} == 0 )); then
  pass compose_services_running critical "all required services are running"
else
  fail compose_services_running critical "missing running services: ${missing[*]}"
fi

# 2) Endpoint readiness
if curl -sf --connect-timeout 5 --max-time 20 "http://${GRAFANA_HOST:-127.0.0.1}:${GRAFANA_PORT:-9001}/api/health" >/dev/null; then
  pass grafana_api_health critical "grafana health endpoint ok"
else
  fail grafana_api_health critical "grafana health endpoint failed"
fi

if curl -sf --connect-timeout 5 --max-time 20 "http://${PROM_HOST:-127.0.0.1}:${PROM_PORT:-9004}/-/ready" | grep -q 'Ready'; then
  pass prometheus_ready critical "prometheus ready endpoint ok"
else
  fail prometheus_ready critical "prometheus ready endpoint failed"
fi

if docker run --rm --network obs curlimages/curl:8.6.0 -sf 'http://loki:3100/ready' >/dev/null; then
  pass loki_ready critical "loki ready endpoint ok"
else
  fail loki_ready critical "loki ready endpoint failed"
fi

# 3) Prometheus targets and up query
targets_json="$(mktemp)"
if curl -sf --connect-timeout 5 --max-time 20 "http://${PROM_HOST:-127.0.0.1}:${PROM_PORT:-9004}/api/v1/targets" > "$targets_json"; then
  bad_targets="$(jq -r '.data.activeTargets[] | select(.health!="up") | .labels.job' "$targets_json" | sort -u)"
  if [[ -z "$bad_targets" ]]; then
    pass prometheus_targets critical "all active targets are up"
  else
    fail prometheus_targets critical "unhealthy targets: $(tr '\n' ' ' <<<"$bad_targets")"
  fi
else
  fail prometheus_targets critical "unable to fetch /api/v1/targets"
fi

up_json="$(mktemp)"
if curl -sfG --connect-timeout 5 --max-time 20 "http://${PROM_HOST:-127.0.0.1}:${PROM_PORT:-9004}/api/v1/query" --data-urlencode 'query=up' > "$up_json"; then
  down_jobs="$(jq -r '.data.result[] | select(.value[1] != "1") | .metric.job' "$up_json" | sort -u)"
  if [[ -z "$down_jobs" ]]; then
    pass prometheus_up_query critical "all up metrics are 1"
  else
    fail prometheus_up_query critical "jobs with up!=1: $(tr '\n' ' ' <<<"$down_jobs")"
  fi
else
  fail prometheus_up_query critical "unable to execute up query"
fi

# 4) Retention + rules
flags_json="$(mktemp)"
if curl -sf --connect-timeout 5 --max-time 20 "http://${PROM_HOST:-127.0.0.1}:${PROM_PORT:-9004}/api/v1/status/flags" > "$flags_json"; then
  retention="$(jq -r '.data["storage.tsdb.retention.time"] // ""' "$flags_json")"
  if [[ "$retention" == "15d" ]]; then
    pass prometheus_retention critical "retention flag is 15d"
  else
    fail prometheus_retention critical "unexpected retention: ${retention:-missing}"
  fi
else
  fail prometheus_retention critical "unable to fetch /api/v1/status/flags"
fi

rules_json="$(mktemp)"
if curl -sf --connect-timeout 5 --max-time 20 "http://${PROM_HOST:-127.0.0.1}:${PROM_PORT:-9004}/api/v1/rules" > "$rules_json"; then
  groups="$(jq -r '.data.groups | length' "$rules_json")"
  if [[ "$groups" =~ ^[0-9]+$ ]] && (( groups > 0 )); then
    pass prometheus_rules warning "rule groups loaded: $groups"
  else
    warn prometheus_rules warning "no rule groups loaded"
  fi
else
  warn prometheus_rules warning "unable to fetch /api/v1/rules"
fi

# 5) Config lint
if docker compose --env-file "$ENV_FILE" -f "$OBS" config >/dev/null; then
  pass compose_config_valid critical "docker compose config is valid"
else
  fail compose_config_valid critical "docker compose config failed"
fi

prom_image="$(sed -nE 's/^[[:space:]]*image:[[:space:]]*(prom\/prometheus:[^[:space:]]+).*/\1/p' "$OBS" | head -n1 || true)"
[[ -n "$prom_image" ]] || prom_image='prom/prometheus:latest'
if docker run --rm --entrypoint /bin/promtool -v "$PWD/infra/logging/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro" "$prom_image" check config /etc/prometheus/prometheus.yml >/dev/null 2>&1; then
  pass promtool_config_valid critical "promtool syntax check passed"
else
  fail promtool_config_valid critical "promtool syntax check failed"
fi

# 6) Ingest proof (warning severity if path unavailable)
proof_line="healthproof-$(date -u +%Y%m%dT%H%M%SZ)"
proof_file="${HOST_VLLM:-/home/luce/apps/vLLM}/_data/mcp-logs/mcp-test.log"
if [[ -w "$proof_file" ]]; then
  echo "$proof_line" >> "$proof_file"
  sleep 3
  now_ns="$(date +%s%N)"
  from_ns="$((now_ns - 15*60*1000000000))"
  proof_json="$(mktemp)"
  if docker run --rm --network obs curlimages/curl:8.6.0 -sfG \
      --data-urlencode "query={env=~\".+\",log_source=\"codeswarm_mcp\"} |= \"${proof_line}\"" \
      --data-urlencode "start=${from_ns}" \
      --data-urlencode "end=${now_ns}" \
      --data-urlencode 'limit=20' \
      --data-urlencode 'direction=BACKWARD' \
      'http://loki:3100/loki/api/v1/query_range' > "$proof_json"; then
    matches="$(jq -r '.data.result | length' "$proof_json")"
    if [[ "$matches" =~ ^[0-9]+$ ]] && (( matches > 0 )); then
      pass loki_ingest_proof critical "ingest proof found matches=$matches"
    else
      fail loki_ingest_proof critical "ingest proof not found"
    fi
  else
    fail loki_ingest_proof critical "loki query for ingest proof failed"
  fi
else
  warn loki_ingest_proof warning "proof file not writable: $proof_file"
fi

# 7) Restart counters + disk
restart_nonzero=""
for c in \
  "${COMPOSE_PROJECT_NAME}-grafana-1" \
  "${COMPOSE_PROJECT_NAME}-prometheus-1" \
  "${COMPOSE_PROJECT_NAME}-loki-1" \
  "${COMPOSE_PROJECT_NAME}-alloy-1" \
  "${COMPOSE_PROJECT_NAME}-host-monitor-1" \
  "${COMPOSE_PROJECT_NAME}-docker-metrics-1"; do
  rc="$(docker inspect -f '{{.RestartCount}}' "$c" 2>/dev/null || echo "-1")"
  if [[ "$rc" =~ ^[0-9]+$ ]] && (( rc > 0 )); then
    restart_nonzero+="$c:$rc "
  fi
done
if [[ -z "$restart_nonzero" ]]; then
  pass restart_counters warning "all restart counts are zero"
else
  warn restart_counters warning "non-zero restart counts: $restart_nonzero"
fi

root_free_pct="$(df -P / | awk 'NR==2 {gsub(/%/,"",$5); print 100-$5}')"
if [[ "$root_free_pct" =~ ^[0-9]+$ ]] && (( root_free_pct >= 10 )); then
  pass disk_free_root critical "root free space ${root_free_pct}%"
else
  fail disk_free_root critical "root free space below threshold (${root_free_pct}%)"
fi

# 8) UFW status (warning-only)
if sudo -n ufw status verbose >/dev/null 2>&1; then
  pass ufw_status warning "ufw active/readable"
else
  warn ufw_status warning "unable to read ufw status (non-root or unavailable)"
fi

critical_failures="$(jq -s '[.[] | select(.severity=="critical" and .status=="fail")] | length' "$CHECKS_NDJSON")"
warning_issues="$(jq -s '[.[] | select(.status=="warn")] | length' "$CHECKS_NDJSON")"

overall="pass"
exit_code=0
if (( critical_failures > 0 )); then
  overall="fail"
  exit_code=1
elif (( warning_issues > 0 )); then
  overall="warn"
fi

jq -s \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg project "$COMPOSE_PROJECT_NAME" \
  --arg compose_file "$OBS" \
  --arg env_file "$ENV_FILE" \
  --arg overall "$overall" \
  ' {
      timestamp_utc: $ts,
      project: $project,
      compose_file: $compose_file,
      env_file: $env_file,
      overall: $overall,
      summary: {
        total: length,
        pass: ([.[] | select(.status=="pass")] | length),
        warn: ([.[] | select(.status=="warn")] | length),
        fail: ([.[] | select(.status=="fail")] | length)
      },
      checks: .
    } ' "$CHECKS_NDJSON" > "$OUT"

echo "audit_output=$OUT"
echo "audit_overall=$overall"

exit "$exit_code"
