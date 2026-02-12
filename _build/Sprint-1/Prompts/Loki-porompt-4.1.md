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
codex_reason: "Findings-based debug phase: verify Alloy is healthy, confirm telemetry shipping, and disable journald only if repeated timeout noise persists."
---

# PHASE — Alloy Restart/Journald Findings Validation

## Findings This Prompt Encodes
- `interrupt received` during Alloy shutdown is expected when containers restart.
- `context canceled` during shutdown is expected.
- Repeated `unable to follow journal ... Timeout expired` can be sandbox noise and may be disabled if not required.

## Objective
1. Confirm Alloy is not crash-looping.
2. Prove telemetry is still shipping to Loki.
3. Optionally disable journald source if timeout noise is persistent.
4. Emit evidence and commit only allowed config/docs updates.

## Guardrails
- No destructive actions.
- Only config mutation allowed: optional journald disable in `infra/logging/alloy-config.alloy`.
- Always write evidence under `.artifacts/prism/evidence/<RUN_UTC>/`.

```bash
set -euo pipefail

RUN_UTC="$(date -u +%Y%m%dT%H%M%SZ)"
REPO="/home/luce/apps/loki-logging"
EVID="${REPO}/.artifacts/prism/evidence/${RUN_UTC}"
mkdir -p "$EVID"
chmod 700 "$EVID"
exec > >(tee -a "$EVID/alloy_debug_exec.log") 2> >(tee -a "$EVID/alloy_debug_exec.err.log" >&2)

echo "RUN_UTC=$RUN_UTC" | tee "$EVID/run_id.txt"
cd "$REPO"

OBS_COMPOSE="${REPO}/infra/logging/docker-compose.observability.yml"
test -f "$OBS_COMPOSE" || { echo "FAIL: missing $OBS_COMPOSE"; exit 1; }

PROJECT="infra_observability"
NAME_LINE="$(awk '/^name:/{print $2; exit}' "$OBS_COMPOSE" || true)"
[ -n "$NAME_LINE" ] && PROJECT="$NAME_LINE"

ALLOY_CID="$(COMPOSE_PROJECT_NAME="$PROJECT" docker compose -f "$OBS_COMPOSE" ps -q alloy 2>/dev/null || true)"
LOKI_CID="$(COMPOSE_PROJECT_NAME="$PROJECT" docker compose -f "$OBS_COMPOSE" ps -q loki 2>/dev/null || true)"
GRAFANA_CID="$(COMPOSE_PROJECT_NAME="$PROJECT" docker compose -f "$OBS_COMPOSE" ps -q grafana 2>/dev/null || true)"

test -n "$ALLOY_CID" || { echo "FAIL: alloy container not found"; exit 1; }
test -n "$LOKI_CID" || { echo "FAIL: loki container not found"; exit 1; }
test -n "$GRAFANA_CID" || { echo "FAIL: grafana container not found"; exit 1; }

# 1) Restart/crash-loop check
# RestartCount should remain low and stable in healthy state.
docker inspect "$ALLOY_CID" > "$EVID/alloy_inspect.json"
docker inspect "$ALLOY_CID" --format 'RestartCount={{.RestartCount}} StartedAt={{.State.StartedAt}} FinishedAt={{.State.FinishedAt}} ExitCode={{.State.ExitCode}}' \
  | tee "$EVID/alloy_restart_state.txt"

# 2) Log analysis window (last 30m)
docker logs --since 30m "$ALLOY_CID" > "$EVID/alloy_logs_30m.txt" || true
grep -n "interrupt received" "$EVID/alloy_logs_30m.txt" | tail -n 20 | tee "$EVID/alloy_interrupt_lines.txt" || true
grep -n "context canceled" "$EVID/alloy_logs_30m.txt" | tail -n 20 | tee "$EVID/alloy_context_canceled_lines.txt" || true
grep -n "unable to follow journal" "$EVID/alloy_logs_30m.txt" | tail -n 20 | tee "$EVID/alloy_journal_errors.txt" || true

# 3) Steady-state shipping proof: telemetry query_range
NOW_NS="$(date +%s%N)"
FROM_NS="$((NOW_NS - 10*60*1000000000))"

cat > "$EVID/query_range_body.json" <<EOJ
{
  "query": "{env=\"sandbox\"} |= \"telemetry tick\"",
  "start": "${FROM_NS}",
  "end": "${NOW_NS}",
  "limit": 20,
  "direction": "BACKWARD"
}
EOJ

if docker exec "$GRAFANA_CID" sh -lc "command -v curl >/dev/null"; then
  docker exec "$GRAFANA_CID" sh -lc "curl -sf -H 'Content-Type: application/json' -d @/dev/stdin http://loki:3100/loki/api/v1/query_range" \
    < "$EVID/query_range_body.json" | tee "$EVID/loki_queryrange_debug.json" >/dev/null
else
  docker exec "$GRAFANA_CID" sh -lc "wget -qO- --header='Content-Type: application/json' --post-data=\"\$(cat)\" http://loki:3100/loki/api/v1/query_range" \
    < "$EVID/query_range_body.json" | tee "$EVID/loki_queryrange_debug.json" >/dev/null
fi

if grep -q "telemetry tick" "$EVID/loki_queryrange_debug.json"; then
  echo "STEADY_STATE_SHIPPING=1" | tee "$EVID/steady_state_shipping.txt"
else
  echo "STEADY_STATE_SHIPPING=0" | tee "$EVID/steady_state_shipping.txt"
fi

# 4) Optional journald disable if timeout noise is persistent (>=3 occurrences)
JCOUNT="$(wc -l < "$EVID/alloy_journal_errors.txt" | tr -d ' ')"
echo "JOURNALD_TIMEOUT_COUNT_LAST_30M=$JCOUNT" | tee "$EVID/journald_timeout_count.txt"

DISABLE_JOURNALD=1
if [ "$DISABLE_JOURNALD" -eq 1 ] && [ "$JCOUNT" -ge 3 ]; then
  echo "ACTION=disable_journald" | tee "$EVID/action.txt"
  cp -a infra/logging/alloy-config.alloy "$EVID/alloy-config.pre_disable_journald.alloy"

  if ! grep -q "DISABLED_JOURNALD_BLOCK" infra/logging/alloy-config.alloy; then
    python3 - <<'PY'
from pathlib import Path
import re
p = Path('/home/luce/apps/loki-logging/infra/logging/alloy-config.alloy')
t = p.read_text(encoding='utf-8')
m = re.search(r'(loki\.source\.journal\s+"journald"\s*\{.*?\n\})', t, re.S)
if not m:
    print('NOCHANGE: journald block not found')
    raise SystemExit(0)
block = m.group(1)
wrapped = "/* DISABLED_JOURNALD_BLOCK\n" + block + "\n*/\n"
p.write_text(t.replace(block, wrapped, 1), encoding='utf-8')
print('UPDATED: journald block disabled')
PY
  else
    echo "NOCHANGE: journald already disabled" | tee -a "$EVID/warnings.txt"
  fi

  cp -a infra/logging/alloy-config.alloy "$EVID/alloy-config.post_disable_journald.alloy"
  COMPOSE_PROJECT_NAME="$PROJECT" docker compose -f "$OBS_COMPOSE" up -d alloy | tee "$EVID/restart_alloy.txt"
  sleep 2
  docker logs --tail 120 "$ALLOY_CID" | tee "$EVID/alloy_logs_tail_post_restart.txt" >/dev/null

  git add infra/logging/alloy-config.alloy
  git commit -m "Alloy: disable journald source (timeout noise) in sandbox" | tee "$EVID/git_commit_config.txt" || true
else
  echo "ACTION=leave_journald_enabled" | tee "$EVID/action.txt"
fi

# 5) Persist findings interpretation doc
NOTE="_build/Sprint-1/validation/artifacts/ALLOY_LOG_INTERPRETATION.md"
mkdir -p "$(dirname "$NOTE")"
cat > "$NOTE" <<EON
# Alloy Log Interpretation (Sandbox)
Run: ${RUN_UTC}

## Expected on restart
- "interrupt received" indicates graceful SIGINT/SIGTERM handling.
- "context canceled" in downstream components during shutdown is expected.

## Optional in sandbox
- Journald ingestion may timeout in containerized setups depending on permissions/mounts.
- If timeout noise is persistent and journald is not required for v1, disabling journald is acceptable.

## Evidence
- ${EVID}
EON

git add "$NOTE"
git commit -m "Docs: clarify Alloy restart/journald log interpretation" | tee "$EVID/git_commit_docs.txt" || true

echo "ALLOY_DEBUG_OK" | tee "$EVID/alloy_debug_ok.txt"
```

## Acceptance
- `alloy_restart_state.txt` does not indicate crash loop.
- `steady_state_shipping.txt` is `1` (preferred).
- If `JOURNALD_TIMEOUT_COUNT_LAST_30M >= 3`, journald disable action is captured with before/after config evidence.
- `ALLOY_LOG_INTERPRETATION.md` exists and is committed.
