#!/usr/bin/env bash
# Config parser for log-truncation module
# Inspired by: /usr/local/bin/codeswarm-tidyup.sh (codeswarm-tidyup will be decommissioned)

# Load config file (source and validate)
load_config() {
    local config_file="$1"
    if [[ ! -f "$config_file" ]]; then
        error "Config file not found: $config_file"
        return 1
    fi

    # Source the config (bash-native)
    set -a  # Export all variables
    # shellcheck disable=SC1090
    source "$config_file"
    set +a

    # Validate required keys exist
    validate_config
}

# Validate required config keys
validate_config() {
    local required_keys=(
        "DEFAULT_ROTATE_COUNT"
        "JOURNAL_MAX_USE"
        "LOG_OWNER_USER"
        "USER_HOME"
    )

    for key in "${required_keys[@]}"; do
        if [[ -z "${!key}" ]]; then
            error "Required config key missing: $key"
            return 1
        fi
    done
}

# Get config value with fallback to default
get_value() {
    local key="$1"
    local default="$2"
    echo "${!key:-$default}"
}

# Check if service is enabled
is_enabled() {
    local service="$1"
    local enabled_key="${service}_ENABLED"
    local enabled="${!enabled_key:-true}"  # Default to true if not specified
    [[ "$enabled" == "true" ]]
}

# === HEALTH MONITORING FUNCTIONS (from codeswarm-tidyup) ===

# Get disk usage percentage
get_disk_usage_percent() {
    df / | tail -1 | awk '{print $5}' | sed 's/%//'
}

# Get disk free space in GB
get_disk_free_gb() {
    df / | tail -1 | awk '{print int($4/1024/1024)}'
}

# Get directory size in MB
get_size_mb() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        du -sm "$dir" 2>/dev/null | awk '{print $1}'
    else
        echo 0
    fi
}

# Get directory size in GB
get_size_gb() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        echo "scale=2; $(du -sm "$dir" 2>/dev/null | awk '{print $1}')/1024" | bc
    else
        echo 0
    fi
}

# Record health status to state file
record_health_status() {
    local status="$1"
    local details="$2"
    mkdir -p "$(dirname "$HEALTH_STATE_FILE")"
    echo "$(date +%s)|$status|$details" >> "$HEALTH_STATE_FILE"
}

# Alert function (logs to file and optionally sends notifications)
alert() {
    local level="$1"
    local message="$2"
    log "[$level] $message"
    # Future: Send email/webhook notification
}
