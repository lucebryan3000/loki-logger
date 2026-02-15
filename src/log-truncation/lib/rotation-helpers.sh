#!/usr/bin/env bash
# Shared helper functions for log rotation scripts

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

ok() {
    echo -e "${GREEN}[OK]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

section() {
    echo ""
    echo -e "${BLUE}=== $* ===${NC}"
    echo ""
}

step() {
    echo -e "${BLUE}→${NC} $*"
}

# Check if running as sudo
require_sudo() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run with sudo"
        exit 1
    fi
}

# Ask yes/no question
ask_yes_no() {
    local prompt="$1"
    read -p "$prompt [y/N] " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

# Log to file (uses LOG_FILE from config if loaded)
log() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" | tee -a "${LOG_FILE:-/tmp/log-truncation.log}"
}
