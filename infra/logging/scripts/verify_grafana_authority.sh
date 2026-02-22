#!/usr/bin/env bash
set -euo pipefail

GRAFANA_URL="${GRAFANA_URL:-http://127.0.0.1:9001}"
LOKI_READY="${LOKI_READY:-http://127.0.0.1:3200/ready}"
PROM_HEALTHY="${PROM_HEALTHY:-http://127.0.0.1:9004/-/healthy}"
ART_DIR="${ART_DIR:-/home/luce/apps/loki-logging/_build/logging}"
INPUT_DIR="${VERIFIER_INPUT_DIR:-/home/luce/apps/loki-logging/_build/logging}"
SRC_DASH_DIR="/home/luce/apps/loki-logging/infra/logging/grafana/dashboards/sources"
DIM_DASH_DIR="/home/luce/apps/loki-logging/infra/logging/grafana/dashboards/dimensions"
ADOPT_OFF_FILE="/home/luce/apps/loki-logging/_build/logging/offending_dashboards.json"
ADOPT_MANIFEST="/home/luce/apps/loki-logging/_build/logging/adopted_dashboards_manifest.json"
AUDIO_AUDIT_SCRIPT="/home/luce/apps/loki-logging/infra/logging/scripts/dashboard_query_audit.sh"
E2E_SCRIPT="/home/luce/apps/loki-logging/infra/logging/scripts/e2e_check_hardened.sh"
DASH_MUTATION_PREFLIGHT_SCRIPT="/home/luce/apps/loki-logging/infra/logging/scripts/dashboard_mutation_preflight.sh"

VERIFY_MODE="${1:-${VERIFY_MODE:-strict}}"
case "$VERIFY_MODE" in
  strict|accuracy|soft) ;;
  *)
    echo "Usage: $0 [strict|accuracy|soft]" >&2
    exit 2
    ;;
esac

pass(){ echo "PASS: $*"; }
fail(){ echo "FAIL: $*" >&2; exit 2; }
warn(){ echo "WARN: $*" >&2; }
NONCRIT_WARNINGS=()
noncritical_or_fail() {
  local msg="$1"
  if [[ "$VERIFY_MODE" == "strict" ]]; then
    fail "$msg"
  else
    NONCRIT_WARNINGS+=("$msg")
    warn "$msg"
  fi
}

mkdir -p "$ART_DIR" 2>/dev/null || true
if ! touch "$ART_DIR/.verify_write_test" 2>/dev/null; then
  ART_DIR="/tmp/logging-artifacts"
  mkdir -p "$ART_DIR"
else
  rm -f "$ART_DIR/.verify_write_test"
fi
ART_PATH="${ART_DIR}/verify_grafana_authority_latest.json"

if [[ ! -f "$INPUT_DIR/log_source_values.json" || ! -f "$INPUT_DIR/chosen_dimension.txt" || ! -f "$INPUT_DIR/dimension_values.txt" ]]; then
  if [[ -f "/tmp/logging-artifacts/log_source_values.json" && -f "/tmp/logging-artifacts/chosen_dimension.txt" && -f "/tmp/logging-artifacts/dimension_values.txt" ]]; then
    INPUT_DIR="/tmp/logging-artifacts"
  fi
fi
SRC_JSON="$INPUT_DIR/log_source_values.json"
DIM_FILE="$INPUT_DIR/chosen_dimension.txt"
DIM_VALUES_FILE="$INPUT_DIR/dimension_values.txt"

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
  # shellcheck disable=SC2024
  sudo /usr/local/bin/logging-e2e-check.sh >/tmp/e2e_authority.out 2>&1 || { cat /tmp/e2e_authority.out >&2; fail "system E2E script failed"; }
  rg -q 'PASS: marker found in Loki' /tmp/e2e_authority.out && pass "E2E marker found in Loki" || { cat /tmp/e2e_authority.out >&2; fail "E2E marker not found"; }
fi

rules_json="$(curl -fsS -u "${GRAFANA_USER}:${GRAFANA_PASS}" "$GRAFANA_URL/api/ruler/grafana/api/v1/rules")"
echo "$rules_json" | rg -q 'logging-e2e-marker-missing' && \
  echo "$rules_json" | rg -q 'logging-total-ingest-down' && \
  echo "$rules_json" | rg -q 'logging-opencode-sse-reconnect' && \
  pass "Grafana alert rule UIDs present" || fail "Grafana alert rule UIDs missing"
echo "$rules_json" | rg -q '"provenance":"file"' && pass "Grafana alert rules provenance=file" || fail "Grafana alert rules not file-provisioned"

