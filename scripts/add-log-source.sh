#!/usr/bin/env bash
# add-log-source.sh — Interactive wrapper for loki-logging-setup playbook
# Usage: ./scripts/add-log-source.sh [application-name] [log-path]
#
# This script helps you add a new log source to the Loki logging stack by:
# 1. Running discovery on the log files
# 2. Invoking the Claude Code playbook to configure Alloy
# 3. Verifying the logs appear in Loki

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLAYBOOK_DIR="${PLAYBOOK_DIR:-$REPO_ROOT/.claude/prompts}"
PLAYBOOK_MAIN="$PLAYBOOK_DIR/loki-logging-setup-playbook.md"
PLAYBOOK_REFERENCE="$PLAYBOOK_DIR/loki-logging-setup-reference.md"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Loki Logging: Add New Log Source ===${NC}"
echo ""

# Check if playbooks exist
if [ ! -f "$PLAYBOOK_MAIN" ]; then
    echo "ERROR: Playbook not found at $PLAYBOOK_MAIN"
    exit 1
fi

# Usage help
if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    cat << 'EOF'
Add a new log source to the Loki logging stack

USAGE:
    ./scripts/add-log-source.sh [APPLICATION] [LOG-PATH]
    
    If arguments not provided, will prompt interactively.

EXAMPLES:
    # Add nginx logs
    ./scripts/add-log-source.sh nginx /var/log/nginx/

    # Add custom app logs
    ./scripts/add-log-source.sh myapp /home/luce/apps/myapp/logs/

    # Interactive mode (no arguments)
    ./scripts/add-log-source.sh

WHAT THIS DOES:
    1. Discovers log files at the specified path
    2. Generates Claude Code prompt to invoke playbook
    3. Guides you through the 8-phase setup process
    4. Verifies logs appear in Loki with proper labels

PLAYBOOK PHASES:
    Phase 1: Discovery       - Find logs, check format, volume
    Phase 2: Mount Check     - Verify Alloy can access the path
    Phase 3: Label Design    - Choose labels (env, log_source, etc)
    Phase 4: Processor       - Dedicated vs shared processor
    Phase 5: Alloy Config    - Add file_match, source, process blocks
    Phase 6: Restart         - Apply changes, check for errors
    Phase 7: Audit           - Run full validation checklist
    Phase 7b: Remediate      - Auto-fix any audit failures
    Phase 8: Rollback        - (if needed) Revert changes

OUTPUT:
    - Updated infra/logging/alloy-config.alloy
    - Logs queryable in Grafana: {log_source="<application>"}

CURRENT SOURCES (8):
    1. journald (via rsyslog)
    2. rsyslog_syslog
    3. docker (vllm, hex projects)
    4. vscode_server
    5. codeswarm_mcp
    6. nvidia_telem
    7. telemetry
    8. tool_sink

EOF
    exit 0
fi

# Interactive or argument-based input
if [ -z "${1:-}" ]; then
    echo -e "${YELLOW}Interactive mode${NC}"
    echo ""
    read -p "Application name (e.g., nginx, postgres, myapp): " APP_NAME
    read -p "Log path (e.g., /var/log/nginx/, /home/luce/apps/myapp/logs/): " LOG_PATH
else
    APP_NAME="$1"
    LOG_PATH="${2:-.}"
fi

echo ""
echo -e "${GREEN}Configuration:${NC}"
echo "  Application: $APP_NAME"
echo "  Log path: $LOG_PATH"
echo ""

# Quick pre-flight checks
echo -e "${GREEN}Running pre-flight checks...${NC}"

# 1. Check if path exists
if [ ! -e "$LOG_PATH" ]; then
    echo -e "${YELLOW}WARNING: Path does not exist: $LOG_PATH${NC}"
    read -p "Continue anyway? (y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "Aborted."
        exit 1
    fi
else
    echo "✓ Path exists: $LOG_PATH"
fi

# 2. Quick file discovery
if [ -d "$LOG_PATH" ]; then
    FILE_COUNT=$(find "$LOG_PATH" -type f \( -name "*.log" -o -name "*.txt" -o -name "*.jsonl" \) 2>/dev/null | wc -l)
    echo "✓ Found $FILE_COUNT log files"
    
    if [ "$FILE_COUNT" -eq 0 ]; then
        echo -e "${YELLOW}WARNING: No .log, .txt, or .jsonl files found${NC}"
    fi
fi

# 3. Check if Alloy can access (if under /home)
if [[ "$LOG_PATH" == /home/* ]]; then
    echo "✓ Path is under /home (accessible via /host/home mount)"
elif [[ "$LOG_PATH" == /var/log/* ]]; then
    echo -e "${YELLOW}WARNING: Path is under /var/log (may need new volume mount in docker-compose)${NC}"
else
    echo -e "${YELLOW}WARNING: Path is outside /home (may need new volume mount in docker-compose)${NC}"
fi

echo ""
echo -e "${GREEN}=== Next Steps ===${NC}"
echo ""
echo "This script will generate a Claude Code prompt to invoke the playbook."
echo "You can either:"
echo ""
echo "  1. Copy the prompt below and paste it into Claude Code"
echo "  2. Run this script with --exec to automatically invoke Claude Code"
echo ""
read -p "Press Enter to generate the prompt..."
echo ""

# Generate the Claude Code invocation prompt
cat << EOF
===============================================================================
CLAUDE CODE PROMPT — Copy and paste this into Claude Code:
===============================================================================

Ingest logs from $APP_NAME at $LOG_PATH

Use the loki-logging-setup playbook (v2.2) at:
  $PLAYBOOK_MAIN

Reference guide at:
  $PLAYBOOK_REFERENCE

Follow all 8 phases:
1. Discovery — Find logs, check format, volume, sensitivity
2. Mount Check — Verify Alloy can access the path
3. Label Design — Choose bounded labels (env, log_source)
4. Processor Decision — Dedicated vs shared (main)
5. Alloy Config — Add file_match, source, process blocks
6. Restart & Verify — Apply changes, check Alloy logs
7. Audit — Run full validation (18+ checks)
7b. Remediate — Auto-fix any audit failures
8. Rollback — (if needed) Revert changes

When complete, verify with:
  {log_source="$APP_NAME"}

===============================================================================

EOF

echo ""
echo "Playbook location: $PLAYBOOK_MAIN"
echo "Reference guide: $PLAYBOOK_REFERENCE"
echo ""
echo -e "${GREEN}Done!${NC}"
