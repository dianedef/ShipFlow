#!/bin/bash
# ShipFlow Configuration File
# Centralized configuration for all scripts

# ============================================================================
# DIRECTORY CONFIGURATION
# ============================================================================

# Main projects directory where environments are created
# Defaults to $HOME (works for any user: /root for root, /home/user for others)
export SHIPFLOW_PROJECTS_DIR="${SHIPFLOW_PROJECTS_DIR:-$HOME}"

# Allowed safe directories for project paths
export SHIPFLOW_SAFE_DIRS=("/root" "/home" "/opt")

# Maximum depth for searching projects
export SHIPFLOW_MAX_SEARCH_DEPTH=4

# ============================================================================
# PORT CONFIGURATION
# ============================================================================

# Port range for PM2 applications
export SHIPFLOW_PORT_RANGE_START="${SHIPFLOW_PORT_RANGE_START:-3000}"
export SHIPFLOW_PORT_RANGE_END="${SHIPFLOW_PORT_RANGE_END:-3100}"
export SHIPFLOW_PORT_MAX_ATTEMPTS="${SHIPFLOW_PORT_MAX_ATTEMPTS:-100}"

# ============================================================================
# SSH TUNNEL CONFIGURATION
# ============================================================================

# SSH keep-alive settings
export SHIPFLOW_SSH_KEEPALIVE_INTERVAL="${SHIPFLOW_SSH_KEEPALIVE_INTERVAL:-30}"
export SHIPFLOW_SSH_KEEPALIVE_MAX="${SHIPFLOW_SSH_KEEPALIVE_MAX:-3}"

# Default SSH configuration
export SHIPFLOW_SSH_REMOTE_USER="${SHIPFLOW_SSH_REMOTE_USER:-root}"
export SHIPFLOW_SSH_REMOTE_HOST="${SHIPFLOW_SSH_REMOTE_HOST:-hetzner}"

# Extra static tunnel ports (comma-separated, port:label format)
# These are always tunneled in addition to PM2-detected ports
export SHIPFLOW_EXTRA_TUNNELS="${SHIPFLOW_EXTRA_TUNNELS:-3773:t3-code}"

# ============================================================================
# LOGGING CONFIGURATION
# ============================================================================

# Enable/disable logging (true/false)
export SHIPFLOW_LOGGING_ENABLED="${SHIPFLOW_LOGGING_ENABLED:-true}"

# Log file location (defaults to user's home directory for proper permissions)
export SHIPFLOW_LOG_DIR="${SHIPFLOW_LOG_DIR:-$HOME/.shipflow/logs}"
export SHIPFLOW_LOG_FILE="${SHIPFLOW_LOG_FILE:-$SHIPFLOW_LOG_DIR/shipflow.log}"

# Log retention (days)
export SHIPFLOW_LOG_RETENTION_DAYS="${SHIPFLOW_LOG_RETENTION_DAYS:-30}"

# Log level (DEBUG, INFO, WARNING, ERROR)
export SHIPFLOW_LOG_LEVEL="${SHIPFLOW_LOG_LEVEL:-INFO}"

# ============================================================================
# GITHUB CONFIGURATION
# ============================================================================

# Number of repos to list from GitHub
export SHIPFLOW_GITHUB_REPO_LIMIT="${SHIPFLOW_GITHUB_REPO_LIMIT:-500}"

# ============================================================================
# DEV TOOLS CONFIGURATION (Inspector & Eruda)
# ============================================================================

# Default state for new projects (when .shipflow-tools.conf doesn't exist)
export SHIPFLOW_INSPECTOR_DEFAULT="${SHIPFLOW_INSPECTOR_DEFAULT:-enabled}"
export SHIPFLOW_ERUDA_DEFAULT="${SHIPFLOW_ERUDA_DEFAULT:-enabled}"

# Screenshot upload expiration (seconds)
export SHIPFLOW_SCREENSHOT_EXPIRATION="${SHIPFLOW_SCREENSHOT_EXPIRATION:-600}"

# ImgBB API key (free service)
export SHIPFLOW_IMGBB_API_KEY="${SHIPFLOW_IMGBB_API_KEY:-e6b9a93df250481a8cd214fbfbb8e7ba}"

# ============================================================================
# PERFORMANCE CONFIGURATION
# ============================================================================

# Enable PM2 data caching (reduces subprocess overhead)
export SHIPFLOW_PM2_CACHE_ENABLED="${SHIPFLOW_PM2_CACHE_ENABLED:-true}"

# Cache TTL in seconds
export SHIPFLOW_PM2_CACHE_TTL="${SHIPFLOW_PM2_CACHE_TTL:-5}"

# Prefer jq over python for JSON parsing (faster)
export SHIPFLOW_PREFER_JQ="${SHIPFLOW_PREFER_JQ:-true}"

# ============================================================================
# HEALTH MONITORING CONFIGURATION
# ============================================================================

# Enable crash loop detection in dashboard
export SHIPFLOW_HEALTH_CHECK_ENABLED="${SHIPFLOW_HEALTH_CHECK_ENABLED:-true}"

# Restart count above which an app is considered in a crash loop
export SHIPFLOW_CRASH_LOOP_THRESHOLD="${SHIPFLOW_CRASH_LOOP_THRESHOLD:-10}"

# Uptime (seconds) below which a running app is considered unstable
export SHIPFLOW_UNSTABLE_UPTIME_SECS="${SHIPFLOW_UNSTABLE_UPTIME_SECS:-30}"