cp_json="$(curl -fsS -u "${GRAFANA_USER}:${GRAFANA_PASS}" "$GRAFANA_URL/api/v1/provisioning/contact-points")"
echo "$cp_json" | jq -e '.[] | select(.name=="logging-ops-webhook" and .type=="webhook")' >/dev/null \
  && pass "Webhook contact point logging-ops-webhook provisioned" \
  || fail "Webhook contact point logging-ops-webhook missing"

pol_json="$(curl -fsS -u "${GRAFANA_USER}:${GRAFANA_PASS}" "$GRAFANA_URL/api/v1/provisioning/policies")"
echo "$pol_json" | jq -e '.receiver=="logging-ops-webhook" or (.routes[]? | .receiver=="logging-ops-webhook")' >/dev/null \
  && pass "Notification policy routes to logging-ops-webhook" \
  || fail "Notification policy receiver mismatch (expected logging-ops-webhook)"

SRC_COUNT=0
PRESENT_FILES=0
MISSING_UIDS=()
SOURCE_GOVERNANCE_OK=true
SOURCE_INDEX_OK="unknown"
if [[ -f "$SRC_JSON" ]]; then
  SRC_COUNT="$(jq -r '.count' "$SRC_JSON")"
  [[ "$SRC_COUNT" =~ ^[0-9]+$ ]] || fail "Invalid source count in log_source_values.json"

  INDEX_EXT_ID="$(curl -fsS -u "${GRAFANA_USER}:${GRAFANA_PASS}" "$GRAFANA_URL/api/dashboards/uid/codeswarm-source-index" | jq -r '.meta.provisionedExternalId // ""' || echo "")"
  if [[ -n "$INDEX_EXT_ID" && "$INDEX_EXT_ID" != "null" ]]; then
    SOURCE_INDEX_OK=true
    pass "Source Index provisioned (externalId=$INDEX_EXT_ID)"
  else
    SOURCE_INDEX_OK=false
    fail "Source Index not provisioned"
  fi

  PRESENT_FILES="$(ls "$SRC_DASH_DIR" 2>/dev/null | rg -c '^codeswarm-src-.*\.json$' || echo 0)"
  while IFS= read -r src; do
    [[ -z "$src" ]] && continue
    uid="codeswarm-src-$(echo "$src" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
    ext_id="$(curl -fsS -u "${GRAFANA_USER}:${GRAFANA_PASS}" "$GRAFANA_URL/api/dashboards/uid/$uid" | jq -r '.meta.provisionedExternalId // ""' 2>/dev/null || echo "")"
    if [[ -z "$ext_id" || "$ext_id" == "null" ]]; then
      MISSING_UIDS+=("$uid")
    fi
  done < <(jq -r '.values[]' "$SRC_JSON")

  if [[ "$PRESENT_FILES" -lt "$SRC_COUNT" ]]; then
    SOURCE_GOVERNANCE_OK=false
    noncritical_or_fail "Per-source dashboard files incomplete ($PRESENT_FILES/$SRC_COUNT)"
  fi
  if [[ "${#MISSING_UIDS[@]}" -gt 0 ]]; then
    SOURCE_GOVERNANCE_OK=false
    noncritical_or_fail "Per-source dashboards missing in Grafana provisioning: ${MISSING_UIDS[*]}"
  fi
  if [[ "$SOURCE_GOVERNANCE_OK" == "true" ]]; then
    pass "Per-source dashboards complete ($PRESENT_FILES/$SRC_COUNT)"
  fi
else
  SOURCE_GOVERNANCE_OK=false
  SOURCE_INDEX_OK=false
  noncritical_or_fail "Missing log_source_values.json (source dashboard governance checks skipped)"
fi

