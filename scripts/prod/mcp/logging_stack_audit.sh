#!/usr/bin/env bash
set -euo pipefail
set -o noclobber                               # BB098: prevent accidental file overwrites with >
shopt -s inherit_errexit 2>/dev/null || true  # BB100: propagate errexit into command substitutions (bash 4.4+)

cd "$(dirname "$0")/../../.."

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: logging_stack_audit.sh [-o output-path] [output-path]

Deep health audit of the observability stack. Produces a structured
JSON report with pass/fail/warn results for each check.

Arguments:
  -o, --output path
                Where to write JSON report
                (default: temp/codex/monitoring/health-<timestamp>.json)
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

output_arg=""
positional_output=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--output)
      if [[ $# -lt 2 ]]; then
        echo "missing_output_path_for=$1" >&2
        exit 2
      fi
      output_arg="$2"
      shift 2
      ;;
    --help|-h)
      # handled above; keep branch for robustness when parsed later
      break
      ;;
    -*)
      echo "unknown_arg=$1" >&2
      echo "try: logging_stack_audit.sh --help" >&2
      exit 2
      ;;
    *)
      if [[ -n "$positional_output" ]]; then
        echo "too_many_output_paths" >&2
        echo "try: logging_stack_audit.sh --help" >&2
        exit 2
      fi
      positional_output="$1"
      shift
      ;;
  esac
done

if [[ ! -f "$ENV_FILE" ]]; then
  echo "missing_env_file=$ENV_FILE" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

if [[ -n "$output_arg" && -n "$positional_output" ]]; then
  echo "conflicting_output_args=use_either_flag_or_positional" >&2
  exit 2
fi

OUT="${output_arg:-${positional_output:-temp/codex/monitoring/health-$(date -u +%Y%m%dT%H%M%SZ).json}}"
mkdir -p "$(dirname "$OUT")"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 2
fi

CHECKS_NDJSON="$(mktemp)"
targets_json=""
up_json=""
targets_down_json=""
targets_up_json=""
flags_json=""
rules_json=""
proof_json=""
nvidia_loki_json=""
sem_total_json=""
sem_level_json=""
trap 'rm -f "$CHECKS_NDJSON" "$targets_json" "$up_json" "$targets_down_json" "$targets_up_json" "$flags_json" "$rules_json" "$proof_json" "$nvidia_loki_json" "$sem_total_json" "$sem_level_json"' EXIT

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
running_services="$(docker compose -p "$COMPOSE_PROJECT_NAME" --env-file "$ENV_FILE" -f "$OBS" ps --services --status running | sort || true)"
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

if grep -qx "alert-sink" <<<"$running_services"; then
  pass alert_sink_running warning "alert-sink webhook receiver is running"
else
  warn alert_sink_running warning "alert-sink is not running (alert delivery may fail in sandbox)"
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

if docker run --rm --network obs curlimages/curl:8.6.0 -sf --connect-timeout 5 --max-time 20 'http://loki:3100/ready' >/dev/null; then
  pass loki_ready critical "loki ready endpoint ok"
else
  fail loki_ready critical "loki ready endpoint failed"
fi

# 3) Prometheus targets and native query contract checks
targets_json="$(mktemp)"
if curl -sf --connect-timeout 5 --max-time 20 "http://${PROM_HOST:-127.0.0.1}:${PROM_PORT:-9004}/api/v1/targets" >| "$targets_json"; then
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
if curl -sfG --connect-timeout 5 --max-time 20 "http://${PROM_HOST:-127.0.0.1}:${PROM_PORT:-9004}/api/v1/query" --data-urlencode 'query=up' >| "$up_json"; then
  down_jobs="$(jq -r '.data.result[] | select(.value[1] != "1") | .metric.job' "$up_json" | sort -u)"
  if [[ -z "$down_jobs" ]]; then
    pass prometheus_up_query critical "all up metrics are 1"
  else
    fail prometheus_up_query critical "jobs with up!=1: $(tr '\n' ' ' <<<"$down_jobs")"
  fi
else
  fail prometheus_up_query critical "unable to execute up query"
fi

