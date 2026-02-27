#!/bin/bash
# BuildFlowz Configuration File
# Centralized configuration for all scripts

# ============================================================================
# DIRECTORY CONFIGURATION
# ============================================================================

# Main projects directory where environments are created
# Defaults to $HOME (works for any user: /root for root, /home/user for others)
export BUILDFLOWZ_PROJECTS_DIR="${BUILDFLOWZ_PROJECTS_DIR:-$HOME}"

# Allowed safe directories for project paths
export BUILDFLOWZ_SAFE_DIRS=("/root" "/home" "/opt")

# Maximum depth for searching projects
export BUILDFLOWZ_MAX_SEARCH_DEPTH=4

# ============================================================================
# PORT CONFIGURATION
# ============================================================================

# Port range for PM2 applications
export BUILDFLOWZ_PORT_RANGE_START=3000
export BUILDFLOWZ_PORT_RANGE_END=3100
export BUILDFLOWZ_PORT_MAX_ATTEMPTS=100

# ============================================================================
# SSH TUNNEL CONFIGURATION
# ============================================================================

# SSH keep-alive settings
export BUILDFLOWZ_SSH_KEEPALIVE_INTERVAL=30
export BUILDFLOWZ_SSH_KEEPALIVE_MAX=3

# Default SSH configuration
export BUILDFLOWZ_SSH_REMOTE_USER="${BUILDFLOWZ_SSH_REMOTE_USER:-root}"
export BUILDFLOWZ_SSH_REMOTE_HOST="${BUILDFLOWZ_SSH_REMOTE_HOST:-hetzner}"

# ============================================================================
# LOGGING CONFIGURATION
# ============================================================================

# Enable/disable logging (true/false)
export BUILDFLOWZ_LOGGING_ENABLED="${BUILDFLOWZ_LOGGING_ENABLED:-true}"

# Log file location (defaults to user's home directory for proper permissions)
export BUILDFLOWZ_LOG_DIR="${BUILDFLOWZ_LOG_DIR:-$HOME/.buildflowz/logs}"
export BUILDFLOWZ_LOG_FILE="${BUILDFLOWZ_LOG_DIR}/buildflowz.log"

# Log retention (days)
export BUILDFLOWZ_LOG_RETENTION_DAYS=30

# Log level (DEBUG, INFO, WARNING, ERROR)
export BUILDFLOWZ_LOG_LEVEL="${BUILDFLOWZ_LOG_LEVEL:-INFO}"

# ============================================================================
# GITHUB CONFIGURATION
# ============================================================================

# Number of repos to list from GitHub
export BUILDFLOWZ_GITHUB_REPO_LIMIT=500

# ============================================================================
# WEB INSPECTOR CONFIGURATION
# ============================================================================

# Screenshot upload expiration (seconds)
export BUILDFLOWZ_SCREENSHOT_EXPIRATION=600

# ImgBB API key (free service)
export BUILDFLOWZ_IMGBB_API_KEY="${BUILDFLOWZ_IMGBB_API_KEY:-e6b9a93df250481a8cd214fbfbb8e7ba}"

# ============================================================================
# PERFORMANCE CONFIGURATION
# ============================================================================

# Enable PM2 data caching (reduces subprocess overhead)
export BUILDFLOWZ_PM2_CACHE_ENABLED="${BUILDFLOWZ_PM2_CACHE_ENABLED:-true}"

# Cache TTL in seconds
export BUILDFLOWZ_PM2_CACHE_TTL=5

# Prefer jq over python for JSON parsing (faster)
export BUILDFLOWZ_PREFER_JQ="${BUILDFLOWZ_PREFER_JQ:-true}"

# ============================================================================
# DISK SPACE CONFIGURATION
# ============================================================================

# Low disk warning threshold in GB (shows alert in menu header)
export BUILDFLOWZ_DISK_WARN_GB="${BUILDFLOWZ_DISK_WARN_GB:-5}"

# ============================================================================
# TOOL REQUIREMENTS
# ============================================================================

# Critical tools (script fails if missing)
export BUILDFLOWZ_REQUIRED_TOOLS=("pm2" "node")

