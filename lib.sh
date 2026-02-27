#!/bin/bash
# ============================================================================
# BuildFlowz Shared Library
# ============================================================================
#
# Description:
#   Core library containing all reusable functions for BuildFlowz CLI.
#   Handles environment management, PM2 operations, port allocation,
#   Flox integration, validation, logging, and caching.
#
# Dependencies:
#   - pm2 (required)
#   - node (required)
#   - flox (optional)
#   - git (optional)
#   - jq (optional, preferred for JSON parsing)
#   - python3 (optional, fallback for JSON parsing)
#
# Author: BuildFlowz Team
# Version: 2.0.0
# Date: 2026-01-24
# ============================================================================

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration
source "$SCRIPT_DIR/config.sh"

# ============================================================================
# ERROR HANDLING SETUP
# ============================================================================

# Enable strict mode if configured
if [ "$BUILDFLOWZ_STRICT_MODE" = "true" ]; then
    set -euo pipefail
fi

# Error trap handler
error_trap_handler() {
    local exit_code=$?
    local line_number=$1
    log ERROR "Script failed at line $line_number with exit code $exit_code"
    error "Script execution failed (line $line_number, code $exit_code)"
}

# Install error trap if configured
if [ "$BUILDFLOWZ_ERROR_TRAPS" = "true" ]; then
    trap 'error_trap_handler ${LINENO}' ERR
fi

# Cleanup trap for temporary files
TEMP_FILES=()
cleanup_temp_files() {
    for file in "${TEMP_FILES[@]}"; do
        [ -f "$file" ] && rm -f "$file" 2>/dev/null || true
    done
}
trap cleanup_temp_files EXIT

# Register a temp file for cleanup
register_temp_file() {
    TEMP_FILES+=("$1")
}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Config (use centralized config values)
PROJECTS_DIR="${BUILDFLOWZ_PROJECTS_DIR}"

# ============================================================================
# GUM DETECTION & UI WRAPPERS
# ============================================================================

# Detect gum availability (don't auto-install)
if gum --version >/dev/null 2>&1; then
    HAS_GUM=true
else
    HAS_GUM=false
fi