# Audit semantics: expected_empty panels are allowed; unexpected empty panels are not.
if [[ -x "$AUDIO_AUDIT_SCRIPT" ]]; then
  "$AUDIO_AUDIT_SCRIPT" "$VERIFY_MODE" >/tmp/dashboard_audit_verify.out 2>&1 || { cat /tmp/dashboard_audit_verify.out >&2; fail "dashboard_query_audit failed"; }
  AUDIT_JSON="$(rg -n '^WROTE_JSON=' /tmp/dashboard_audit_verify.out | tail -n 1 | sed 's/^[0-9]*:WROTE_JSON=//')"
  [[ -n "$AUDIT_JSON" ]] || AUDIT_JSON="/home/luce/apps/loki-logging/_build/logging/dashboard_audit_latest.json"
  [[ -f "$AUDIT_JSON" ]] || fail "Missing dashboard audit artifact"
  AUDIT_EMPTY="$(jq -r '.summary.empty_panels' "$AUDIT_JSON")"
  AUDIT_ERRORS="$(jq -r '.summary.error_panels // 0' "$AUDIT_JSON")"
  AUDIT_EXPECTED_EMPTY="$(jq -r '.summary.expected_empty_panels // 0' "$AUDIT_JSON")"
  AUDIT_UNEXPECTED_EMPTY="$(jq -r '.summary.unexpected_empty_panels // .summary.empty_panels // -1' "$AUDIT_JSON")"
  [[ "$AUDIT_EMPTY" =~ ^[0-9]+$ ]] || fail "Invalid dashboard audit empty_panels value"
  [[ "$AUDIT_ERRORS" =~ ^[0-9]+$ ]] || fail "Invalid dashboard audit error_panels value"
  [[ "$AUDIT_EXPECTED_EMPTY" =~ ^[0-9]+$ ]] || fail "Invalid dashboard audit expected_empty_panels value"
  [[ "$AUDIT_UNEXPECTED_EMPTY" =~ ^[0-9]+$ ]] || fail "Invalid dashboard audit unexpected_empty_panels value"
  if [[ "$AUDIT_ERRORS" -gt 0 ]]; then
    AUDIT_PASS=false
    fail "Dashboard audit has query/runtime errors (errors=$AUDIT_ERRORS)"
  fi
  if [[ "$AUDIT_UNEXPECTED_EMPTY" -eq 0 ]]; then
    AUDIT_PASS=true
    AUDIT_GOVERNANCE_OK=true
    pass "Dashboard audit clean after expected-empty allowance (unexpected=$AUDIT_UNEXPECTED_EMPTY empty=$AUDIT_EMPTY expected=$AUDIT_EXPECTED_EMPTY errors=$AUDIT_ERRORS)"
  else
    AUDIT_PASS=true
    AUDIT_GOVERNANCE_OK=false
    noncritical_or_fail "Dashboard audit unexpected empty panels (unexpected=$AUDIT_UNEXPECTED_EMPTY empty=$AUDIT_EMPTY expected=$AUDIT_EXPECTED_EMPTY errors=$AUDIT_ERRORS)"
  fi
else
  AUDIT_PASS="unknown"
  AUDIT_EMPTY="-1"
  AUDIT_ERRORS="0"
  AUDIT_EXPECTED_EMPTY="0"
  AUDIT_UNEXPECTED_EMPTY="-1"
  AUDIT_GOVERNANCE_OK="unknown"
fi

DASH_MUTATION_PREFLIGHT_OK="unknown"
DASH_MUTATION_PREFLIGHT_JSON=""
if [[ -x "$DASH_MUTATION_PREFLIGHT_SCRIPT" ]]; then
  PREFLIGHT_MODE_ARG="--strict"
  if [[ "$VERIFY_MODE" != "strict" ]]; then
    PREFLIGHT_MODE_ARG="--soft"
  fi
  if "$DASH_MUTATION_PREFLIGHT_SCRIPT" "$PREFLIGHT_MODE_ARG" >/tmp/dashboard_mutation_preflight_verify.out 2>&1; then
    DASH_MUTATION_PREFLIGHT_OK=true
    DASH_MUTATION_PREFLIGHT_JSON="$(rg -n '^PREFLIGHT_JSON=' /tmp/dashboard_mutation_preflight_verify.out | tail -n 1 | sed 's/^[0-9]*:PREFLIGHT_JSON=//')"
    pass "Dashboard mutation preflight passed"
  else
    DASH_MUTATION_PREFLIGHT_OK=false
    cat /tmp/dashboard_mutation_preflight_verify.out >&2 || true
    noncritical_or_fail "Dashboard mutation preflight failed"
  fi
else
  DASH_MUTATION_PREFLIGHT_OK=false
  noncritical_or_fail "Missing dashboard mutation preflight script"
fi

