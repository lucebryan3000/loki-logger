#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

source "$ROOT_DIR/lib/rotation-helpers.sh"

require_sudo

section "Testing log rotation (forced)"

step "Force rotating loki-sources"
set +e
rotation_output="$(sudo logrotate -fv /etc/logrotate.d/loki-sources 2>&1)"
rotation_rc=$?
set -e
printf '%s\n' "$rotation_output" | tail -20

if [[ $rotation_rc -eq 0 ]]; then
  ok "Rotation triggered"
elif [[ $rotation_rc -eq 1 ]] && grep -q "Permission denied" <<<"$rotation_output"; then
  warn "Rotation hit host permission constraints on some historical files; continuing"
  ok "Rotation triggered with non-blocking permission warnings"
elif [[ $rotation_rc -eq 1 ]] && grep -q "does not exist -- skipping" <<<"$rotation_output" && ! grep -q "^error:" <<<"$rotation_output"; then
  info "Rotation completed with expected no-file skips for optional globs"
  ok "Rotation triggered"
else
  error "Rotation failed (logrotate exit $rotation_rc)"
  exit $rotation_rc
fi

step "Checking for rotated files (last 5 minutes)"
echo ""
find /home/luce/_logs /home/luce/_telemetry /home/luce/apps/vLLM/_data/mcp-logs /home/luce/apps/vLLM/logs/telemetry/nvidia -name "*.gz" -mmin -5 2>/dev/null | head -10 || info "No recent .gz files (logs may be empty or below size threshold)"

section "Test complete"
info "Run './scripts/status.sh' to see updated disk usage"
