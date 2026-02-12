---
codex_reviewed_utc: '2026-02-12T00:00:00Z'
codex_revision: 2
codex_ready_to_execute: "yes"
codex_kind: task
codex_scope: single-file
codex_targets:
  - infra/logging/alloy-config.alloy
codex_autocommit: "yes"
codex_move_to_completed: "yes"
codex_warn_gate: "yes"
codex_warn_mode: ask
codex_allow_noncritical: "yes"
codex_prompt_sha256_mode: "none"
codex_reason: "Fix CodeSwarm ingestion proof (C=0) by enabling file_match glob discovery for codeswarm_mcp, restart Alloy, then re-prove Loki ingestion via query_range GET (labeled + broad) using Evidence v2."
codex_last_run_utc: '20260212T233321Z'
codex_last_run_dir: '/home/luce/apps/loki-logging/scripts/prompt-exec/evidence/Loki-prompt-8/20260212T233321Z'
codex_last_run_status: 'failed'
codex_last_run_git_head: '02712bea1dca2f8fb0f004d010bfd006bb8ba814'
codex_last_run_warning_count: '0'
codex_last_run_failed_block: 'block002'
codex_last_run_last_ok_block: '1'
codex_last_run_prompt_sha256: 'e8067a6414365583af8f51459c7ddb03e88e57e4eb9ff8f7e972d9a762498a78'
---

# PHASE — CodeSwarm Ingestion: Enable file_match Glob Discovery + Prove Loki

## Objective
- Ensure `loki.source.file "codeswarm_mcp"` is configured for reliable glob discovery.
- Restart Alloy and verify it loads successfully.
- Write a fresh CodeSwarm marker and prove ingestion in Loki using `query_range` GET with both labeled and broad selectors.
- Record run evidence with `scripts/prism/evidence.sh` only.

## Affects
- `infra/logging/alloy-config.alloy`

## Conflict Report
- `OK`: Evidence format is v2 (`temp/.artifacts/prism/evidence/<RUN_UTC>/`).
- `OK`: Prompt edits only one repo file (`infra/logging/alloy-config.alloy`) and uses runtime evidence outputs.
- `CONFLICT RESOLVED`: Trailing natural-language text was inside the shell fence; moved outside fenced commands.

## Phase 0 — Preflight Gate (STOP if any FAIL)

```bash
set -euo pipefail

REPO="/home/luce/apps/loki-logging"
cd "$REPO"

FAIL=0

need_cmd() {
  local c="$1"
  if command -v "$c" >/dev/null 2>&1; then
    echo "PASS: command '$c' found"
  else
    echo "FAIL: command '$c' missing"
    FAIL=1
  fi
}

need_file() {
  local f="$1"
  if [ -f "$f" ]; then
    echo "PASS: file exists: $f"
  else
    echo "FAIL: missing file: $f"
    FAIL=1
  fi
}

need_cmd docker
need_cmd python3
need_cmd git
need_cmd awk
need_cmd sha256sum

need_file "$REPO/scripts/prism/evidence.sh"
need_file "$REPO/infra/logging/alloy-config.alloy"
need_file "$REPO/infra/logging/docker-compose.observability.yml"

if [ "$FAIL" -ne 0 ]; then
  echo "PRECHECK_FAIL"
  exit 1
fi

echo "PRECHECK_OK"
```

## Phase 1 — Patch + Restart + Proof

