#!/usr/bin/env bash
set -euo pipefail
umask 022
source "/home/luce/apps/loki-logging/scripts/prompt-exec/evidence/Loki-prompt-1/20260212T112400Z/env.sh"
if [ -n "${REPO_ROOT:-}" ]; then cd "$REPO_ROOT"; else cd "$PROMPT_DIR"; fi
set -euo pipefail
cd /home/luce/apps

if [ ! -d /home/luce/apps/loki-logging/.git ]; then
  git clone https://github.com/lucebryan3000/loki-logger.git /home/luce/apps/loki-logging
fi

cd /home/luce/apps/loki-logging

# Fail closed if dirty tree (we want deterministic diffs)
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "FAIL: git working tree not clean. Commit/stash manually before running this prompt." | tee -a "$EVID/stop_reason.txt"
  git status --porcelain | tee "$EVID/git_status_dirty.txt"
  exit 1
fi

mkdir -p infra/logging/prometheus
mkdir -p infra/logging/grafana/provisioning/datasources
mkdir -p infra/logging/grafana/provisioning/dashboards
mkdir -p infra/logging/grafana/dashboards
mkdir -p scripts/mcp

# Host bind targets
mkdir -p /home/luce/_logs
mkdir -p /home/luce/_telemetry
chmod 700 /home/luce/_logs /home/luce/_telemetry

# Evidence snapshot of tree
git rev-parse HEAD | tee "$EVID/git_head_before.txt"
ls -la infra/logging | tee "$EVID/infra_logging_ls.txt"