# Optional tools (warnings only)
# jq is preferred over python3 for JSON parsing (faster)
export BUILDFLOWZ_OPTIONAL_TOOLS=("flox" "git" "jq" "python3")

# ============================================================================
# FLOX CONFIGURATION
# ============================================================================

# Default Flox packages to install for each project type
export BUILDFLOWZ_FLOX_NODEJS_PACKAGES="nodejs"
export BUILDFLOWZ_FLOX_PYTHON_PACKAGES="python3 python3Packages.pip"
export BUILDFLOWZ_FLOX_RUST_PACKAGES="rustc cargo"
export BUILDFLOWZ_FLOX_GO_PACKAGES="go"

# ============================================================================
# VALIDATION CONFIGURATION
# ============================================================================

# Regex for valid environment names
export BUILDFLOWZ_ENV_NAME_REGEX="^[a-zA-Z0-9._-]+$"

# Regex for dangerous path characters
export BUILDFLOWZ_DANGEROUS_CHARS_REGEX='[\;\&\|\$\`]'

# ============================================================================
# CADDY CONFIGURATION
# ============================================================================

# Caddyfile location
export BUILDFLOWZ_CADDYFILE="/etc/caddy/Caddyfile"

# ============================================================================
# SECRETS / CREDENTIAL CACHE CONFIGURATION
# ============================================================================

# Directory for storing cached credentials (chmod 700)
export BUILDFLOWZ_SECRETS_DIR="${BUILDFLOWZ_SECRETS_DIR:-$HOME/.buildflowz}"

# ============================================================================
# SESSION IDENTITY CONFIGURATION
# ============================================================================

# Session directory for storing identity files
export BUILDFLOWZ_SESSION_DIR="${BUILDFLOWZ_SESSION_DIR:-$HOME/.buildflowz/session}"

# Enable/disable session identity display
export BUILDFLOWZ_SESSION_ENABLED="${BUILDFLOWZ_SESSION_ENABLED:-true}"

# ============================================================================
# ERROR HANDLING CONFIGURATION
# ============================================================================

# Enable strict error handling (set -euo pipefail equivalent)
export BUILDFLOWZ_STRICT_MODE="${BUILDFLOWZ_STRICT_MODE:-false}"

# Enable error traps (cleanup on failure)
export BUILDFLOWZ_ERROR_TRAPS="${BUILDFLOWZ_ERROR_TRAPS:-true}"

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Print configuration (for debugging)
buildflowz_print_config() {
    echo "BuildFlowz Configuration:"
    echo "  Projects Dir: $BUILDFLOWZ_PROJECTS_DIR"
    echo "  Port Range: $BUILDFLOWZ_PORT_RANGE_START-$BUILDFLOWZ_PORT_RANGE_END"
    echo "  Logging: $BUILDFLOWZ_LOGGING_ENABLED"
    echo "  Log File: $BUILDFLOWZ_LOG_FILE"
    echo "  Log Level: $BUILDFLOWZ_LOG_LEVEL"
    echo "  PM2 Cache: $BUILDFLOWZ_PM2_CACHE_ENABLED"
}

# Validate configuration
buildflowz_validate_config() {
    local errors=0

    # Check projects directory exists
    if [ ! -d "$BUILDFLOWZ_PROJECTS_DIR" ]; then
        echo "ERROR: Projects directory does not exist: $BUILDFLOWZ_PROJECTS_DIR"
        ((errors++))
    fi

    # Check port range is valid
    if [ "$BUILDFLOWZ_PORT_RANGE_START" -ge "$BUILDFLOWZ_PORT_RANGE_END" ]; then
        echo "ERROR: Invalid port range"
        ((errors++))
    fi

    # Check log directory is writable
    if [ "$BUILDFLOWZ_LOGGING_ENABLED" = "true" ]; then
        mkdir -p "$BUILDFLOWZ_LOG_DIR" 2>/dev/null || {
            echo "WARNING: Cannot create log directory: $BUILDFLOWZ_LOG_DIR"
        }
    fi

    return $errors
}