```bash
set -euo pipefail

REPO="/home/luce/apps/loki-logging"
cd "$REPO"

source scripts/prism/evidence.sh
export REPO_ROOT="$REPO"
prism_init

OBS_COMPOSE="${REPO}/infra/logging/docker-compose.observability.yml"
PROJECT="$(awk '/^name:/{print $2; exit}' "$OBS_COMPOSE" 2>/dev/null || true)"
PROJECT="${PROJECT:-infra_observability}"
export COMPOSE_PROJECT_NAME="$PROJECT"
prism_event ctx compose_project="$PROJECT" compose_file="$OBS_COMPOSE"

ALLOY_CFG="infra/logging/alloy-config.alloy"
test -f "$ALLOY_CFG" || { prism_event fail reason="missing_alloy_cfg"; exit 1; }

BEFORE_SHA="$(sha256sum "$ALLOY_CFG" | awk '{print $1}')"

python3 - <<'PY'
from pathlib import Path
import re

p = Path('/home/luce/apps/loki-logging/infra/logging/alloy-config.alloy')
t = p.read_text(encoding='utf-8')

m = re.search(r'loki\.source\.file\s+"codeswarm_mcp"\s*\{.*?\n\}', t, re.S)
if not m:
    raise SystemExit('FAIL: loki.source.file "codeswarm_mcp" block not found')

block = m.group(0)
glob_pat = '/host/home/luce/apps/vLLM/_data/mcp-logs/*.log'

# Accept either valid layout:
# 1) glob declared directly in the source block, or
# 2) source block points at local.file_match.codeswarm_mcp.targets and
#    local.file_match carries the glob path.
has_direct_glob = glob_pat in block
uses_local_match = 'local.file_match.codeswarm_mcp.targets' in block
has_local_match_glob = re.search(
    r'local\.file_match\s+"codeswarm_mcp"\s*\{.*?/host/home/luce/apps/vLLM/_data/mcp-logs/\*\.log.*?\n\}',
    t,
    re.S,
) is not None

if not (has_direct_glob or (uses_local_match and has_local_match_glob)):
    raise SystemExit('FAIL: codeswarm_mcp source does not resolve expected MCP glob target')

if 'tail_from_end' not in block:
    block = block.replace('{', '{\n  tail_from_end = true\n', 1)

if 'file_match' not in block:
    insert = '\n  file_match {\n    enabled     = true\n    sync_period = "2s"\n  }\n'
    block = block[:-1] + insert + '\n}\n'

# Remove illegal hash comments that break Alloy parsing
block = re.sub(r'(?m)^\s*#.*$', '', block)

t2 = t[:m.start()] + block + t[m.end():]
t2 = re.sub(r'(?m)^\s*#.*$', '', t2)

p.write_text(t2, encoding='utf-8')
print('UPDATED: codeswarm_mcp has file_match + tail_from_end; stripped # comments')
PY

AFTER_SHA="$(sha256sum "$ALLOY_CFG" | awk '{print $1}')"
prism_event cfg alloy_cfg="$ALLOY_CFG" sha_before="$BEFORE_SHA" sha_after="$AFTER_SHA"

if [ "$BEFORE_SHA" != "$AFTER_SHA" ]; then
  git add "$ALLOY_CFG"
  git commit -m "Alloy: enable file_match glob discovery for codeswarm_mcp (sync_period=2s)" || true
  prism_event git commit="alloy_cfg_changed"
else
  prism_event cfg note="nochange_alloy_cfg"
fi

prism_cmd "restart alloy" -- docker compose -f "$OBS_COMPOSE" up -d alloy

ALLOY_CID="$(docker compose -f "$OBS_COMPOSE" ps -q alloy)"
GRAFANA_CID="$(docker compose -f "$OBS_COMPOSE" ps -q grafana)"
test -n "$ALLOY_CID" && test -n "$GRAFANA_CID" || { prism_event fail reason="missing_container_ids"; exit 1; }

sleep 3
docker logs --tail 300 "$ALLOY_CID" > "${PRISM_EVID_DIR}/alloy_tail_300.log" || true

if grep -q "could not perform the initial load successfully" "${PRISM_EVID_DIR}/alloy_tail_300.log"; then
  prism_event fail reason="alloy_initial_load_failed"
  exit 1
fi

# Best-effort signals
rg -n -- "codeswarm_mcp" "${PRISM_EVID_DIR}/alloy_tail_300.log" | tail -n 50 > "${PRISM_EVID_DIR}/alloy_codeswarm_hits.txt" || true
rg -n -- "mcp-logs" "${PRISM_EVID_DIR}/alloy_tail_300.log" | tail -n 50 > "${PRISM_EVID_DIR}/alloy_mcp_path_hits.txt" || true
prism_event alloy logs_saved="alloy_tail_300.log"

HOST_TEST="/home/luce/apps/vLLM/_data/mcp-logs/mcp-test.log"
mkdir -p "$(dirname "$HOST_TEST")"
touch "$HOST_TEST"

TESTLINE="codeswarm-mcp-proof ${RUN_UTC}"
echo "$TESTLINE" >> "$HOST_TEST"
prism_event marker file="$HOST_TEST" testline="$TESTLINE"

sleep 2
docker exec "$ALLOY_CID" sh -lc "tail -n 5 /host/home/luce/apps/vLLM/_data/mcp-logs/mcp-test.log" > "${PRISM_EVID_DIR}/alloy_tail_mcp_test.txt" || true
if ! grep -q "$TESTLINE" "${PRISM_EVID_DIR}/alloy_tail_mcp_test.txt"; then
  prism_event fail reason="marker_not_visible_inside_alloy"
  exit 1
fi
prism_event pass check="marker_visible_inside_alloy"

NOW_NS="$(date +%s%N)"
FROM_NS="$((NOW_NS - 15*60*1000000000))"

run_query() {
  local q="$1"
  local out="$2"

  if docker exec "$GRAFANA_CID" sh -lc "command -v curl >/dev/null 2>&1"; then
    docker exec -e Q="$q" -e START="$FROM_NS" -e END="$NOW_NS" "$GRAFANA_CID" sh -lc '
      curl -sfG \
        --data-urlencode "query=${Q}" \
        --data-urlencode "start=${START}" \
        --data-urlencode "end=${END}" \
        --data-urlencode "limit=50" \
        --data-urlencode "direction=BACKWARD" \
        http://loki:3100/loki/api/v1/query_range
    ' > "$out" || true
  else
    URL="$(python3 - <<PY
import urllib.parse
q = urllib.parse.quote('''$q''', safe='')
print(f"http://loki:3100/loki/api/v1/query_range?query={q}&start=${FROM_NS}&end=${NOW_NS}&limit=50&direction=BACKWARD")
PY
)"
    docker exec "$GRAFANA_CID" sh -lc "wget -qO- '$URL'" > "$out" || true
  fi
}

# Optional label discovery snapshot
if docker exec "$GRAFANA_CID" sh -lc "command -v curl >/dev/null 2>&1"; then
  docker exec "$GRAFANA_CID" sh -lc "curl -sf --connect-timeout 5 --max-time 20 http://loki:3100/loki/api/v1/label/log_source/values || true" > "${PRISM_EVID_DIR}/loki_label_log_source_values.json" || true
else
  docker exec "$GRAFANA_CID" sh -lc "wget -qO- http://loki:3100/loki/api/v1/label/log_source/values || true" > "${PRISM_EVID_DIR}/loki_label_log_source_values.json" || true
fi

Q_LABELED="{log_source=\"codeswarm_mcp\"} |= \"${TESTLINE}\""
Q_BROAD="{} |= \"${TESTLINE}\""

END_WAIT="$((SECONDS + 90))"
PROOF_L=0
PROOF_B=0

while [ $SECONDS -lt $END_WAIT ]; do
  run_query "$Q_LABELED" "${PRISM_EVID_DIR}/loki_labeled.json"
  if grep -q "$TESTLINE" "${PRISM_EVID_DIR}/loki_labeled.json" 2>/dev/null; then
    PROOF_L=1
    break
  fi

  run_query "$Q_BROAD" "${PRISM_EVID_DIR}/loki_broad.json"
  if grep -q "$TESTLINE" "${PRISM_EVID_DIR}/loki_broad.json" 2>/dev/null; then
    PROOF_B=1
    break
  fi

  sleep 3
done

prism_event proof labeled="$PROOF_L" broad="$PROOF_B"

if [ "$PROOF_L" -eq 1 ] || [ "$PROOF_B" -eq 1 ]; then
  prism_event pass phase="codeswarm_ingestion_proof"
else
  prism_event warn phase="codeswarm_ingestion_proof" note="marker_not_found_in_loki_within_window"
fi

prism_event done phase="prompt_8"
```

## Acceptance
- Alloy reloads without initial-load failure.
- Marker is visible from inside Alloy container.
- At least one proof selector (`labeled` or `broad`) is captured in NDJSON event stream.

## Post-Run
Capture from `events.ndjson`:
- `proof.labeled`
- `proof.broad`

If either is `1`, mark Phase E green and proceed to Phase G.