# -----------------------------------------------------------------------------
# ui_choose - Interactive selection (gum choose || numbered list)
#
# Arguments:
#   $1 - Prompt text
#   Remaining args or stdin - Options to choose from
#
# Outputs:
#   Selected value to stdout
#
# Returns:
#   1 if cancelled or no selection
# -----------------------------------------------------------------------------
ui_choose() {
    local prompt="$1"
    shift

    if [ "$HAS_GUM" = true ]; then
        if [ $# -gt 0 ]; then
            printf '%s\n' "$@" | gum choose --header "$prompt"
        else
            gum choose --header "$prompt"
        fi
    else
        # Numbered list fallback
        local options=()
        if [ $# -gt 0 ]; then
            options=("$@")
        else
            while IFS= read -r line; do
                options+=("$line")
            done
        fi

        if [ ${#options[@]} -eq 0 ]; then
            return 1
        fi

        echo -e "${BLUE}$prompt${NC}" >&2
        echo "" >&2
        local i=1
        for opt in "${options[@]}"; do
            echo -e "  ${CYAN}$i)${NC} $opt" >&2
            ((i++))
        done
        echo "" >&2
        echo -e "  ${CYAN}0)${NC} Cancel" >&2
        echo "" >&2
        echo -e "${YELLOW}Choose (0-$((i-1))):${NC} \c" >&2
        read -r choice

        if [[ "$choice" == "0" ]] || [ -z "$choice" ]; then
            return 1
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le $((i-1)) ]; then
            echo "${options[$((choice-1))]}"
            return 0
        else
            echo -e "${RED}Invalid choice${NC}" >&2
            return 1
        fi
    fi
}

# -----------------------------------------------------------------------------
# ui_input - Text input (gum input || read)
#
# Arguments:
#   $1 - Prompt text
#   $2 - Placeholder text (optional)
#   $3 - "--password" for hidden input (optional)
#
# Outputs:
#   User input to stdout
# -----------------------------------------------------------------------------
ui_input() {
    local prompt="$1"
    local placeholder="${2:-}"
    local password_flag="${3:-}"

    if [ "$HAS_GUM" = true ]; then
        if [ "$password_flag" = "--password" ]; then
            gum input --placeholder "$placeholder" --password
        elif [ -n "$placeholder" ]; then
            gum input --placeholder "$placeholder"
        else
            gum input --placeholder "$prompt"
        fi
    else
        if [ "$password_flag" = "--password" ]; then
            echo -e "${YELLOW}${prompt}${NC} \c" >&2
            read -rs value
            echo "" >&2
            echo "$value"
        else
            echo -e "${YELLOW}${prompt}${NC} \c" >&2
            read -r value
            echo "$value"
        fi
    fi
}

# -----------------------------------------------------------------------------
# ui_confirm - Yes/no confirmation (gum confirm || read)
#
# Arguments:
#   $1 - Prompt text
#
# Returns:
#   0 for yes, 1 for no
# -----------------------------------------------------------------------------
ui_confirm() {
    local prompt="$1"

    if [ "$HAS_GUM" = true ]; then
        gum confirm "$prompt"
    else
        echo -e "${YELLOW}${prompt} (y/N):${NC} \c" >&2
        read -r answer
        case "$answer" in
            [yY]|[yY][eE][sS]) return 0 ;;
            *) return 1 ;;
        esac
    fi
}

# -----------------------------------------------------------------------------
# ui_header - Styled header (gum style || ANSI echo)
#
# Arguments:
#   $1 - Title text
#   $2 - Subtitle (optional)
#   $3 - Status left (optional, shown at top-left)
#   $4 - Status right (optional, shown at top-right)
# -----------------------------------------------------------------------------
ui_header() {
    local title="$1"
    local subtitle="${2:-}"
    local status_left="${3:-}"
    local status_right="${4:-}"
    local width=50
    local content_width=46

    local status_line=""
    if [ -n "$status_left" ] || [ -n "$status_right" ]; then
        local left="$status_left"
        local right="$status_right"
        local left_len=${#left}
        local right_len=${#right}
        local max_right=$((content_width - left_len - 1))
        if [ $max_right -lt 0 ]; then
            max_right=0
        fi
        if [ $right_len -gt $max_right ]; then
            right=${right:0:$max_right}
            right_len=${#right}
        fi
        local spaces=$((content_width - left_len - right_len))
        if [ $spaces -lt 1 ]; then
            spaces=1
        fi
        status_line="${left}$(printf '%*s' "$spaces" '')${right}"
    fi

    center_line() {
        local text="$1"
        local text_len=${#text}
        if [ $text_len -ge $content_width ]; then
            echo "${text:0:$content_width}"
            return
        fi
        local pad=$(( (content_width - text_len) / 2 ))
        printf "%*s%s" "$pad" "" "$text"
    }

    if [ "$HAS_GUM" = true ]; then
        local header_lines=()
        if [ -n "$status_line" ]; then
            header_lines+=("$status_line" "")
        fi
        header_lines+=("$(center_line "$title")")
        if [ -n "$subtitle" ]; then
            header_lines+=("$(center_line "$subtitle")")
        fi

        gum style \
            --foreground 212 --border-foreground 212 --border double \
            --align left --width 50 --margin "1 2" --padding "1 2" \
            "${header_lines[@]}"
    else
        echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
        if [ -n "$status_line" ]; then
            echo -e " ${GREEN}${status_line}${NC}"
            echo -e "${CYAN}--------------------------------------------------${NC}"
        fi
        printf " %s\n" "$(center_line "$title")" | sed "s/^/${YELLOW}/;s/\$/${NC}/"
        if [ -n "$subtitle" ]; then
            printf " %s\n" "$(center_line "$subtitle")" | sed "s/^/${BLUE}/;s/\$/${NC}/"
        fi
        echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    fi
}

# -----------------------------------------------------------------------------
# ui_spinner - Loading indicator (gum spin || echo + run)
#
# Arguments:
#   $1 - Title/message
#   $2+ - Command to run
# -----------------------------------------------------------------------------
ui_spinner() {
    local title="$1"
    shift

    if [ "$HAS_GUM" = true ]; then
        gum spin --spinner dot --title "$title" -- "$@"
    else
        echo -e "${BLUE}${title}${NC}" >&2
        "$@"
    fi
}

# ============================================================================
# DISK CLEANUP UTILITIES
# ============================================================================

disk_free_bytes() {
    df -B1 --output=avail / 2>/dev/null | tail -n 1 | tr -d ' '
}

disk_free_human() {
    df -h --output=avail / 2>/dev/null | tail -n 1 | tr -d ' '
}

disk_warn_threshold_bytes() {
    local gb="${BUILDFLOWZ_DISK_WARN_GB:-5}"
    if ! [[ "$gb" =~ ^[0-9]+$ ]]; then
        gb=5
    fi
    echo $((gb * 1024 * 1024 * 1024))
}

disk_is_low_space() {
    local free_bytes
    free_bytes=$(disk_free_bytes)
    local threshold
    threshold=$(disk_warn_threshold_bytes)
    [ -n "$free_bytes" ] && [ -n "$threshold" ] && [ "$free_bytes" -lt "$threshold" ]
}

format_bytes() {
    local bytes="$1"
    if command -v numfmt >/dev/null 2>&1; then
        numfmt --to=iec --suffix=B "$bytes"
    else
        echo "${bytes}B"
    fi
}

cleanup_disk_light() {
    rm -rf "$HOME/.cache/yarn" \
        "$HOME/.cache/pip" \
        "$HOME/.cache/pnpm" \
        "$HOME/.npm/_cacache" 2>/dev/null || true
}

cleanup_disk_aggressive() {
    cleanup_disk_light
    rm -rf "$HOME/.npm" \
        "$HOME/.local/share/pnpm" 2>/dev/null || true
}

disk_cleanup_menu() {
    echo -e "${GREEN}🧹 Disk Cleanup${NC}"
    echo ""

    local before_bytes
    before_bytes=$(disk_free_bytes)
    local before_human
    before_human=$(disk_free_human)

    echo -e "${BLUE}Free space before:${NC} ${GREEN}${before_human}${NC}"
    echo ""

    local choice
    choice=$(printf "%s\n%s\n%s" \
        "Light (safe caches only)" \
        "Aggressive (includes npm + pnpm caches)" \
        "Cancel" | ui_choose "Cleanup level:")

    if [ -z "$choice" ] || [ "$choice" = "Cancel" ]; then
        echo -e "${BLUE}Cancelled${NC}"
        return 0
    fi

    echo ""
    if [ "$choice" = "Light (safe caches only)" ]; then
        echo -e "${YELLOW}This will remove:${NC}"
        echo -e "  ${CYAN}•${NC} ~/.cache/yarn"
        echo -e "  ${CYAN}•${NC} ~/.cache/pip"
        echo -e "  ${CYAN}•${NC} ~/.cache/pnpm"
        echo -e "  ${CYAN}•${NC} ~/.npm/_cacache"
        echo ""
        if ! ui_confirm "Proceed with light cleanup?"; then
            echo -e "${BLUE}Cancelled${NC}"
            return 0
        fi
        cleanup_disk_light
    else
        echo -e "${YELLOW}This will remove:${NC}"
        echo -e "  ${CYAN}•${NC} ~/.cache/yarn"
        echo -e "  ${CYAN}•${NC} ~/.cache/pip"
        echo -e "  ${CYAN}•${NC} ~/.cache/pnpm"
        echo -e "  ${CYAN}•${NC} ~/.npm/_cacache"
        echo -e "  ${CYAN}•${NC} ~/.npm"
        echo -e "  ${CYAN}•${NC} ~/.local/share/pnpm"
        echo ""
        if ! ui_confirm "Proceed with aggressive cleanup?"; then
            echo -e "${BLUE}Cancelled${NC}"
            return 0
        fi
        cleanup_disk_aggressive
    fi

    local after_bytes
    after_bytes=$(disk_free_bytes)
    local after_human
    after_human=$(disk_free_human)

    echo ""
    echo -e "${BLUE}Free space after:${NC} ${GREEN}${after_human}${NC}"

    if [ -n "$before_bytes" ] && [ -n "$after_bytes" ] && [ "$after_bytes" -ge "$before_bytes" ]; then
        local freed=$((after_bytes - before_bytes))
        echo -e "${GREEN}Recovered:${NC} $(format_bytes "$freed")"
    fi
}

# ============================================================================
# UPDATE CHECK UTILITIES
# ============================================================================

UPDATE_CACHE_TIME=0
UPDATE_CACHE_TOTAL=""
UPDATE_CACHE_APT=0
UPDATE_CACHE_NPM=0
UPDATE_CACHE_PIP=0
UPDATE_CACHE_RUSTUP=0
UPDATE_CACHE_TTL=300

run_with_timeout() {
    if command -v timeout >/dev/null 2>&1; then
        timeout 6s "$@"
    else
        "$@"
    fi
}

count_apt_updates() {
    if ! command -v apt >/dev/null 2>&1; then
        echo 0
        return
    fi
    local out
    out=$(run_with_timeout apt list --upgradable 2>/dev/null || true)
    echo "$out" | tail -n +2 | sed '/^$/d' | wc -l
}

count_npm_updates() {
    if ! command -v npm >/dev/null 2>&1; then
        echo 0
        return
    fi
    local out
    out=$(run_with_timeout npm -g outdated --parseable --depth=0 2>/dev/null || true)
    echo "$out" | sed '/^$/d' | wc -l
}

count_pip_updates() {
    if command -v python3 >/dev/null 2>&1; then
        local out
        out=$(run_with_timeout python3 -m pip list --outdated --format=columns 2>/dev/null || true)
        echo "$out" | tail -n +3 | sed '/^$/d' | wc -l
        return
    fi
    if command -v pip >/dev/null 2>&1; then
        local out
        out=$(run_with_timeout pip list --outdated --format=columns 2>/dev/null || true)
        echo "$out" | tail -n +3 | sed '/^$/d' | wc -l
        return
    fi
    echo 0
}

count_rustup_updates() {
    if ! command -v rustup >/dev/null 2>&1; then
        echo 0
        return
    fi
    local out
    out=$(run_with_timeout rustup update --check 2>/dev/null || true)
    echo "$out" | grep -ci "available"
}

updates_refresh_cache() {
    local now
    now=$(date +%s)
    if [ $((now - UPDATE_CACHE_TIME)) -lt $UPDATE_CACHE_TTL ] && [ -n "$UPDATE_CACHE_TOTAL" ]; then
        return
    fi

    UPDATE_CACHE_APT=$(count_apt_updates)
    UPDATE_CACHE_NPM=$(count_npm_updates)
    UPDATE_CACHE_PIP=$(count_pip_updates)
    UPDATE_CACHE_RUSTUP=$(count_rustup_updates)

    UPDATE_CACHE_TOTAL=$((UPDATE_CACHE_APT + UPDATE_CACHE_NPM + UPDATE_CACHE_PIP + UPDATE_CACHE_RUSTUP))
    UPDATE_CACHE_TIME=$now
}

updates_total_cached() {
    updates_refresh_cache
    echo "$UPDATE_CACHE_TOTAL"
}

updates_menu() {
    updates_refresh_cache

    echo -e "${GREEN}⬆️  Updates Summary${NC}"
    echo ""
    echo -e "${BLUE}Pending updates:${NC}"
    echo -e "  ${CYAN}•${NC} apt:     ${YELLOW}${UPDATE_CACHE_APT}${NC}"
    echo -e "  ${CYAN}•${NC} npm -g:  ${YELLOW}${UPDATE_CACHE_NPM}${NC}"
    echo -e "  ${CYAN}•${NC} pip:     ${YELLOW}${UPDATE_CACHE_PIP}${NC}"
    echo -e "  ${CYAN}•${NC} rustup:  ${YELLOW}${UPDATE_CACHE_RUSTUP}${NC}"
    echo -e "  ${CYAN}•${NC} Total:   ${GREEN}${UPDATE_CACHE_TOTAL}${NC}"
    echo ""

    echo -e "${BLUE}Options:${NC}"
    echo -e "  ${CYAN}1)${NC} Update All"
    echo -e "  ${CYAN}0)${NC} Back"
    echo ""
    echo -e "${YELLOW}Your choice:${NC} \c"
    read -r update_choice

    case $update_choice in
        1)
            echo -e "${YELLOW}This will run system and global package updates.${NC}"
            if ! ui_confirm "Proceed with Update All?"; then
                echo -e "${BLUE}Cancelled${NC}"
                return 0
            fi

            if command -v apt >/dev/null 2>&1; then
                echo -e "${GREEN}🔧 Updating apt...${NC}"
                sudo apt update && sudo apt upgrade -y
            fi

            if command -v npm >/dev/null 2>&1; then
                echo -e "${GREEN}🔧 Updating npm globals...${NC}"
                npm -g update
            fi

            if command -v python3 >/dev/null 2>&1; then
                echo -e "${GREEN}🔧 Updating pip packages...${NC}"
                python3 -m pip list --outdated --format=freeze 2>/dev/null | cut -d= -f1 | \
                    xargs -n1 python3 -m pip install -U 2>/dev/null || true
            elif command -v pip >/dev/null 2>&1; then
                echo -e "${GREEN}🔧 Updating pip packages...${NC}"
                pip list --outdated --format=freeze 2>/dev/null | cut -d= -f1 | \
                    xargs -n1 pip install -U 2>/dev/null || true
            fi

            if command -v rustup >/dev/null 2>&1; then
                echo -e "${GREEN}🔧 Updating rustup toolchains...${NC}"
                rustup update
            fi

            echo -e "${GREEN}✅ Updates complete${NC}"
            UPDATE_CACHE_TIME=0
            updates_refresh_cache
            ;;
        *)
            ;;
    esac
}

# ============================================================================
# ENVIRONMENT SELECTION
# ============================================================================

# -----------------------------------------------------------------------------
# select_environment - Interactive environment picker with status icons
#
# Arguments:
#   $1 - Prompt text (optional, default: "Select an environment")
#
# Outputs:
#   Selected environment name to stdout
#
# Returns:
#   0 - Selection made
#   1 - Cancelled or no environments
# -----------------------------------------------------------------------------
select_environment() {
    local prompt_text="${1:-Select an environment}"

    local all_envs=$(list_all_environments)

    if [ -z "$all_envs" ]; then
        echo -e "${RED}No environments found${NC}" >&2
        return 1
    fi

    # Build options with status icons
    local options=()
    while IFS= read -r env; do
        local status=$(get_pm2_status "$env")
        local icon=$(get_status_icon "$status")
        options+=("${icon} ${env}")
    done <<< "$all_envs"

    # Use ui_choose for selection
    local selected
    selected=$(ui_choose "$prompt_text" "${options[@]}") || return 1

    # Strip the icon prefix to return just the environment name
    echo "$selected" | sed 's/^[^ ]* //'
    return 0
}

# ============================================================================
# CREDENTIAL CACHE
# ============================================================================

# Secrets file path
BUILDFLOWZ_SECRETS_FILE="${BUILDFLOWZ_SECRETS_DIR}/secrets"

# -----------------------------------------------------------------------------
# save_secret - Save a key=value pair to the secrets file
#
# Arguments:
#   $1 - Key name
#   $2 - Value (will NOT be logged or echoed)
#
# Side Effects:
#   Creates ~/.buildflowz/ (chmod 700) and secrets file (chmod 600) if needed
# -----------------------------------------------------------------------------
save_secret() {
    local key="$1"
    local value="$2"

    # Create directory with restricted permissions
    if [ ! -d "$BUILDFLOWZ_SECRETS_DIR" ]; then
        mkdir -p "$BUILDFLOWZ_SECRETS_DIR"
        chmod 700 "$BUILDFLOWZ_SECRETS_DIR"
    fi

    # Create or update secrets file
    if [ ! -f "$BUILDFLOWZ_SECRETS_FILE" ]; then
        touch "$BUILDFLOWZ_SECRETS_FILE"
        chmod 600 "$BUILDFLOWZ_SECRETS_FILE"
    else
        # Ensure permissions are correct
        chmod 600 "$BUILDFLOWZ_SECRETS_FILE"
    fi

    # Update existing key or append new one
    if grep -q "^${key}=" "$BUILDFLOWZ_SECRETS_FILE" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$BUILDFLOWZ_SECRETS_FILE"
    else
        echo "${key}=${value}" >> "$BUILDFLOWZ_SECRETS_FILE"
    fi

    log INFO "Secret saved: $key (value hidden)"
}

# -----------------------------------------------------------------------------
# load_secret - Load a value from the secrets file
#
# Arguments:
#   $1 - Key name
#
# Outputs:
#   Value to stdout
#
# Returns:
#   0 - Key found
#   1 - Key not found or file doesn't exist
# -----------------------------------------------------------------------------
load_secret() {
    local key="$1"

    if [ ! -f "$BUILDFLOWZ_SECRETS_FILE" ]; then
        return 1
    fi

    local value
    value=$(grep "^${key}=" "$BUILDFLOWZ_SECRETS_FILE" 2>/dev/null | head -1 | cut -d'=' -f2-)

    if [ -z "$value" ]; then
        return 1
    fi

    echo "$value"
    return 0
}

# ============================================================================
# STRUCTURED LOGGING
# ============================================================================

# Ensure log directory exists
init_logging() {
    if [ "$BUILDFLOWZ_LOGGING_ENABLED" = "true" ]; then
        mkdir -p "$BUILDFLOWZ_LOG_DIR" 2>/dev/null || true

        # Rotate old logs
        if [ -f "$BUILDFLOWZ_LOG_FILE" ]; then
            local log_size=$(stat -f%z "$BUILDFLOWZ_LOG_FILE" 2>/dev/null || stat -c%s "$BUILDFLOWZ_LOG_FILE" 2>/dev/null || echo 0)
            # Rotate if larger than 10MB
            if [ "$log_size" -gt 10485760 ]; then
                mv "$BUILDFLOWZ_LOG_FILE" "$BUILDFLOWZ_LOG_FILE.$(date +%s)" 2>/dev/null || true

                # Clean old logs
                find "$BUILDFLOWZ_LOG_DIR" -name "*.log.*" -mtime +$BUILDFLOWZ_LOG_RETENTION_DAYS -delete 2>/dev/null || true
            fi
        fi
    fi
}

# Structured logging function
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Check if logging is enabled
    if [ "$BUILDFLOWZ_LOGGING_ENABLED" != "true" ]; then
        return 0
    fi

    # Check log level filtering
    local level_priority=0
    case "$level" in
        DEBUG) level_priority=0 ;;
        INFO) level_priority=1 ;;
        WARNING) level_priority=2 ;;
        ERROR) level_priority=3 ;;
    esac

    local config_priority=1  # Default to INFO
    case "$BUILDFLOWZ_LOG_LEVEL" in
        DEBUG) config_priority=0 ;;
        INFO) config_priority=1 ;;
        WARNING) config_priority=2 ;;
        ERROR) config_priority=3 ;;
    esac

    # Only log if level meets threshold
    if [ $level_priority -lt $config_priority ]; then
        return 0
    fi

    # Format: [TIMESTAMP] [LEVEL] message
    local log_entry="[$timestamp] [$level] $message"

    # Append to log file
    echo "$log_entry" >> "$BUILDFLOWZ_LOG_FILE" 2>/dev/null || true
}

# Initialize logging on load
init_logging

# ============================================================================
# JSON PARSING UTILITIES (Priority 3 #9: jq over Python)
# ============================================================================

# -----------------------------------------------------------------------------
# parse_json - Parse JSON data with jq or python fallback
#
# Description:
#   Parses JSON using jq if available (faster), falls back to python3.
#   Automatically chooses best available tool.
#
# Arguments:
#   $1 - JQ expression (e.g., '.[] | .name')
#   stdin - JSON data to parse
#
# Returns:
#   Parsed output
#
# Example:
#   echo '{"name":"test"}' | parse_json '.name'
# -----------------------------------------------------------------------------
parse_json() {
    local jq_expr=$1

    # Prefer jq if available and configured
    if [ "$BUILDFLOWZ_PREFER_JQ" = "true" ] && command -v jq >/dev/null 2>&1; then
        jq -r "$jq_expr" 2>/dev/null || {
            log ERROR "jq parsing failed with expression: $jq_expr"
            return 1
        }
    elif command -v python3 >/dev/null 2>&1; then
        # Fallback to python3
        # Convert jq expression to python (basic support)
        python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    # Note: This is a simplified fallback, not full jq compatibility
    print(data)
except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null || {
            log ERROR "python3 JSON parsing failed"
            return 1
        }
    else
        log ERROR "No JSON parser available (install jq or python3)"
        error "No JSON parser available"
        return 1
    fi
}