targets_down_json="$(mktemp)"
if curl -sfG --connect-timeout 5 --max-time 20 "http://${PROM_HOST:-127.0.0.1}:${PROM_PORT:-9004}/api/v1/query" --data-urlencode 'query=sprint3:targets_down:count' >| "$targets_down_json"; then
  td_val="$(jq -r '.data.result[0].value[1] // ""' "$targets_down_json")"
  if [[ -z "$td_val" ]]; then
    td_val="$(curl -sfG --connect-timeout 5 --max-time 20 "http://${PROM_HOST:-127.0.0.1}:${PROM_PORT:-9004}/api/v1/query" --data-urlencode 'query=sum(1-up)' | jq -r '.data.result[0].value[1] // ""' || true)"
  fi
  if [[ "$td_val" =~ ^[0-9]+(\.[0-9]+)?$ ]] && [[ "$td_val" == "0" || "$td_val" == "0.0" ]]; then
    pass prom_rule_targets_down critical "sprint3:targets_down:count is 0"
  else
    fail prom_rule_targets_down critical "sprint3:targets_down:count unexpected value=${td_val:-missing}"
  fi
else
  fail prom_rule_targets_down critical "unable to query sprint3:targets_down:count"
fi

targets_up_json="$(mktemp)"
if curl -sfG --connect-timeout 5 --max-time 20 "http://${PROM_HOST:-127.0.0.1}:${PROM_PORT:-9004}/api/v1/query" --data-urlencode 'query=sprint3:targets_up:count' >| "$targets_up_json"; then
  tu_val="$(jq -r '.data.result[0].value[1] // ""' "$targets_up_json")"
  if [[ -z "$tu_val" ]]; then
    tu_val="$(curl -sfG --connect-timeout 5 --max-time 20 "http://${PROM_HOST:-127.0.0.1}:${PROM_PORT:-9004}/api/v1/query" --data-urlencode 'query=sum(up)' | jq -r '.data.result[0].value[1] // ""' || true)"
  fi
  if [[ "$tu_val" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    pass prom_rule_targets_up critical "sprint3:targets_up:count value=${tu_val}"
  else
    fail prom_rule_targets_up critical "sprint3:targets_up:count missing/non-numeric"
  fi
else
  fail prom_rule_targets_up critical "unable to query sprint3:targets_up:count"
fi

# 4) Retention + rules
flags_json="$(mktemp)"
if curl -sf --connect-timeout 5 --max-time 20 "http://${PROM_HOST:-127.0.0.1}:${PROM_PORT:-9004}/api/v1/status/flags" >| "$flags_json"; then
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
if curl -sf --connect-timeout 5 --max-time 20 "http://${PROM_HOST:-127.0.0.1}:${PROM_PORT:-9004}/api/v1/rules" >| "$rules_json"; then
  has_core_groups="$(jq -r '[(.data.groups[]?.name // empty)] | (index("loki_logging_v1") != null and index("sprint3_minimum_v1") != null)' "$rules_json")"
  has_recording_rules="$(jq -r '[.data.groups[]?.rules[]? | select(.type=="recording") | .name] | (index("sprint3:targets_up:count") != null and index("sprint3:targets_down:count") != null and index("sprint3:host_cpu_usage_percent") != null and index("sprint3:host_memory_usage_percent") != null and index("sprint3:host_disk_usage_percent") != null)' "$rules_json")"
  has_min_alerts="$(jq -r '[.data.groups[]?.rules[]? | select(.type=="alerting") | .name] | (index("PrometheusScrapeFailure") != null and index("PrometheusTargetDown") != null and index("LokiIngestionErrors") != null)' "$rules_json")"
  if [[ "$has_core_groups" == "true" && "$has_recording_rules" == "true" && "$has_min_alerts" == "true" ]]; then
    pass prometheus_rules critical "required groups, recording rules, and minimum alerts are loaded"
  else
    fail prometheus_rules critical "rule contract mismatch (groups=${has_core_groups} records=${has_recording_rules} alerts=${has_min_alerts})"
  fi
else
  fail prometheus_rules critical "unable to fetch /api/v1/rules"
fi

# 5) Config lint
if docker compose -p "$COMPOSE_PROJECT_NAME" --env-file "$ENV_FILE" -f "$OBS" config >/dev/null; then
  pass compose_config_valid critical "docker compose config is valid"
else
  fail compose_config_valid critical "docker compose config failed"
fi

prom_image="$(docker compose -p "$COMPOSE_PROJECT_NAME" --env-file "$ENV_FILE" -f "$OBS" config --format json 2>/dev/null | jq -r '.services.prometheus.image // empty' || true)"
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
  if docker run --rm --network obs curlimages/curl:8.6.0 -sfG --connect-timeout 5 --max-time 20 \
      --data-urlencode "query={env=~\".+\",log_source=\"codeswarm_mcp\"} |= \"${proof_line}\"" \
      --data-urlencode "start=${from_ns}" \
      --data-urlencode "end=${now_ns}" \
      --data-urlencode 'limit=20' \
      --data-urlencode 'direction=BACKWARD' \
      'http://loki:3100/loki/api/v1/query_range' >| "$proof_json"; then
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

# 6b) Runtime validation: GPU/NVIDIA telemetry source activity vs Loki delivery
nvidia_dir="${HOST_VLLM:-/home/luce/apps/vLLM}/logs/telemetry/nvidia"
gpu_dir="${GPU_TELEMETRY_DIR:-/home/luce/_telemetry/gpu}"
cutoff_epoch="$(( $(date +%s) - 24*60*60 ))"
nvidia_recent_host=0
nvidia_host_files=0
nvidia_host_bytes=0
gpu_recent_host=0
gpu_host_files=0
gpu_host_bytes=0

if [[ -d "$nvidia_dir" ]]; then
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    nvidia_host_files=$((nvidia_host_files + 1))
    sz="$(stat -c '%s' "$f" 2>/dev/null || echo 0)"
    mt="$(stat -c '%Y' "$f" 2>/dev/null || echo 0)"
    if [[ "$sz" =~ ^[0-9]+$ ]]; then
      nvidia_host_bytes=$((nvidia_host_bytes + sz))
    fi
    if [[ "$mt" =~ ^[0-9]+$ ]] && (( mt >= cutoff_epoch )) && [[ "$sz" =~ ^[0-9]+$ ]] && (( sz > 0 )); then
      nvidia_recent_host=1
    fi
  done < <(find "$nvidia_dir" -type f \( -name '*.jsonl' -o -name '*.jsonl-*' \) 2>/dev/null | sort)
fi

for f in "$gpu_dir/gpu-live.csv" "$gpu_dir/gpu-proc.csv"; do
  [[ -f "$f" ]] || continue
  gpu_host_files=$((gpu_host_files + 1))
  sz="$(stat -c '%s' "$f" 2>/dev/null || echo 0)"
  mt="$(stat -c '%Y' "$f" 2>/dev/null || echo 0)"
  if [[ "$sz" =~ ^[0-9]+$ ]]; then
    gpu_host_bytes=$((gpu_host_bytes + sz))
  fi
  if [[ "$mt" =~ ^[0-9]+$ ]] && (( mt >= cutoff_epoch )) && [[ "$sz" =~ ^[0-9]+$ ]] && (( sz > 0 )); then
    gpu_recent_host=1
  fi
done

nvidia_loki_matches=""
gpu_loki_count_6h="0"
now_ns="$(date +%s%N)"
from_ns="$((now_ns - 24*60*60*1000000000))"
nvidia_loki_json="$(mktemp)"
if docker run --rm --network obs curlimages/curl:8.6.0 -sfG --connect-timeout 5 --max-time 20 \
  --data-urlencode 'query={log_source="nvidia_telem"}' \
  --data-urlencode "start=${from_ns}" \
  --data-urlencode "end=${now_ns}" \
  --data-urlencode 'limit=1' \
  --data-urlencode 'direction=BACKWARD' \
      'http://loki:3100/loki/api/v1/query_range' >| "$nvidia_loki_json"; then
  nvidia_loki_matches="$(jq -r '.data.result | length' "$nvidia_loki_json" 2>/dev/null || echo "")"
fi

gpu_loki_count_6h="$(docker run --rm --network obs curlimages/curl:8.6.0 -sfG --connect-timeout 5 --max-time 20 \
  --data-urlencode 'query=sum(count_over_time({log_source="gpu_telemetry"}[6h]))' \
  --data-urlencode "time=${now_ns}" \
  'http://loki:3100/loki/api/v1/query' \
  | jq -r '.data.result[0].value[1] // "0"' 2>/dev/null || echo "0")"

if [[ "$gpu_recent_host" -eq 1 ]] && awk "BEGIN{exit !(($gpu_loki_count_6h+0) > 0)}"; then
  pass nvidia_telem_runtime warning "gpu_telemetry active (host_recent=1 loki_6h=${gpu_loki_count_6h})"
elif [[ "$nvidia_recent_host" -eq 1 ]] && [[ "$nvidia_loki_matches" =~ ^[1-9][0-9]*$ ]]; then
  pass nvidia_telem_runtime warning "legacy nvidia_telem stream active (host_recent=1 loki_24h_matches=${nvidia_loki_matches})"
elif awk "BEGIN{exit !(($gpu_loki_count_6h+0) > 0)}"; then
  pass nvidia_telem_runtime warning "gpu_telemetry stream active in Loki despite no recent host-file mtime (loki_6h=${gpu_loki_count_6h})"
elif [[ "$nvidia_loki_matches" =~ ^[1-9][0-9]*$ ]]; then
  pass nvidia_telem_runtime warning "legacy nvidia_telem stream present in Loki (24h_matches=${nvidia_loki_matches})"
elif [[ "$gpu_recent_host" -eq 1 ]]; then
  warn nvidia_telem_runtime warning "recent host gpu telemetry files but no Loki gpu_telemetry lines in 6h (files=${gpu_host_files} bytes=${gpu_host_bytes})"
elif [[ "$nvidia_recent_host" -eq 1 ]]; then
  warn nvidia_telem_runtime warning "recent host nvidia input but no Loki nvidia_telem matches in 24h (files=${nvidia_host_files} bytes=${nvidia_host_bytes})"
else
  warn nvidia_telem_runtime warning "no recent gpu/nvidia telemetry host input detected (gpu_files=${gpu_host_files} gpu_bytes=${gpu_host_bytes} nvidia_files=${nvidia_host_files} nvidia_bytes=${nvidia_host_bytes})"
fi

# 6c) Runtime validation: failure-semantics severity normalization
sem_total_json="$(mktemp)"
sem_level_json="$(mktemp)"
if docker run --rm --network obs curlimages/curl:8.6.0 -sfG --connect-timeout 5 --max-time 20 \
  --data-urlencode 'query=sum(count_over_time({log_source=~".+"} |~ "(?i)(Failed with result|Main process exited|Failed to start|Operation not permitted|exit-code)" [24h]))' \
  'http://loki:3100/loki/api/v1/query' >| "$sem_total_json" && \
  docker run --rm --network obs curlimages/curl:8.6.0 -sfG --connect-timeout 5 --max-time 20 \
  --data-urlencode 'query=sum(count_over_time({log_source=~".+",level=~"(?i)(error|warn|warning|info|debug)"} |~ "(?i)(Failed with result|Main process exited|Failed to start|Operation not permitted|exit-code)" [24h]))' \
  'http://loki:3100/loki/api/v1/query' >| "$sem_level_json"; then
  sem_total="$(jq -r '.data.result[0].value[1] // "0"' "$sem_total_json" 2>/dev/null || echo "0")"
  sem_level="$(jq -r '.data.result[0].value[1] // "0"' "$sem_level_json" 2>/dev/null || echo "0")"
  if awk "BEGIN{exit !($sem_total+0 > 0)}"; then
    if awk "BEGIN{exit !($sem_level+0 > 0)}"; then
      pass severity_normalization_runtime warning "normalized failure semantics present (total=${sem_total}, with_level=${sem_level})"
    else
      warn severity_normalization_runtime warning "failure semantics present but level-normalized count is zero (total=${sem_total}, with_level=${sem_level})"
    fi
  else
    pass severity_normalization_runtime warning "no failure-semantics events observed in last 24h"
  fi
else
  warn severity_normalization_runtime warning "unable to query Loki for severity normalization runtime validation"
fi

# 6d) Runtime validation: known-noise suppression effectiveness
noise_syslog="nan"
noise_vscode="nan"
noise_codex="nan"
noise_syslog_15m="nan"
noise_vscode_15m="nan"
noise_codex_15m="nan"
noise_syslog_24h="nan"
noise_vscode_24h="nan"
noise_codex_24h="nan"

noise_syslog="$(docker run --rm --network obs curlimages/curl:8.6.0 -sfG --connect-timeout 5 --max-time 20 \
  --data-urlencode 'query=sum(count_over_time({log_source="rsyslog_syslog"} |~ "(?i)(Health check for container .* OCI runtime exec failed|copy stream failed.*reading from a closed fifo|ShouldRestart failed, container will not be restarted|restart canceled|hasBeenManuallyStopped=true|Container failed to exit within 10s of signal 15 - using the force)" [2m]))' \
  'http://loki:3100/loki/api/v1/query' \
  | jq -r '.data.result[0].value[1] // "0"' 2>/dev/null || echo "nan")"

noise_vscode="$(docker run --rm --network obs curlimages/curl:8.6.0 -sfG --connect-timeout 5 --max-time 20 \
  --data-urlencode 'query=sum(count_over_time({log_source="vscode_server"} |~ "(?i)(npm warn Unknown project config|Melissa[.]ai:.*state: exec-error|Failed to load config error=.*AgentRoleToml|Failed to load apps list error=.*object Object|git config failed: Failed to execute git)" [2m]))' \
  'http://loki:3100/loki/api/v1/query' \
  | jq -r '.data.result[0].value[1] // "0"' 2>/dev/null || echo "nan")"

noise_codex="$(docker run --rm --network obs curlimages/curl:8.6.0 -sfG --connect-timeout 5 --max-time 20 \
  --data-urlencode 'query=sum(count_over_time({log_source="codex_tui"} |~ "(?i)(Ran set -euo pipefail|ToolCall: (exec_command|apply_patch|write_stdin|list_mcp_resources|list_mcp_resource_templates|read_mcp_resource|update_plan|multi_tool_use[.]parallel))" [2m]))' \
  'http://loki:3100/loki/api/v1/query' \
  | jq -r '.data.result[0].value[1] // "0"' 2>/dev/null || echo "nan")"

noise_syslog_15m="$(docker run --rm --network obs curlimages/curl:8.6.0 -sfG --connect-timeout 5 --max-time 20 \
  --data-urlencode 'query=sum(count_over_time({log_source="rsyslog_syslog"} |~ "(?i)(Health check for container .* OCI runtime exec failed|copy stream failed.*reading from a closed fifo|ShouldRestart failed, container will not be restarted|restart canceled|hasBeenManuallyStopped=true|Container failed to exit within 10s of signal 15 - using the force)" [15m]))' \
  'http://loki:3100/loki/api/v1/query' \
  | jq -r '.data.result[0].value[1] // "0"' 2>/dev/null || echo "nan")"

noise_vscode_15m="$(docker run --rm --network obs curlimages/curl:8.6.0 -sfG --connect-timeout 5 --max-time 20 \
  --data-urlencode 'query=sum(count_over_time({log_source="vscode_server"} |~ "(?i)(npm warn Unknown project config|Melissa[.]ai:.*state: exec-error|Failed to load config error=.*AgentRoleToml|Failed to load apps list error=.*object Object|git config failed: Failed to execute git)" [15m]))' \
  'http://loki:3100/loki/api/v1/query' \
  | jq -r '.data.result[0].value[1] // "0"' 2>/dev/null || echo "nan")"

noise_codex_15m="$(docker run --rm --network obs curlimages/curl:8.6.0 -sfG --connect-timeout 5 --max-time 20 \
  --data-urlencode 'query=sum(count_over_time({log_source="codex_tui"} |~ "(?i)(Ran set -euo pipefail|ToolCall: (exec_command|apply_patch|write_stdin|list_mcp_resources|list_mcp_resource_templates|read_mcp_resource|update_plan|multi_tool_use[.]parallel))" [15m]))' \
  'http://loki:3100/loki/api/v1/query' \
  | jq -r '.data.result[0].value[1] // "0"' 2>/dev/null || echo "nan")"

noise_syslog_24h="$(docker run --rm --network obs curlimages/curl:8.6.0 -sfG --connect-timeout 5 --max-time 20 \
  --data-urlencode 'query=sum(count_over_time({log_source="rsyslog_syslog"} |~ "(?i)(Health check for container .* OCI runtime exec failed|copy stream failed.*reading from a closed fifo|ShouldRestart failed, container will not be restarted|restart canceled|hasBeenManuallyStopped=true|Container failed to exit within 10s of signal 15 - using the force)" [24h]))' \
  'http://loki:3100/loki/api/v1/query' \
  | jq -r '.data.result[0].value[1] // "0"' 2>/dev/null || echo "nan")"

noise_vscode_24h="$(docker run --rm --network obs curlimages/curl:8.6.0 -sfG --connect-timeout 5 --max-time 20 \
  --data-urlencode 'query=sum(count_over_time({log_source="vscode_server"} |~ "(?i)(npm warn Unknown project config|Melissa[.]ai:.*state: exec-error|Failed to load config error=.*AgentRoleToml|Failed to load apps list error=.*object Object|git config failed: Failed to execute git)" [24h]))' \
  'http://loki:3100/loki/api/v1/query' \
  | jq -r '.data.result[0].value[1] // "0"' 2>/dev/null || echo "nan")"

noise_codex_24h="$(docker run --rm --network obs curlimages/curl:8.6.0 -sfG --connect-timeout 5 --max-time 20 \
  --data-urlencode 'query=sum(count_over_time({log_source="codex_tui"} |~ "(?i)(Ran set -euo pipefail|ToolCall: (exec_command|apply_patch|write_stdin|list_mcp_resources|list_mcp_resource_templates|read_mcp_resource|update_plan|multi_tool_use[.]parallel))" [24h]))' \
  'http://loki:3100/loki/api/v1/query' \
  | jq -r '.data.result[0].value[1] // "0"' 2>/dev/null || echo "nan")"

if [[ "$noise_syslog" =~ ^[0-9]+(\.[0-9]+)?$ ]] && [[ "$noise_vscode" =~ ^[0-9]+(\.[0-9]+)?$ ]] && [[ "$noise_codex" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
  if awk "BEGIN{exit !(($noise_syslog+0)==0 && ($noise_vscode+0)==0 && ($noise_codex+0)==0)}"; then
    pass runtime_noise_suppression warning "known-noise signatures suppressed in last 2m (syslog=${noise_syslog}, vscode=${noise_vscode}, codex=${noise_codex})"
  else
    warn runtime_noise_suppression warning "known-noise signatures still present in last 2m (syslog=${noise_syslog}, vscode=${noise_vscode}, codex=${noise_codex})"
  fi
else
  warn runtime_noise_suppression warning "unable to query Loki for known-noise suppression validation"
fi

if [[ "$noise_syslog_15m" =~ ^[0-9]+(\.[0-9]+)?$ ]] && [[ "$noise_vscode_15m" =~ ^[0-9]+(\.[0-9]+)?$ ]] && [[ "$noise_codex_15m" =~ ^[0-9]+(\.[0-9]+)?$ ]] && [[ "$noise_syslog_24h" =~ ^[0-9]+(\.[0-9]+)?$ ]] && [[ "$noise_vscode_24h" =~ ^[0-9]+(\.[0-9]+)?$ ]] && [[ "$noise_codex_24h" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
  pass runtime_noise_suppression_trend warning "suppression trend: 15m(syslog=${noise_syslog_15m},vscode=${noise_vscode_15m},codex=${noise_codex_15m}) 24h(syslog=${noise_syslog_24h},vscode=${noise_vscode_24h},codex=${noise_codex_24h})"
else
  warn runtime_noise_suppression_trend warning "unable to query Loki for suppression trend windows (15m/24h)"
fi

# 6e) Suppression-decay per-ADR artifact (2m/15m/1h/24h)
SUPPRESSION_REPORT_SCRIPT="infra/logging/scripts/suppression_decay_report.sh"
if [[ -x "$SUPPRESSION_REPORT_SCRIPT" ]]; then
  suppression_out="$("$SUPPRESSION_REPORT_SCRIPT" 2>/tmp/suppression_decay_report.err || true)"
  sup_json="$(printf '%s\n' "$suppression_out" | awk -F= '/^SUPPRESSION_DECAY_JSON=/{print $2}' | tail -n 1)"
  sup_2m="$(printf '%s\n' "$suppression_out" | awk -F= '/^SUPPRESSION_DECAY_2M_PASS=/{print $2}' | tail -n 1)"
  sup_1h="$(printf '%s\n' "$suppression_out" | awk -F= '/^SUPPRESSION_DECAY_1H_PASS=/{print $2}' | tail -n 1)"
  sup_24h="$(printf '%s\n' "$suppression_out" | awk -F= '/^SUPPRESSION_DECAY_24H_PASS=/{print $2}' | tail -n 1)"
  if [[ "$sup_2m" == "true" && "$sup_1h" == "true" && "$sup_24h" == "true" ]]; then
    pass suppression_decay_report warning "per-ADR suppression decay complete through 24h (artifact=${sup_json:-unknown})"
  elif [[ "$sup_2m" == "true" && "$sup_1h" == "true" ]]; then
    warn suppression_decay_report warning "per-ADR suppression live windows clean; 24h decay pending (artifact=${sup_json:-unknown})"
  else
    warn suppression_decay_report warning "per-ADR suppression still active in live windows (artifact=${sup_json:-unknown})"
  fi
else
  warn suppression_decay_report warning "suppression decay report script missing or not executable"
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
    } ' "$CHECKS_NDJSON" >| "$OUT"

echo "audit_output=$OUT"
echo "audit_overall=$overall"

exit "$exit_code"
