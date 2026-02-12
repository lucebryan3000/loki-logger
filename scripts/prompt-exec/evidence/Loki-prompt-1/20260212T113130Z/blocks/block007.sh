#!/usr/bin/env bash
set -euo pipefail
umask 022
source "/home/luce/apps/loki-logging/scripts/prompt-exec/evidence/Loki-prompt-1/20260212T113130Z/env.sh"
if [ -n "${REPO_ROOT:-}" ]; then cd "$REPO_ROOT"; else cd "$PROMPT_DIR"; fi
set -euo pipefail
cd /home/luce/apps/loki-logging

git add \
  infra/logging/docker-compose.observability.yml \
  infra/logging/loki-config.yml \
  infra/logging/alloy-config.alloy \
  infra/logging/prometheus/prometheus.yml \
  infra/logging/grafana/provisioning/datasources/loki.yml \
  infra/logging/grafana/provisioning/datasources/prometheus.yml \
  infra/logging/grafana/provisioning/dashboards/dashboards.yml \
  scripts/mcp/logging_stack_up.sh \
  scripts/mcp/logging_stack_down.sh \
  scripts/mcp/logging_stack_health.sh

# Do NOT commit secrets (.env). Verify it's not staged.
if git status --porcelain | grep -q "infra/logging/.env"; then
  echo "FAIL: .env is staged. Remove it from staging and ensure it is gitignored." | tee "$EVID/stop_reason_env_staged.txt"
  exit 1
fi

git commit -m "Deploy Loki logging v1 (loopback-only) + provisioning + scripts" | tee "$EVID/git_commit.txt"
git rev-parse HEAD | tee "$EVID/git_head_after.txt"
