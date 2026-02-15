#!/usr/bin/env bash
# Integration Test: Log Truncation Module
# Phase 3 E2E test on live system
#
# Test workflow: baseline → build → validate → install → verify → status → test rotation
# Captures outputs to test/results/ directory

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
RESULTS_DIR="$SCRIPT_DIR/results"

mkdir -p "$RESULTS_DIR"

source "$ROOT_DIR/lib/rotation-helpers.sh"

section "Integration Test: Log Truncation Module"

# Phase 1: Baseline
section "Phase 1: Baseline"
step "Capturing disk usage"
{
    echo "=== Baseline Disk Usage ==="
    echo "Timestamp: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
    echo ""
    journalctl --disk-usage
    du -sh /home/luce/_logs /home/luce/_telemetry /home/luce/apps/vLLM/_data/mcp-logs 2>/dev/null || true
    du -sh /var/lib/docker/containers 2>/dev/null || true
} > "$RESULTS_DIR/baseline.txt"
ok "Baseline captured: $RESULTS_DIR/baseline.txt"

# Phase 2: Build & Install
section "Phase 2: Build & Install"
step "Building configs"
"$ROOT_DIR/scripts/build-configs.sh"
ok "Configs built"

step "Installing configs"
sudo "$ROOT_DIR/scripts/install.sh" | tee "$RESULTS_DIR/install.log"
ok "Configs installed"

# Phase 3: Validation
section "Phase 3: Validation"
step "Validating installation"
"$ROOT_DIR/scripts/validate.sh" | tee "$RESULTS_DIR/validate.log"
ok "Validation passed"

# Phase 4: Force Rotation
section "Phase 4: Force Rotation"
step "Running test rotation"
sudo "$ROOT_DIR/scripts/test-rotation.sh" | tee "$RESULTS_DIR/test-rotation.log"
ok "Test rotation complete"

# Phase 5: Status Check
section "Phase 5: Post-Install Status"
"$ROOT_DIR/scripts/status.sh" > "$RESULTS_DIR/status-post-install.txt"
ok "Status captured: $RESULTS_DIR/status-post-install.txt"

# Phase 6: Results
section "Integration Test Complete"
info "Results directory: $RESULTS_DIR"
info ""
info "Next steps:"
info "  1. Wait 24 hours for scheduled logrotate run"
info "  2. Re-run status: ./scripts/status.sh > test/results/status-24h.txt"
info "  3. Compare disk usage: diff test/results/baseline.txt test/results/status-24h.txt"
info "  4. Verify journal size < 1GB: journalctl --disk-usage"
info ""
info "To uninstall: sudo ./scripts/uninstall.sh"
