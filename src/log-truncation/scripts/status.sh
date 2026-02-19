#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

source "$ROOT_DIR/lib/rotation-helpers.sh"
source "$ROOT_DIR/lib/config-parser.sh"

# Load config for paths
load_config "$ROOT_DIR/config/retention.conf"

section "Log Rotation Status"

# === HEALTH CHECK (from codeswarm-tidyup pattern) ===
if [[ "$ENABLE_HEALTH_CHECKS" == "true" ]]; then
    echo ""
    echo "=== System Health ==="
    echo ""

    DISK_USAGE=$(get_disk_usage_percent)
    DISK_FREE=$(get_disk_free_gb)

    step "Disk status"
    info "Usage: ${DISK_USAGE}% (alert threshold: ${DISK_USAGE_ALERT_THRESHOLD}%)"
    info "Free: ${DISK_FREE}GB (alert threshold: ${DISK_FREE_ALERT_THRESHOLD}GB)"

    if [[ "$DISK_USAGE" -gt "$DISK_USAGE_ALERT_THRESHOLD" ]]; then
        warn "Disk usage exceeds threshold!"
    fi

    if [[ "$DISK_FREE" -lt "$DISK_FREE_ALERT_THRESHOLD" ]]; then
        warn "Low disk space!"
    fi

    # Health state history
    if [[ -f "$HEALTH_STATE_FILE" ]]; then
        step "Recent health status"
        tail -5 "$HEALTH_STATE_FILE" 2>/dev/null | while IFS='|' read -r timestamp status details; do
            date_str=$(date -d "@$timestamp" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "unknown")
            info "$date_str - $status - $details"
        done
    fi
fi

# Disk usage by handler
echo ""
echo "=== Disk Usage by Handler ==="
echo ""

step "Docker logs (json-file driver)"
DOCKER_LOGS=$(sudo du -sh /var/lib/docker/containers 2>/dev/null | awk '{print $1}' || echo "N/A")
info "Total: $DOCKER_LOGS"

step "Alloy-ingested file sources"
# Use config values for paths
info "Tool sink:        $(du -sh /home/luce/_logs 2>/dev/null | awk '{print $1}' || echo '0')"
info "Telemetry:        $(du -sh /home/luce/_telemetry 2>/dev/null | awk '{print $1}' || echo '0')"
info "MCP logs:         $(du -sh /home/luce/apps/vLLM/_data/mcp-logs 2>/dev/null | awk '{print $1}' || echo '0')"
info "NVIDIA telemetry: $(du -sh /home/luce/apps/vLLM/logs/telemetry/nvidia 2>/dev/null | awk '{print $1}' || echo '0')"
info "VSCode Server:    $(du -sh /home/luce/.vscode-server 2>/dev/null | awk '{print $1}' || echo '0')"

step "systemd journal"
JOURNAL_SIZE=$(journalctl --disk-usage 2>/dev/null | grep -oP '\d+\.\d+[A-Z]+' || echo "unknown")
info "Total: $JOURNAL_SIZE (limit: ${JOURNAL_MAX_USE})"

step "System logs (rsyslog)"
info "/var/log: $(sudo du -sh /var/log 2>/dev/null | awk '{print $1}')"

# Logrotate status
echo ""
echo "=== Logrotate Status ==="
echo ""

if [[ -f /var/lib/logrotate/status ]]; then
    step "Last run timestamps (loki-sources)"
    sudo grep "loki-sources" /var/lib/logrotate/status || info "No runs recorded yet"
fi

step "Next scheduled run"
systemctl list-timers logrotate.timer --no-pager | grep logrotate || echo "Timer not found"

# Installed configs
echo ""
echo "=== Installed Configs ==="
echo ""
[[ -f /etc/logrotate.d/loki-sources ]] && ok "/etc/logrotate.d/loki-sources" || warn "Missing: loki-sources"
if is_enabled "SAMBA"; then
    [[ -f /etc/logrotate.d/samba ]] && ok "/etc/logrotate.d/samba" || warn "Missing: samba"
fi
[[ -f /etc/systemd/journald.conf.d/99-loki-retention.conf ]] && ok "/etc/systemd/journald.conf.d/99-loki-retention.conf" || warn "Missing: journald override"
