#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

source "$ROOT_DIR/lib/rotation-helpers.sh"

require_sudo

# Check for --yes flag
YES_FLAG=false
if [[ "${1:-}" == "--yes" ]] || [[ "${1:-}" == "-y" ]]; then
    YES_FLAG=true
fi

section "Codeswarm-Tidyup Decommission"

# === PRE-FLIGHT CHECKS ===

step "Checking prerequisites"

# 1. Verify log-truncation is installed
if [[ ! -f /etc/logrotate.d/loki-sources ]]; then
    error "log-truncation not installed. Run './scripts/install.sh' first."
    exit 1
fi

# 2. Verify log-truncation is healthy
if [[ ! -f "$ROOT_DIR/.build/loki-sources.conf" ]]; then
    error "log-truncation build artifacts missing. Run './scripts/build-configs.sh' first."
    exit 1
fi

# 3. Check journal size
JOURNAL_SIZE_RAW=$(journalctl --disk-usage 2>/dev/null | grep -oP '\d+\.\d+[A-Z]+' || echo "unknown")
JOURNAL_SIZE_GB=$(journalctl --disk-usage 2>/dev/null | grep -oP '\d+\.\d+' || echo "999")

if (( $(echo "$JOURNAL_SIZE_GB > 1.5" | bc -l) )); then
    warn "Journal size is ${JOURNAL_SIZE_RAW} (expected <1GB). Decommission may be premature."
    if [[ "$YES_FLAG" == "false" ]]; then
        if ! ask_yes_no "Continue anyway?"; then
            info "Aborted. Wait for journal to stabilize."
            exit 0
        fi
    else
        info "Continuing (--yes flag)"
    fi
fi

ok "Prerequisites verified"

# === CONFIRMATION ===

warn "This will decommission codeswarm-tidyup service and remove all related files."
warn "Files will be backed up to /var/log/archive/codeswarm-tidyup-$(date +%Y%m%d)/"
echo ""
info "Codeswarm-tidyup files to be removed:"
info "  - /etc/systemd/system/codeswarm-tidyup.service"
info "  - /etc/systemd/system/codeswarm-tidyup.timer"
info "  - /etc/codeswarm-tidyup.conf"
info "  - /usr/local/bin/codeswarm-tidyup.sh"
info "  - /var/log/codeswarm-tidyup.log"
info "  - /var/lib/codeswarm-tidyup/"
info "  - /var/log/codeswarm-tidyup-reports/"
echo ""

if [[ "$YES_FLAG" == "false" ]]; then
    if ! ask_yes_no "Proceed with decommission?"; then
        info "Aborted"
        exit 0
    fi
else
    info "Proceeding (--yes flag)"
fi

# === BACKUP ===

BACKUP_DIR="/var/log/archive/codeswarm-tidyup-$(date +%Y%m%d-%H%M%S)"
section "Creating backup: $BACKUP_DIR"

sudo mkdir -p "$BACKUP_DIR"

step "Backing up systemd units"
if [[ -f /etc/systemd/system/codeswarm-tidyup.service ]]; then
    sudo cp /etc/systemd/system/codeswarm-tidyup.service "$BACKUP_DIR/"
    ok "Backed up codeswarm-tidyup.service"
fi
if [[ -f /etc/systemd/system/codeswarm-tidyup.timer ]]; then
    sudo cp /etc/systemd/system/codeswarm-tidyup.timer "$BACKUP_DIR/"
    ok "Backed up codeswarm-tidyup.timer"
fi

step "Backing up config"
if [[ -f /etc/codeswarm-tidyup.conf ]]; then
    sudo cp /etc/codeswarm-tidyup.conf "$BACKUP_DIR/"
    ok "Backed up codeswarm-tidyup.conf"
fi

step "Backing up script"
if [[ -f /usr/local/bin/codeswarm-tidyup.sh ]]; then
    sudo cp /usr/local/bin/codeswarm-tidyup.sh "$BACKUP_DIR/"
    ok "Backed up codeswarm-tidyup.sh"
fi

step "Backing up runtime files"
if [[ -f /var/log/codeswarm-tidyup.log ]]; then
    sudo cp /var/log/codeswarm-tidyup.log "$BACKUP_DIR/"
    ok "Backed up codeswarm-tidyup.log"