# Known error patterns to auto-diagnose (pipe-separated)
# Each entry: "pattern|human-readable label|auto-fix hint"
export SHIPFLOW_KNOWN_ERROR_PATTERNS=(
    "Unable to acquire lock|Stale lock file (.next/dev/lock)|Remove .next/dev/lock and restart"
    "EADDRINUSE|Port already in use|Kill process on port or change PORT"
    "Cannot find module|Missing dependency|Run npm install / pnpm install"
    "not found$|Command not found (missing dependency or PATH)|Run npm install / pnpm install in project dir"
    "ENOSPC|Disk full or inotify limit|Free disk space or increase fs.inotify.max_user_watches"
    "content collection.*frontmatter\|zod.*validation\|ZodError|Invalid content file (empty or bad frontmatter)|Fix or rename file with _ prefix"
    "SyntaxError|Syntax error in source code|Check recent file changes"
    "ExperimentalWarning.*fetch|Node.js fetch warning (non-fatal)|Ignorable — upgrade Node.js if persistent"
)

# ============================================================================
# DISK SPACE CONFIGURATION
# ============================================================================

# Low disk warning threshold in GB (shows alert in menu header)
export SHIPFLOW_DISK_WARN_GB="${SHIPFLOW_DISK_WARN_GB:-5}"

# Menu status cache TTL in seconds (free space + update counts)
export SHIPFLOW_MENU_STATUS_CACHE_TTL="${SHIPFLOW_MENU_STATUS_CACHE_TTL:-120}"

# ============================================================================
# TOOL REQUIREMENTS
# ============================================================================

# Critical tools (script fails if missing)
export SHIPFLOW_REQUIRED_TOOLS=("pm2" "node")

# Optional tools (warnings only)
# jq is preferred over python3 for JSON parsing (faster)
export SHIPFLOW_OPTIONAL_TOOLS=("flox" "git" "jq" "python3")

# ============================================================================
# FLOX CONFIGURATION
# ============================================================================

# Default Flox packages to install for each project type
export SHIPFLOW_FLOX_NODEJS_PACKAGES="nodejs"
export SHIPFLOW_FLOX_PYTHON_PACKAGES="python3 python3Packages.pip"
export SHIPFLOW_FLOX_RUST_PACKAGES="rustc cargo"
export SHIPFLOW_FLOX_GO_PACKAGES="go"

# ============================================================================
# VALIDATION CONFIGURATION
# ============================================================================

# Regex for valid environment names
export SHIPFLOW_ENV_NAME_REGEX="^[a-zA-Z0-9._-]+$"

# Regex for dangerous path characters
export SHIPFLOW_DANGEROUS_CHARS_REGEX='[\;\&\|\$\`]'

# ============================================================================
# CADDY CONFIGURATION
# ============================================================================

# Caddyfile location
export SHIPFLOW_CADDYFILE="${SHIPFLOW_CADDYFILE:-/etc/caddy/Caddyfile}"

# ============================================================================
# SECRETS / CREDENTIAL CACHE CONFIGURATION
# ============================================================================

# Directory for storing cached credentials (chmod 700)
export SHIPFLOW_SECRETS_DIR="${SHIPFLOW_SECRETS_DIR:-$HOME/.shipflow}"

# ============================================================================
# SESSION IDENTITY CONFIGURATION
# ============================================================================

# Session directory for storing identity files
export SHIPFLOW_SESSION_DIR="${SHIPFLOW_SESSION_DIR:-$SHIPFLOW_SECRETS_DIR/session}"

# Enable/disable session identity display
export SHIPFLOW_SESSION_ENABLED="${SHIPFLOW_SESSION_ENABLED:-true}"

# ============================================================================
# ERROR HANDLING CONFIGURATION
# ============================================================================

# Enable strict error handling (set -euo pipefail equivalent)
export SHIPFLOW_STRICT_MODE="${SHIPFLOW_STRICT_MODE:-false}"

# Enable error traps (cleanup on failure)
export SHIPFLOW_ERROR_TRAPS="${SHIPFLOW_ERROR_TRAPS:-true}"

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Print configuration (for debugging)
shipflow_print_config() {
    echo "ShipFlow Configuration:"
    echo "  Projects Dir: $SHIPFLOW_PROJECTS_DIR"
    echo "  Port Range: $SHIPFLOW_PORT_RANGE_START-$SHIPFLOW_PORT_RANGE_END"
    echo "  Logging: $SHIPFLOW_LOGGING_ENABLED"
    echo "  Log File: $SHIPFLOW_LOG_FILE"
    echo "  Log Level: $SHIPFLOW_LOG_LEVEL"
    echo "  PM2 Cache: $SHIPFLOW_PM2_CACHE_ENABLED"
}

# Validate configuration
shipflow_validate_config() {
    local errors=0

    if [ ! -d "$SHIPFLOW_PROJECTS_DIR" ]; then
        echo "ERROR: Projects directory does not exist: $SHIPFLOW_PROJECTS_DIR"
        ((errors++))
    fi

    if [ "$SHIPFLOW_PORT_RANGE_START" -ge "$SHIPFLOW_PORT_RANGE_END" ]; then
        echo "ERROR: Invalid port range"
        ((errors++))
    fi

    if [ "$SHIPFLOW_LOGGING_ENABLED" = "true" ]; then
        mkdir -p "$SHIPFLOW_LOG_DIR" 2>/dev/null || {
            echo "WARNING: Cannot create log directory: $SHIPFLOW_LOG_DIR"
        }
    fi

    return $errors
}
