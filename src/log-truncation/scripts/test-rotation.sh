#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

source "$ROOT_DIR/lib/rotation-helpers.sh"

require_sudo

section "Testing log rotation (forced)"

step "Force rotating loki-sources"
sudo logrotate -fv /etc/logrotate.d/loki-sources 2>&1 | tail -20
ok "Rotation triggered"

step "Checking for rotated files (last 5 minutes)"
echo ""
find /home/luce/_logs /home/luce/_telemetry /home/luce/apps/vLLM/_data/mcp-logs /home/luce/apps/vLLM/logs/telemetry/nvidia -name "*.gz" -mmin -5 2>/dev/null | head -10 || info "No recent .gz files (logs may be empty or below size threshold)"

section "Test complete"
info "Run './scripts/status.sh' to see updated disk usage"
