#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

source "$ROOT_DIR/lib/rotation-helpers.sh"

require_sudo

warn "This will remove all log rotation configs installed by this module."
warn "System will revert to default log retention (unbounded)."
if ! ask_yes_no "Continue?"; then
    info "Aborted"
    exit 0
fi

section "Uninstalling log rotation configs"

step "Removing logrotate configs"
sudo rm -f /etc/logrotate.d/loki-sources
sudo rm -f /etc/logrotate.d/samba
ok "Removed logrotate configs"

step "Removing journald override"
sudo rm -f /etc/systemd/journald.conf.d/99-loki-retention.conf
ok "Removed journald override"

step "Restarting systemd-journald"
sudo systemctl restart systemd-journald
ok "Restarted systemd-journald"

section "Uninstall complete"
info "System reverted to default log retention settings"
info "Backup configs remain in: /etc/logrotate.d.backup-*"