fi
if [[ -d /var/lib/codeswarm-tidyup ]]; then
    sudo cp -r /var/lib/codeswarm-tidyup "$BACKUP_DIR/"
    ok "Backed up health state"
fi

info "Backup complete: $BACKUP_DIR"
sudo du -sh "$BACKUP_DIR"

# === DECOMMISSION ===

section "Decommissioning codeswarm-tidyup"

# 1. Stop and disable timer
step "Stopping codeswarm-tidyup.timer"
if systemctl is-active --quiet codeswarm-tidyup.timer; then
    sudo systemctl stop codeswarm-tidyup.timer
    ok "Timer stopped"
else
    info "Timer already stopped"
fi

if systemctl is-enabled --quiet codeswarm-tidyup.timer 2>/dev/null; then
    sudo systemctl disable codeswarm-tidyup.timer
    ok "Timer disabled"
else
    info "Timer already disabled"
fi

# 2. Stop service (if running)
step "Stopping codeswarm-tidyup.service"
if systemctl is-active --quiet codeswarm-tidyup.service; then
    sudo systemctl stop codeswarm-tidyup.service
    ok "Service stopped"
else
    info "Service not running"
fi

# 3. Remove systemd units
step "Removing systemd units"
sudo rm -f /etc/systemd/system/codeswarm-tidyup.service
sudo rm -f /etc/systemd/system/codeswarm-tidyup.timer
sudo systemctl daemon-reload
ok "Systemd units removed"

# 4. Remove config
step "Removing config file"
sudo rm -f /etc/codeswarm-tidyup.conf
ok "Config removed"

# 5. Remove script
step "Removing executable script"
sudo rm -f /usr/local/bin/codeswarm-tidyup.sh
ok "Script removed"

# 6. Remove runtime files
step "Removing runtime files"
sudo rm -f /var/log/codeswarm-tidyup.log
sudo rm -rf /var/lib/codeswarm-tidyup
sudo rm -rf /var/log/codeswarm-tidyup-reports
ok "Runtime files removed"

# === VERIFICATION ===

section "Verifying removal"

step "Checking for remaining codeswarm-tidyup services"
REMAINING_SERVICES=$(systemctl list-units --all | grep -c codeswarm-tidyup || true)
if [[ "$REMAINING_SERVICES" -eq 0 ]]; then
    ok "No services found"
else
    warn "Found $REMAINING_SERVICES remaining service references"
    systemctl list-units --all | grep codeswarm-tidyup || true
fi

step "Checking for remaining codeswarm-tidyup files"
REMAINING_FILES=$(sudo find /etc /usr/local/bin /var/log /var/lib -name "*codeswarm-tidyup*" 2>/dev/null | wc -l)
if [[ "$REMAINING_FILES" -eq 0 ]]; then
    ok "No files found"
else
    warn "Found $REMAINING_FILES remaining files:"
    sudo find /etc /usr/local/bin /var/log /var/lib -name "*codeswarm-tidyup*" 2>/dev/null || true
fi

# === SUMMARY ===

section "Decommission Complete"

info "Backup location: $BACKUP_DIR"
info "Backup size: $(sudo du -sh "$BACKUP_DIR" | awk '{print $1}')"
echo ""
info "Rollback instructions (if needed):"
info "  sudo cp $BACKUP_DIR/*.service /etc/systemd/system/"
info "  sudo cp $BACKUP_DIR/*.timer /etc/systemd/system/"
info "  sudo cp $BACKUP_DIR/codeswarm-tidyup.conf /etc/"
info "  sudo cp $BACKUP_DIR/codeswarm-tidyup.sh /usr/local/bin/"
info "  sudo chmod +x /usr/local/bin/codeswarm-tidyup.sh"
info "  sudo systemctl daemon-reload"
info "  sudo systemctl enable codeswarm-tidyup.timer"
info "  sudo systemctl start codeswarm-tidyup.timer"
echo ""
info "Next steps:"
info "  - Monitor log-truncation: ./scripts/status.sh"
info "  - Check disk usage: journalctl --disk-usage"
info "  - Verify logrotate runs: journalctl -u logrotate.service"
