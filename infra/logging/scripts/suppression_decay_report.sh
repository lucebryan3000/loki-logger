#!/usr/bin/env bash
set -euo pipefail

ROOT="/home/luce/apps/loki-logging"
OUTDIR="$ROOT/_build/logging"
mkdir -p "$OUTDIR" 2>/dev/null || true
if ! touch "$OUTDIR/.suppression_decay_write_test" 2>/dev/null; then
  OUTDIR="/tmp/logging-artifacts"
  mkdir -p "$OUTDIR"
else
  rm -f "$OUTDIR/.suppression_decay_write_test"
fi

OUT_JSON="$OUTDIR/suppression_decay_latest.json"
OUT_MD="$OUTDIR/suppression_decay_latest.md"

query_count() {
  local expr="$1" window="$2"
  local query
  query="sum(count_over_time({log_source=~\".+\"} |~ \"${expr}\" [${window}]))"
  docker run --rm --network obs curlimages/curl:8.6.0 -sfG \
    --connect-timeout 5 --max-time 20 \
    --data-urlencode "query=${query}" \
    'http://loki:3100/loki/api/v1/query' \
    | jq -r '.data.result[0].value[1] // "0"'
}

declare -a ADRS=(
  "ADR-171"
  "ADR-173"
  "ADR-183"
  "ADR-184"
  "ADR-185"
  "ADR-186"
  "ADR-187"
  "ADR-188"
  "ADR-189"
  "ADR-190"
  "ADR-191"
  "ADR-192"
)

declare -a EXPRS=(
  '(?i)(ShouldRestart failed, container will not be restarted|restart canceled|hasBeenManuallyStopped=true)'
  '(?i)copy stream failed.*reading from a closed fifo'
  '(?i)Health check for container .* OCI runtime exec failed'
  '(?i)copy stream failed.*reading from a closed fifo'
  '(?i)Container failed to exit within 10s of signal 15 - using the force'
  '(?i)Ran set -euo pipefail'
  '(?i)Failed to load config error=.*AgentRoleToml'
  '(?i)Failed to load apps list error=.*object Object'
  '(?i)git config failed: Failed to execute git'
  '(?i)ToolCall: (exec_command|apply_patch|write_stdin|list_mcp_resources|list_mcp_resource_templates|read_mcp_resource|update_plan|multi_tool_use[.]parallel)'
  '(?i)npm warn Unknown project config'
  '(?i)Melissa[.]ai:.*state: exec-error'
)

rows_json="$(mktemp)"
trap 'rm -f "$rows_json"' EXIT
echo "[]" >| "$rows_json"

zero_2m=0
zero_15m=0
zero_1h=0
zero_24h=0
total="${#ADRS[@]}"

for i in "${!ADRS[@]}"; do
  adr="${ADRS[$i]}"
  expr="${EXPRS[$i]}"

  c2="$(query_count "$expr" "2m")"
  c15="$(query_count "$expr" "15m")"
  c1h="$(query_count "$expr" "1h")"
  c24="$(query_count "$expr" "24h")"

  [[ "$c2" =~ ^[0-9]+(\.[0-9]+)?$ ]] || c2="nan"
  [[ "$c15" =~ ^[0-9]+(\.[0-9]+)?$ ]] || c15="nan"
  [[ "$c1h" =~ ^[0-9]+(\.[0-9]+)?$ ]] || c1h="nan"
  [[ "$c24" =~ ^[0-9]+(\.[0-9]+)?$ ]] || c24="nan"

  if awk "BEGIN{exit !(($c2+0)==0)}" 2>/dev/null; then zero_2m=$((zero_2m+1)); fi
  if awk "BEGIN{exit !(($c15+0)==0)}" 2>/dev/null; then zero_15m=$((zero_15m+1)); fi
  if awk "BEGIN{exit !(($c1h+0)==0)}" 2>/dev/null; then zero_1h=$((zero_1h+1)); fi
  if awk "BEGIN{exit !(($c24+0)==0)}" 2>/dev/null; then zero_24h=$((zero_24h+1)); fi

  status="pending_24h_decay"
  if awk "BEGIN{exit !(($c24+0)==0)}" 2>/dev/null; then
    status="decayed_24h"
  elif awk "BEGIN{exit !(($c1h+0)==0)}" 2>/dev/null; then
    status="live_clean_pending_24h"
  fi

  jq \
    --arg adr "$adr" \
    --arg expr "$expr" \
    --arg c2 "$c2" \
    --arg c15 "$c15" \
    --arg c1h "$c1h" \
    --arg c24 "$c24" \
    --arg status "$status" \
    '. += [{
      adr: $adr,
      expr: $expr,
      count_2m: ($c2|tonumber? // $c2),
      count_15m: ($c15|tonumber? // $c15),
      count_1h: ($c1h|tonumber? // $c1h),
      count_24h: ($c24|tonumber? // $c24),
      status: $status
    }]' "$rows_json" >| "${rows_json}.tmp"
  mv "${rows_json}.tmp" "$rows_json"
done

pass_2m=false
pass_15m=false
pass_1h=false
pass_24h=false
if (( zero_2m == total )); then pass_2m=true; fi
if (( zero_15m == total )); then pass_15m=true; fi
if (( zero_1h == total )); then pass_1h=true; fi
if (( zero_24h == total )); then pass_24h=true; fi

timestamp_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

jq -n \
  --arg ts "$timestamp_utc" \
  --argjson total "$total" \
  --argjson z2 "$zero_2m" \
  --argjson z15 "$zero_15m" \
  --argjson z1h "$zero_1h" \
  --argjson z24 "$zero_24h" \
  --arg p2 "$pass_2m" \
  --arg p15 "$pass_15m" \
  --arg p1h "$pass_1h" \
  --arg p24 "$pass_24h" \
  --slurpfile rows "$rows_json" \
  '{
    timestamp_utc: $ts,
    summary: {
      total: $total,
      zero_2m: $z2,
      zero_15m: $z15,
      zero_1h: $z1h,
      zero_24h: $z24,
      pass_2m: ($p2 == "true"),
      pass_15m: ($p15 == "true"),
      pass_1h: ($p1h == "true"),
      pass_24h: ($p24 == "true")
    },
    rows: $rows[0]
  }' >| "$OUT_JSON"

{
  echo "# Suppression Decay Report"
  echo
  echo "- timestamp_utc: $timestamp_utc"
  echo "- total: $total"
  echo "- pass_2m: $pass_2m"
  echo "- pass_15m: $pass_15m"
  echo "- pass_1h: $pass_1h"
  echo "- pass_24h: $pass_24h"
  echo
  echo "| ADR | 2m | 15m | 1h | 24h | Status |"
  echo "|-----|----|-----|----|-----|--------|"
  jq -r '.rows[] | "| \(.adr) | \(.count_2m) | \(.count_15m) | \(.count_1h) | \(.count_24h) | \(.status) |"' "$OUT_JSON"
} >| "$OUT_MD"

echo "SUPPRESSION_DECAY_JSON=$OUT_JSON"
echo "SUPPRESSION_DECAY_MD=$OUT_MD"
echo "SUPPRESSION_DECAY_2M_PASS=$pass_2m"
echo "SUPPRESSION_DECAY_15M_PASS=$pass_15m"
echo "SUPPRESSION_DECAY_1H_PASS=$pass_1h"
echo "SUPPRESSION_DECAY_24H_PASS=$pass_24h"
