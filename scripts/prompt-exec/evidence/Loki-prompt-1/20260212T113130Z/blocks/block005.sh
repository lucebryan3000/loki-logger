#!/usr/bin/env bash
set -euo pipefail
umask 022
source "/home/luce/apps/loki-logging/scripts/prompt-exec/evidence/Loki-prompt-1/20260212T113130Z/env.sh"
if [ -n "${REPO_ROOT:-}" ]; then cd "$REPO_ROOT"; else cd "$PROMPT_DIR"; fi
set -euo pipefail
cd /home/luce/apps/loki-logging

cat > scripts/mcp/logging_stack_up.sh <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
export COMPOSE_PROJECT_NAME=infra_observability
docker compose -f infra/logging/docker-compose.observability.yml up -d
BASH

cat > scripts/mcp/logging_stack_down.sh <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
export COMPOSE_PROJECT_NAME=infra_observability
docker compose -f infra/logging/docker-compose.observability.yml down -v
BASH

cat > scripts/mcp/logging_stack_health.sh <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
export COMPOSE_PROJECT_NAME=infra_observability

docker compose -f infra/logging/docker-compose.observability.yml ps

# loopback checks
curl -sf --connect-timeout 5 --max-time 20 http://127.0.0.1:9001/api/health >/dev/null && echo "grafana_ok=1" || { echo "grafana_ok=0"; exit 1; }
curl -sf --connect-timeout 5 --max-time 20 http://127.0.0.1:9004/-/ready | grep -q "Ready" && echo "prometheus_ok=1" || { echo "prometheus_ok=0"; exit 1; }
BASH

chmod +x scripts/mcp/logging_stack_*.sh
ls -la scripts/mcp | tee "$EVID/scripts_ls.txt"
