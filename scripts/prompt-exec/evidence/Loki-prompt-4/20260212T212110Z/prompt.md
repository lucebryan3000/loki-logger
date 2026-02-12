---
codex_reviewed_utc: "2026-02-12T00:00:00Z"
codex_revision: 1
codex_ready_to_execute: "yes"
codex_kind: task
codex_scope: single-phase
codex_targets:
  - _build/Sprint-1/Prompts/Loki-logging-1.md
codex_autocommit: "yes"
codex_move_to_completed: "yes"
codex_warn_gate: "yes"
codex_warn_mode: ask
codex_allow_noncritical: "yes"
codex_prompt_sha256: "PENDING"
codex_reason: "Runbook Phase B: enable CodeSwarm file sources by adding required host bind mounts to vLLM compose and proving Loki ingestion."
---

# Phase B — Enable CodeSwarm file sources (vLLM bind mounts) + Loki proof

## Objective

Update `/home/luce/apps/vLLM/docker-compose.yml` so the CodeSwarm/MCP service has these host binds:

- `/home/luce/apps/vLLM/_data/mcp-state:/logs`
- `/home/luce/apps/vLLM/_data/mcp-logs:/logs/mcp`

Then prove:

1. mounts present in container `docker inspect`
2. a test line written on host under `_data/mcp-logs` is visible inside container under `/logs/mcp`
3. Loki `query_range` returns that test line (internal query via grafana container)

## Dirty-state policy

- Proceed even if `/home/luce/apps/loki-logging` git tree is dirty.
- DO NOT modify or stage `.gitignore` or `.claudeignore`.

## Phase