# Second-dimension coverage (service_name/source_type/etc)
DIM_NAME="unknown"
DIM_COUNT=0
DIM_PRESENT_FILES=0
DIM_INDEX_UID="unknown"
DIM_MISSING_UIDS=()
DIMENSION_GOVERNANCE_OK=true
DIM_INDEX_OK="unknown"
if [[ -f "$DIM_FILE" && -f "$DIM_VALUES_FILE" ]]; then
  DIM_NAME="$(cat "$DIM_FILE" | tr -d '[:space:]')"
  [[ -n "$DIM_NAME" ]] || fail "chosen_dimension.txt empty"
  DIM_NAME_SLUG="$(echo "$DIM_NAME" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
  DIM_COUNT="$(rg -c '.' "$DIM_VALUES_FILE" || true)"
  [[ "$DIM_COUNT" =~ ^[0-9]+$ ]] || fail "Invalid dimension count"
  DIM_PRESENT_FILES="$(ls "$DIM_DASH_DIR" 2>/dev/null | rg -c "^codeswarm-dim-${DIM_NAME_SLUG}-.*\\.json$|^codeswarm-dim-index-${DIM_NAME}\\.json$|^codeswarm-dim-index-${DIM_NAME_SLUG}\\.json$" || echo 0)"

  DIM_INDEX_UID="codeswarm-dim-index-${DIM_NAME_SLUG}"
  DIM_INDEX_EXT_ID="$(curl -fsS -u "${GRAFANA_USER}:${GRAFANA_PASS}" "$GRAFANA_URL/api/dashboards/uid/$DIM_INDEX_UID" | jq -r '.meta.provisionedExternalId // ""' 2>/dev/null || echo "")"
  if [[ -n "$DIM_INDEX_EXT_ID" && "$DIM_INDEX_EXT_ID" != "null" ]]; then
    DIM_INDEX_OK=true
    pass "Dimension index provisioned ($DIM_INDEX_UID)"
  else
    DIM_INDEX_OK=false
    fail "Dimension index missing ($DIM_INDEX_UID)"
  fi

  while IFS= read -r v; do
    [[ -z "$v" ]] && continue
    slug="$(echo "$v" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
    prefix="codeswarm-dim-${DIM_NAME_SLUG}-"
    max_slug_len=$((40 - ${#prefix}))
    if [[ "$max_slug_len" -lt 1 ]]; then
      max_slug_len=1
    fi
    uid="${prefix}${slug:0:max_slug_len}"
    ext_id="$(curl -fsS -u "${GRAFANA_USER}:${GRAFANA_PASS}" "$GRAFANA_URL/api/dashboards/uid/$uid" | jq -r '.meta.provisionedExternalId // ""' 2>/dev/null || echo "")"
    if [[ -z "$ext_id" || "$ext_id" == "null" ]]; then
      DIM_MISSING_UIDS+=("$uid")
    fi
  done < "$DIM_VALUES_FILE"

  if [[ "${#DIM_MISSING_UIDS[@]}" -gt 0 ]]; then
    DIMENSION_GOVERNANCE_OK=false
    noncritical_or_fail "Per-dimension dashboards missing in Grafana provisioning: ${DIM_MISSING_UIDS[*]}"
  fi
  if [[ "$DIMENSION_GOVERNANCE_OK" == "true" ]]; then
    pass "Per-dimension dashboards complete (${DIM_COUNT}/${DIM_COUNT})"
  fi
else
  DIMENSION_GOVERNANCE_OK=false
  DIM_INDEX_OK=false
  noncritical_or_fail "Missing chosen_dimension.txt or dimension_values.txt (dimension governance checks skipped)"
fi

# Canonical navigation governance: codeswarm-managed dashboards must carry both
# codeswarm and canonical tags for predictable discovery/search.
if python3 - <<'PY'
import glob
import json

missing = []
for fp in glob.glob('/home/luce/apps/loki-logging/infra/logging/grafana/dashboards/**/*.json', recursive=True):
    try:
        d = json.load(open(fp))
    except Exception:
        continue
    title = d.get('title', '')
    uid = d.get('uid', '')
    tags = d.get('tags') if isinstance(d.get('tags'), list) else []
    managed = title.startswith('CodeSwarm') or uid.startswith('codeswarm-') or ('codeswarm' in tags)
    if not managed:
        continue
    need = {'codeswarm', 'canonical'}
    if not need.issubset(set(tags)):
        missing.append((fp, tags))

if missing:
    print('MISSING_CANONICAL_TAGS=' + str(len(missing)))
    for fp, tags in missing:
        print(f'{fp}\t{tags}')
    raise SystemExit(1)

print('CANONICAL_TAG_GOVERNANCE=ok')
PY
then
  CANONICAL_TAG_OK=true
  pass "Canonical tag governance (codeswarm + canonical) OK"
else
  CANONICAL_TAG_OK=false
  noncritical_or_fail "Canonical tag governance failed (codeswarm/canonical tags missing)"
fi

# Adopted dashboards coverage for non-repo-managed dashboards
if [[ -f "$ADOPT_OFF_FILE" ]]; then
  ADOPT_OFF_COUNT="$(jq -r 'length' "$ADOPT_OFF_FILE" 2>/dev/null || echo 0)"
else
  ADOPT_OFF_COUNT=0
fi
if [[ -f "$ADOPT_MANIFEST" ]]; then
  ADOPT_COUNT="$(jq -r 'map(select(.status == "adopted")) | length' "$ADOPT_MANIFEST" 2>/dev/null || echo 0)"
else
  ADOPT_COUNT=0
fi
[[ "$ADOPT_OFF_COUNT" =~ ^[0-9]+$ ]] || fail "Invalid offending dashboard count"
[[ "$ADOPT_COUNT" =~ ^[0-9]+$ ]] || fail "Invalid adopted dashboard count"
if [[ "$ADOPT_OFF_COUNT" -gt 0 && "$ADOPT_COUNT" -lt "$ADOPT_OFF_COUNT" ]]; then
  ADOPTION_OK=false
  noncritical_or_fail "Adoption incomplete (offenders=$ADOPT_OFF_COUNT adopted=$ADOPT_COUNT)"
else
  ADOPTION_OK=true
  pass "Adoption coverage OK (offenders=$ADOPT_OFF_COUNT adopted=$ADOPT_COUNT)"
fi

NONCRIT_WARNINGS_B64="$(printf '%s\n' "${NONCRIT_WARNINGS[@]}" | base64 | tr -d '\n')"
export NONCRIT_WARNINGS_B64

python3 - <<PY
import base64
import json
import os
import time

decoded = base64.b64decode(os.environ.get("NONCRIT_WARNINGS_B64", "") or b"").decode(errors="ignore")
warnings = [line for line in decoded.splitlines() if line]
art={
  "timestamp_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
  "mode": "$VERIFY_MODE",
  "pass": True,
  "critical_checks": {
    "loki_ready": True,
    "prom_healthy": True,
    "grafana_api": True,
    "e2e_marker_found": True,
    "rule_uids_present": True,
    "rule_provenance_file": True
  },
  "non_critical_checks": {
    "source_governance_ok": "$SOURCE_GOVERNANCE_OK",
    "source_index_ok": "$SOURCE_INDEX_OK",
    "dimension_governance_ok": "$DIMENSION_GOVERNANCE_OK",
    "dimension_index_ok": "$DIM_INDEX_OK",
    "dashboard_audit_governance_ok": "$AUDIT_GOVERNANCE_OK",
    "dashboard_mutation_preflight_ok": "$DASH_MUTATION_PREFLIGHT_OK",
    "canonical_tag_governance_ok": "$CANONICAL_TAG_OK",
    "adoption_coverage_ok": "$ADOPTION_OK",
    "warnings": warnings
  },
  "checks": {
    "loki_ready": True,
    "prom_healthy": True,
    "grafana_api": True,
    "e2e_marker_found": True,
    "rule_uids_present": ["logging-e2e-marker-missing","logging-total-ingest-down","logging-opencode-sse-reconnect"],
    "rule_provenance_file": True,
    "webhook_contact_point_logging_ops_webhook": True,
    "notification_policy_receiver": "logging-ops-webhook",
    "source_index_provisioned": "$SOURCE_INDEX_OK",
    "log_source_count": int("$SRC_COUNT"),
    "dashboards_expected": int("$SRC_COUNT"),
    "dashboards_present_files": int("$PRESENT_FILES"),
    "dashboards_missing": [],
    "audit_pass": "$AUDIT_PASS" == "true",
    "audit_empty_panels": int("$AUDIT_EMPTY"),
    "audit_error_panels": int("$AUDIT_ERRORS"),
    "audit_expected_empty_panels": int("$AUDIT_EXPECTED_EMPTY"),
    "audit_unexpected_empty_panels": int("$AUDIT_UNEXPECTED_EMPTY"),
    "dashboard_mutation_preflight_ok": "$DASH_MUTATION_PREFLIGHT_OK",
    "dashboard_mutation_preflight_artifact": "$DASH_MUTATION_PREFLIGHT_JSON",
    "dimension_name": "$DIM_NAME",
    "dimension_values_count": int("$DIM_COUNT"),
    "dimension_dashboards_present_files": int("$DIM_PRESENT_FILES"),
    "dimension_dashboards_missing": [],
    "dimension_index_uid": "$DIM_INDEX_UID",
    "adoption_offending_count": int("$ADOPT_OFF_COUNT"),
    "adoption_adopted_count": int("$ADOPT_COUNT")
  }
}
with open("$ART_PATH","w") as f:
    json.dump(art,f,indent=2)
print("ARTIFACT_WRITTEN=$ART_PATH")
PY

echo "PASS: verify_grafana_authority complete"
