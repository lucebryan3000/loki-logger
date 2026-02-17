#!/usr/bin/env bash
set -euo pipefail

GRAFANA_URL="${GRAFANA_URL:-http://127.0.0.1:9001}"
LOKI_READY="${LOKI_READY:-http://127.0.0.1:3200/ready}"
PROM_HEALTHY="${PROM_HEALTHY:-http://127.0.0.1:9004/-/healthy}"
ART_DIR="${ART_DIR:-/home/luce/apps/loki-logging/_build/logging}"
ART_PATH="${ART_DIR}/verify_grafana_authority_latest.json"
SRC_JSON="/home/luce/apps/loki-logging/_build/logging/log_source_values.json"
SRC_DASH_DIR="/home/luce/apps/loki-logging/infra/logging/grafana/dashboards/sources"
E2E_SCRIPT="/home/luce/apps/loki-logging/infra/logging/scripts/e2e_check_hardened.sh"

pass(){ echo "PASS: $*"; }
fail(){ echo "FAIL: $*" >&2; exit 2; }

mkdir -p "$ART_DIR"

GRAFANA_USER="${GRAFANA_USER:-admin}"
if [[ -z "${GRAFANA_PASS:-}" ]]; then
  GRAFANA_PASS="$(docker inspect logging-grafana-1 --format '{{range .Config.Env}}{{println .}}{{end}}' | rg '^GF_SECURITY_ADMIN_PASSWORD=' | sed 's/^GF_SECURITY_ADMIN_PASSWORD=//' || true)"
fi
[[ -n "$GRAFANA_PASS" ]] || fail "Grafana password not derivable"

curl -fsS "$LOKI_READY" >/dev/null && pass "Loki ready" || fail "Loki not ready"
curl -fsS "$PROM_HEALTHY" >/dev/null && pass "Prometheus healthy" || fail "Prometheus not healthy"
curl -fsS -u "${GRAFANA_USER}:${GRAFANA_PASS}" "$GRAFANA_URL/api/health" >/dev/null && pass "Grafana API reachable" || fail "Grafana API not reachable"

if [[ -x "$E2E_SCRIPT" ]]; then
  "$E2E_SCRIPT" >/tmp/e2e_authority.out 2>&1 || { cat /tmp/e2e_authority.out >&2; fail "repo hardened E2E script failed"; }
  rg -q 'PASS: marker found in Loki' /tmp/e2e_authority.out && pass "E2E marker found in Loki" || { cat /tmp/e2e_authority.out >&2; fail "E2E marker not found"; }
else
  sudo /usr/local/bin/logging-e2e-check.sh >/tmp/e2e_authority.out 2>&1 || { cat /tmp/e2e_authority.out >&2; fail "system E2E script failed"; }
  rg -q 'PASS: marker found in Loki' /tmp/e2e_authority.out && pass "E2E marker found in Loki" || { cat /tmp/e2e_authority.out >&2; fail "E2E marker not found"; }
fi

rules_json="$(curl -fsS -u "${GRAFANA_USER}:${GRAFANA_PASS}" "$GRAFANA_URL/api/ruler/grafana/api/v1/rules")"
echo "$rules_json" | rg -q 'logging-e2e-marker-missing' && echo "$rules_json" | rg -q 'logging-total-ingest-down' && pass "Grafana alert rule UIDs present" || fail "Grafana alert rule UIDs missing"

[[ -f "$SRC_JSON" ]] || fail "Missing log_source_values.json"
SRC_COUNT="$(jq -r '.count' "$SRC_JSON")"
[[ "$SRC_COUNT" =~ ^[0-9]+$ ]] || fail "Invalid source count in log_source_values.json"

INDEX_META="$(curl -fsS -u "${GRAFANA_USER}:${GRAFANA_PASS}" "$GRAFANA_URL/api/dashboards/uid/codeswarm-source-index" | jq -r '.meta.provisioned' || echo false)"
[[ "$INDEX_META" == "true" ]] && pass "Source Index provisioned" || fail "Source Index not provisioned"

PRESENT_FILES="$(ls "$SRC_DASH_DIR" 2>/dev/null | rg -c '^codeswarm-src-.*\.json$' || echo 0)"
MISSING_UIDS=()
while IFS= read -r src; do
  [[ -z "$src" ]] && continue
  uid="codeswarm-src-$(echo "$src" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
  prov="$(curl -fsS -u "${GRAFANA_USER}:${GRAFANA_PASS}" "$GRAFANA_URL/api/dashboards/uid/$uid" | jq -r '.meta.provisioned' 2>/dev/null || echo false)"
  if [[ "$prov" != "true" ]]; then
    MISSING_UIDS+=("$uid")
  fi
done < <(jq -r '.values[]' "$SRC_JSON")

if [[ "$PRESENT_FILES" -lt "$SRC_COUNT" ]]; then
  fail "Per-source dashboard files incomplete ($PRESENT_FILES/$SRC_COUNT)"
fi
if [[ "${#MISSING_UIDS[@]}" -gt 0 ]]; then
  fail "Per-source dashboards missing in Grafana provisioning: ${MISSING_UIDS[*]}"
fi
pass "Per-source dashboards complete ($PRESENT_FILES/$SRC_COUNT)"

python3 - <<PY
import json, time
art={
  "timestamp_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
  "pass": True,
  "checks": {
    "loki_ready": True,
    "prom_healthy": True,
    "grafana_api": True,
    "e2e_marker_found": True,
    "rule_uids_present": ["logging-e2e-marker-missing","logging-total-ingest-down"],
    "source_index_provisioned": True,
    "log_source_count": int("$SRC_COUNT"),
    "dashboards_expected": int("$SRC_COUNT"),
    "dashboards_present_files": int("$PRESENT_FILES"),
    "dashboards_missing": []
  }
}
with open("$ART_PATH","w") as f:
    json.dump(art,f,indent=2)
print("ARTIFACT_WRITTEN=$ART_PATH")
PY

echo "PASS: verify_grafana_authority complete"
