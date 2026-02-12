#!/usr/bin/env bash
set -euo pipefail
IFS=$
	
umask 022
source "/home/luce/apps/loki-logging/scripts/prompt-exec/evidence/Loki-prompt-10/20260212T234329Z/env.sh"
if [ -n "${REPO_ROOT:-}" ]; then cd "$REPO_ROOT"; else cd "$PROMPT_DIR"; fi
set -euo pipefail

REPO="/home/luce/apps/loki-logging"
cd "$REPO"

# Evidence v2
source scripts/prism/evidence.sh
export REPO_ROOT="$REPO"
prism_init
prism_event phase_start phase="H" note="tighten_docker_logging"

# External target (do not commit this file)
VLLM_DIR="/home/luce/apps/vLLM"
VLLM_COMPOSE="${VLLM_DIR}/docker-compose.yml"
test -f "$VLLM_COMPOSE" || { prism_event fail reason="missing_vllm_compose" path="$VLLM_COMPOSE"; exit 1; }

SERVICE="codeswarm-mcp"   # PRD target service name
prism_event ctx vllm_compose="$VLLM_COMPOSE" service="$SERVICE"

# Snapshot external file to evidence
cp -a "$VLLM_COMPOSE" "${PRISM_EVID_DIR}/vllm_compose_before.yml"

# Read current max-file value (best-effort)
BEFORE_MAXFILE="$(awk '
  $0 ~ "^  '"$SERVICE"':" {in_svc=1}
  in_svc && $0 ~ "^  [A-Za-z0-9_.-]+:" && $0 !~ "^  '"$SERVICE"':" {in_svc=0}
  in_svc && $0 ~ "max-file" {gsub(/.*max-file:[[:space:]]*\"?/,""); gsub(/\".*/,""); print; exit}
' "$VLLM_COMPOSE" || true)"
[ -z "$BEFORE_MAXFILE" ] && BEFORE_MAXFILE="(not_found)"
prism_event current max_file="$BEFORE_MAXFILE"

# Patch compose: ensure logging.options.max-file is "3" for the service.
# Idempotent: if already "3" do nothing. If missing, add logging block.
python3 - <<'PY'
from pathlib import Path
import re

compose = Path("/home/luce/apps/vLLM/docker-compose.yml")
svc = "codeswarm-mcp"
txt = compose.read_text()

# find service block
m = re.search(rf"^  {re.escape(svc)}:\s*$", txt, re.M)
if not m:
    raise SystemExit(f"FAIL: service '{svc}' not found")

start = m.start()
m2 = re.search(r"^  [A-Za-z0-9_.-]+:\s*$", txt[m.end():], re.M)
end = m.end() + (m2.start() if m2 else len(txt[m.end():]))
block = txt[start:end]

# If max-file exists, replace any value with "3"
if re.search(r'^\s*max-file:\s*"?\d+"?\s*$', block, re.M):
    block2 = re.sub(r'(^\s*max-file:\s*"?)(\d+)("?\s*$)', r'\g<1>3\g<3>', block, flags=re.M)
else:
    # Ensure logging/options hierarchy exists
    if re.search(r'^\s*logging:\s*$', block, re.M):
        # logging exists; ensure options exists
        if re.search(r'^\s*options:\s*$', block, re.M):
            # insert max-file under options
            block2 = re.sub(r'(^\s*options:\s*$)', r'\1\n      max-file: "3"', block, flags=re.M, count=1)
        else:
            # insert options + max-file under logging
            block2 = re.sub(r'(^\s*logging:\s*$)', r'\1\n    options:\n      max-file: "3"', block, flags=re.M, count=1)
    else:
        # add full logging block near top of service block (after service header line)
        lines = block.splitlines(True)
        block2 = lines[0] + "    logging:\n      options:\n        max-file: \"3\"\n" + "".join(lines[1:])

# Also reduce max-size if present and huge? (leave untouched unless present)
# (No-op: PRD only required max-file change.)

newtxt = txt[:start] + block2 + txt[end:]
compose.write_text(newtxt)
print("UPDATED: ensured codeswarm-mcp logging.options.max-file = 3")
PY

cp -a "$VLLM_COMPOSE" "${PRISM_EVID_DIR}/vllm_compose_after.yml"

# Confirm the change in file
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

# Restart vLLM stack (non-destructive)
cd "$VLLM_DIR"
prism_cmd "vLLM compose up" -- docker compose -f "$VLLM_COMPOSE" up -d

# Verify runtime via docker inspect (log driver config)
CID="$(docker compose -f "$VLLM_COMPOSE" ps -q "$SERVICE" | head -n1 || true)"
test -n "$CID" || { prism_event fail reason="missing_container_id" service="$SERVICE"; exit 1; }

docker inspect "$CID" > "${PRISM_EVID_DIR}/codeswarm_container_inspect.json"

# Extract log config (HostConfig.LogConfig.Config.max-file)
RUNTIME_MAXFILE="$(python3 - "$RUN_UTC" <<'PY'
import json
import sys
p = "/home/luce/apps/loki-logging/temp/.artifacts/prism/evidence/" + sys.argv[1] + "/codeswarm_container_inspect.json"
d = json.load(open(p))
cfg = d[0].get("HostConfig", {}).get("LogConfig", {}).get("Config", {})
print(cfg.get("max-file", "missing"))
PY
)"

prism_event runtime max_file="$RUNTIME_MAXFILE"

# Record external mutation in repo (do not stage vLLM compose)
cd "$REPO"
NOTE="_build/Sprint-1/validation/artifacts/EXTERNAL_MUTATIONS.md"
mkdir -p "$(dirname "$NOTE")"
touch "$NOTE"

if ! grep -q "Phase H — Tighten local logging" "$NOTE" 2>/dev/null; then
  cat >> "$NOTE" <<EOF

## Phase H — Tighten local logging (${RUN_UTC})
- File: /home/luce/apps/vLLM/docker-compose.yml
- Service: ${SERVICE}
- Change: logging.options.max-file -> "3"
- Before: ${BEFORE_MAXFILE}
- After: ${AFTER_MAXFILE}
- Runtime (inspect): ${RUNTIME_MAXFILE}
- Evidence dir: ${PRISM_EVID_DIR}
EOF
fi

git add -f "$NOTE"
git reset -- .gitignore .claudeignore 2>/dev/null || true
git commit -m "Phase H: tighten codeswarm-mcp docker log retention (max-file=3) (external mutation)" || true

prism_event phase_ok phase="H"
