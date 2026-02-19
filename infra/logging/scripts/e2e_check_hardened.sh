#!/usr/bin/env bash
set -euo pipefail

TAG="${TAG:-logging-e2e-check}"
LOKI_BASE="${LOKI_BASE:-http://127.0.0.1:3200}"
WINDOW_MINUTES="${WINDOW_MINUTES:-20}"
ATTEMPTS="${ATTEMPTS:-6}"
SLEEP_S="${SLEEP_S:-2}"

pass(){ echo "PASS: $*"; }
fail(){ echo "FAIL: $*" >&2; exit 2; }

marker="${TAG}-$(date -u +%Y%m%dT%H%M%SZ)-$RANDOM"
echo "MARKER=${marker}"
logger -t "${TAG}" "${marker}"

ok_j=0
# shellcheck disable=SC2034
for i in $(seq 1 "$ATTEMPTS"); do
  if journalctl -t "${TAG}" --since "${WINDOW_MINUTES} minutes ago" --no-pager | rg -q "${marker}"; then
    ok_j=1
    break
  fi
  sleep "$SLEEP_S"
done
[[ "$ok_j" == "1" ]] && pass "marker present in journald" || fail "marker not present in journald after retries"

curl -fsS "${LOKI_BASE}/ready" >/dev/null && pass "Loki ready" || fail "Loki not ready"

start_ns=$((($(date +%s)-(${WINDOW_MINUTES}*60))*1000000000))
end_ns=$((($(date +%s)+60)*1000000000))
query='{log_source="rsyslog_syslog"} |= "'"${marker}"'"'

ok_l=0
# shellcheck disable=SC2034
for i in $(seq 1 "$ATTEMPTS"); do
  resp=$(curl -fsS "${LOKI_BASE}/loki/api/v1/query_range" --get \
    --data-urlencode "query=${query}" \
    --data-urlencode "start=${start_ns}" \
    --data-urlencode "end=${end_ns}" \
    --data-urlencode "limit=20" \
    --data-urlencode "direction=BACKWARD") || true
  if echo "$resp" | rg -q '"result"\s*:\s*\[\s*\{'; then
    ok_l=1
    break
  fi
  sleep "$SLEEP_S"
done
[[ "$ok_l" == "1" ]] && pass "marker found in Loki" || fail "marker not found in Loki after retries"
