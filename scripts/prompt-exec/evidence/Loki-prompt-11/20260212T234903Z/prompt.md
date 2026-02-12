---
codex_ready_to_execute: yes
codex_kind: task
codex_scope: single-file
codex_autocommit: yes
codex_move_to_completed: yes
codex_warn_gate: yes
codex_warn_mode: ask
codex_allow_noncritical: yes
codex_reason: ""
codex_prompt_sha256_mode: none
codex_reviewed_utc: 2026-02-12T23:48:43Z
codex_revision: 1
codex_last_reason: 'Prompt 10 / Phase 8: tighten codeswarm-mcp docker log retention
  by setting logging.options.max-file=3 in /home/luce/apps/vLLM/docker-compose.yml
  (external mutation), force-recreate service, and record evidence using Evidence
  v2 (temp/.artifacts + NDJSON).'
codex_targets:
- _build/Sprint-1/Prompts/Loki-prompt-11.md
---

# Prompt 10 — Phase 8: Tighten local logging after stability

```bash
set -euo pipefail

REPO="/home/luce/apps/loki-logging"
cd "$REPO"

# Evidence v2 (temp/.artifacts + events.ndjson)
source scripts/prism/evidence.sh
export REPO_ROOT="$REPO"
prism_init
prism_event phase_start phase="8" prompt="10" note="tighten_local_logging"

# External target (do not commit this file)
VLLM_DIR="/home/luce/apps/vLLM"
VLLM_COMPOSE="${VLLM_DIR}/docker-compose.yml"
SERVICE="codeswarm-mcp"

test -f "$VLLM_COMPOSE" || { prism_event fail reason="missing_vllm_compose" path="$VLLM_COMPOSE"; exit 1; }
prism_event ctx vllm_compose="$VLLM_COMPOSE" service="$SERVICE"

# Snapshot external file to evidence
cp -a "$VLLM_COMPOSE" "${PRISM_EVID_DIR}/vllm_compose_before.yml"

# Extract current max-file (best-effort)
BEFORE_MAXFILE="$(awk '
  $0 ~ "^  '"$SERVICE"':" {in_svc=1}
  in_svc && $0 ~ "^  [A-Za-z0-9_.-]+:" && $0 !~ "^  '"$SERVICE"':" {in_svc=0}
  in_svc && $0 ~ "max-file" {gsub(/.*max-file:[[:space:]]*\"?/,""); gsub(/\".*/,""); print; exit}
' "$VLLM_COMPOSE" || true)"
[ -z "$BEFORE_MAXFILE" ] && BEFORE_MAXFILE="(not_found)"
prism_event current max_file="$BEFORE_MAXFILE"

# Patch compose: ensure logging.options.max-file is "3" for codeswarm-mcp
python3 - <<'PY'
from pathlib import Path
import re

compose = Path("/home/luce/apps/vLLM/docker-compose.yml")
svc = "codeswarm-mcp"
txt = compose.read_text()

m = re.search(rf"^  {re.escape(svc)}:\s*$", txt, re.M)
if not m:
    raise SystemExit(f"FAIL: service '{svc}' not found")

start = m.start()
m2 = re.search(r"^  [A-Za-z0-9_.-]+:\s*$", txt[m.end():], re.M)
end = m.end() + (m2.start() if m2 else len(txt[m.end():]))
block = txt[start:end]

def ensure_max_file(b: str) -> str:
    # If max-file exists, replace it
    if re.search(r'^\s*max-file:\s*"?\d+"?\s*$', b, re.M):
        return re.sub(r'(^\s*max-file:\s*"?)(\d+)("?\s*$)', r'\g<1>3\g<3>', b, flags=re.M)
    # Else create logging/options if needed and insert
    if re.search(r'^\s*logging:\s*$', b, re.M):
        if re.search(r'^\s*options:\s*$', b, re.M):
            return re.sub(r'(^\s*options:\s*$)', r'\1\n      max-file: "3"', b, flags=re.M, count=1)
        return re.sub(r'(^\s*logging:\s*$)', r'\1\n    options:\n      max-file: "3"', b, flags=re.M, count=1)
    # Add full block directly after service header
    lines = b.splitlines(True)
    return lines[0] + "    logging:\n      options:\n        max-file: \"3\"\n" + "".join(lines[1:])

block2 = ensure_max_file(block)
newtxt = txt[:start] + block2 + txt[end:]
compose.write_text(newtxt)
print("UPDATED: ensured codeswarm-mcp logging.options.max-file = 3")
PY

cp -a "$VLLM_COMPOSE" "${PRISM_EVID_DIR}/vllm_compose_after.yml"

AFTER_MAXFILE="$(awk '
  $0 ~ "^  '"$SERVICE"':" {in_svc=1}
  in_svc && $0 ~ "^  [A-Za-z0-9_.-]+:" && $0 !~ "^  '"$SERVICE"':" {in_svc=0}
  in_svc && $0 ~ "max-file" {gsub(/.*max-file:[[:space:]]*\"?/,""); gsub(/\".*/,""); print; exit}
' "$VLLM_COMPOSE" || true)"
[ -z "$AFTER_MAXFILE" ] && AFTER_MAXFILE="(not_found)"
prism_event updated max_file_before="$BEFORE_MAXFILE" max_file_after="$AFTER_MAXFILE"

if [ "$AFTER_MAXFILE" != "3" ]; then
  prism_event fail reason="max_file_not_3_after_patch" got="$AFTER_MAXFILE"
  exit 1
fi

# Force-recreate the service so docker log options apply
cd "$VLLM_DIR"
prism_cmd "compose up (force-recreate service)" -- docker compose -f "$VLLM_COMPOSE" up -d --force-recreate "$SERVICE"
prism_cmd "compose ps" -- docker compose -f "$VLLM_COMPOSE" ps

CID="$(docker compose -f "$VLLM_COMPOSE" ps -q "$SERVICE" | head -n1 || true)"
test -n "$CID" || { prism_event fail reason="missing_container_id" service="$SERVICE"; exit 1; }
prism_event ctx container_id="$CID"

docker inspect "$CID" > "${PRISM_EVID_DIR}/codeswarm_container_inspect.json"

# Read runtime log config max-file
RUNTIME_MAXFILE="$(python3 - <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
cfg = d[0].get("HostConfig", {}).get("LogConfig", {}).get("Config", {})
print(cfg.get("max-file", "missing"))
PY
"${PRISM_EVID_DIR}/codeswarm_container_inspect.json")"

prism_event runtime max_file="$RUNTIME_MAXFILE"

# Record external mutation in repo (do not stage vLLM compose)
cd "$REPO"
NOTE="_build/Sprint-1/validation/artifacts/EXTERNAL_MUTATIONS.md"
mkdir -p "$(dirname "$NOTE")"
touch "$NOTE"

cat >> "$NOTE" <<EOF

## Prompt 10 / Phase 8 — Tighten local logging (${RUN_UTC})
- File: /home/luce/apps/vLLM/docker-compose.yml
- Service: ${SERVICE}
- Change: logging.options.max-file -> "3"
- Before: ${BEFORE_MAXFILE}
- After: ${AFTER_MAXFILE}
- Runtime (inspect): ${RUNTIME_MAXFILE}
- Evidence dir: ${PRISM_EVID_DIR}
EOF

git add "$NOTE"
git reset -- .gitignore .claudeignore 2>/dev/null || true
git commit -m "Prompt 10 / Phase 8: tighten codeswarm-mcp docker log retention (max-file=3) (external mutation)" || true

prism_event phase_ok phase="8" prompt="10"