```bash
set -euo pipefail

RUN_UTC="$(date -u +%Y%m%dT%H%M%SZ)"
REPO="/home/luce/apps/loki-logging"
EVID="${REPO}/.artifacts/prism/evidence/${RUN_UTC}"
mkdir -p "$EVID"
chmod 700 "$EVID"
exec > >(tee -a "$EVID/phaseB_exec.log") 2> >(tee -a "$EVID/phaseB_exec.err.log" >&2)

echo "RUN_UTC=$RUN_UTC" | tee "$EVID/run_id.txt"

CSDIR="/home/luce/apps/vLLM"
CSFILE="${CSDIR}/docker-compose.yml"
test -f "$CSFILE" || { echo "FAIL: missing $CSFILE"; exit 1; }

NEED1="/home/luce/apps/vLLM/_data/mcp-state:/logs"
NEED2="/home/luce/apps/vLLM/_data/mcp-logs:/logs/mcp"

mkdir -p "${CSDIR}/_data/mcp-state" "${CSDIR}/_data/mcp-logs"
chmod 700 "${CSDIR}/_data/mcp-state" "${CSDIR}/_data/mcp-logs" || true

cp -a "$CSFILE" "$EVID/vllm_compose_before.yml"

# Identify target service: choose first service matching codeswarm|mcp|vllm
SERVICE="$(grep -nE '^[[:space:]]{2}[A-Za-z0-9_.-]+:[[:space:]]*$' "$CSFILE" \
  | sed -E 's/^[[:space:]]{2}([A-Za-z0-9_.-]+):.*/\1/' \
  | grep -Ei 'codeswarm|mcp|vllm' | head -n1 || true)"
test -n "$SERVICE" || { echo "FAIL: could not infer target service name in $CSFILE"; exit 1; }
echo "TARGET_SERVICE=$SERVICE" | tee "$EVID/target_service.txt"

# If mounts already present, no-op; else insert under service volumes
HAS1="$(grep -F "$NEED1" "$CSFILE" >/dev/null && echo 1 || echo 0)"
HAS2="$(grep -F "$NEED2" "$CSFILE" >/dev/null && echo 1 || echo 0)"
echo "HAS_MOUNT_state=$HAS1" | tee "$EVID/has_mount_state.txt"
echo "HAS_MOUNT_logs=$HAS2" | tee "$EVID/has_mount_logs.txt"

if [ "$HAS1" -eq 0 ] || [ "$HAS2" -eq 0 ]; then
  python3 - <<PY
import re, pathlib
p = pathlib.Path("$CSFILE")
txt = p.read_text()
svc = "$SERVICE"

m1 = "      - $NEED1"
m2 = "      - $NEED2"

# Find service block
m = re.search(rf"^  {re.escape(svc)}:\s*$", txt, re.M)
if not m:
    raise SystemExit("FAIL: service header not found")

start = m.start()
# service block ends at next two-space service header or EOF
m2b = re.search(r"^  [A-Za-z0-9_.-]+:\s*$", txt[m.end():], re.M)
end = m.end() + (m2b.start() if m2b else len(txt[m.end():]))
block = txt[start:end]

if "$NEED1" in block and "$NEED2" in block:
    print("NOCHANGE: mounts already present in service block")
    raise SystemExit(0)

# Ensure volumes: exists under service
if re.search(r"^    volumes:\s*$", block, re.M):
    # Insert missing mounts after volumes: line
    lines = block.splitlines(True)
    out = []
    inserted = False
    seen_vol = False
    for line in lines:
        out.append(line)
        if re.match(r"^    volumes:\s*$", line):
            seen_vol = True
            continue
        if seen_vol and not inserted:
            # volumes list entries are 6 spaces + "-". Insert before first non-list line.
            if not re.match(r"^      - ", line):
                if "$NEED1" not in block:
                    out.append(m1 + "\n")
                if "$NEED2" not in block:
                    out.append(m2 + "\n")
                inserted = True
    if seen_vol and not inserted:
        if "$NEED1" not in block:
            out.append(m1 + "\n")
        if "$NEED2" not in block:
            out.append(m2 + "\n")
    newblock = "".join(out)
else:
    # Add volumes block after the service header line
    lines = block.splitlines(True)
    out = []
    out.append(lines[0])
    out.append("    volumes:\n")
    out.append(m1 + "\n")
    out.append(m2 + "\n")
    out.extend(lines[1:])
    newblock = "".join(out)

newtxt = txt[:start] + newblock + txt[end:]
p.write_text(newtxt)
print("UPDATED: inserted required bind mounts")
PY
fi

cp -a "$CSFILE" "$EVID/vllm_compose_after.yml"
grep -F "$NEED1" "$CSFILE" >/dev/null || { echo "FAIL: missing mount1 after edit"; exit 1; }
grep -F "$NEED2" "$CSFILE" >/dev/null || { echo "FAIL: missing mount2 after edit"; exit 1; }

# Restart vLLM stack
cd "$CSDIR"
docker compose -f "$CSFILE" up -d | tee "$EVID/vllm_up.txt"
docker compose -f "$CSFILE" ps | tee "$EVID/vllm_ps.txt"

CID="$(docker compose -f "$CSFILE" ps -q "$SERVICE" | head -n1 || true)"
test -n "$CID" || { echo "FAIL: could not resolve container ID for $SERVICE"; exit 1; }
echo "TARGET_CID=$CID" | tee "$EVID/target_cid.txt"

docker inspect "$CID" > "$EVID/target_inspect.json"

# Host->container visibility proof
TESTLINE="codeswarm-mcp-test ${RUN_UTC}"
echo "$TESTLINE" >> "${CSDIR}/_data/mcp-logs/mcp-test.log"
sleep 1
docker exec "$CID" sh -lc "test -f /logs/mcp/mcp-test.log && tail -n 5 /logs/mcp/mcp-test.log" | tee "$EVID/container_tail_mcp_test.txt"
grep -F "$TESTLINE" "$EVID/container_tail_mcp_test.txt" >/dev/null || { echo "FAIL: test line not visible at /logs/mcp"; exit 1; }

# Loki query_range proof (internal)
OBS_COMPOSE="${REPO}/infra/logging/docker-compose.observability.yml"
PROJECT="infra_observability"
NAME_LINE="$(awk '/^name:/{print $2; exit}' "$OBS_COMPOSE" || true)"
[ -n "$NAME_LINE" ] && PROJECT="$NAME_LINE"

GRAFANA_CID="$(COMPOSE_PROJECT_NAME="$PROJECT" docker compose -f "$OBS_COMPOSE" ps -q grafana 2>/dev/null || true)"
test -n "$GRAFANA_CID" || { echo "FAIL: grafana container missing for internal query"; exit 1; }

NOW_NS="$(date +%s%N)"
FROM_NS="$((NOW_NS - 15*60*1000000000))"

cat > "$EVID/query_range_body.json" <<EOF
{
  "query": "{env=\"sandbox\"} |= \"${TESTLINE}\"",
  "start": "${FROM_NS}",
  "end": "${NOW_NS}",
  "limit": 50,
  "direction": "BACKWARD"
}
EOF

# wait up to 45s for Alloy tail->Loki
END="$((SECONDS + 45))"
PROVED=0
while [ $SECONDS -lt $END ]; do
  if docker exec "$GRAFANA_CID" sh -lc "command -v curl >/dev/null"; then
    docker exec "$GRAFANA_CID" sh -lc "curl -sf -H 'Content-Type: application/json' -d @/dev/stdin http://loki:3100/loki/api/v1/query_range" \
      < "$EVID/query_range_body.json" > "$EVID/loki_queryrange_codeswarm.json" || true
  else
    docker exec "$GRAFANA_CID" sh -lc "wget -qO- --header='Content-Type: application/json' --post-data=\"\$(cat)\" http://loki:3100/loki/api/v1/query_range" \
      < "$EVID/query_range_body.json" > "$EVID/loki_queryrange_codeswarm.json" || true
  fi
  if grep -q "$TESTLINE" "$EVID/loki_queryrange_codeswarm.json" 2>/dev/null; then
    PROVED=1
    break
  fi
  sleep 3
done

echo "LOKI_CODESWARM_QUERYRANGE_PROOF=${PROVED}" | tee "$EVID/loki_codeswarm_queryrange_proof.txt"
test "$PROVED" -eq 1 || echo "WARN: Loki did not show codeswarm test line within window; inspect alloy logs and tail config" | tee -a "$EVID/warnings.txt"

# Record external mutation in repo (do NOT commit vLLM compose)
cd "$REPO"
NOTE="_build/Sprint-1/validation/artifacts/EXTERNAL_MUTATIONS.md"
mkdir -p "$(dirname "$NOTE")"
touch "$NOTE"
if ! grep -q "Phase B — CodeSwarm mounts" "$NOTE" 2>/dev/null; then
  cat >> "$NOTE" <<EOF

## Phase B — CodeSwarm mounts applied (${RUN_UTC})
- File: /home/luce/apps/vLLM/docker-compose.yml
- Binds added:
  - ${NEED1}
  - ${NEED2}
- Evidence: ${EVID}
EOF
fi

git add "$NOTE"
git commit -m "Phase B: record vLLM CodeSwarm MCP bind mounts (external mutation)" | tee "$EVID/git_commit.txt"

echo "PHASE_B_OK" | tee "$EVID/phase_b_ok.txt"
```

## Acceptance

- `phase_b_ok.txt` exists
- `container_tail_mcp_test.txt` contains the test line
- `loki_codeswarm_queryrange_proof.txt` is `1` (warnings allowed only if proof fails but all other checks pass)
