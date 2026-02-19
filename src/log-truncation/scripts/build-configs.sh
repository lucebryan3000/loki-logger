#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

source "$ROOT_DIR/lib/rotation-helpers.sh"
source "$ROOT_DIR/lib/config-parser.sh"
source "$ROOT_DIR/lib/template-engine.sh"

section "Building log rotation configs from templates"

# Load user config
step "Loading config"
load_config "$ROOT_DIR/config/retention.conf"
ok "Config loaded"

# Set generation timestamp
GENERATION_TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
export GENERATION_TIMESTAMP

# Create temp build directory
BUILD_DIR="$ROOT_DIR/.build"
mkdir -p "$BUILD_DIR"

# Render logrotate config
step "Rendering logrotate config"
render_template \
    "$ROOT_DIR/templates/logrotate.conf.tmpl" \
    "$BUILD_DIR/loki-sources.conf"
ok "Generated: $BUILD_DIR/loki-sources.conf"

# Render journald config
step "Rendering journald config"
render_template \
    "$ROOT_DIR/templates/journald.conf.tmpl" \
    "$BUILD_DIR/99-loki-retention.conf"
ok "Generated: $BUILD_DIR/99-loki-retention.conf"

# Conditional: Render samba config
if is_enabled "SAMBA"; then
    step "Rendering samba config (enabled)"
    render_template \
        "$ROOT_DIR/templates/samba.conf.tmpl" \
        "$BUILD_DIR/samba.conf"
    ok "Generated: $BUILD_DIR/samba.conf"
else
    info "Skipping samba config (SAMBA_ENABLED=false)"
fi

section "Build complete"
info "Generated configs in: $BUILD_DIR"
info "Next: Run './scripts/install.sh' to deploy"
