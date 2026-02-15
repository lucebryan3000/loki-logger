#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$ROOT_DIR/.build"

source "$ROOT_DIR/lib/rotation-helpers.sh"
source "$ROOT_DIR/lib/config-parser.sh"

require_sudo

section "Installing log rotation configs"

# Verify build artifacts exist
step "Checking build artifacts"
if [[ ! -f "$BUILD_DIR/loki-sources.conf" ]]; then
    error "Build artifacts not found. Run './scripts/build-configs.sh' first."
    exit 1
fi
ok "Build artifacts found"

# Load config for conditional logic
load_config "$ROOT_DIR/config/retention.conf"

# Backup existing configs
BACKUP_DIR="/etc/logrotate.d.backup-$(date +%Y%m%d-%H%M%S)"
if [[ -d /etc/logrotate.d ]] && [[ -f /etc/logrotate.d/loki-sources ]]; then
    step "Backing up existing configs"
    sudo mkdir -p "$BACKUP_DIR"
    sudo cp /etc/logrotate.d/loki-sources "$BACKUP_DIR/" 2>/dev/null || true
    ok "Backup created: $BACKUP_DIR"
fi

# Install logrotate config
step "Installing logrotate config"
sudo cp "$BUILD_DIR/loki-sources.conf" /etc/logrotate.d/loki-sources
sudo chmod 644 /etc/logrotate.d/loki-sources
ok "Installed: /etc/logrotate.d/loki-sources"

# Install samba config if enabled
if is_enabled "SAMBA" && [[ -f "$BUILD_DIR/samba.conf" ]]; then
    step "Installing samba logrotate config"
    sudo cp "$BUILD_DIR/samba.conf" /etc/logrotate.d/samba
    sudo chmod 644 /etc/logrotate.d/samba
    ok "Installed: /etc/logrotate.d/samba"
fi

# Install journald config
step "Installing journald retention config"
sudo mkdir -p /etc/systemd/journald.conf.d
sudo cp "$BUILD_DIR/99-loki-retention.conf" /etc/systemd/journald.conf.d/99-loki-retention.conf
sudo chmod 644 /etc/systemd/journald.conf.d/99-loki-retention.conf
ok "Installed: /etc/systemd/journald.conf.d/99-loki-retention.conf"

# Validate installed configs
section "Validating installed configs"
"$SCRIPT_DIR/validate.sh"

# Apply journald changes
section "Applying journald changes"
step "Restarting systemd-journald"
sudo systemctl restart systemd-journald
ok "Restarted systemd-journald"

step "Vacuuming journal to ${JOURNAL_MAX_USE}"
sudo journalctl --vacuum-size="${JOURNAL_MAX_USE}"
ok "Journal vacuumed"

# Show status
section "Installation complete"
"$SCRIPT_DIR/status.sh"

info ""
info "Next steps:"
info "  - Monitor logrotate: sudo journalctl -u logrotate.service -f"
info "  - Force test rotation: sudo ./scripts/test-rotation.sh"
info "  - Check status: ./scripts/status.sh"