# ============================================================================
# PREREQUISITE & VALIDATION FUNCTIONS
# ============================================================================

# -----------------------------------------------------------------------------
# check_prerequisites - Validate required and optional tools are installed
#
# Description:
#   Checks for critical tools (pm2, node) and warns about missing optional
#   tools (flox, git, jq, python3). Fails if critical tools are missing.
#
# Arguments:
#   None
#
# Returns:
#   0 - All required tools present
#   1 - Missing required tools
#
# Outputs:
#   Error messages for missing required tools
#   Warning messages for missing optional tools
#
# Example:
#   check_prerequisites || exit 1
# -----------------------------------------------------------------------------
check_prerequisites() {
    local missing=()
    local warnings=()

    # Critical tools
    for cmd in pm2 node; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done

    # Optional but recommended tools
    for cmd in flox git python3; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            warnings+=("$cmd")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        error "Missing required tools: ${missing[*]}"
        info "Run: ./install.sh or install manually"
        return 1
    fi

    if [ ${#warnings[@]} -gt 0 ]; then
        warning "Optional tools missing: ${warnings[*]}"
        info "Some features may not work properly"
    fi

    return 0
}

# -----------------------------------------------------------------------------
# validate_project_path - Validate project directory path for security
#
# Description:
#   Validates a project path to prevent security vulnerabilities:
#   - Path traversal attacks (.. sequences)
#   - Command injection (special characters)
#   - Access to unsafe directories
#   - Non-existent paths
#
# Arguments:
#   $1 - Path to validate
#
# Returns:
#   0 - Path is valid and safe
#   1 - Path is invalid or unsafe
#
# Security:
#   Blocks: .., ;, &, |, $, backticks
#   Allows only: /root/*, /home/*, /opt/*
#
# Example:
#   validate_project_path "/root/myapp" || exit 1
# -----------------------------------------------------------------------------
validate_project_path() {
    local path=$1

    # Must not be empty
    if [ -z "$path" ]; then
        error "Path cannot be empty"
        return 1
    fi

    # Must be absolute path
    if [[ "$path" != /* ]]; then
        error "Path must be absolute (start with /)"
        return 1
    fi

    # Must start with /root or be a known safe directory
    if [[ "$path" != "/root" ]] && [[ "$path" != /root/* ]] && \
       [[ "$path" != "/home" ]] && [[ "$path" != /home/* ]] && \
       [[ "$path" != "/opt" ]] && [[ "$path" != /opt/* ]]; then
        error "Path must be under /root, /home, or /opt for safety"
        return 1
    fi

    # Must not contain path traversal attempts
    if [[ "$path" == *..* ]]; then
        error "Path cannot contain '..' (path traversal blocked)"
        return 1
    fi

    # Must not contain suspicious characters
    if [[ "$path" =~ [\;\&\|\$\`] ]]; then
        error "Path contains invalid characters"
        return 1
    fi

    # Must exist and be a directory
    if [ ! -d "$path" ]; then
        error "Path does not exist or is not a directory: $path"
        return 1
    fi

    return 0
}

# -----------------------------------------------------------------------------
# validate_env_name - Validate environment/project name
#
# Description:
#   Ensures environment names follow safe naming conventions.
#
# Arguments:
#   $1 - Environment name to validate
#
# Returns:
#   0 - Name is valid
#   1 - Name is invalid
#
# Rules:
#   - Only alphanumeric, dash, underscore, dot allowed
#   - Cannot start with dash or dot
#   - Cannot be empty
#
# Example:
#   validate_env_name "my-app" || exit 1
# -----------------------------------------------------------------------------
validate_env_name() {
    local name=$1

    if [ -z "$name" ]; then
        error "Environment name cannot be empty"
        return 1
    fi

    # Must contain only alphanumeric, dash, underscore, dot
    if [[ ! "$name" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        error "Environment name can only contain letters, numbers, dash, underscore, dot"
        return 1
    fi

    # Must not start with dash or dot
    if [[ "$name" =~ ^[-.] ]]; then
        error "Environment name cannot start with dash or dot"
        return 1
    fi

    return 0
}

# Helper functions (with logging)
success() {
    echo -e "${GREEN}✅${NC} $1"
    log INFO "SUCCESS: $1"
}

error() {
    echo -e "${RED}❌${NC} $1"
    log ERROR "$1"
}

info() {
    echo -e "${BLUE}ℹ️${NC} $1"
    log INFO "$1"
}

warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
    log WARNING "$1"
}

# ============================================================================
# PM2 DATA CACHING (Performance Optimization)
# ============================================================================

# Global cache variables
PM2_DATA_CACHE=""
PM2_DATA_CACHE_TIME=0

# -----------------------------------------------------------------------------
# get_pm2_data_cached - Fetch and cache all PM2 application data
#
# Description:
#   Retrieves all PM2 app data in a single call and caches the results.
#   Uses jq for JSON parsing (falls back to python3).
#   Cache is valid for BUILDFLOWZ_PM2_CACHE_TTL seconds (default: 5).
#
# Arguments:
#   None
#
# Returns:
#   0 - Success
#   1 - PM2 not installed or error
#
# Outputs:
#   name|status|port|cwd for each PM2 app (one per line)
#
# Cache Behavior:
#   - Returns cached data if age < TTL
#   - Fetches fresh data if cache expired
#   - Global variables: PM2_DATA_CACHE, PM2_DATA_CACHE_TIME
#
# Example:
#   get_pm2_data_cached
# -----------------------------------------------------------------------------
get_pm2_data_cached() {
    local current_time=$(date +%s)
    local cache_age=$((current_time - PM2_DATA_CACHE_TIME))

    # Return cached data if fresh
    if [ "$BUILDFLOWZ_PM2_CACHE_ENABLED" = "true" ] && [ $cache_age -lt $BUILDFLOWZ_PM2_CACHE_TTL ] && [ -n "$PM2_DATA_CACHE" ]; then
        log DEBUG "Using cached PM2 data (age: ${cache_age}s)"
        echo "$PM2_DATA_CACHE"
        return 0
    fi

    # Fetch fresh data
    log DEBUG "Fetching fresh PM2 data"
    if ! command -v pm2 >/dev/null 2>&1; then
        log WARNING "PM2 not installed"
        return 1
    fi

    # Get all PM2 data in one call: name|status|port|cwd
    # Use jq if available (faster), fallback to python3
    if [ "$BUILDFLOWZ_PREFER_JQ" = "true" ] && command -v jq >/dev/null 2>&1; then
        PM2_DATA_CACHE=$(pm2 jlist 2>/dev/null | jq -r '.[] | "\(.name)|\(.pm2_env.status // "unknown")|\(.pm2_env.env.PORT // "")|\(.pm2_env.pm_cwd // "")"' 2>/dev/null)
    elif command -v python3 >/dev/null 2>&1; then
        PM2_DATA_CACHE=$(pm2 jlist 2>/dev/null | python3 -c "
import sys, json
try:
    apps = json.load(sys.stdin)
    for app in apps:
        name = app.get('name', '')
        status = app.get('pm2_env', {}).get('status', 'unknown')
        port = app.get('pm2_env', {}).get('env', {}).get('PORT', '')
        cwd = app.get('pm2_env', {}).get('pm_cwd', '')
        print(f'{name}|{status}|{port}|{cwd}')
except Exception as e:
    import sys
    print(f'ERROR: {e}', file=sys.stderr)
" 2>/dev/null)
    else
        log ERROR "No JSON parser available (jq or python3 required)"
        return 1
    fi

    PM2_DATA_CACHE_TIME=$current_time
    echo "$PM2_DATA_CACHE"
}

# -----------------------------------------------------------------------------
# invalidate_pm2_cache - Clear PM2 data cache
#
# Description:
#   Invalidates the PM2 data cache to force a fresh fetch on next access.
#   Should be called after any PM2 state changes (start, stop, delete).
#
# Arguments:
#   None
#
# Returns:
#   0 - Always succeeds
#
# Example:
#   pm2 start app.js
#   invalidate_pm2_cache
# -----------------------------------------------------------------------------
invalidate_pm2_cache() {
    log DEBUG "Invalidating PM2 cache"
    PM2_DATA_CACHE=""
    PM2_DATA_CACHE_TIME=0
}

# -----------------------------------------------------------------------------
# get_pm2_app_data - Extract specific PM2 app data from cache
#
# Description:
#   Retrieves a specific field for a PM2 app from the cached data.
#
# Arguments:
#   $1 - App name
#   $2 - Field to retrieve: "status", "port", "cwd", or empty for all
#
# Returns:
#   0 - App found
#   1 - App not found or cache empty
#
# Outputs:
#   Requested field value(s)
#
# Example:
#   port=$(get_pm2_app_data "myapp" "port")
# -----------------------------------------------------------------------------
get_pm2_app_data() {
    local app_name=$1
    local field=$2  # status, port, or cwd

    local data=$(get_pm2_data_cached)
    if [ -z "$data" ]; then
        return 1
    fi

    # Parse cached data
    echo "$data" | while IFS='|' read -r name status port cwd; do
        if [ "$name" = "$app_name" ]; then
            case "$field" in
                status) echo "$status" ;;
                port) echo "$port" ;;
                cwd) echo "$cwd" ;;
                *) echo "$status|$port|$cwd" ;;
            esac
            return 0
        fi
    done
}

# ============================================================================
# PORT MANAGEMENT FUNCTIONS
# ============================================================================

# -----------------------------------------------------------------------------
# is_port_in_use - Check if a TCP port is currently in use
#
# Description:
#   Uses ss command to check if a port is listening.
#
# Arguments:
#   $1 - Port number to check
#
# Returns:
#   0 - Port is in use
#   1 - Port is available
#
# Example:
#   if is_port_in_use 3000; then
#       echo "Port 3000 is busy"
#   fi
# -----------------------------------------------------------------------------
is_port_in_use() {
    local port=$1
    ss -ltn 2>/dev/null | awk '{print $4}' | grep -E "[:.]${port}$" >/dev/null 2>&1
}

# Get all ports used by PM2 apps (even stopped ones) - OPTIMIZED
get_all_pm2_ports() {
    if ! command -v pm2 >/dev/null 2>&1; then
        return 0
    fi

    local data=$(get_pm2_data_cached)
    if [ -z "$data" ]; then
        return 0
    fi

    # Extract ports from cached data
    echo "$data" | awk -F'|' '{if ($3 != "") print $3}' | tr '\n' ' '
}

# -----------------------------------------------------------------------------
# find_available_port - Find next available port in range
#
# Description:
#   Searches for an available port starting from base_port.
#   Checks both active ports (via ss) and PM2-assigned ports.
#
# Arguments:
#   $1 - Base port to start search (default: BUILDFLOWZ_PORT_RANGE_START)
#
# Returns:
#   0 - Available port found
#   1 - No available port in range
#
# Outputs:
#   Available port number to stdout
#
# Notes:
#   - Searches up to BUILDFLOWZ_PORT_MAX_ATTEMPTS ports
#   - Avoids race conditions by checking both active and reserved ports
#
# Example:
#   port=$(find_available_port 3000)
# -----------------------------------------------------------------------------
find_available_port() {
    local base_port=${1:-$BUILDFLOWZ_PORT_RANGE_START}
    local max_range=$BUILDFLOWZ_PORT_MAX_ATTEMPTS
    local port=$base_port

    # Get all ports already assigned in PM2 (atomic read)
    local pm2_ports=$(get_all_pm2_ports)

    # Search for available port
    while [ $((port - base_port)) -lt $max_range ]; do
        # Double-check: not in use AND not already assigned in PM2
        # This reduces race condition window
        if ! is_port_in_use $port && ! echo "$pm2_ports" | grep -q "\<$port\>"; then
            # Final verification before returning
            if ! is_port_in_use $port; then
                echo $port
                log DEBUG "Found available port: $port"
                return 0
            fi
        fi
        port=$((port + 1))
    done

    error "Impossible de trouver un port disponible après $max_range tentatives"
    log ERROR "Port exhaustion: no ports available in range $base_port-$((base_port + max_range))"
    return 1
}

# Get project status from PM2 - OPTIMIZED
get_pm2_status() {
    local identifier=$1
    local project_dir=$(resolve_project_path "$identifier")

    if [ -z "$project_dir" ]; then
        echo "not-found"
        return 1
    fi

    local env_name=$(basename "$project_dir") # Use basename as the PM2 app name

    if ! command -v pm2 >/dev/null 2>&1; then
        echo "pm2-not-installed"
        return 1
    fi

    # Use cached data
    local status=$(get_pm2_app_data "$env_name" "status")

    if [ -n "$status" ]; then
        echo "$status"
        return 0
    else
        echo "not_found"
        return 0
    fi
}

# Get project directory path


# Get port from PM2 env vars for a project - OPTIMIZED
get_port_from_pm2() {
    local identifier=$1
    local project_dir=$(resolve_project_path "$identifier")

    if [ -z "$project_dir" ]; then
        return 1
    fi

    local env_name=$(basename "$project_dir") # Use basename as the PM2 app name

    if ! command -v pm2 >/dev/null 2>&1; then
        return 1
    fi

    # Use cached data
    local port=$(get_pm2_app_data "$env_name" "port")

    if [ -n "$port" ]; then
        echo "$port"
        return 0
    fi

    return 1
}


# -----------------------------------------------------------------------------
# resolve_project_path - Resolve project directory from identifier
#
# Description:
#   Converts an environment name or path to an absolute project directory.
#   Searches for .flox directory to confirm valid project.
#
# Arguments:
#   $1 - Environment name or absolute path
#
# Returns:
#   0 - Project found
#   1 - Project not found
#
# Outputs:
#   Absolute path to project directory
#
# Search Strategy:
#   1. If absolute path with .flox, return as-is
#   2. Search PROJECTS_DIR for matching name with .flox
#
# Example:
#   path=$(resolve_project_path "myapp")
#   path=$(resolve_project_path "/root/myapp")
# -----------------------------------------------------------------------------
resolve_project_path() {
    local identifier=$1

    # Case 1: Identifier is already an absolute path
    if [[ "$identifier" == /* && -d "$identifier" && -d "$identifier/.flox" ]]; then
        echo "$identifier"
        return 0
    fi

    # Case 2: Identifier is an environment name, search within PROJECTS_DIR
    local found_path
    found_path=$(find "$PROJECTS_DIR" -maxdepth 4 -type d -name "$identifier" 2>/dev/null | while read -r project_dir; do
        if [ -d "$project_dir/.flox" ]; then
            echo "$project_dir"
            exit 0
        fi
    done)

    if [ -n "$found_path" ]; then
        echo "$found_path"
        return 0
    fi
    
    return 1 # Project not found
}

# List all environments (projects with Flox env)
list_all_environments() {
    if [ -d "$PROJECTS_DIR" ]; then
        find "$PROJECTS_DIR" -maxdepth 4 \
            \( -name "node_modules" -o -name ".git" -o -name "venv" -o -name ".venv" \
               -o -name "__pycache__" -o -name "target" -o -name ".next" -o -name ".nuxt" \
               -o -name "dist" -o -name ".cache" -o -name ".pnpm" -o -name ".yarn" \) -prune \
            -o -type d -name ".flox" -print 2>/dev/null | while read -r flox_dir; do
            # Extract the project name from the path, e.g., /root/my-robots/chatbot/.flox -> chatbot
            echo "$(basename "$(dirname "$flox_dir")")"
        done | grep -v "^\.$" | sort
    fi
}

# List all environment identifiers (for menu selection)
list_all_environment_identifiers() {
    list_all_environments
    # Add any other known project paths that might not be detected by list_all_environments but exist
    # For example, if you want to explicitly add /root/my-robots/chatbot as an option
    if [ -d "/root/my-robots/chatbot/.flox" ]; then
        echo "/root/my-robots/chatbot"
    fi
}


# Cleanup orphan projects
cleanup_orphan_projects() {
    echo -e "${YELLOW}🔍 Recherche de projets orphelins...${NC}"
    
    if [ -d "$PROJECTS_DIR" ]; then
        find "$PROJECTS_DIR" -maxdepth 1 -type d ! -path "$PROJECTS_DIR" | while read -r dir; do
            if [ ! -d "$dir/.flox" ]; then
                project_name=$(basename "$dir")
                echo -e "${YELLOW}🗑️  Projet sans Flox détecté: $project_name${NC}"
                echo -e "${YELLOW}   (pas d'environnement Flox)${NC}"
            fi
        done
    fi
    
    echo -e "${GREEN}✅ Nettoyage terminé${NC}"
}

# ============================================================================
# SESSION IDENTITY FUNCTIONS
# ============================================================================

# Word list for human-readable session codes
SESSION_WORDS=(
    "CORAL" "WAVE" "STORM" "TIGER" "EMBER" "FROST" "SOLAR" "LUNAR" "DELTA" "ALPHA"
    "CYBER" "NEXUS" "PULSE" "DRIFT" "SPARK" "BLAZE" "CLOUD" "SWIFT" "GHOST" "PRIME"
    "OMEGA" "SIGMA" "AZURE" "FLAME" "SHADE" "LIGHT" "STONE" "RIVER" "FORGE" "STEEL"
    "NOVA" "QUEST" "PIXEL" "VORTEX" "COMET" "ORBIT" "PRISM" "QUARK" "SONIC" "TURBO"
    "BOLT" "FLASH" "FROST" "GLEAM" "HAZE" "JADE" "KARMA" "LOTUS" "MAGIC" "NEON"
)

# -----------------------------------------------------------------------------
# init_session - Initialize session identity for this server/user
#
# Description:
#   Creates the session directory and generates a unique session ID if not
#   already present. The session ID is based on USER, HOSTNAME, and creation
#   timestamp, making it unique and persistent.
#
# Arguments:
#   None
#
# Returns:
#   0 - Success
#   1 - Error creating directory
#
# Side Effects:
#   - Creates ~/.buildflowz/session/ directory
#   - Creates session_id file if not present
#
# Example:
#   init_session
# -----------------------------------------------------------------------------
init_session() {
    if [ "$BUILDFLOWZ_SESSION_ENABLED" != "true" ]; then
        return 0
    fi

    # Create session directory
    if ! mkdir -p "$BUILDFLOWZ_SESSION_DIR" 2>/dev/null; then
        log ERROR "Failed to create session directory: $BUILDFLOWZ_SESSION_DIR"
        return 1
    fi

    local session_file="$BUILDFLOWZ_SESSION_DIR/session_id"

    # Generate session ID if not present
    if [ ! -f "$session_file" ]; then
        local timestamp=$(date +%s)
        local user="${USER:-unknown}"
        local host="${HOSTNAME:-$(hostname 2>/dev/null || echo 'unknown')}"
        local random_part=$(head -c 16 /dev/urandom 2>/dev/null | od -An -tx1 | tr -d ' \n' || echo "$RANDOM$RANDOM")

        # Create unique session ID
        local session_id="${user}@${host}:${timestamp}:${random_part}"

        echo "$session_id" > "$session_file"
        log INFO "Created new session ID for $user@$host"
    fi

    return 0
}

# -----------------------------------------------------------------------------
# get_session_id - Retrieve the current session ID
#
# Description:
#   Returns the session ID, initializing the session if needed.
#
# Arguments:
#   None
#
# Returns:
#   0 - Success
#   1 - Session disabled or error
#
# Outputs:
#   Session ID string to stdout
#
# Example:
#   session_id=$(get_session_id)
# -----------------------------------------------------------------------------
get_session_id() {
    if [ "$BUILDFLOWZ_SESSION_ENABLED" != "true" ]; then
        return 1
    fi

    local session_file="$BUILDFLOWZ_SESSION_DIR/session_id"

    # Initialize if needed
    if [ ! -f "$session_file" ]; then
        init_session || return 1
    fi

    cat "$session_file" 2>/dev/null
}

# -----------------------------------------------------------------------------
# generate_hash_art - Generate deterministic ASCII art from session ID
#
# Description:
#   Creates a unique 5x20 ASCII pattern from a session ID using SHA256 hash.
#   The pattern is deterministic - same session ID always produces same art.
#
# Arguments:
#   $1 - Session ID string
#
# Returns:
#   0 - Success
#
# Outputs:
#   5-line ASCII art pattern to stdout
#
# Example:
#   generate_hash_art "user@host:123456:abc"
# -----------------------------------------------------------------------------
generate_hash_art() {
    local session_id="$1"

    if [ -z "$session_id" ]; then
        return 1
    fi

    # Generate SHA256 hash
    local hash
    if command -v sha256sum >/dev/null 2>&1; then
        hash=$(echo -n "$session_id" | sha256sum | cut -d' ' -f1)
    elif command -v shasum >/dev/null 2>&1; then
        hash=$(echo -n "$session_id" | shasum -a 256 | cut -d' ' -f1)
    else
        # Fallback: use md5 if available
        if command -v md5sum >/dev/null 2>&1; then
            hash=$(echo -n "$session_id" | md5sum | cut -d' ' -f1)
            hash="${hash}${hash}"  # Double it for length
        else
            log ERROR "No hash utility available (sha256sum, shasum, or md5sum)"
            return 1
        fi
    fi

    # Characters for the art (from sparse to dense)
    local chars=("·" "░" "▒" "▓" "█")
    local width=20
    local height=5
    local art=""

    for ((row=0; row<height; row++)); do
        local line=""
        for ((col=0; col<width; col++)); do
            # Extract 2 characters from hash based on position
            local pos=$(( (row * width + col) * 2 % 64 ))
            local hex_val="${hash:$pos:2}"

            # Convert hex to decimal and map to character index (0-4)
            local dec_val=$((16#$hex_val % 5))
            line+="${chars[$dec_val]}"
        done

        if [ $row -lt $((height - 1)) ]; then
            art+="$line\n"
        else
            art+="$line"
        fi
    done

    echo -e "$art"
}

# -----------------------------------------------------------------------------
# get_session_code - Generate human-readable session code
#
# Description:
#   Creates a memorable code in format WORD-WORD-XX from session ID.
#   Deterministic - same session ID always produces same code.
#
# Arguments:
#   $1 - Session ID string
#
# Returns:
#   0 - Success
#
# Outputs:
#   Session code string (e.g., "CORAL-WAVE-7F") to stdout
#
# Example:
#   code=$(get_session_code "user@host:123456:abc")
# -----------------------------------------------------------------------------
get_session_code() {
    local session_id="$1"

    if [ -z "$session_id" ]; then
        return 1
    fi

    # Generate hash
    local hash
    if command -v sha256sum >/dev/null 2>&1; then
        hash=$(echo -n "$session_id" | sha256sum | cut -d' ' -f1)
    elif command -v shasum >/dev/null 2>&1; then
        hash=$(echo -n "$session_id" | shasum -a 256 | cut -d' ' -f1)
    elif command -v md5sum >/dev/null 2>&1; then
        hash=$(echo -n "$session_id" | md5sum | cut -d' ' -f1)
    else
        echo "UNKNOWN"
        return 1
    fi

    # Get word indices from hash
    local word_count=${#SESSION_WORDS[@]}
    local idx1=$((16#${hash:0:4} % word_count))
    local idx2=$((16#${hash:4:4} % word_count))
    local hex_suffix="${hash:8:2}"

    # Build code
    local word1="${SESSION_WORDS[$idx1]}"
    local word2="${SESSION_WORDS[$idx2]}"

    echo "${word1}-${word2}-${hex_suffix^^}"
}

# -----------------------------------------------------------------------------
# display_session_banner - Display formatted session identity banner
#
# Description:
#   Shows the hash art and session code in a formatted box.
#   Used by server-side menus to display identity.
#
# Arguments:
#   None
#
# Returns:
#   0 - Success
#   1 - Session disabled
#
# Outputs:
#   Formatted banner to stdout
#
# Example:
#   display_session_banner
# -----------------------------------------------------------------------------
display_session_banner() {
    if [ "$BUILDFLOWZ_SESSION_ENABLED" != "true" ]; then
        return 1
    fi

    local session_id=$(get_session_id)
    if [ -z "$session_id" ]; then
        return 1
    fi

    local hash_art=$(generate_hash_art "$session_id")
    local session_code=$(get_session_code "$session_id")
    local user="${USER:-unknown}"
    local host="${HOSTNAME:-$(hostname 2>/dev/null || echo 'unknown')}"

    echo -e "                 ${MAGENTA}Session Identity${NC}"
    echo -e "${CYAN}──────────────────────────────────────────────────${NC}"

    # Display hash art (centered visually)
    while IFS= read -r line; do
        echo -e "              ${BLUE}$line${NC}"
    done <<< "$hash_art"

    echo -e "        ${GREEN}$user@$host${NC}    ${YELLOW}$session_code${NC}"
    echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
}

# -----------------------------------------------------------------------------
# reset_session - Regenerate session identity
#
# Description:
#   Deletes the existing session ID and creates a new one.
#   Use this if you want a fresh identity or if the session was compromised.
#
# Arguments:
#   None
#
# Returns:
#   0 - Success
#   1 - Error
#
# Side Effects:
#   - Deletes existing session_id file
#   - Creates new session_id with fresh timestamp
#
# Example:
#   reset_session
# -----------------------------------------------------------------------------
reset_session() {
    if [ "$BUILDFLOWZ_SESSION_ENABLED" != "true" ]; then
        echo "Session identity is disabled"
        return 1
    fi

    local session_file="$BUILDFLOWZ_SESSION_DIR/session_id"

    # Remove existing session
    if [ -f "$session_file" ]; then
        rm -f "$session_file"
        log INFO "Removed existing session ID"
    fi

    # Create new session
    init_session

    local new_id=$(get_session_id)
    local new_code=$(get_session_code "$new_id")

    echo -e "${GREEN}✅ Session identity reset${NC}"
    echo -e "${YELLOW}New session code: ${CYAN}$new_code${NC}"
    log INFO "Session identity reset - new code: $new_code"

    return 0
}

# -----------------------------------------------------------------------------
# get_session_info - Get detailed session information
#
# Description:
#   Returns detailed information about the current session including
#   creation time and user/host info.
#
# Arguments:
#   None
#
# Returns:
#   0 - Success
#
# Outputs:
#   Formatted session info to stdout
#
# Example:
#   get_session_info
# -----------------------------------------------------------------------------
get_session_info() {
    if [ "$BUILDFLOWZ_SESSION_ENABLED" != "true" ]; then
        echo "Session identity is disabled"
        return 1
    fi

    local session_id=$(get_session_id)
    if [ -z "$session_id" ]; then
        echo "No session found"
        return 1
    fi

    # Parse session ID components
    local user_host=$(echo "$session_id" | cut -d: -f1)
    local timestamp=$(echo "$session_id" | cut -d: -f2)
    local session_code=$(get_session_code "$session_id")

    # Convert timestamp to readable date
    local created_date
    if date -d "@$timestamp" &>/dev/null; then
        created_date=$(date -d "@$timestamp" '+%Y-%m-%d %H:%M:%S')
    else
        created_date=$(date -r "$timestamp" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "Unknown")
    fi

    echo -e "${CYAN}Session Information:${NC}"
    echo -e "  ${BLUE}User@Host:${NC}    $user_host"
    echo -e "  ${BLUE}Session Code:${NC} ${YELLOW}$session_code${NC}"
    echo -e "  ${BLUE}Created:${NC}      $created_date"
    echo -e "  ${BLUE}File:${NC}         $BUILDFLOWZ_SESSION_DIR/session_id"
}

# -----------------------------------------------------------------------------
# get_session_info_for_ssh - Get session info formatted for SSH retrieval
#
# Description:
#   Returns session information in a parseable format for SSH.
#   Used by client scripts to retrieve server session identity.
#
# Arguments:
#   None
#
# Returns:
#   0 - Success
#
# Outputs:
#   SESSION_ID, HASH_ART, and SESSION_CODE separated by markers
#
# Example:
#   ssh server "source lib.sh && get_session_info_for_ssh"
# -----------------------------------------------------------------------------
get_session_info_for_ssh() {
    if [ "$BUILDFLOWZ_SESSION_ENABLED" != "true" ]; then
        echo "SESSION_DISABLED"
        return 1
    fi

    local session_id=$(get_session_id)
    if [ -z "$session_id" ]; then
        echo "SESSION_ERROR"
        return 1
    fi

    local hash_art=$(generate_hash_art "$session_id")
    local session_code=$(get_session_code "$session_id")
    local user="${USER:-unknown}"
    local host="${HOSTNAME:-$(hostname 2>/dev/null || echo 'unknown')}"

    # Output in parseable format
    echo "---SESSION_START---"
    echo "USER:$user"
    echo "HOST:$host"
    echo "CODE:$session_code"
    echo "---HASH_ART_START---"
    echo "$hash_art"
    echo "---HASH_ART_END---"
    echo "---SESSION_END---"
}

# GitHub repo operations
list_github_repos() {
    if ! command -v gh >/dev/null 2>&1; then
        error "GitHub CLI (gh) n'est pas installé"
        info "Installation: apt install gh"
        return 1
    fi

    if ! gh auth status >/dev/null 2>&1; then
        error "Non authentifié sur GitHub"
        info "Authentification: gh auth login"
        return 1
    fi

    local all_repos
    all_repos=$(gh repo list --limit "$BUILDFLOWZ_GITHUB_REPO_LIMIT" --json name,description --jq '.[] | "\(.name): \(.description)"' 2>/dev/null)

    if [ -z "$all_repos" ]; then
        return 0
    fi

    # Filter out repos already deployed (directory exists in PROJECTS_DIR)
    while IFS= read -r line; do
        local repo_name="${line%%:*}"
        local repo_name_lower="${repo_name,,}"
        if [ ! -d "$PROJECTS_DIR/$repo_name_lower" ] && [ ! -d "$PROJECTS_DIR/$repo_name" ]; then
            echo "$line"
        fi
    done <<< "$all_repos"
}

# Validate GitHub repo name
validate_repo_name() {
    local repo=$1

    if [ -z "$repo" ]; then
        error "Repository name cannot be empty"
        return 1
    fi

    # GitHub repo names: alphanumeric, dash, underscore, dot
    if [[ ! "$repo" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        error "Invalid repository name: $repo"
        return 1
    fi

    return 0
}

get_github_username() {
    gh api user --jq .login 2>/dev/null
}

# Detect project type and return package manager info
detect_project_type() {
    local project_dir=$1
    
    cd "$project_dir" || return 1
    
    if [ -f "package-lock.json" ]; then
        echo "nodejs:npm"
    elif [ -f "pnpm-lock.yaml" ]; then
        echo "nodejs:pnpm"
    elif [ -f "yarn.lock" ]; then
        echo "nodejs:yarn"
    elif [ -f "package.json" ]; then
        echo "nodejs:npm"
    elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
        echo "python:pip"
    elif [ -f "Cargo.toml" ]; then
        echo "rust:cargo"
    elif [ -f "go.mod" ]; then
        echo "go:go"
    else
        echo "generic:none"
    fi
}

# Create or init Flox environment for project
init_flox_env() {
    local project_dir=$1
    local project_name=$2

    log INFO "Initializing Flox environment: $project_name at $project_dir"

    # Check if flox is installed
    if ! command -v flox >/dev/null 2>&1; then
        error "Flox is not installed"
        info "Install with: curl -fsSL https://flox.dev/install | bash"
        return 1
    fi

    cd "$project_dir" || return 1

    if [ -d ".flox" ]; then
        echo -e "${GREEN}✅ Environnement Flox existe déjà${NC}"
        log DEBUG "Flox environment already exists for $project_name"
        return 0
    fi

    echo -e "${BLUE}🔧 Création de l'environnement Flox...${NC}"
    
    # Detect project type
    local project_type=$(detect_project_type "$project_dir")
    local lang=$(echo "$project_type" | cut -d: -f1)
    local pm=$(echo "$project_type" | cut -d: -f2)
    
    echo -e "${BLUE}📦 Type détecté: $lang ($pm)${NC}"
    
    # Init flox environment
    if ! flox init -d "$project_dir" 2>/dev/null; then
        error "Échec de l'initialisation Flox"
        return 1
    fi
    
    # Install packages based on project type
    case "$lang" in
        nodejs)
            echo -e "${BLUE}📦 Installation de Node.js...${NC}"
            flox install nodejs 2>&1 | tail -1
            # Install package manager if needed
            if [ "$pm" = "pnpm" ]; then
                echo -e "${BLUE}📦 Installation de pnpm...${NC}"
                flox install pnpm 2>&1 | tail -1
            elif [ "$pm" = "yarn" ]; then
                echo -e "${BLUE}📦 Installation de yarn...${NC}"
                flox install yarn 2>&1 | tail -1
            fi
            ;;
        python)
            echo -e "${BLUE}🐍 Installation de Python et pip...${NC}"
            flox install python3 python3Packages.pip
            ;;
        rust)
            echo -e "${BLUE}🦀 Installation de Rust...${NC}"
            flox install rustc cargo
            ;;
        go)
            echo -e "${BLUE}🐹 Installation de Go...${NC}"
            flox install go
            ;;
        generic)
            echo -e "${YELLOW}📄 Projet générique - environnement Flox de base${NC}"
            ;;
    esac
    
    # Install project dependencies if needed
    if [ "$lang" = "nodejs" ]; then
        echo -e "${BLUE}📦 Installation des dépendances du projet...${NC}"
        cd "$project_dir"
        if [ "$pm" = "pnpm" ] && [ -f "pnpm-lock.yaml" ]; then
            flox activate -- pnpm install 2>&1 | grep -v "Progress:" || true
        elif [ "$pm" = "yarn" ] && [ -f "yarn.lock" ]; then
            flox activate -- yarn install 2>&1 | grep -v "Progress:" || true
        elif [ -f "package.json" ]; then
            flox activate -- npm install 2>&1 | grep -v "npm WARN" || true
        fi
        echo -e "${GREEN}✅ Dépendances installées${NC}"
    elif [ "$lang" = "python" ]; then
        echo -e "${BLUE}🐍 Configuration de l'environnement Python...${NC}"
        cd "$project_dir"
        # Create venv if it doesn't exist
        if [ ! -d "venv" ]; then
            echo -e "${BLUE}   Creating Python venv...${NC}"
            flox activate -- python -m venv venv 2>&1 || true
        fi
        # Install requirements if they exist
        if [ -f "requirements.txt" ]; then
            echo -e "${BLUE}   Installing requirements.txt...${NC}"
            flox activate -- ./venv/bin/pip install -r requirements.txt -q 2>&1 || true
        elif [ -f "pyproject.toml" ]; then
            echo -e "${BLUE}   Installing from pyproject.toml...${NC}"
            flox activate -- ./venv/bin/pip install -e . -q 2>&1 || true
        fi
        echo -e "${GREEN}✅ Environnement Python configuré${NC}"
    fi
    
    # Fix port configuration in project files
    fix_port_config "$project_dir"
        
    success "Environnement Flox créé pour $project_name"
    return 0
}

# Fix port configuration in project config files
fix_port_config() {
    local project_dir=$1
    
    cd "$project_dir" || return 1
    
    # Astro: astro.config.mjs or astro.config.ts
    if [ -f "astro.config.mjs" ] || [ -f "astro.config.ts" ]; then
        local config_file=""
        [ -f "astro.config.mjs" ] && config_file="astro.config.mjs"
        [ -f "astro.config.ts" ] && config_file="astro.config.ts"
        
        if [ -n "$config_file" ]; then
            echo -e "${BLUE}🔧 Configuration d'Astro pour utiliser PORT...${NC}"
            
            # Check if server config exists with hardcoded port
            if grep -q "server.*:.*{" "$config_file" && grep -q "port.*:.*[0-9]" "$config_file"; then
                # Replace hardcoded port with process.env.PORT or default
                sed -i 's/port: *[0-9]\+/port: parseInt(process.env.PORT) || 3000/' "$config_file"
                echo -e "${GREEN}✅ Configuration Astro mise à jour${NC}"
            elif ! grep -q "server.*:" "$config_file"; then
                # Add server config if not exists
                sed -i '/export default defineConfig({/a\  server: {\n    port: parseInt(process.env.PORT) || 3000\n  },' "$config_file"
                echo -e "${GREEN}✅ Configuration Astro ajoutée${NC}"
            fi
        fi
    fi
    
    # Next.js: next.config.js or next.config.mjs
    if [ -f "next.config.js" ] || [ -f "next.config.mjs" ]; then
        echo -e "${BLUE}ℹ️  Next.js utilise -p pour le port (déjà géré)${NC}"
    fi
    
    # Vite: vite.config.js/ts
    if [ -f "vite.config.js" ] || [ -f "vite.config.ts" ]; then
        local config_file=""
        [ -f "vite.config.js" ] && config_file="vite.config.js"
        [ -f "vite.config.ts" ] && config_file="vite.config.ts"
        
        if [ -n "$config_file" ]; then
            echo -e "${BLUE}🔧 Configuration de Vite pour utiliser PORT...${NC}"
            
            if grep -q "server.*:.*{" "$config_file" && grep -q "port.*:.*[0-9]" "$config_file"; then
                sed -i 's/port: *[0-9]\+/port: parseInt(process.env.PORT) || 3000/' "$config_file"
                # Add HMR configuration if not present
                if ! grep -q "hmr.*:.*{" "$config_file"; then
                    sed -i '/server.*:.*{/a\    hmr: {\n      protocol: '\''ws'\'',\n      host: '\''localhost'\'',\n      port: parseInt(process.env.PORT) || 3000\n    },' "$config_file"
                fi
                echo -e "${GREEN}✅ Configuration Vite mise à jour avec HMR${NC}"
            elif grep -q "export default defineConfig({" "$config_file"; then
                sed -i '/export default defineConfig({/a\  server: {\n    port: parseInt(process.env.PORT) || 3000,\n    host: true,\n    hmr: {\n      protocol: '\''ws'\'',\n      host: '\''localhost'\'',\n      port: parseInt(process.env.PORT) || 3000\n    }\n  },' "$config_file"
                echo -e "${GREEN}✅ Configuration Vite ajoutée avec HMR${NC}"
            fi
        fi
    fi
    
    # Nuxt: nuxt.config.ts
    if [ -f "nuxt.config.ts" ]; then
        echo -e "${BLUE}ℹ️  Nuxt utilise --port pour le port (déjà géré)${NC}"
    fi
}

# Detect dev command for project
detect_dev_command() {
    local project_dir=$1
    local port=$2  # Port à utiliser
    
    cd "$project_dir" || return 1
    
    if [ -f "package.json" ]; then
        # Detect framework from package.json
        local framework=""
        if grep -q '"astro"' package.json; then
            framework="astro"
        elif grep -q '"next"' package.json; then
            framework="next"
        elif grep -q '"vite"' package.json; then
            framework="vite"
        elif grep -q '"nuxt"' package.json; then
            framework="nuxt"
        fi
        
        # Determine package manager
        local pm_cmd=""
        if [ -f "pnpm-lock.yaml" ]; then
            pm_cmd="pnpm"
        elif [ -f "yarn.lock" ]; then
            pm_cmd="yarn"
        else
            pm_cmd="npm run"
        fi
        
        # Build command based on framework and port
        if [ -n "$framework" ]; then
            case "$framework" in
                astro)
                    echo "$pm_cmd dev -- --port \$PORT"
                    ;;
                next)
                    echo "$pm_cmd dev -p \$PORT"
                    ;;
                vite)
                    echo "$pm_cmd dev -- --port \$PORT --host"
                    ;;
                nuxt)
                    echo "$pm_cmd dev --port \$PORT"
                    ;;
                *)
                    echo "$pm_cmd dev"
                    ;;
            esac
        elif grep -q '"dev"' package.json; then
            echo "$pm_cmd dev"
        elif grep -q '"start"' package.json; then
            echo "$pm_cmd start"
        fi
    elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
        # Use venv python if it exists, otherwise fallback to system python
        local py_cmd="python"
        if [ -d "venv/bin" ]; then
            py_cmd="./venv/bin/python"
        fi
        if [ -f "manage.py" ]; then
            echo "$py_cmd manage.py runserver 0.0.0.0:\$PORT"
        elif [ -f "app.py" ]; then
            echo "$py_cmd app.py"
        elif [ -f "main.py" ]; then
            echo "$py_cmd main.py"
        else
            echo "$py_cmd -m http.server \$PORT"
        fi
    elif [ -f "Cargo.toml" ]; then
        echo "cargo run"
    elif [ -f "go.mod" ]; then
        echo "go run ."
    else
        echo "echo 'No dev command detected'"
    fi
}

# ============================================================================
# ENVIRONMENT LIFECYCLE OPERATIONS
# ============================================================================

# -----------------------------------------------------------------------------
# env_start - Start a development environment with PM2 + Flox
#
# Description:
#   Starts a project environment using PM2 for process management and
#   Flox for dependency isolation. Automatically:
#   - Validates identifier
#   - Initializes Flox environment if needed
#   - Detects dev command for project
#   - Allocates/reuses port
#   - Creates PM2 ecosystem config
#   - Injects web inspector
#   - Starts PM2 process
#
# Arguments:
#   $1 - Environment identifier (name or absolute path)
#
# Returns:
#   0 - Environment started successfully
#   1 - Error occurred
#
# Side Effects:
#   - Creates ecosystem.config.cjs in project directory
#   - Invalidates PM2 cache
#   - Kills existing PM2 process if running
#   - May modify vite.config.js or astro.config.mjs for port config
#
# Example:
#   env_start "myapp"
#   env_start "/root/custom/path"
# -----------------------------------------------------------------------------
env_start() {
    local identifier=$1 # Can be env_name or custom_path
    local project_dir=""
    local env_name=""
    local pm2_config=""

    # Validate identifier
    if [ -z "$identifier" ]; then
        error "Environment identifier is required"
        return 1
    fi

    # If it looks like a path, validate it
    if [[ "$identifier" == /* ]]; then
        if ! validate_project_path "$identifier"; then
            return 1
        fi
    else
        if ! validate_env_name "$identifier"; then
            return 1
        fi
    fi

    project_dir=$(resolve_project_path "$identifier")
    if [ -z "$project_dir" ]; then
        error "Projet introuvable pour l'identifiant: $identifier"
        return 1
    fi
    
    env_name=$(basename "$project_dir") # Derive env_name from the resolved path
    pm2_config="$project_dir/ecosystem.config.cjs"

    # Check if Flox env exists, create if not
    if [ ! -d "$project_dir/.flox" ]; then
        echo -e "${YELLOW}⚠️  Pas d'environnement Flox détecté${NC}"
        init_flox_env "$project_dir" "$env_name" || return 1
    fi

    # Detect dev command
    local dev_cmd=$(detect_dev_command "$project_dir")
    
    if [ -z "$dev_cmd" ] || [ "$dev_cmd" = "echo 'No dev command detected'" ]; then
        warning "Aucune commande de dev détectée pour $env_name"
        return 1
    fi

    local port=""
    local doppler_prefix=""
    # Check for existing port and doppler in ecosystem.config.cjs - PROPER PARSING
    if [ -f "$pm2_config" ]; then
        # Use Node.js to properly parse the config file
        local config_data=$(node -e "
            try {
                const cfg = require('$pm2_config');
                const app = cfg.apps[0];
                const port = app.env && app.env.PORT ? app.env.PORT : '';
                const hasDoppler = app.args && Array.isArray(app.args) && app.args.join(' ').includes('doppler run');
                console.log(JSON.stringify({ port: port, hasDoppler: hasDoppler }));
            } catch (e) {
                console.log(JSON.stringify({ port: '', hasDoppler: false }));
            }
        " 2>/dev/null)

        if [ -n "$config_data" ]; then
            port=$(echo "$config_data" | python3 -c "import sys, json; d = json.load(sys.stdin); print(d.get('port', ''))" 2>/dev/null)
            local has_doppler=$(echo "$config_data" | python3 -c "import sys, json; d = json.load(sys.stdin); print('true' if d.get('hasDoppler') else 'false')" 2>/dev/null)
            if [ "$has_doppler" = "true" ]; then
                doppler_prefix="doppler run -- "
            fi
        fi
    fi

    # If no persistent port found, find an available one
    if [ -z "$port" ]; then
        port=$(find_available_port 3000)
        [ -z "$port" ] && return 1
        echo -e "${BLUE}🔌 Nouveau port assigné: $port${NC}"
    else
        # Verify persistent port isn't already taken by another PM2 app
        local other_app=$(get_pm2_data_cached | awk -F'|' -v p="$port" -v n="$env_name" '$3 == p && $1 != n {print $1}')
        if [ -n "$other_app" ] || is_port_in_use "$port"; then
            warning "Port $port (persistant) déjà utilisé par ${other_app:-un autre processus}, recherche d'un nouveau port..."
            port=$(find_available_port 3000)
            [ -z "$port" ] && return 1
            echo -e "${BLUE}🔌 Nouveau port assigné: $port${NC}"
        else
            echo -e "${BLUE}🔌 Port persistant réutilisé: $port${NC}"
        fi
    fi
    
    echo -e "${BLUE}🚀 Commande: $dev_cmd${NC}"
    
    # Replace $PORT in dev_cmd with actual port value
    local final_cmd="${dev_cmd//\$PORT/$port}"

    # For Doppler projects, override PORT after doppler injects its env vars
    # to prevent Doppler's PORT value from taking precedence over BuildFlowz's assignment
    local inner_cmd="$final_cmd"
    if [ -n "$doppler_prefix" ]; then
        inner_cmd="env PORT=$port $final_cmd"
    fi

    # Create persistent ecosystem file
    cat > "$pm2_config" <<EOF
module.exports = {
  apps: [{
    name: "$env_name",
    cwd: "$project_dir",
    script: "bash",
    args: ["-c", "export PORT=$port && flox activate -- ${doppler_prefix}${inner_cmd}"],
    env: {
      PORT: $port
    },
    autorestart: true,
    watch: false
  }]
};
EOF
    
    echo -e "${GREEN}✅ Fichier ecosystem.config.cjs créé/mis à jour${NC}"

    # Inject web inspector before starting the dev server
    (cd "$project_dir" && init_web_inspector)

    # Atomic cleanup of existing process (Priority 3 #11: Fix race condition)
    # Use pm2 delete with idempotent operation (no check-then-act)
    pm2 delete "$env_name" 2>/dev/null || true

    # Kill any lingering processes on the port to avoid zombies
    if command -v fuser >/dev/null 2>&1; then
        fuser -k "$port/tcp" 2>/dev/null || true
    fi

    # Small delay to ensure port is fully released
    sleep 0.5
    
    pm2 start "$pm2_config"
    pm2 save >/dev/null 2>&1

    # Invalidate cache after PM2 state change
    invalidate_pm2_cache

    success "Projet $env_name démarré sur le port $port"
    log INFO "Started environment: $env_name on port $port at $project_dir"
}

# -----------------------------------------------------------------------------
# env_stop - Stop a running environment
#
# Description:
#   Stops a PM2-managed environment gracefully.
#
# Arguments:
#   $1 - Environment identifier (name or path)
#
# Returns:
#   0 - Environment stopped or already stopped
#   1 - Error occurred
#
# Side Effects:
#   - Invalidates PM2 cache
#   - Saves PM2 process list
#
# Example:
#   env_stop "myapp"
# -----------------------------------------------------------------------------
env_stop() {
    local identifier=$1

    # Validate identifier
    if [ -z "$identifier" ]; then
        error "Environment identifier is required"
        return 1
    fi

    local project_dir=$(resolve_project_path "$identifier")

    if [ -z "$project_dir" ]; then
        warning "Projet $identifier introuvable ou chemin invalide."
        return 1
    fi

    # Ensure env_name is correctly derived for PM2 operations
    local pm2_app_name=$(basename "$project_dir")

    # Atomic stop operation (Priority 3 #11: Fix race condition)
    # Use pm2 stop with idempotent operation (no check-then-act)
    if pm2 stop "$pm2_app_name" 2>/dev/null; then
        pm2 save >/dev/null 2>&1
        # Invalidate cache after PM2 state change
        invalidate_pm2_cache
        success "Projet $pm2_app_name arrêté"
        log INFO "Stopped environment: $pm2_app_name"
    else
        info "Projet $pm2_app_name n'est pas en cours d'exécution"
        log DEBUG "Environment $pm2_app_name was not running"
    fi

    return 0
}

# Web Inspector Functions
# Generate CSS selector for an element
generate_css_selector() {
    local element="$1"
    echo "css-selector-for-$element" | sed 's/[^a-zA-Z0-9_-]/-/g'
}

# Initialize web inspector
init_web_inspector() {
    local script_path="${SCRIPT_DIR}/injectors/web-inspector.js"

    if [ ! -f "$script_path" ]; then
        log ERROR "Web inspector script not found at $script_path"
        echo "Error: Web inspector script not found at $script_path"
        return 1
    fi

    # Step 1: Copy script to project's public/ directory
    mkdir -p public
    cp "$script_path" public/buildflowz-inspector.js
    echo "Copied web inspector to public/buildflowz-inspector.js"

    local script_tag='<script src="/buildflowz-inspector.js" defer></script>'
    local marker="<!-- buildflowz-inspector -->"

    # Step 2: Add script tag to the appropriate file
    if [ -f "index.html" ]; then
        # Vite/React/Vue projects with root index.html
        if ! grep -q "buildflowz-inspector" "index.html"; then
            sed -i "s|</body>|  ${marker}\n  ${script_tag}\n</body>|" "index.html"
            echo "Injected script tag into index.html"
        else
            echo "Script tag already present in index.html"
        fi
    elif [ -f "package.json" ] && grep -q '"astro"' package.json; then
        # Astro projects: inject into layout files
        local injected=false
        for layout in src/layouts/*.astro; do
            [ -f "$layout" ] || continue
            if grep -q "</body>" "$layout" && ! grep -q "buildflowz-inspector" "$layout"; then
                sed -i "s|</body>|  ${marker}\n  ${script_tag}\n</body>|" "$layout"
                echo "Injected script tag into $layout"
                injected=true
            elif grep -q "buildflowz-inspector" "$layout"; then
                echo "Script tag already present in $layout"
                injected=true
            fi
        done
        if [ "$injected" = false ]; then
            log WARNING "No layout with </body> found for Astro project"
            echo "Warning: No layout with </body> found for Astro project"
        fi
    else
        # Check for Next.js project (direct or monorepo)
        local is_nextjs=false
        local layout_file=""
        local public_dir="public"

        # Direct Next.js detection (next.config.*, next-env.d.ts, or "next" in package.json)
        if [ -f "next.config.ts" ] || [ -f "next.config.js" ] || [ -f "next.config.mjs" ] || [ -f "next-env.d.ts" ] || ([ -f "package.json" ] && grep -q '"next"' package.json); then
            is_nextjs=true
            for candidate in "app/layout.tsx" "app/layout.jsx" "src/app/layout.tsx" "src/app/layout.jsx"; do
                if [ -f "$candidate" ]; then
                    layout_file="$candidate"
                    break
                fi
            done
        fi

        # Monorepo detection (check apps/* and packages/* for Next.js indicators)
        if [ "$is_nextjs" = false ]; then
            for app_dir in apps/* packages/*; do
                [ -d "$app_dir" ] || continue
                # Check for Next.js indicators in this app
                if [ -f "$app_dir/next.config.ts" ] || [ -f "$app_dir/next.config.js" ] || [ -f "$app_dir/next.config.mjs" ] || [ -f "$app_dir/next-env.d.ts" ] || ([ -f "$app_dir/package.json" ] && grep -q '"next"' "$app_dir/package.json"); then
                    is_nextjs=true
                    # Find layout in this app directory
                    for candidate in "$app_dir/app/layout.tsx" "$app_dir/app/layout.jsx" "$app_dir/src/app/layout.tsx" "$app_dir/src/app/layout.jsx"; do
                        if [ -f "$candidate" ]; then
                            layout_file="$candidate"
                            # For monorepos, also copy to the app's public dir
                            if [ -d "$app_dir/public" ]; then
                                cp "$script_path" "$app_dir/public/buildflowz-inspector.js"
                                echo "Copied web inspector to $app_dir/public/buildflowz-inspector.js"
                            fi
                            break 2
                        fi
                    done
                fi
            done
        fi

        if [ "$is_nextjs" = true ]; then
            if [ -z "$layout_file" ]; then
                log WARNING "Next.js project detected but no app/layout found"
                echo "Warning: Next.js project detected but no app/layout found"
            elif grep -q "buildflowz-inspector" "$layout_file"; then
                echo "Script already present in $layout_file"
            else
                # Add Script import if not present
                if ! grep -q "from ['\"]next/script['\"]" "$layout_file"; then
                    # Add import after the first import line
                    sed -i '0,/^import /s//import Script from "next\/script";\n&/' "$layout_file"
                    echo "Added Script import to $layout_file"
                fi

                # Add Script component before </body>
                local nextjs_script='<Script src="/buildflowz-inspector.js" strategy="afterInteractive" id="buildflowz-inspector" />'
                if grep -q "</body>" "$layout_file"; then
                    sed -i "s|</body>|        ${nextjs_script}\n      </body>|" "$layout_file"
                    echo "Injected Script component into $layout_file"
                else
                    log WARNING "No </body> tag found in $layout_file"
                    echo "Warning: No </body> tag found in $layout_file"
                fi
            fi
        else
            log WARNING "Could not find injection target (no index.html, Astro layout, or Next.js layout)"
            echo "Warning: Could not find injection target (no index.html, Astro layout, or Next.js layout)"
        fi
    fi

    echo "Web inspector configured"
}

# -----------------------------------------------------------------------------
# toggle_web_inspector - Enable or disable web inspector for a project
#
# Description:
#   Toggles the web inspector injection. If the inspector JS file exists in
#   the project's public/ directory, it removes it and strips injected script
#   tags. If not present, calls init_web_inspector to inject it.
#
# Arguments:
#   $1 - Project directory (absolute path)
#
# Returns:
#   0 - Success
#   1 - Invalid directory
#
# Outputs:
#   "Web inspector enabled" or "Web inspector disabled"
#
# Example:
#   toggle_web_inspector "/root/myapp"
# -----------------------------------------------------------------------------
toggle_web_inspector() {
    local project_dir=$1

    if [ -z "$project_dir" ] || [ ! -d "$project_dir" ]; then
        error "Invalid project directory: $project_dir"
        return 1
    fi

    cd "$project_dir" || return 1

    if [ -f "public/buildflowz-inspector.js" ]; then
        # Disable: remove JS file
        rm -f "public/buildflowz-inspector.js"

        # Remove injected lines from index.html
        if [ -f "index.html" ]; then
            sed -i '/buildflowz-inspector/d' "index.html"
        fi

        # Remove from Astro layouts
        for layout in src/layouts/*.astro; do
            [ -f "$layout" ] || continue
            sed -i '/buildflowz-inspector/d' "$layout"
        done

        # Remove from Next.js layouts
        for candidate in "app/layout.tsx" "app/layout.jsx" "src/app/layout.tsx" "src/app/layout.jsx"; do
            [ -f "$candidate" ] || continue
            sed -i '/buildflowz-inspector/d' "$candidate"
        done

        # Remove from monorepo app layouts
        for app_dir in apps/* packages/*; do
            [ -d "$app_dir" ] || continue
            rm -f "$app_dir/public/buildflowz-inspector.js" 2>/dev/null
            for candidate in "$app_dir/app/layout.tsx" "$app_dir/app/layout.jsx" "$app_dir/src/app/layout.tsx" "$app_dir/src/app/layout.jsx"; do
                [ -f "$candidate" ] || continue
                sed -i '/buildflowz-inspector/d' "$candidate"
            done
        done

        echo "Web inspector disabled"
        log INFO "Web inspector disabled for $project_dir"
    else
        # Enable: call init_web_inspector
        init_web_inspector
        echo "Web inspector enabled"
        log INFO "Web inspector enabled for $project_dir"
    fi

    return 0
}

# -----------------------------------------------------------------------------
# env_remove - Remove an environment completely
#
# Description:
#   Stops the PM2 process and deletes the project directory.
#   This operation is DESTRUCTIVE and cannot be undone.
#
# Arguments:
#   $1 - Environment identifier (name or path)
#
# Returns:
#   0 - Environment removed
#   1 - Error occurred
#
# Side Effects:
#   - Deletes PM2 process
#   - Removes entire project directory (DESTRUCTIVE!)
#   - Invalidates PM2 cache
#
# Warning:
#   This permanently deletes all project files!
#
# Example:
#   env_remove "myapp"
# -----------------------------------------------------------------------------
env_remove() {
    local identifier=$1

    # Validate identifier
    if [ -z "$identifier" ]; then
        error "Environment identifier is required"
        return 1
    fi

    local project_dir=$(resolve_project_path "$identifier")

    if [ -z "$project_dir" ]; then
        warning "Projet $identifier introuvable ou chemin invalide. Impossible de supprimer."
        return 1
    fi

    local env_name=$(basename "$project_dir")

    # Atomic deletion of PM2 process (Priority 3 #11: Fix race condition)
    # Use pm2 delete with idempotent operation (no check-then-act)
    if pm2 delete "$env_name" 2>/dev/null; then
        echo -e "${YELLOW}🛑 Arrêt du processus PM2 $env_name...${NC}"
        pm2 save >/dev/null 2>&1
        # Invalidate cache after PM2 state change
        invalidate_pm2_cache
    fi

    # Remove project directory (atomic operation)
    if [ -d "$project_dir" ]; then
        log INFO "Removing environment: $env_name at $project_dir"
        rm -rf "$project_dir" || {
            error "Failed to remove directory: $project_dir"
            log ERROR "Failed to remove $project_dir"
            return 1
        }
        success "Projet $env_name supprimé"
    else
        warning "Répertoire $project_dir introuvable (peut-être déjà supprimé ou chemin incorrect)"
    fi

    return 0
}

# -----------------------------------------------------------------------------
# get_status_icon - Return emoji status icon for a PM2 status string
#
# Arguments:
#   $1 - PM2 status string (online, stopped, errored, error, etc.)
#
# Outputs:
#   Emoji icon to stdout
#
# Example:
#   icon=$(get_status_icon "online")  # Returns 🟢
# -----------------------------------------------------------------------------
get_status_icon() {
    local status=$1
    case "$status" in
        online)        echo "🟢";;
        stopped)       echo "🟡";;
        errored|error) echo "🔴";;
        *)             echo "⚪";;
    esac
}

# ============================================================================
# BATCH OPERATIONS
# ============================================================================

# -----------------------------------------------------------------------------
# batch_stop_all - Stop all PM2-managed environments
#
# Description:
#   Iterates all environments and stops each using env_stop().
#
# Returns:
#   0 - Completed (even if some environments failed)
# -----------------------------------------------------------------------------
batch_stop_all() {
    local all_envs=$(list_all_environments)

    if [ -z "$all_envs" ]; then
        echo -e "${YELLOW}No environments found${NC}"
        return 0
    fi

    local total=$(echo "$all_envs" | wc -l)
    log INFO "Batch stop initiated for $total environment(s)"
    echo -e "${BLUE}Stopping $total environment(s)...${NC}"
    echo ""

    local count=0
    local failed=0
    while IFS= read -r name; do
        ((count++))
        echo -e "${BLUE}[$count/$total] Stopping $name...${NC}"
        if env_stop "$name" >/dev/null 2>&1; then
            echo -e "  ${GREEN}✅ $name stopped${NC}"
        else
            echo -e "  ${RED}❌ $name failed to stop${NC}"
            log ERROR "Batch stop failed for $name"
            ((failed++))
        fi
    done <<< "$all_envs"

    invalidate_pm2_cache
    echo ""
    echo -e "${GREEN}Summary: $((count - failed))/$total stopped successfully${NC}"
    log INFO "Batch stop complete: $((count - failed))/$total succeeded, $failed failed"
    if [ $failed -gt 0 ]; then
        echo -e "${RED}$failed environment(s) failed to stop${NC}"
    fi
    return 0
}

# -----------------------------------------------------------------------------
# batch_start_all - Start all PM2-managed environments
#
# Description:
#   Iterates all environments and starts each using env_start().
#   Continues on individual failures.
#
# Returns:
#   0 - Completed (even if some environments failed)
# -----------------------------------------------------------------------------
batch_start_all() {
    local all_envs=$(list_all_environments)

    if [ -z "$all_envs" ]; then
        echo -e "${YELLOW}No environments found${NC}"
        return 0
    fi

    local total=$(echo "$all_envs" | wc -l)
    log INFO "Batch start initiated for $total environment(s)"
    echo -e "${BLUE}Starting $total environment(s)...${NC}"
    echo ""

    local count=0
    local failed=0
    while IFS= read -r name; do
        ((count++))
        echo -e "${BLUE}[$count/$total] Starting $name...${NC}"
        if env_start "$name" >/dev/null 2>&1; then
            echo -e "  ${GREEN}✅ $name started${NC}"
        else
            echo -e "  ${RED}❌ $name failed to start${NC}"
            log ERROR "Batch start failed for $name"
            ((failed++))
        fi
    done <<< "$all_envs"

    invalidate_pm2_cache
    echo ""
    echo -e "${GREEN}Summary: $((count - failed))/$total started successfully${NC}"
    log INFO "Batch start complete: $((count - failed))/$total succeeded, $failed failed"
    if [ $failed -gt 0 ]; then
        echo -e "${RED}$failed environment(s) failed to start${NC}"
    fi
    return 0
}

# -----------------------------------------------------------------------------
# batch_restart_all - Restart all PM2-managed environments
#
# Description:
#   Iterates all environments and restarts each using env_restart().
#
# Returns:
#   0 - Completed (even if some environments failed)
# -----------------------------------------------------------------------------
batch_restart_all() {
    local all_envs=$(list_all_environments)

    if [ -z "$all_envs" ]; then
        echo -e "${YELLOW}No environments found${NC}"
        return 0
    fi

    local total=$(echo "$all_envs" | wc -l)
    log INFO "Batch restart initiated for $total environment(s)"
    echo -e "${BLUE}Restarting $total environment(s)...${NC}"
    echo ""

    local count=0
    local failed=0
    while IFS= read -r name; do
        ((count++))
        echo -e "${BLUE}[$count/$total] Restarting $name...${NC}"
        if env_restart "$name" >/dev/null 2>&1; then
            echo -e "  ${GREEN}✅ $name restarted${NC}"
        else
            echo -e "  ${RED}❌ $name failed to restart${NC}"
            log ERROR "Batch restart failed for $name"
            ((failed++))
        fi
    done <<< "$all_envs"

    invalidate_pm2_cache
    echo ""
    echo -e "${GREEN}Summary: $((count - failed))/$total restarted successfully${NC}"
    log INFO "Batch restart complete: $((count - failed))/$total succeeded, $failed failed"
    if [ $failed -gt 0 ]; then
        echo -e "${RED}$failed environment(s) failed to restart${NC}"
    fi
    return 0
}

# -----------------------------------------------------------------------------
# show_dashboard - Display comprehensive dashboard with all environments
#
# Description:
#   Shows a unified view combining environment list, ports, status, and URLs.
#   Replaces separate "List environments" and "Show URLs" commands for better UX.
#   Displays local URLs (localhost) and web URLs (DuckDNS) in one view.
#
# Arguments:
#   None
#
# Returns:
#   0 - Success
#   1 - No environments found
#
# Outputs:
#   Formatted dashboard to stdout with environment status, ports, and URLs
#
# Example:
#   show_dashboard
# -----------------------------------------------------------------------------
show_dashboard() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}            ${YELLOW}Environment Dashboard${NC}             ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""

    # Get all environments
    local all_envs=$(list_all_environments)

    if [ -z "$all_envs" ]; then
        echo -e "${YELLOW}⚠️  No environments found${NC}"
        echo ""
        echo -e "${BLUE}💡 Tip: Use 'Start/Deploy' to create a new environment${NC}"
        return 1
    fi

    # Display environments with status
    echo -e "${GREEN}📊 Active Environments:${NC}"
    echo ""

    local count=0
    while IFS= read -r name; do
        ((count++))
        local status=$(get_pm2_status "$name")
        local port=$(get_port_from_pm2 "$name")
        local project_dir=$(resolve_project_path "$name")

        # Status indicator
        local status_icon=$(get_status_icon "$status")

        # Display environment info
        printf "  %s %-20s" "$status_icon" "$name"

        if [ -n "$port" ]; then
            printf "${BLUE}Port: %-6s${NC}" ":$port"
            printf "${CYAN}http://localhost:$port${NC}"
        else
            printf "${YELLOW}No port${NC}"
        fi

        echo ""
    done <<< "$all_envs"

    echo ""
    echo -e "${BLUE}Total: $count environment(s)${NC}"

    # Check for web URLs (Caddyfile)
    if [ -f "/etc/caddy/Caddyfile" ]; then
        echo ""
        echo -e "${GREEN}🌐 Web URLs (HTTPS):${NC}"
        echo ""

        # Parse Caddyfile for domains
        local domains=$(grep -E "^[a-zA-Z0-9\-]+\.duckdns\.org" /etc/caddy/Caddyfile 2>/dev/null | sort -u)

        if [ -n "$domains" ]; then
            while IFS= read -r domain; do
                echo -e "  ${CYAN}https://$domain${NC}"
            done <<< "$domains"
        else
            echo -e "  ${YELLOW}No web URLs configured${NC}"
        fi
    fi

    echo ""
    return 0
}

# -----------------------------------------------------------------------------
# env_restart - Restart an environment
#
# Description:
#   Restarts a PM2 environment in one step (stop + start).
#   Faster than manual stop → start workflow.
#   Invalidates PM2 cache to ensure fresh data.
#
# Arguments:
#   $1 - Environment identifier (name or path)
#
# Returns:
#   0 - Successfully restarted
#   1 - Error occurred
#
# Outputs:
#   Status messages to stdout
#
# Side Effects:
#   - Restarts PM2 process
#   - Invalidates PM2 cache
#   - Saves PM2 state
#
# Example:
#   env_restart "my-app"
#   env_restart "/root/my-app"
# -----------------------------------------------------------------------------
env_restart() {
    local identifier=$1

    if [ -z "$identifier" ]; then
        error "Usage: env_restart <environment-name-or-path>"
        return 1
    fi

    # Resolve project directory
    local project_dir=$(resolve_project_path "$identifier")
    if [ -z "$project_dir" ]; then
        error "Environment not found: $identifier"
        return 1
    fi

    local env_name=$(basename "$project_dir")

    echo -e "${BLUE}🔄 Restarting environment: $env_name${NC}"
    log INFO "Restarting environment: $env_name"

    # Check if environment exists in PM2
    local status=$(get_pm2_status "$env_name")

    if [ "$status" = "not_found" ]; then
        warning "Environment $env_name not running in PM2"
        echo -e "${YELLOW}Starting instead...${NC}"
        env_start "$project_dir"
        return $?
    fi

    # Restart PM2 process (atomic operation)
    if pm2 restart "$env_name" >/dev/null 2>&1; then
        pm2 save >/dev/null 2>&1
        invalidate_pm2_cache

        local port=$(get_port_from_pm2 "$env_name")
        success "Environment $env_name restarted successfully"

        if [ -n "$port" ]; then
            echo -e "${GREEN}✅ URL: ${CYAN}http://localhost:$port${NC}"
        fi

        log INFO "Successfully restarted: $env_name"
        return 0
    else
        error "Failed to restart $env_name"
        log ERROR "Failed to restart: $env_name"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# view_environment_logs - Display PM2 logs for an environment
#
# Description:
#   Shows the last 50 lines of PM2 logs for debugging and monitoring.
#   Useful for troubleshooting errors and checking application output.
#
# Arguments:
#   $1 - Environment identifier (name or path)
#   $2 - Number of lines to show (optional, default: 50)
#
# Returns:
#   0 - Successfully displayed logs
#   1 - Error occurred
#
# Outputs:
#   PM2 logs to stdout
#
# Example:
#   view_environment_logs "my-app"
#   view_environment_logs "my-app" 100
# -----------------------------------------------------------------------------
view_environment_logs() {
    local identifier=$1
    local lines=${2:-50}

    if [ -z "$identifier" ]; then
        error "Usage: view_environment_logs <environment-name-or-path> [lines]"
        return 1
    fi

    # Resolve project directory
    local project_dir=$(resolve_project_path "$identifier")
    if [ -z "$project_dir" ]; then
        error "Environment not found: $identifier"
        return 1
    fi

    local env_name=$(basename "$project_dir")

    # Check if environment exists in PM2
    local status=$(get_pm2_status "$env_name")

    if [ "$status" = "not_found" ]; then
        error "Environment $env_name not found in PM2"
        return 1
    fi

    echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${YELLOW}Logs: $env_name${NC} (last $lines lines)         ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""

    # Display logs
    pm2 logs "$env_name" --lines "$lines" --nostream

    echo ""
    echo -e "${BLUE}💡 Tip: Use Ctrl+C to stop, or 'pm2 logs $env_name' for live tail${NC}"
    echo ""

    return 0
}

# -----------------------------------------------------------------------------
# deploy_github_project - Deploy a project from GitHub repository
#
# Description:
#   Complete workflow to deploy a GitHub repository:
#   - Creates project directory
#   - Clones repository from GitHub
#   - Initializes Flox environment
#   - Starts the application with PM2
#   - Handles existing projects (asks to replace)
#
# Arguments:
#   $1 - Repository name (e.g., "my-repo")
#
# Returns:
#   0 - Successfully deployed
#   1 - Error occurred
#
# Outputs:
#   Progress messages and final URLs to stdout
#
# Side Effects:
#   - Creates directory in PROJECTS_DIR
#   - Clones git repository
#   - Initializes Flox environment
#   - Starts PM2 process
#
# Example:
#   deploy_github_project "my-awesome-app"
# -----------------------------------------------------------------------------
deploy_github_project() {
    local repo_name=$1

    if [ -z "$repo_name" ]; then
        error "Usage: deploy_github_project <repo-name>"
        return 1
    fi

    # Validate repo name
    if ! validate_repo_name "$repo_name"; then
        error "Invalid repository name: $repo_name"
        return 1
    fi

    echo ""
    echo -e "${GREEN}📦 Repository: $repo_name${NC}"
    echo -e "${BLUE}🚀 Starting deployment...${NC}"
    echo ""

    # Project setup
    local project_name="${repo_name,,}"  # lowercase
    local project_dir="$PROJECTS_DIR/$project_name"

    # Check if project already exists
    local existing_project=$(resolve_project_path "$project_name")
    if [ -n "$existing_project" ]; then
        echo -e "${YELLOW}⚠️  Project $project_name already exists at $existing_project${NC}"
        echo -e "${YELLOW}Replace it? (yes/N):${NC} \c"
        read -r confirm

        if [[ ! "$confirm" =~ ^(yes|YES)$ ]]; then
            echo -e "${BLUE}❌ Cancelled${NC}"
            return 1
        fi

        # Remove old project
        echo -e "${YELLOW}Removing old project...${NC}"
        env_remove "$project_name"
    fi

    # Create project directory
    echo -e "${YELLOW}Creating project directory: $project_dir${NC}"
    mkdir -p "$project_dir"

    # Clone repository
    local github_user=$(get_github_username)
    if [ -z "$github_user" ]; then
        error "Could not determine GitHub username"
        rm -rf "$project_dir"
        return 1
    fi

    local repo_url="git@github.com:$github_user/$repo_name.git"
    echo -e "${YELLOW}Cloning (SSH): $repo_url${NC}"
    echo ""

    if git clone "$repo_url" "$project_dir"; then
        echo ""
        echo -e "${GREEN}✅ Repository cloned successfully${NC}"
    else
        echo ""
        log ERROR "Failed to clone repository: $repo_url"
        echo -e "${RED}❌ Failed to clone repository${NC}"
        echo -e "${YELLOW}Please check:${NC}"
        echo -e "  • Repository exists: https://github.com/$github_user/$repo_name"
        echo -e "  • SSH key is configured: ssh -T git@github.com"
        echo -e "  • Or use: gh auth login --with-token"
        rm -rf "$project_dir"
        return 1
    fi

    # Initialize Flox environment
    echo ""
    echo -e "${YELLOW}🔧 Initializing Flox environment...${NC}"
    if ! init_flox_env "$project_dir" "$project_name"; then
        log ERROR "Flox initialization failed for $project_name at $project_dir"
        echo -e "${RED}❌ Flox initialization failed${NC}"
        echo -e "${YELLOW}Cleanup: Removing project directory${NC}"
        rm -rf "$project_dir"
        return 1
    fi

    # Start the environment
    echo ""
    echo -e "${GREEN}🚀 Starting application...${NC}"
    if ! env_start "$project_name"; then
        log ERROR "Failed to start application after deploy: $project_name"
        echo -e "${RED}❌ Failed to start application${NC}"
        echo -e "${YELLOW}Project cloned but not started. Try manually:${NC}"
        echo -e "  cd $project_dir"
        echo -e "  flox activate"
        return 1
    fi

    # Get port and display success
    local port=$(get_port_from_pm2 "$project_name")

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║            ✅ Deployment Successful!             ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}📊 Project Information:${NC}"
    echo -e "  • Name: $project_name"
    echo -e "  • Directory: $project_dir"

    if [ -n "$port" ]; then
        echo -e "  • Port: $port"
        echo ""
        echo -e "${BLUE}🌐 Access URLs:${NC}"
        echo -e "  • Local: ${CYAN}http://localhost:$port${NC}"
    fi

    echo ""
    echo -e "${YELLOW}📝 Next steps:${NC}"
    echo -e "  • View logs: Option 7 → View Logs → Select '$project_name'"
    echo -e "  • Edit code: cd $project_dir"
    echo -e "  • Publish web: Option 6 (Publish to Web)"
    echo ""

    log INFO "Successfully deployed GitHub project: $repo_name"
    return 0
}
