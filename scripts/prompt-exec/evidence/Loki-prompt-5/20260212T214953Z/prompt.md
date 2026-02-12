---
codex_reviewed_utc: '2026-02-12T00:00:00Z'
codex_revision: 2
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
codex_reason: "Close Phase E for CodeSwarm lane: tail /home/luce/apps/vLLM/_data/mcp-logs via Alloy and prove Loki ingestion with query_range."
---

# PHASE — Enable Alloy tail of CodeSwarm MCP logs + Loki query_range proof

```bash
set -euo pipefail

RUN_UTC="$(date -u +%Y%m%dT%H%M%SZ)"
REPO="/home/luce/apps/loki-logging"
EVID="${REPO}/.artifacts/prism/evidence/${RUN_UTC}"
mkdir -p "$EVID"; chmod 700 "$EVID"
exec > >(tee -a "$EVID/codeswarm_alloy_exec.log") 2> >(tee -a "$EVID/codeswarm_alloy_exec.err.log" >&2)
echo "RUN_UTC=$RUN_UTC" | tee "$EVID/run_id.txt"

cd "$REPO"
command -v rg >/dev/null || { echo "FAIL: rg required"; exit 1; }

OBS_COMPOSE="${REPO}/infra/logging/docker-compose.observability.yml"
test -f "$OBS_COMPOSE" || { echo "FAIL: missing $OBS_COMPOSE"; exit 1; }

PROJECT="infra_observability"
NAME_LINE="$(awk '/^name:/{print $2; exit}' "$OBS_COMPOSE" || true)"
[ -n "$NAME_LINE" ] && PROJECT="$NAME_LINE"
echo "COMPOSE_PROJECT_NAME=$PROJECT" | tee "$EVID/compose_project.txt"

ALLOY_CFG="infra/logging/alloy-config.alloy"
cp -a "$ALLOY_CFG" "$EVID/alloy-config.before.alloy"

if ! rg -n 'local\.file_match\s+"codeswarm_mcp"' "$ALLOY_CFG" >/dev/null; then
  cat >> "$ALLOY_CFG" <<'HCL'

# --- CodeSwarm MCP logs (Phase B) ---
local.file_match "codeswarm_mcp" {
  path_targets = [{ "__path__" = "/host/home/luce/apps/vLLM/_data/mcp-logs/*.log" }]
}

loki.source.file "codeswarm_mcp" {
  targets       = local.file_match.codeswarm_mcp.targets
  tail_from_end = true
  forward_to    = [loki.process.codeswarm.receiver]
}

loki.process "codeswarm" {
  stage.static_labels {
    values = {
      log_source = "codeswarm_mcp",
    }
  }
  forward_to = [loki.write.default.receiver]
}
HCL
fi

cp -a "$ALLOY_CFG" "$EVID/alloy-config.after.alloy"

COMPOSE_PROJECT_NAME="$PROJECT" docker compose -f "$OBS_COMPOSE" up -d alloy | tee "$EVID/restart_alloy.txt"
sleep 2
ALLOY_CID="$(COMPOSE_PROJECT_NAME="$PROJECT" docker compose -f "$OBS_COMPOSE" ps -q alloy)"
GRAFANA_CID="$(COMPOSE_PROJECT_NAME="$PROJECT" docker compose -f "$OBS_COMPOSE" ps -q grafana)"
test -n "$ALLOY_CID" && test -n "$GRAFANA_CID" || { echo "FAIL: missing alloy or grafana container id"; exit 1; }

docker logs --tail 200 "$ALLOY_CID" | tee "$EVID/alloy_logs_tail.txt" >/dev/null

CS_MCP_TEST="/home/luce/apps/vLLM/_data/mcp-logs/mcp-test.log"
TESTLINE="codeswarm-mcp-ingest ${RUN_UTC}"
echo "$TESTLINE" >> "$CS_MCP_TEST"
echo "WROTE_TESTLINE=$TESTLINE" | tee "$EVID/testline.txt"

NOW_NS="$(date +%s%N)"
FROM_NS="$((NOW_NS - 15*60*1000000000))"
cat > "$EVID/query_range_body.json" <<EOJ
{
  "query": "{log_source=\"codeswarm_mcp\"} |= \"${TESTLINE}\"",
  "start": "${FROM_NS}",
  "end": "${NOW_NS}",
  "limit": 50,
  "direction": "BACKWARD"
}
EOJ

END="$((SECONDS + 60))"
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
    PROVED=1; break
  fi
  sleep 3
done

echo "LOKI_CODESWARM_QUERYRANGE_PROOF=${PROVED}" | tee "$EVID/loki_codeswarm_queryrange_proof.txt"
test "$PROVED" -eq 1 || echo "WARN: Loki proof not observed; inspect alloy_logs_tail.txt + file_match path" | tee -a "$EVID/warnings.txt"

git add "$ALLOY_CFG"
git commit -m "Alloy: tail CodeSwarm MCP logs from vLLM host bind" | tee "$EVID/git_commit.txt"

echo "CODESWARM_INGEST_PHASE_OK" | tee "$EVID/codeswarm_ingest_phase_ok.txt"
```
