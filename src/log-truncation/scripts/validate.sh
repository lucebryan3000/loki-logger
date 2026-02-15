#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

source "$ROOT_DIR/lib/rotation-helpers.sh"
source "$ROOT_DIR/lib/config-parser.sh"

section "Validating log rotation configs"

# Load config
load_config "$ROOT_DIR/config/retention.conf"

# Validate logrotate config syntax
step "Validating /etc/logrotate.d/loki-sources"
if [[ ! -f /etc/logrotate.d/loki-sources ]]; then
    error "Config not found: /etc/logrotate.d/loki-sources"
    exit 1
fi

if sudo logrotate -d /etc/logrotate.d/loki-sources >/dev/null 2>&1; then
    ok "Syntax valid"
else
    error "Syntax errors detected"
    sudo logrotate -d /etc/logrotate.d/loki-sources
    exit 1
fi

# Validate samba config if enabled
if is_enabled "SAMBA" && [[ -f /etc/logrotate.d/samba ]]; then
    step "Validating /etc/logrotate.d/samba"
    if sudo logrotate -d /etc/logrotate.d/samba >/dev/null 2>&1; then
        ok "Syntax valid"
    else
        warn "Syntax errors (non-fatal)"
    fi
fi

# Check journald config
step "Checking journald config"
if [[ -f /etc/systemd/journald.conf.d/99-loki-retention.conf ]]; then
    ok "Config exists: /etc/systemd/journald.conf.d/99-loki-retention.conf"

    # Verify key settings
    if grep -q "^SystemMaxUse=${JOURNAL_MAX_USE}" /etc/systemd/journald.conf.d/99-loki-retention.conf; then
        ok "SystemMaxUse=${JOURNAL_MAX_USE} configured"
    else
        warn "SystemMaxUse mismatch"
    fi
else
    error "Journald config not found"
    exit 1
fi

# Check logrotate timer
step "Checking logrotate.timer"
if systemctl is-active --quiet logrotate.timer; then
    ok "logrotate.timer is active"
    NEXT_RUN=$(systemctl list-timers logrotate.timer --no-pager | grep logrotate.timer | awk '{print $1, $2, $3}' || echo "unknown")
    info "Next run: $NEXT_RUN"
else
    warn "logrotate.timer is not active"
fi

# Check systemd-journald
step "Checking systemd-journald"
if systemctl is-active --quiet systemd-journald; then
    ok "systemd-journald is running"
else
    error "systemd-journald is not running"
    exit 1
fi

section "Validation complete"
