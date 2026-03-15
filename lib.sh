#!/bin/bash
# ============================================================================
# ShipFlow Shared Library
# ============================================================================
#
# Description:
#   Core library containing all reusable functions for ShipFlow CLI.
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
# Author: ShipFlow Team
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
if [ "$SHIPFLOW_STRICT_MODE" = "true" ]; then
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
if [ "$SHIPFLOW_ERROR_TRAPS" = "true" ]; then
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
PROJECTS_DIR="${SHIPFLOW_PROJECTS_DIR}"

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
    local gb="${SHIPFLOW_DISK_WARN_GB:-5}"
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
        "$HOME/.npm/_cacache" \
        "$HOME/.chromium-browser-snapshots" \
        "$HOME/.rustup/tmp"/* 2>/dev/null || true
}

cleanup_disk_aggressive() {
    cleanup_disk_light
    rm -rf "$HOME/.npm" \
        "$HOME/.local/share/pnpm" \
        "$HOME/.cache" 2>/dev/null || true
    # Clean Rust/Tauri build artifacts (target/ dirs)
    local dir
    for dir in "$HOME"/*/src-tauri/target "$HOME"/*/target; do
        if [ -d "$dir" ] && [ -f "${dir%/target}/Cargo.toml" ]; then
            echo -e "  ${CYAN}Cleaning${NC} $dir"
            rm -rf "$dir" 2>/dev/null || true
        fi
    done
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
        echo -e "  ${CYAN}•${NC} ~/.chromium-browser-snapshots"
        echo -e "  ${CYAN}•${NC} ~/.rustup/tmp/*"
        echo ""
        if ! ui_confirm "Proceed with light cleanup?"; then
            echo -e "${BLUE}Cancelled${NC}"
            return 0
        fi
        cleanup_disk_light
    else
        echo -e "${YELLOW}This will remove:${NC}"
        echo -e "  ${CYAN}•${NC} ~/.cache (entire cache directory)"
        echo -e "  ${CYAN}•${NC} ~/.npm"
        echo -e "  ${CYAN}•${NC} ~/.local/share/pnpm"
        echo -e "  ${CYAN}•${NC} ~/.chromium-browser-snapshots"
        echo -e "  ${CYAN}•${NC} ~/.rustup/tmp/*"
        echo -e "  ${CYAN}•${NC} Rust/Tauri target/ build artifacts"
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
MENU_STATUS_CACHE_FILE="${SHIPFLOW_SECRETS_DIR}/menu-status.cache"
MENU_STATUS_LOCK_FILE="${SHIPFLOW_SECRETS_DIR}/menu-status.lock"

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

# -----------------------------------------------------------------------------
# read_menu_status_cache - Read cached header status values from disk
#
# Outputs (globals):
#   MENU_STATUS_TS, MENU_STATUS_FREE_HUMAN, MENU_STATUS_UPDATES_TOTAL,
#   MENU_STATUS_LOW_SPACE
# -----------------------------------------------------------------------------
read_menu_status_cache() {
    MENU_STATUS_TS=0
    MENU_STATUS_FREE_HUMAN=""
    MENU_STATUS_UPDATES_TOTAL=""
    MENU_STATUS_LOW_SPACE=0

    [ -f "$MENU_STATUS_CACHE_FILE" ] || return 1

    while IFS='=' read -r key value; do
        case "$key" in
            ts) MENU_STATUS_TS="$value" ;;
            free_human) MENU_STATUS_FREE_HUMAN="$value" ;;
            updates_total) MENU_STATUS_UPDATES_TOTAL="$value" ;;
            low_space) MENU_STATUS_LOW_SPACE="$value" ;;
        esac
    done < "$MENU_STATUS_CACHE_FILE"

    return 0
}

# -----------------------------------------------------------------------------
# refresh_menu_status_cache_sync - Recompute and persist menu header status
#
# Returns:
#   0 - Cache written
#   1 - Failed to compute/write cache
# -----------------------------------------------------------------------------
refresh_menu_status_cache_sync() {
    mkdir -p "$SHIPFLOW_SECRETS_DIR" 2>/dev/null || true

    local now
    now=$(date +%s)
    local free_human
    free_human=$(disk_free_human)
    local updates_total
    updates_total=$(updates_total_cached)
    local low_space=0
    if disk_is_low_space; then
        low_space=1
    fi

    local tmp_file
    tmp_file=$(mktemp "${MENU_STATUS_CACHE_FILE}.tmp.XXXXXX" 2>/dev/null) || return 1
    register_temp_file "$tmp_file"

    {
        echo "ts=$now"
        echo "free_human=$free_human"
        echo "updates_total=$updates_total"
        echo "low_space=$low_space"
    } > "$tmp_file"

    mv "$tmp_file" "$MENU_STATUS_CACHE_FILE" 2>/dev/null || return 1
    chmod 600 "$MENU_STATUS_CACHE_FILE" 2>/dev/null || true
    return 0
}

# -----------------------------------------------------------------------------
# refresh_menu_status_cache_async_if_stale - Background cache refresh
#
# Behavior:
#   - Returns immediately
#   - Refreshes only when cache is missing/stale
#   - Uses PID lock to avoid concurrent expensive refreshes
# -----------------------------------------------------------------------------
refresh_menu_status_cache_async_if_stale() {
    local ttl="${SHIPFLOW_MENU_STATUS_CACHE_TTL:-120}"
    if ! [[ "$ttl" =~ ^[0-9]+$ ]]; then
        ttl=120
    fi

    local now cache_ts=0
    now=$(date +%s)

    if read_menu_status_cache && [ -n "$MENU_STATUS_TS" ]; then
        cache_ts="$MENU_STATUS_TS"
    fi

    if [ $((now - cache_ts)) -lt "$ttl" ]; then
        return 0
    fi

    if [ -f "$MENU_STATUS_LOCK_FILE" ]; then
        local existing_pid
        existing_pid=$(cat "$MENU_STATUS_LOCK_FILE" 2>/dev/null || true)
        if [ -n "$existing_pid" ] && kill -0 "$existing_pid" 2>/dev/null; then
            return 0
        fi
    fi

    (
        echo $$ > "$MENU_STATUS_LOCK_FILE"
        refresh_menu_status_cache_sync >/dev/null 2>&1 || true
        rm -f "$MENU_STATUS_LOCK_FILE" 2>/dev/null || true
    ) >/dev/null 2>&1 &
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
SHIPFLOW_SECRETS_FILE="${SHIPFLOW_SECRETS_DIR}/secrets"

# -----------------------------------------------------------------------------
# save_secret - Save a key=value pair to the secrets file
#
# Arguments:
#   $1 - Key name
#   $2 - Value (will NOT be logged or echoed)
#
# Side Effects:
#   Creates ~/.shipflow/ (chmod 700) and secrets file (chmod 600) if needed
# -----------------------------------------------------------------------------
save_secret() {
    local key="$1"
    local value="$2"

    # Create directory with restricted permissions
    if [ ! -d "$SHIPFLOW_SECRETS_DIR" ]; then
        mkdir -p "$SHIPFLOW_SECRETS_DIR"
        chmod 700 "$SHIPFLOW_SECRETS_DIR"
    fi

    # Create or update secrets file
    if [ ! -f "$SHIPFLOW_SECRETS_FILE" ]; then
        touch "$SHIPFLOW_SECRETS_FILE"
        chmod 600 "$SHIPFLOW_SECRETS_FILE"
    else
        # Ensure permissions are correct
        chmod 600 "$SHIPFLOW_SECRETS_FILE"
    fi

    # Update existing key or append new one
    if grep -q "^${key}=" "$SHIPFLOW_SECRETS_FILE" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$SHIPFLOW_SECRETS_FILE"
    else
        echo "${key}=${value}" >> "$SHIPFLOW_SECRETS_FILE"
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

    if [ ! -f "$SHIPFLOW_SECRETS_FILE" ]; then
        return 1
    fi

    local value
    value=$(grep "^${key}=" "$SHIPFLOW_SECRETS_FILE" 2>/dev/null | head -1 | cut -d'=' -f2-)

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
    if [ "$SHIPFLOW_LOGGING_ENABLED" = "true" ]; then
        mkdir -p "$SHIPFLOW_LOG_DIR" 2>/dev/null || true

        # Rotate old logs
        if [ -f "$SHIPFLOW_LOG_FILE" ]; then
            local log_size=$(stat -f%z "$SHIPFLOW_LOG_FILE" 2>/dev/null || stat -c%s "$SHIPFLOW_LOG_FILE" 2>/dev/null || echo 0)
            # Rotate if larger than 10MB
            if [ "$log_size" -gt 10485760 ]; then
                mv "$SHIPFLOW_LOG_FILE" "$SHIPFLOW_LOG_FILE.$(date +%s)" 2>/dev/null || true

                # Clean old logs
                find "$SHIPFLOW_LOG_DIR" -name "*.log.*" -mtime +$SHIPFLOW_LOG_RETENTION_DAYS -delete 2>/dev/null || true
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
    if [ "$SHIPFLOW_LOGGING_ENABLED" != "true" ]; then
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
    case "$SHIPFLOW_LOG_LEVEL" in
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
    echo "$log_entry" >> "$SHIPFLOW_LOG_FILE" 2>/dev/null || true
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
    if [ "$SHIPFLOW_PREFER_JQ" = "true" ] && command -v jq >/dev/null 2>&1; then
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
#   Cache is valid for SHIPFLOW_PM2_CACHE_TTL seconds (default: 5).
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
    if [ "$SHIPFLOW_PM2_CACHE_ENABLED" = "true" ] && [ $cache_age -lt $SHIPFLOW_PM2_CACHE_TTL ] && [ -n "$PM2_DATA_CACHE" ]; then
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
    if [ "$SHIPFLOW_PREFER_JQ" = "true" ] && command -v jq >/dev/null 2>&1; then
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
#   $1 - Base port to start search (default: SHIPFLOW_PORT_RANGE_START)
#
# Returns:
#   0 - Available port found
#   1 - No available port in range
#
# Outputs:
#   Available port number to stdout
#
# Notes:
#   - Searches up to SHIPFLOW_PORT_MAX_ATTEMPTS ports
#   - Avoids race conditions by checking both active and reserved ports
#
# Example:
#   port=$(find_available_port 3000)
# -----------------------------------------------------------------------------
find_available_port() {
    local base_port=${1:-$SHIPFLOW_PORT_RANGE_START}
    local max_range=$SHIPFLOW_PORT_MAX_ATTEMPTS
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
    # Accept paths with OR without .flox — env_start handles Flox initialization
    if [[ "$identifier" == /* && -d "$identifier" ]]; then
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
#   - Creates ~/.shipflow/session/ directory
#   - Creates session_id file if not present
#
# Example:
#   init_session
# -----------------------------------------------------------------------------
init_session() {
    if [ "$SHIPFLOW_SESSION_ENABLED" != "true" ]; then
        return 0
    fi

    # Create session directory
    if ! mkdir -p "$SHIPFLOW_SESSION_DIR" 2>/dev/null; then
        log ERROR "Failed to create session directory: $SHIPFLOW_SESSION_DIR"
        return 1
    fi

    local session_file="$SHIPFLOW_SESSION_DIR/session_id"

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
    if [ "$SHIPFLOW_SESSION_ENABLED" != "true" ]; then
        return 1
    fi

    local session_file="$SHIPFLOW_SESSION_DIR/session_id"

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
    if [ "$SHIPFLOW_SESSION_ENABLED" != "true" ]; then
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
    if [ "$SHIPFLOW_SESSION_ENABLED" != "true" ]; then
        echo "Session identity is disabled"
        return 1
    fi

    local session_file="$SHIPFLOW_SESSION_DIR/session_id"

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
    if [ "$SHIPFLOW_SESSION_ENABLED" != "true" ]; then
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
    echo -e "  ${BLUE}File:${NC}         $SHIPFLOW_SESSION_DIR/session_id"
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
    if [ "$SHIPFLOW_SESSION_ENABLED" != "true" ]; then
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
    all_repos=$(gh repo list --limit "$SHIPFLOW_GITHUB_REPO_LIMIT" --json name,description --jq '.[] | "\(.name): \(.description)"' 2>/dev/null)

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
            local npm_output
            npm_output=$(flox activate -- npm install 2>&1)
            if echo "$npm_output" | grep -q "ERESOLVE"; then
                echo -e "${YELLOW}⚠️  Conflit de peer deps détecté, retry avec --legacy-peer-deps...${NC}"
                flox activate -- npm install --legacy-peer-deps 2>&1 | grep -v "npm WARN" || true
            else
                echo "$npm_output" | grep -v "npm WARN" || true
            fi
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
        if grep -q '"expo"' package.json || grep -q '"expo-router"' package.json; then
            framework="expo"
        elif grep -q '"astro"' package.json; then
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
                expo)
                    echo "npx expo start --dev-client --tunnel"
                    ;;
                astro)
                    echo "$pm_cmd dev -- --port \$PORT"
                    ;;
                next)
                    # Next.js reads PORT env var natively - no -p flag needed
                    # Using -p with pnpm causes quoting issues ("-p" "3023")
                    echo "$pm_cmd dev"
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

    # Expo/React Native projects use a tunnel — no fixed port needed
    local is_expo=false
    if [[ "$dev_cmd" == *"expo start"* ]]; then
        is_expo=true
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

    # If no persistent port found, find an available one (skip for Expo tunnel projects)
    if [ "$is_expo" = "true" ]; then
        echo -e "${BLUE}📱 Projet Expo — pas de port fixe (tunnel Metro)${NC}"
    elif [ -z "$port" ]; then
        port=$(find_available_port 3000)
        [ -z "$port" ] && return 1
        echo -e "${BLUE}🔌 Nouveau port assigné: $port${NC}"
    else
        # Refresh cache to avoid using stale PM2 state when deciding port reuse
        invalidate_pm2_cache

        # Verify persistent port isn't already taken by another PM2 app
        local other_app=$(get_pm2_data_cached | awk -F'|' -v p="$port" -v n="$env_name" '$3 == p && $1 != n {print $1}')

        # Detect if the port is currently used by this same app (normal during start/redeploy)
        local self_status=$(get_pm2_app_data "$env_name" "status")
        local self_port=$(get_pm2_app_data "$env_name" "port")
        local self_owns_port="false"
        if [ "$self_status" = "online" ] && [ "$self_port" = "$port" ] && is_port_in_use "$port"; then
            self_owns_port="true"
        fi

        if [ -n "$other_app" ]; then
            warning "Port $port (persistant) déjà utilisé par $other_app, recherche d'un nouveau port..."
            port=$(find_available_port 3000)
            [ -z "$port" ] && return 1
            echo -e "${BLUE}🔌 Nouveau port assigné: $port${NC}"
        elif is_port_in_use "$port" && [ "$self_owns_port" != "true" ]; then
            warning "Port $port (persistant) déjà utilisé par un autre processus, recherche d'un nouveau port..."
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
    # to prevent Doppler's PORT value from taking precedence over ShipFlow's assignment
    local inner_cmd="$final_cmd"
    if [ -n "$doppler_prefix" ]; then
        inner_cmd="env PORT=$port $final_cmd"
    fi

    # Create persistent ecosystem file (Expo has no PORT)
    if [ "$is_expo" = "true" ]; then
        cat > "$pm2_config" <<EOF
module.exports = {
  apps: [{
    name: "$env_name",
    cwd: "$project_dir",
    script: "bash",
    args: ["-c", "flox activate -- $dev_cmd"],
    autorestart: false,
    watch: false
  }]
};
EOF
    else
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
    fi

    echo -e "${GREEN}✅ Fichier ecosystem.config.cjs créé/mis à jour${NC}"

    # Inject dev tools based on per-project preferences (skip for Expo)
    if [ "$is_expo" = "false" ]; then
        (cd "$project_dir" && init_dev_tools)
    fi

    # Atomic cleanup of existing process (Priority 3 #11: Fix race condition)
    # Use pm2 delete with idempotent operation (no check-then-act)
    pm2 delete "$env_name" 2>/dev/null || true

    # Kill any lingering processes on the port to avoid zombies (skip for Expo)
    if [ "$is_expo" = "false" ] && command -v fuser >/dev/null 2>&1; then
        fuser -k "$port/tcp" 2>/dev/null || true
    fi

    # Small delay to ensure port is fully released
    sleep 0.5

    pm2 start "$pm2_config"
    pm2 save >/dev/null 2>&1

    # Invalidate cache after PM2 state change
    invalidate_pm2_cache

    if [ "$is_expo" = "true" ]; then
        success "Projet $env_name (Expo) démarré — URL tunnel dans: pm2 logs $env_name"
        log INFO "Started Expo environment: $env_name at $project_dir"
    else
        success "Projet $env_name démarré sur le port $port"
        log INFO "Started environment: $env_name on port $port at $project_dir"
    fi

    # Initialize ShipFlow tracking on first start (no TASKS.md yet)
    if [ ! -e "$project_dir/TASKS.md" ]; then
        shipflow_init_project "$env_name" "$project_dir"
    fi
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

# ============================================================================
# DEV TOOLS — Inspector & Eruda (per-project preferences)
# ============================================================================

# Generate CSS selector for an element
generate_css_selector() {
    local element="$1"
    echo "css-selector-for-$element" | sed 's/[^a-zA-Z0-9_-]/-/g'
}

# -----------------------------------------------------------------------------
# get_tools_pref - Read a dev tool preference for a project
#
# Arguments:
#   $1 - Project directory (absolute path)
#   $2 - Key name ("inspector" or "eruda")
#
# Outputs:
#   "enabled" or "disabled" to stdout
# -----------------------------------------------------------------------------
get_tools_pref() {
    local project_dir="$1"
    local key="$2"
    local conf_file="$project_dir/.shipflow-tools.conf"

    if [ -f "$conf_file" ]; then
        local value
        value=$(grep "^${key}=" "$conf_file" 2>/dev/null | head -1 | cut -d'=' -f2)
        if [ "$value" = "disabled" ] || [ "$value" = "enabled" ]; then
            echo "$value"
            return
        fi
    fi

    # Fall back to config.sh defaults
    case "$key" in
        inspector) echo "${SHIPFLOW_INSPECTOR_DEFAULT:-enabled}" ;;
        eruda)     echo "${SHIPFLOW_ERUDA_DEFAULT:-enabled}" ;;
        *)         echo "enabled" ;;
    esac
}

# -----------------------------------------------------------------------------
# set_tools_pref - Write a dev tool preference for a project
#
# Arguments:
#   $1 - Project directory (absolute path)
#   $2 - Key name ("inspector" or "eruda")
#   $3 - Value ("enabled" or "disabled")
# -----------------------------------------------------------------------------
set_tools_pref() {
    local project_dir="$1"
    local key="$2"
    local value="$3"
    local conf_file="$project_dir/.shipflow-tools.conf"

    if [ ! -f "$conf_file" ]; then
        echo "# ShipFlow Dev Tools Preferences" > "$conf_file"
        echo "inspector=enabled" >> "$conf_file"
        echo "eruda=enabled" >> "$conf_file"
    fi

    if grep -q "^${key}=" "$conf_file" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$conf_file"
    else
        echo "${key}=${value}" >> "$conf_file"
    fi

    log INFO "Set $key=$value for $(basename "$project_dir")"
}

# -----------------------------------------------------------------------------
# inject_tool_script - Inject a JS file + script tag into a project
#
# Description:
#   Copies a JS source file to public/ and injects the corresponding
#   <script> tag before </body> in the appropriate layout file.
#   Handles: index.html, Astro layouts, Next.js layouts, monorepos.
#
# Arguments:
#   $1 - Source file path (e.g., injectors/web-inspector.js)
#   $2 - Public file name (e.g., shipflow-inspector.js)
#   $3 - Marker ID (e.g., shipflow-inspector)
#
# Must be called from the project directory (cd "$project_dir" first).
# -----------------------------------------------------------------------------
inject_tool_script() {
    local source_path="$1"
    local public_name="$2"
    local marker_id="$3"
    local marker="<!-- ${marker_id} -->"
    local script_tag="<script src=\"/${public_name}\" defer></script>"

    if [ ! -f "$source_path" ]; then
        log ERROR "Script not found: $source_path"
        return 1
    fi

    # Copy to public/
    mkdir -p public
    cp "$source_path" "public/$public_name"

    # Inject into the appropriate layout file
    if [ -f "index.html" ]; then
        if ! grep -q "$marker_id" "index.html"; then
            sed -i "s|</body>|  ${marker}\n  ${script_tag}\n</body>|" "index.html"
        fi
    elif [ -f "package.json" ] && grep -q '"astro"' package.json; then
        for layout in src/layouts/*.astro; do
            [ -f "$layout" ] || continue
            if grep -q "</body>" "$layout" && ! grep -q "$marker_id" "$layout"; then
                sed -i "s|</body>|  ${marker}\n  ${script_tag}\n</body>|" "$layout"
            fi
        done
    else
        # Next.js detection (direct or monorepo)
        local is_nextjs=false
        local layout_file=""

        if [ -f "next.config.ts" ] || [ -f "next.config.js" ] || [ -f "next.config.mjs" ] || [ -f "next-env.d.ts" ] || ([ -f "package.json" ] && grep -q '"next"' package.json); then
            is_nextjs=true
            for candidate in "app/layout.tsx" "app/layout.jsx" "src/app/layout.tsx" "src/app/layout.jsx"; do
                [ -f "$candidate" ] && layout_file="$candidate" && break
            done
        fi

        # Monorepo detection
        if [ "$is_nextjs" = false ]; then
            for app_dir in apps/* packages/*; do
                [ -d "$app_dir" ] || continue
                if [ -f "$app_dir/next.config.ts" ] || [ -f "$app_dir/next.config.js" ] || [ -f "$app_dir/next.config.mjs" ] || [ -f "$app_dir/next-env.d.ts" ] || ([ -f "$app_dir/package.json" ] && grep -q '"next"' "$app_dir/package.json"); then
                    is_nextjs=true
                    for candidate in "$app_dir/app/layout.tsx" "$app_dir/app/layout.jsx" "$app_dir/src/app/layout.tsx" "$app_dir/src/app/layout.jsx"; do
                        if [ -f "$candidate" ]; then
                            layout_file="$candidate"
                            [ -d "$app_dir/public" ] && cp "$source_path" "$app_dir/public/$public_name"
                            break 2
                        fi
                    done
                fi
            done
        fi

        if [ "$is_nextjs" = true ] && [ -n "$layout_file" ]; then
            if ! grep -q "$marker_id" "$layout_file"; then
                # Add Script import if not present
                if ! grep -q "from ['\"]next/script['\"]" "$layout_file"; then
                    sed -i '0,/^import /s//import Script from "next\/script";\n&/' "$layout_file"
                fi
                local nextjs_script="<Script src=\"/${public_name}\" strategy=\"afterInteractive\" id=\"${marker_id}\" />"
                if grep -q "</body>" "$layout_file"; then
                    sed -i "s|</body>|        ${nextjs_script}\n      </body>|" "$layout_file"
                fi
            fi
        fi
    fi
}

# -----------------------------------------------------------------------------
# remove_tool_script - Remove an injected JS file + script tags from a project
#
# Arguments:
#   $1 - Public file name (e.g., shipflow-inspector.js)
#   $2 - Marker ID (e.g., shipflow-inspector)
#
# Must be called from the project directory (cd "$project_dir" first).
# -----------------------------------------------------------------------------
remove_tool_script() {
    local public_name="$1"
    local marker_id="$2"

    # Remove public JS file
    rm -f "public/$public_name"

    # Remove from index.html
    [ -f "index.html" ] && sed -i "/${marker_id}/d" "index.html"

    # Remove from Astro layouts
    for layout in src/layouts/*.astro; do
        [ -f "$layout" ] || continue
        sed -i "/${marker_id}/d" "$layout"
    done

    # Remove from Next.js layouts
    for candidate in "app/layout.tsx" "app/layout.jsx" "src/app/layout.tsx" "src/app/layout.jsx"; do
        [ -f "$candidate" ] || continue
        sed -i "/${marker_id}/d" "$candidate"
    done

    # Remove from monorepo layouts
    for app_dir in apps/* packages/*; do
        [ -d "$app_dir" ] || continue
        rm -f "$app_dir/public/$public_name" 2>/dev/null
        for candidate in "$app_dir/app/layout.tsx" "$app_dir/app/layout.jsx" "$app_dir/src/app/layout.tsx" "$app_dir/src/app/layout.jsx"; do
            [ -f "$candidate" ] || continue
            sed -i "/${marker_id}/d" "$candidate"
        done
    done
}

# -----------------------------------------------------------------------------
# init_dev_tools - Inject dev tools based on per-project preferences
#
# Description:
#   Reads .shipflow-tools.conf to decide which tools to inject.
#   Injects inspector and/or eruda based on preferences.
#   Replaces the old init_web_inspector (backwards compatible).
#
# Must be called from the project directory (cd "$project_dir" first).
# -----------------------------------------------------------------------------
init_dev_tools() {
    local project_dir="$PWD"
    local inspector_pref
    local eruda_pref
    inspector_pref=$(get_tools_pref "$project_dir" "inspector")
    eruda_pref=$(get_tools_pref "$project_dir" "eruda")

    local injected=false

    if [ "$inspector_pref" = "enabled" ]; then
        inject_tool_script "${SCRIPT_DIR}/injectors/web-inspector.js" "shipflow-inspector.js" "shipflow-inspector"
        injected=true
    else
        # Make sure it's removed if disabled
        remove_tool_script "shipflow-inspector.js" "shipflow-inspector"
    fi

    if [ "$eruda_pref" = "enabled" ]; then
        inject_tool_script "${SCRIPT_DIR}/injectors/eruda-console.js" "shipflow-eruda.js" "shipflow-eruda"
        injected=true
    else
        remove_tool_script "shipflow-eruda.js" "shipflow-eruda"
    fi

    if [ "$injected" = true ]; then
        echo "Outils dev configurés (inspecteur: $inspector_pref, eruda: $eruda_pref)"
    else
        echo "Outils dev désactivés pour ce projet"
    fi
}

# Backwards-compatible alias
init_web_inspector() {
    init_dev_tools
}

# -----------------------------------------------------------------------------
# set_tool_state - Enable or disable a specific dev tool for a project
#
# Arguments:
#   $1 - Project directory (absolute path)
#   $2 - Tool name ("inspector" or "eruda")
#   $3 - State ("enabled" or "disabled")
# -----------------------------------------------------------------------------
set_tool_state() {
    local project_dir="$1"
    local tool="$2"
    local state="$3"

    if [ -z "$project_dir" ] || [ ! -d "$project_dir" ]; then
        error "Répertoire invalide : $project_dir"
        return 1
    fi

    set_tools_pref "$project_dir" "$tool" "$state"

    cd "$project_dir" || return 1

    if [ "$tool" = "inspector" ]; then
        if [ "$state" = "enabled" ]; then
            inject_tool_script "${SCRIPT_DIR}/injectors/web-inspector.js" "shipflow-inspector.js" "shipflow-inspector"
        else
            remove_tool_script "shipflow-inspector.js" "shipflow-inspector"
        fi
    elif [ "$tool" = "eruda" ]; then
        if [ "$state" = "enabled" ]; then
            inject_tool_script "${SCRIPT_DIR}/injectors/eruda-console.js" "shipflow-eruda.js" "shipflow-eruda"
        else
            remove_tool_script "shipflow-eruda.js" "shipflow-eruda"
        fi
    fi
}

# -----------------------------------------------------------------------------
# toggle_web_inspector - Backwards-compatible toggle (both tools at once)
#
# Arguments:
#   $1 - Project directory (absolute path)
# -----------------------------------------------------------------------------
toggle_web_inspector() {
    local project_dir=$1

    if [ -z "$project_dir" ] || [ ! -d "$project_dir" ]; then
        error "Invalid project directory: $project_dir"
        return 1
    fi

    local inspector_pref
    inspector_pref=$(get_tools_pref "$project_dir" "inspector")

    if [ "$inspector_pref" = "enabled" ]; then
        set_tool_state "$project_dir" "inspector" "disabled"
        set_tool_state "$project_dir" "eruda" "disabled"
        echo "Outils dev désactivés"
        log INFO "Dev tools disabled for $project_dir"
    else
        set_tool_state "$project_dir" "inspector" "enabled"
        set_tool_state "$project_dir" "eruda" "enabled"
        echo "Outils dev activés"
        log INFO "Dev tools enabled for $project_dir"
    fi

    return 0
}

# -----------------------------------------------------------------------------
# env_check_git_safety - Check for unsaved git work in a project directory
#
# Description:
#   Checks if a directory is a git repo with uncommitted changes, untracked
#   files, or unpushed commits. Returns a summary of what would be lost.
#
# Arguments:
#   $1 - Project directory path
#
# Returns:
#   0 - Clean (safe to delete)
#   1 - Dirty (unsaved work detected)
#
# Outputs:
#   Warning messages describing unsaved work
# -----------------------------------------------------------------------------
env_check_git_safety() {
    local project_dir="$1"

    # Not a git repo — nothing to check
    if [ ! -d "$project_dir/.git" ]; then
        return 0
    fi

    local has_issues=false

    # Check for uncommitted changes (staged + unstaged)
    local changed_files
    changed_files=$(git -C "$project_dir" status --porcelain 2>/dev/null)
    if [ -n "$changed_files" ]; then
        has_issues=true
        local modified_count=$(echo "$changed_files" | grep -c "^ M\|^M " 2>/dev/null || echo 0)
        local untracked_count=$(echo "$changed_files" | grep -c "^??" 2>/dev/null || echo 0)
        local staged_count=$(echo "$changed_files" | grep -c "^[ADMR] " 2>/dev/null || echo 0)

        echo -e "${YELLOW}  📝 Modifications non commitées :${NC}"
        if [ "$modified_count" -gt 0 ]; then
            echo -e "${YELLOW}     - $modified_count fichier(s) modifié(s)${NC}"
        fi
        if [ "$staged_count" -gt 0 ]; then
            echo -e "${YELLOW}     - $staged_count fichier(s) stagé(s)${NC}"
        fi
        if [ "$untracked_count" -gt 0 ]; then
            echo -e "${YELLOW}     - $untracked_count fichier(s) non tracké(s)${NC}"
        fi
    fi

    # Check for unpushed commits
    local upstream
    upstream=$(git -C "$project_dir" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null)
    if [ -n "$upstream" ]; then
        local unpushed
        unpushed=$(git -C "$project_dir" log "$upstream"..HEAD --oneline 2>/dev/null)
        if [ -n "$unpushed" ]; then
            has_issues=true
            local unpushed_count
            unpushed_count=$(echo "$unpushed" | wc -l)
            echo -e "${YELLOW}  📤 $unpushed_count commit(s) non poussé(s) vers $upstream :${NC}"
            echo "$unpushed" | head -5 | while IFS= read -r line; do
                echo -e "${YELLOW}     - $line${NC}"
            done
            if [ "$unpushed_count" -gt 5 ]; then
                echo -e "${YELLOW}     ... et $(( unpushed_count - 5 )) autre(s)${NC}"
            fi
        fi
    else
        # No upstream — check if there are any commits at all (local-only repo)
        local has_commits
        has_commits=$(git -C "$project_dir" rev-parse HEAD 2>/dev/null)
        if [ -n "$has_commits" ]; then
            local remote_count
            remote_count=$(git -C "$project_dir" remote 2>/dev/null | wc -l)
            if [ "$remote_count" -eq 0 ]; then
                has_issues=true
                local total_commits
                total_commits=$(git -C "$project_dir" rev-list --count HEAD 2>/dev/null || echo 0)
                echo -e "${YELLOW}  📤 Repo local sans remote — $total_commits commit(s) seraient perdus${NC}"
            fi
        fi
    fi

    if [ "$has_issues" = true ]; then
        return 1
    fi
    return 0
}

# -----------------------------------------------------------------------------
# env_cleanup_external_data - Remove ShipFlow data and Caddy entries for a project
#
# Description:
#   Cleans up external references to a project:
#   - Removes shipflow_data/projects/<name>/ directory
#   - Removes entry from shipflow_data/PROJECTS.md
#   - Warns about Caddy routes (does not auto-modify Caddyfile)
#
# Arguments:
#   $1 - Environment name
#   $2 - Project directory path
#
# Side Effects:
#   - Deletes shipflow_data/projects/<name>/
#   - Edits PROJECTS.md to remove the row
#   - Logs warnings about Caddy entries
# -----------------------------------------------------------------------------
env_cleanup_external_data() {
    local env_name="$1"
    local project_dir="$2"
    local shipflow_data="${SHIPFLOW_DATA_DIR:-$HOME/shipflow_data}"
    local project_data_dir="$shipflow_data/projects/$env_name"

    # Clean up shipflow_data/projects/<name>/
    if [ -d "$project_data_dir" ]; then
        rm -rf "$project_data_dir"
        log INFO "Removed shipflow_data for $env_name: $project_data_dir"
        echo -e "${BLUE}  🗑  Données ShipFlow supprimées ($project_data_dir)${NC}"
    fi

    # Remove entry from PROJECTS.md
    local projects_file="$shipflow_data/PROJECTS.md"
    if [ -f "$projects_file" ] && grep -q "| $env_name |" "$projects_file"; then
        sed -i "/| $env_name |/d" "$projects_file"
        log INFO "Removed $env_name from $projects_file"
        echo -e "${BLUE}  🗑  Entrée retirée de PROJECTS.md${NC}"
    fi

    # Check Caddy for routes pointing to this project
    if [ -f "/etc/caddy/Caddyfile" ]; then
        local port
        port=$(get_port_from_pm2 "$env_name" 2>/dev/null)
        if [ -n "$port" ] && grep -q "localhost:$port" /etc/caddy/Caddyfile 2>/dev/null; then
            warning "Le Caddyfile contient encore une route vers localhost:$port ($env_name)"
            echo -e "${YELLOW}  💡 Pense à régénérer le Caddyfile (option Publish du menu)${NC}"
        fi
    fi
}

# -----------------------------------------------------------------------------
# env_remove - Remove an environment completely
#
# Description:
#   Stops the PM2 process and deletes the project directory.
#   Before deletion, checks for unsaved git work (uncommitted changes,
#   unpushed commits, untracked files) and warns the user.
#   Also cleans up external ShipFlow data and warns about Caddy routes.
#   This operation is DESTRUCTIVE and cannot be undone.
#
# Arguments:
#   $1 - Environment identifier (name or path)
#   $2 - (optional) "--force" to skip git safety checks
#
# Returns:
#   0 - Environment removed
#   1 - Error occurred
#   2 - Cancelled by user (unsaved git work)
#
# Side Effects:
#   - Deletes PM2 process
#   - Removes entire project directory (DESTRUCTIVE!)
#   - Removes shipflow_data/projects/<name>/
#   - Removes entry from PROJECTS.md
#   - Invalidates PM2 cache
#
# Warning:
#   This permanently deletes all project files!
#
# Example:
#   env_remove "myapp"
#   env_remove "myapp" --force
# -----------------------------------------------------------------------------
env_remove() {
    local identifier=$1
    local force_flag="${2:-}"

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

    # Git safety check (skip with --force)
    if [ "$force_flag" != "--force" ] && [ -d "$project_dir" ]; then
        local git_warnings
        git_warnings=$(env_check_git_safety "$project_dir" 2>&1)
        if [ $? -ne 0 ]; then
            echo ""
            echo -e "${RED}⚠️  Travail non sauvegardé détecté dans $env_name :${NC}"
            echo "$git_warnings"
            echo ""
            if ! ui_confirm "Supprimer quand même $env_name ? Tout sera perdu."; then
                echo -e "${BLUE}Annulé — rien n'a été supprimé${NC}"
                log INFO "env_remove cancelled for $env_name: unsaved git work"
                return 2
            fi
        fi
    fi

    # Check Caddy routes before deleting PM2 (we need the port info)
    env_cleanup_external_data "$env_name" "$project_dir"

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
# HEALTH MONITORING FUNCTIONS
# ============================================================================

# -----------------------------------------------------------------------------
# get_pm2_health_data - Get restart count and uptime for all PM2 apps
#
# Description:
#   Fetches extended PM2 data including restart_time and pm_uptime fields
#   that are not included in the standard cached data. This is a separate
#   call from get_pm2_data_cached() because it needs additional fields.
#
# Returns:
#   0 - Success
#   1 - PM2 not available
#
# Outputs:
#   Lines of: name|status|restarts|uptime_ms|error_log_path
# -----------------------------------------------------------------------------
get_pm2_health_data() {
    if ! command -v pm2 >/dev/null 2>&1; then
        return 1
    fi

    if [ "$SHIPFLOW_PREFER_JQ" = "true" ] && command -v jq >/dev/null 2>&1; then
        pm2 jlist 2>/dev/null | jq -r '.[] | "\(.name)|\(.pm2_env.status // "unknown")|\(.pm2_env.restart_time // 0)|\(.pm2_env.pm_uptime // 0)|\(.pm2_env.pm_err_log_path // "")"' 2>/dev/null
    elif command -v python3 >/dev/null 2>&1; then
        pm2 jlist 2>/dev/null | python3 -c "
import sys, json
try:
    apps = json.load(sys.stdin)
    for app in apps:
        name = app.get('name', '')
        env = app.get('pm2_env', {})
        status = env.get('status', 'unknown')
        restarts = env.get('restart_time', 0)
        uptime = env.get('pm_uptime', 0)
        err_log = env.get('pm_err_log_path', '')
        print(f'{name}|{status}|{restarts}|{uptime}|{err_log}')
except Exception:
    pass
" 2>/dev/null
    else
        return 1
    fi
}

# -----------------------------------------------------------------------------
# detect_crash_loop - Check if a specific app is in a crash loop
#
# Arguments:
#   $1 - App name
#   $2 - Restart count
#   $3 - Uptime in milliseconds
#   $4 - Status
#
# Returns:
#   0 - App is in a crash loop
#   1 - App is healthy
#
# Outputs:
#   "crash_loop" | "unstable" | "healthy"
# -----------------------------------------------------------------------------
detect_crash_loop() {
    local name=$1
    local restarts=$2
    local uptime_ms=$3
    local status=$4

    local threshold=${SHIPFLOW_CRASH_LOOP_THRESHOLD:-10}
    local unstable_secs=${SHIPFLOW_UNSTABLE_UPTIME_SECS:-30}
    local unstable_ms=$((unstable_secs * 1000))

    # Errored with high restarts = crash loop
    if [ "$status" = "errored" ] && [ "$restarts" -gt "$threshold" ]; then
        echo "crash_loop"
        return 0
    fi

    # Online but high restarts + low uptime = crash loop (just restarted again)
    if [ "$restarts" -gt "$threshold" ] && [ "$uptime_ms" -lt "$unstable_ms" ]; then
        echo "crash_loop"
        return 0
    fi

    # Online but high restarts (recovered but was looping)
    if [ "$restarts" -gt "$threshold" ]; then
        echo "unstable"
        return 0
    fi

    echo "healthy"
    return 1
}

# -----------------------------------------------------------------------------
# diagnose_app_errors - Analyze error logs for known patterns
#
# Description:
#   Reads the last 50 lines of an app's PM2 error log and matches
#   against known error patterns from config.
#
# Arguments:
#   $1 - Path to PM2 error log
#
# Returns:
#   0 - Known error found
#   1 - No known error matched
#
# Outputs:
#   "label|hint" for the first matching pattern
# -----------------------------------------------------------------------------
diagnose_app_errors() {
    local err_log=$1

    if [ ! -f "$err_log" ] || [ ! -s "$err_log" ]; then
        return 1
    fi

    local recent_errors
    recent_errors=$(tail -50 "$err_log" 2>/dev/null)

    for pattern_entry in "${SHIPFLOW_KNOWN_ERROR_PATTERNS[@]}"; do
        local pattern label hint
        pattern=$(echo "$pattern_entry" | cut -d'|' -f1)
        label=$(echo "$pattern_entry" | cut -d'|' -f2)
        hint=$(echo "$pattern_entry" | cut -d'|' -f3)

        if echo "$recent_errors" | grep -qiE "$pattern"; then
            echo "${label}|${hint}"
            return 0
        fi
    done

    return 1
}

# -----------------------------------------------------------------------------
# health_check_all - Run health checks on all PM2 apps
#
# Description:
#   Scans all PM2 apps for crash loops and known error patterns.
#   Outputs a formatted health report. Used by dashboard and
#   standalone health check command.
#
# Arguments:
#   $1 - "quiet" for machine-readable, "verbose" for full report (default)
#
# Returns:
#   0 - All apps healthy
#   1 - One or more apps unhealthy
#
# Outputs:
#   Formatted health report
# -----------------------------------------------------------------------------
health_check_all() {
    local mode=${1:-verbose}
    local health_data
    health_data=$(get_pm2_health_data)

    if [ -z "$health_data" ]; then
        if [ "$mode" = "verbose" ]; then
            echo -e "${YELLOW}⚠️  No PM2 apps found or PM2 unavailable${NC}"
        fi
        return 0
    fi

    local unhealthy_count=0
    local crash_loop_count=0
    local total_count=0
    local alerts=""

    while IFS='|' read -r name status restarts uptime_ms err_log; do
        [ -z "$name" ] && continue
        ((total_count++))

        # Skip stopped apps (they're intentionally stopped)
        [ "$status" = "stopped" ] && continue

        local health
        health=$(detect_crash_loop "$name" "$restarts" "$uptime_ms" "$status")

        if [ "$health" = "crash_loop" ]; then
            ((crash_loop_count++))
            ((unhealthy_count++))

            local diagnosis=""
            if [ -n "$err_log" ]; then
                diagnosis=$(diagnose_app_errors "$err_log")
            fi

            local diag_label diag_hint
            if [ -n "$diagnosis" ]; then
                diag_label=$(echo "$diagnosis" | cut -d'|' -f1)
                diag_hint=$(echo "$diagnosis" | cut -d'|' -f2)
            fi

            if [ "$mode" = "verbose" ]; then
                alerts+="  🔴 ${RED}${name}${NC} — crash loop (${restarts} restarts)\n"
                if [ -n "$diag_label" ]; then
                    alerts+="     ${YELLOW}Cause:${NC} ${diag_label}\n"
                    alerts+="     ${CYAN}Fix:${NC}   ${diag_hint}\n"
                else
                    alerts+="     ${YELLOW}Cause:${NC} Unknown — check: ${CYAN}pm2 logs ${name} --lines 30${NC}\n"
                fi
                alerts+="\n"
            else
                echo "CRASH_LOOP|${name}|${restarts}|${diag_label:-unknown}"
            fi

            log WARNING "Crash loop detected: $name ($restarts restarts) — ${diag_label:-unknown cause}"

        elif [ "$health" = "unstable" ]; then
            ((unhealthy_count++))

            if [ "$mode" = "verbose" ]; then
                alerts+="  🟠 ${YELLOW}${name}${NC} — unstable (${restarts} restarts, now running)\n"
            else
                echo "UNSTABLE|${name}|${restarts}"
            fi

            log WARNING "Unstable app: $name ($restarts restarts, currently online)"
        fi

    done <<< "$health_data"

    if [ "$mode" = "verbose" ]; then
        if [ "$unhealthy_count" -gt 0 ]; then
            echo -e "${RED}⚠️  Health Issues Detected ($unhealthy_count/$total_count apps):${NC}"
            echo ""
            echo -e "$alerts"
        else
            echo -e "${GREEN}✅ All $total_count app(s) healthy${NC}"
        fi
    fi

    [ "$unhealthy_count" -eq 0 ]
}

# -----------------------------------------------------------------------------
# auto_fix_known_issues - Attempt automatic fixes for common crash causes
#
# Description:
#   For each app in crash loop, checks for known fixable issues:
#   - Stale .next/dev/lock files (Next.js)
#   - Empty content files in Astro collections
#   Prompts before applying fixes.
#
# Arguments:
#   None (scans all PM2 apps)
#
# Returns:
#   0 - Fixes applied or nothing to fix
#   1 - Errors during fix
# -----------------------------------------------------------------------------
auto_fix_known_issues() {
    local health_data
    health_data=$(get_pm2_health_data)
    local fixed=0

    while IFS='|' read -r name status restarts uptime_ms err_log; do
        [ -z "$name" ] && continue

        local health
        health=$(detect_crash_loop "$name" "$restarts" "$uptime_ms" "$status")
        [ "$health" = "healthy" ] && continue

        local cwd
        cwd=$(get_pm2_app_data "$name" "cwd")
        [ -z "$cwd" ] && continue

        # --- Fix 1: Stale Next.js lock file ---
        if [ -f "${cwd}/.next/dev/lock" ]; then
            echo -e "  ${YELLOW}🔧 ${name}:${NC} Stale .next/dev/lock found"
            echo -e "     Removing lock file and restarting..."
            pm2 stop "$name" 2>/dev/null || true
            rm -f "${cwd}/.next/dev/lock"
            pm2 start "$name" 2>/dev/null
            pm2 save 2>/dev/null
            invalidate_pm2_cache
            ((fixed++))
            log INFO "Auto-fix: removed stale .next/dev/lock for $name"
            echo -e "     ${GREEN}✅ Fixed${NC}"
            echo ""
        fi

        # --- Fix 2: Check for empty .md files in Astro content dirs ---
        if [ -d "${cwd}/src/data" ] || [ -d "${cwd}/src/content" ]; then
            local content_dir
            for content_dir in "${cwd}/src/data" "${cwd}/src/content"; do
                [ ! -d "$content_dir" ] && continue
                local empty_files
                empty_files=$(find "$content_dir" -name "*.md" -empty ! -name "_*" 2>/dev/null)
                if [ -n "$empty_files" ]; then
                    echo -e "  ${YELLOW}🔧 ${name}:${NC} Empty .md file(s) in content collection"
                    while IFS= read -r empty_file; do
                        local dir_name base_name new_name
                        dir_name=$(dirname "$empty_file")
                        base_name=$(basename "$empty_file")
                        new_name="${dir_name}/_${base_name}"
                        mv "$empty_file" "$new_name"
                        echo -e "     Renamed: ${base_name} → _${base_name}"
                        log INFO "Auto-fix: renamed empty content file $empty_file → $new_name for $name"
                    done <<< "$empty_files"
                    pm2 restart "$name" 2>/dev/null
                    pm2 save 2>/dev/null
                    invalidate_pm2_cache
                    ((fixed++))
                    echo -e "     ${GREEN}✅ Fixed — restarted $name${NC}"
                    echo ""
                fi
            done
        fi

    done <<< "$health_data"

    if [ "$fixed" -eq 0 ]; then
        echo -e "${YELLOW}No auto-fixable issues found.${NC}"
        echo -e "Run ${CYAN}pm2 logs <app> --lines 30${NC} to investigate manually."
    else
        echo -e "${GREEN}✅ Applied $fixed fix(es). Waiting for apps to stabilize...${NC}"
        sleep 3
        invalidate_pm2_cache
    fi
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
            local port=$(get_pm2_app_data "$name" "port")
            if [ -n "$port" ]; then
                echo -e "  ${GREEN}✅ $name${NC} ${CYAN}→ :$port${NC}"
            else
                echo -e "  ${GREEN}✅ $name${NC} ${CYAN}→ tunnel (expo logs)${NC}"
            fi
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
            local port=$(get_pm2_app_data "$name" "port")
            if [ -n "$port" ]; then
                echo -e "  ${GREEN}✅ $name${NC} ${CYAN}→ :$port${NC}"
            else
                echo -e "  ${GREEN}✅ $name${NC} ${CYAN}→ tunnel (expo logs)${NC}"
            fi
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

    # Pre-fetch health data for restart counts (one PM2 call)
    local health_data=""
    if [ "${SHIPFLOW_HEALTH_CHECK_ENABLED:-true}" = "true" ]; then
        health_data=$(get_pm2_health_data 2>/dev/null)
    fi

    # Display environments with status
    echo -e "${GREEN}📊 Active Environments:${NC}"
    echo ""

    local count=0
    local unhealthy_names=""
    while IFS= read -r name; do
        ((count++))
        local status=$(get_pm2_status "$name")
        local port=$(get_port_from_pm2 "$name")
        local project_dir=$(resolve_project_path "$name")

        # Status indicator
        local status_icon=$(get_status_icon "$status")

        # Check for crash loop via pre-fetched health data
        local restart_tag=""
        if [ -n "$health_data" ]; then
            local app_health_line
            app_health_line=$(echo "$health_data" | grep "^${name}|")
            if [ -n "$app_health_line" ]; then
                local h_restarts h_uptime h_status
                h_restarts=$(echo "$app_health_line" | cut -d'|' -f3)
                h_uptime=$(echo "$app_health_line" | cut -d'|' -f4)
                h_status=$(echo "$app_health_line" | cut -d'|' -f2)
                local health_state
                health_state=$(detect_crash_loop "$name" "$h_restarts" "$h_uptime" "$h_status")
                if [ "$health_state" = "crash_loop" ]; then
                    restart_tag=" ${RED}⚠ CRASH LOOP (${h_restarts}x)${NC}"
                    unhealthy_names+="$name "
                elif [ "$health_state" = "unstable" ]; then
                    restart_tag=" ${YELLOW}⚠ ${h_restarts} restarts${NC}"
                    unhealthy_names+="$name "
                fi
            fi
        fi

        # Display environment info
        printf "  %s %-20s" "$status_icon" "$name"

        if [ -n "$port" ]; then
            printf "${BLUE}Port: %-6s${NC}" ":$port"
            printf "${CYAN}http://localhost:$port${NC}"
        else
            printf "${YELLOW}No port${NC}"
        fi

        # Append crash loop tag
        if [ -n "$restart_tag" ]; then
            printf "%b" "$restart_tag"
        fi

        echo ""
    done <<< "$all_envs"

    echo ""
    echo -e "${BLUE}Total: $count environment(s)${NC}"

    # Health alert banner
    if [ -n "$unhealthy_names" ]; then
        echo ""
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED}⚠️  Unhealthy apps detected!${NC} Run ${CYAN}health check${NC} (option ${CYAN}h${NC}) for diagnostics & auto-fix."
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    fi

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
# shipflow_init_project - Initialize ShipFlow tracking files for a project
#
# Description:
#   Creates TASKS.md in shipflow_data/projects/[name]/ and symlinks it into
#   the project directory. Creates CHANGELOG.md directly in the project dir.
#   Safe to call multiple times — skips files that already exist.
#
# Arguments:
#   $1 - project_name (e.g. "myapp")
#   $2 - project_dir  (e.g. "/root/myapp")
#
# Side Effects:
#   - Creates shipflow_data/projects/[name]/TASKS.md
#   - Creates symlink [project_dir]/TASKS.md → shipflow_data/projects/[name]/TASKS.md
#   - Creates [project_dir]/CHANGELOG.md (if missing)
#   - Adds entry to shipflow_data/PROJECTS.md (if missing)
# -----------------------------------------------------------------------------
shipflow_init_project() {
    local project_name="$1"
    local project_dir="$2"
    local shipflow_data="${SHIPFLOW_DATA_DIR:-$HOME/shipflow_data}"
    local project_data_dir="$shipflow_data/projects/$project_name"

    # Ensure shipflow_data/projects/[name]/ exists
    mkdir -p "$project_data_dir"

    # Create TASKS.md in shipflow_data (if not already there)
    if [ ! -f "$project_data_dir/TASKS.md" ]; then
        cat > "$project_data_dir/TASKS.md" << TASKS_EOF
# Tasks — $project_name

> **Priority:** 🔴 P0 blocker · 🟠 P1 high · 🟡 P2 normal · 🟢 P3 low · ⚪ deferred
> **Status:** 📋 todo · 🔄 in progress · ✅ done · ⛔ blocked · 💤 deferred

---

## Setup

| Pri | Task | Status |
|-----|------|--------|
| 🟠 | Review project structure and configure environment | 📋 todo |

---

## Backlog

| Pri | Task | Status |
|-----|------|--------|

---

## Audit Findings
<!-- Populated by /shipflow-audit — dated sections added automatically -->
TASKS_EOF
        log INFO "Created TASKS.md for $project_name in shipflow_data"
    fi

    # Create symlink in project dir (only if TASKS.md is not already there)
    if [ ! -e "$project_dir/TASKS.md" ]; then
        ln -s "$project_data_dir/TASKS.md" "$project_dir/TASKS.md"
        log INFO "Linked $project_dir/TASKS.md → $project_data_dir/TASKS.md"
    elif [ ! -L "$project_dir/TASKS.md" ]; then
        # A real file exists (not a symlink) — move it to shipflow_data and replace with symlink
        mv "$project_dir/TASKS.md" "$project_data_dir/TASKS.md"
        ln -s "$project_data_dir/TASKS.md" "$project_dir/TASKS.md"
        log INFO "Migrated existing TASKS.md to shipflow_data and replaced with symlink"
    fi

    # Create CHANGELOG.md directly in project dir (lives in git repo)
    if [ ! -f "$project_dir/CHANGELOG.md" ]; then
        local today
        today=$(date +%Y-%m-%d)
        cat > "$project_dir/CHANGELOG.md" << CHANGELOG_EOF
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased] — $today

### Added
- Initial project setup
CHANGELOG_EOF
        log INFO "Created CHANGELOG.md for $project_name"
    fi

    # Register project in shipflow_data/PROJECTS.md (if not already listed)
    local projects_file="$shipflow_data/PROJECTS.md"
    if [ -f "$projects_file" ] && ! grep -q "| $project_name |" "$projects_file"; then
        # Detect basic stack info
        local stack="unknown"
        if [ -f "$project_dir/package.json" ]; then
            stack="Node.js"
            grep -q '"next"' "$project_dir/package.json" 2>/dev/null && stack="Next.js"
            grep -q '"astro"' "$project_dir/package.json" 2>/dev/null && stack="Astro"
            grep -q '"nuxt"' "$project_dir/package.json" 2>/dev/null && stack="Nuxt"
            grep -q '"vite"' "$project_dir/package.json" 2>/dev/null && stack="Vite"
        elif [ -f "$project_dir/requirements.txt" ]; then
            stack="Python"
        elif ls "$project_dir"/*.sh >/dev/null 2>&1; then
            stack="Bash"
        fi
        # Append row to Project Registry table
        sed -i "/^| Name | Path | Stack |/,/^$/{/^$/i | $project_name | $project_dir | $stack |
}" "$projects_file" 2>/dev/null || \
            echo "| $project_name | $project_dir | $stack |" >> "$projects_file"
    fi

    # Configure codebase-mcp for this project
    local mcp_server="/home/claude/ShipFlow/tools/codebase-mcp/server.py"
    if [ -f "$mcp_server" ]; then
        local claude_dir="$project_dir/.claude"
        local settings_file="$claude_dir/settings.json"
        mkdir -p "$claude_dir"
        if [ ! -f "$settings_file" ]; then
            cat > "$settings_file" << MCP_EOF
{
  "mcpServers": {
    "codebase": {
      "command": "python3",
      "args": ["$mcp_server", "$project_dir"]
    }
  }
}
MCP_EOF
            log INFO "Configured codebase-mcp for $project_name"
        elif ! grep -q "codebase-mcp" "$settings_file"; then
            # settings.json exists but no codebase entry — merge it
            local tmp_file
            tmp_file=$(mktemp)
            python3 -c "
import json, sys
with open('$settings_file') as f:
    cfg = json.load(f)
cfg.setdefault('mcpServers', {})['codebase'] = {
    'command': 'python3',
    'args': ['$mcp_server', '$project_dir']
}
print(json.dumps(cfg, indent=2))
" > "$tmp_file" && mv "$tmp_file" "$settings_file"
            log INFO "Merged codebase-mcp into existing settings.json for $project_name"
        fi
    fi

    echo -e "${GREEN}📋 ShipFlow tracking initialized for $project_name${NC}"
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

        # Remove old project (user already confirmed above)
        echo -e "${YELLOW}Removing old project...${NC}"
        env_remove "$project_name" --force
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

    # Initialize ShipFlow tracking (TASKS.md + CHANGELOG.md)
    shipflow_init_project "$project_name" "$project_dir"

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
    else
        echo ""
        echo -e "${BLUE}📱 Projet mobile (Expo)${NC}"
        echo -e "  • URL tunnel: ${CYAN}pm2 logs $project_name --lines 30${NC}"
        echo -e "  • Installe l'APK dev build sur ton téléphone, puis scan le QR"
    fi

    echo ""
    echo -e "${YELLOW}📝 Next steps:${NC}"
    echo -e "  • View logs: Option 7 → View Logs → Select '$project_name'"
    echo -e "  • Edit code: cd $project_dir"
    if [ -z "$port" ]; then
        echo -e "  • APK build (1 seule fois): eas build --profile development --platform android"
    else
        echo -e "  • Publish web: Option 6 (Publish to Web)"
    fi
    echo ""

    log INFO "Successfully deployed GitHub project: $repo_name"
    return 0
}

# ============================================================================
# SHARED MENU FUNCTIONS (used by all menu frontends)
# ============================================================================

# -----------------------------------------------------------------------------
# show_shipflow_menu - ShipFlow overview: Tasks, Priorities, Changelog, Audit
# -----------------------------------------------------------------------------
show_shipflow_menu() {
    local SHIPFLOW_DATA="${SHIPFLOW_DATA_DIR:-/home/claude/shipflow_data}"
    local TASKS_FILE="$SHIPFLOW_DATA/TASKS.md"
    local AUDIT_FILE="$SHIPFLOW_DATA/AUDIT_LOG.md"

    # First-run: create data directory with starter files if missing
    if [ ! -d "$SHIPFLOW_DATA" ]; then
        mkdir -p "$SHIPFLOW_DATA"
        cat > "$SHIPFLOW_DATA/TASKS.md" << 'TASKS_EOF'
# Master Project Tracker

> **Priority:** 🔴 P0 blocker · 🟠 P1 high · 🟡 P2 normal · 🟢 P3 low · ⚪ deferred
> **Status:** 📋 todo · 🔄 in progress · ✅ done · ⛔ blocked · 💤 deferred

---

## Dashboard

| # | Project | Phase | Status | Top Priority |
|---|---------|-------|--------|--------------|

**Legend:** 🟢 Stable · 🟡 Active · 🟠 Planning · 🔴 Blocked · ⚪ Empty

---

## Backlog

| Pri | Task | Status |
|-----|------|--------|
| 🟡 | Add first project with /shipflow-init | 📋 todo |
TASKS_EOF
        cat > "$SHIPFLOW_DATA/AUDIT_LOG.md" << 'AUDIT_EOF'
# Audit Log

> Populated by `/shipflow-audit` skills. Each entry follows the format:
> `### Audit: [Domain] — [Project] (YYYY-MM-DD)`

---
AUDIT_EOF
        cat > "$SHIPFLOW_DATA/PROJECTS.md" << 'PROJECTS_EOF'
# Projects

## Project Registry

| Name | Path | Stack |
|------|------|-------|

## Domain Applicability

| Project | Code | Design | Copy | SEO | GTM | Translate | Deps | Perf |
|---------|------|--------|------|-----|-----|-----------|------|------|
PROJECTS_EOF
        echo -e "${GREEN}✅ Created data directory: $SHIPFLOW_DATA${NC}"
        sleep 1
    fi
    local CHANGELOG_FILE="$SCRIPT_DIR/CHANGELOG.md"

    while true; do
        clear
        echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
        echo -e "               ${YELLOW}⚡ ShipFlow Overview${NC}"
        echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
        echo ""

        # Mini dashboard: show project table from TASKS.md
        if [ -f "$TASKS_FILE" ]; then
            grep -E "^\| [0-9]+" "$TASKS_FILE" 2>/dev/null | head -12 | while IFS= read -r line; do
                echo -e "  $line"
            done
            echo ""
        fi

        echo -e "${GREEN}Choisis :${NC}"
        echo ""
        echo -e "  ${CYAN}1)${NC} 📋 Tâches      — Parcourir tous les projets"
        echo -e "  ${CYAN}2)${NC} 🔴 Priorités   — Afficher P0 & P1 uniquement"
        echo -e "  ${CYAN}3)${NC} 📝 Changelog   — Voir les changements récents"
        echo -e "  ${CYAN}4)${NC} 📊 Audit Log   — Scores de qualité"
        echo ""
        echo -e "  ${CYAN}x)${NC} ← Retour"
        echo ""
        echo -e "${YELLOW}Ton choix :${NC} \c"
        read -r sf_choice

        case $sf_choice in
            1)
                if [ -f "$TASKS_FILE" ]; then
                    less -R "$TASKS_FILE"
                else
                    echo -e "${RED}❌ TASKS.md introuvable : $TASKS_FILE${NC}"
                    sleep 2
                fi
                ;;
            2)
                if [ -f "$TASKS_FILE" ]; then
                    clear
                    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
                    echo -e "       ${RED}🔴 P0 Bloquants${NC}  &  ${YELLOW}🟠 P1 Haute priorité${NC}"
                    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
                    echo ""
                    local current_project=""
                    while IFS= read -r line; do
                        if echo "$line" | grep -qE "^## [0-9]+\."; then
                            current_project=$(echo "$line" | sed 's/^## //')
                        fi
                        if echo "$line" | grep -qE "^\| (🔴|🟠)"; then
                            if [ -n "$current_project" ]; then
                                echo -e "${BLUE}── $current_project${NC}"
                                current_project=""
                            fi
                            echo "  $line"
                        fi
                    done < "$TASKS_FILE"
                    echo ""
                    echo -e "${YELLOW}Appuie sur Entrée pour continuer...${NC}"
                    read -r
                else
                    echo -e "${RED}❌ TASKS.md introuvable${NC}"
                    sleep 2
                fi
                ;;
            3)
                if [ -f "$CHANGELOG_FILE" ]; then
                    less -R "$CHANGELOG_FILE"
                else
                    echo -e "${RED}❌ CHANGELOG.md introuvable : $CHANGELOG_FILE${NC}"
                    sleep 2
                fi
                ;;
            4)
                if [ -f "$AUDIT_FILE" ]; then
                    less -R "$AUDIT_FILE"
                else
                    echo -e "${RED}❌ AUDIT_LOG.md introuvable : $AUDIT_FILE${NC}"
                    sleep 2
                fi
                ;;
            x|X|q|Q)
                return 0
                ;;
            *)
                echo -e "${RED}❌ Choix invalide${NC}"
                sleep 1
                ;;
        esac
    done
}

# -----------------------------------------------------------------------------
# show_help - Paginated help documentation
# -----------------------------------------------------------------------------
show_help() {
    local page=1
    local total_pages=4

    while true; do
        clear
        echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
        echo -e "              ${YELLOW}Aide ShipFlow${NC} (Page $page/$total_pages)"
        echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
        echo ""

        case $page in
            1)
                echo -e "${GREEN}🚀 GUIDE DE DEMARRAGE${NC}"
                echo ""
                echo -e "  ${CYAN}Étape 1 :${NC} ${GREEN}Prépare ton projet${NC}"
                echo -e "           Place ton projet dans ${YELLOW}/root/${NC}"
                echo -e "           (ou clone depuis GitHub via Déployer → GitHub)"
                echo ""
                echo -e "  ${CYAN}Étape 2 :${NC} ${GREEN}Démarre ton projet${NC}"
                echo -e "           Depuis le menu principal, choisis ${YELLOW}Déployer${NC}"
                echo -e "           Puis ${YELLOW}Auto-detect${NC} et sélectionne ton projet"
                echo ""
                echo -e "  ${CYAN}Étape 3 :${NC} ${GREEN}Accède à ton app${NC}"
                echo -e "           Ton app tourne sur ${YELLOW}http://localhost:<port>${NC}"
                echo -e "           Vérifie le port dans le ${YELLOW}Dashboard${NC}"
                echo ""
                echo -e "  ${CYAN}Étape 4 :${NC} ${GREEN}Publie sur le web (optionnel)${NC}"
                echo -e "           Va dans ${YELLOW}Options avancées → Publier${NC}"
                ;;
            2)
                echo -e "${GREEN}📐 COMMENT SHIPFLOW FONCTIONNE${NC}"
                echo ""
                echo -e "  ${BLUE}1.${NC} Tu sélectionnes un projet"
                echo -e "  ${BLUE}2.${NC} ShipFlow vérifie s'il a un répertoire ${CYAN}.flox${NC}"
                echo -e "     ${GREEN}Oui${NC} → utilise l'existant   ${YELLOW}Non${NC} → crée et configure"
                echo -e "  ${BLUE}3.${NC} Auto-détection du type de projet et commande dev"
                echo -e "     ${CYAN}package.json${NC} → npm/yarn/pnpm dev"
                echo -e "     ${CYAN}requirements.txt${NC} → python"
                echo -e "     ${CYAN}Cargo.toml${NC} → cargo run"
                echo -e "  ${BLUE}4.${NC} Crée ${CYAN}ecosystem.config.cjs${NC} pour PM2"
                echo -e "  ${BLUE}5.${NC} PM2 gère le processus :"
                echo -e "     ${GREEN}• Redémarrage auto en cas de crash${NC}"
                echo -e "     ${GREEN}• Logs capturés${NC}"
                echo -e "     ${GREEN}• Gestion des ports${NC}"
                ;;
            3)
                echo -e "${GREEN}🛠️  TECHNOLOGIES SUPPORTEES${NC}"
                echo ""
                echo -e "  ${CYAN}Node.js${NC}    package.json → npm/yarn/pnpm dev"
                echo -e "  ${CYAN}Python${NC}     requirements.txt → venv + pip + python"
                echo -e "  ${CYAN}Rust${NC}       Cargo.toml → cargo run"
                echo -e "  ${CYAN}Go${NC}         go.mod → go run ."
                echo ""
                echo -e "${GREEN}📦 FRAMEWORKS AUTO-DETECTES${NC}"
                echo ""
                echo -e "  ${CYAN}Next.js${NC}       npm dev (PORT via env)"
                echo -e "  ${CYAN}Astro${NC}         npm dev -- --port \$PORT --host"
                echo -e "  ${CYAN}Vite${NC}          npm dev -- --port \$PORT --host"
                echo -e "  ${CYAN}Nuxt${NC}          npm dev --port \$PORT"
                echo -e "  ${CYAN}Expo${NC}          npx expo start --dev-client --tunnel"
                echo -e "  ${CYAN}Django${NC}        python manage.py runserver 0.0.0.0:\$PORT"
                echo -e "  ${CYAN}Flask/FastAPI${NC}  python app.py"
                ;;
            4)
                echo -e "${GREEN}🔍 INSPECTEUR WEB (Sélection visuelle)${NC}"
                echo ""
                echo -e "  Injecte un sélecteur visuel dans ton app web :"
                echo ""
                echo -e "  ${CYAN}•${NC} Active/désactive via ${YELLOW}Options avancées → Outils Dev${NC}"
                echo -e "  ${CYAN}•${NC} Affiche des boutons numérotés sur chaque ${YELLOW}<div>${NC}"
                echo -e "  ${CYAN}•${NC} ${GREEN}Clic${NC} → Copie le XPath"
                echo -e "  ${CYAN}•${NC} ${GREEN}Appui long${NC} → Menu capture d'écran"
                echo ""
                echo -e "${GREEN}🖥️  CONSOLE ERUDA${NC}"
                echo ""
                echo -e "  Console de dev mobile (activable par projet) :"
                echo ""
                echo -e "  ${CYAN}•${NC} console.log, requêtes réseau, DOM, erreurs JS"
                echo -e "  ${CYAN}•${NC} localStorage, cookies"
                echo ""
                echo -e "${YELLOW}💡 Les deux outils sont configurables indépendamment${NC}"
                echo -e "   ${CYAN}Options avancées → Outils Dev → choisis un projet${NC}"
                ;;
        esac

        echo ""
        echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
        echo -e "  ${CYAN}p${NC} Précédent   ${CYAN}Entrée/n${NC} Suivant   ${CYAN}1-4${NC} Aller à   ${CYAN}x${NC} Retour"
        echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
        echo ""
        echo -e "${YELLOW}[$page/$total_pages] :${NC} \c"
        read -r help_choice

        case $help_choice in
            ""|n|N)
                [ $page -lt $total_pages ] && page=$((page + 1))
                ;;
            p|P|b|B)
                [ $page -gt 1 ] && page=$((page - 1))
                ;;
            x|X|q|Q)
                return
                ;;
            [1-4])
                page=$help_choice
                ;;
        esac
    done
}

# -----------------------------------------------------------------------------
# show_mobile_guide - Step-by-step guide for Expo + Android
# -----------------------------------------------------------------------------
show_mobile_guide() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "          ${YELLOW}📱 Guide Mobile — Expo + Android${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "Ce guide configure ton téléphone Android pour le dev en live."
    echo -e "Suis les étapes dans l'ordre. Ce qui est déjà fait sera ignoré."
    echo ""
    echo -e "${YELLOW}Appuie sur Entrée pour commencer...${NC}"
    read -r

    # ── ÉTAPE 1 : EAS CLI ──────────────────────────────────────────────────
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "  ${YELLOW}ÉTAPE 1/4${NC} — Installation de EAS CLI"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo ""
    if command -v eas >/dev/null 2>&1; then
        local eas_ver
        eas_ver=$(eas --version 2>/dev/null | head -1)
        echo -e "  ${GREEN}✅ EAS CLI déjà installé${NC} ($eas_ver)"
    else
        echo -e "  ${YELLOW}⚠️  EAS CLI non trouvé. Installation...${NC}"
        echo ""
        npm install -g eas-cli
        if command -v eas >/dev/null 2>&1; then
            echo -e "  ${GREEN}✅ EAS CLI installé${NC}"
        else
            echo -e "  ${RED}❌ Échec de l'installation. Vérifie que npm est dispo.${NC}"
            echo ""
            echo -e "${YELLOW}Appuie sur Entrée pour quitter le guide...${NC}"
            read -r
            return 1
        fi
    fi
    echo ""
    echo -e "${YELLOW}Appuie sur Entrée pour l'étape suivante...${NC}"
    read -r

    # ── ÉTAPE 2 : Connexion EAS ────────────────────────────────────────────
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "  ${YELLOW}ÉTAPE 2/4${NC} — Connexion à ton compte Expo"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo ""
    local eas_user
    eas_user=$(eas whoami 2>/dev/null)
    if [ -n "$eas_user" ] && [[ "$eas_user" != *"Not logged"* ]]; then
        echo -e "  ${GREEN}✅ Connecté en tant que: $eas_user${NC}"
    else
        echo -e "  ${YELLOW}⚠️  Pas connecté à Expo. Lance la connexion...${NC}"
        echo ""
        eas login
        eas_user=$(eas whoami 2>/dev/null)
        if [ -n "$eas_user" ] && [[ "$eas_user" != *"Not logged"* ]]; then
            echo -e "  ${GREEN}✅ Connecté en tant que: $eas_user${NC}"
        else
            echo -e "  ${RED}❌ Connexion échouée. Réessaie depuis le guide.${NC}"
            echo ""
            echo -e "${YELLOW}Appuie sur Entrée pour quitter...${NC}"
            read -r
            return 1
        fi
    fi
    echo ""
    echo -e "${YELLOW}Appuie sur Entrée pour l'étape suivante...${NC}"
    read -r

    # ── ÉTAPE 3 : Build APK ────────────────────────────────────────────────
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "  ${YELLOW}ÉTAPE 3/4${NC} — Build de l'APK de développement"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${BLUE}ℹ️  C'est la seule étape longue (10-15 min).${NC}"
    echo -e "  ${BLUE}   Le build tourne sur les serveurs Expo, pas sur ce serveur.${NC}"
    echo -e "  ${BLUE}   Tu fais ça UNE SEULE FOIS. Ensuite, l'APK reste sur ton tel.${NC}"
    echo ""

    local expo_projects=""
    for d in /root/*/; do
        [ -f "${d}package.json" ] || continue
        if grep -q '"expo"' "${d}package.json" 2>/dev/null || grep -q '"expo-router"' "${d}package.json" 2>/dev/null; then
            expo_projects="$expo_projects$(basename "$d")\n"
        fi
    done
    expo_projects=$(printf "%b" "$expo_projects" | grep -v "^$")

    if [ -z "$expo_projects" ]; then
        echo -e "  ${YELLOW}⚠️  Aucun projet Expo trouvé dans /root/${NC}"
        echo -e "  ${BLUE}   Déploie d'abord ton projet depuis le menu principal.${NC}"
        echo ""
        echo -e "${YELLOW}Appuie sur Entrée pour quitter...${NC}"
        read -r
        return 0
    fi

    local selected_project
    selected_project=$(echo "$expo_projects" | ui_choose "Sélectionne ton projet Expo :")

    if [ -z "$selected_project" ]; then
        echo -e "${BLUE}Annulé${NC}"
        return 0
    fi

    local project_dir="/root/$selected_project"
    echo ""
    echo -e "  ${GREEN}Projet: $selected_project${NC}"
    echo ""
    echo -e "  ${YELLOW}Lancer le build Android? (o/N):${NC} \c"
    read -r build_confirm

    if [[ "$build_confirm" =~ ^[oOyY]$ ]]; then
        echo ""
        echo -e "  ${BLUE}🔨 Build en cours... (ne ferme pas ce terminal)${NC}"
        echo ""
        cd "$project_dir" && eas build --profile development --platform android
        echo ""
        echo -e "  ${GREEN}✅ Build terminé ! Télécharge l'APK depuis le lien ci-dessus.${NC}"
        echo -e "  ${BLUE}   Installe-le sur ton téléphone Android.${NC}"
    else
        echo -e "  ${BLUE}Build ignoré — si tu as déjà l'APK sur ton tel, c'est bon.${NC}"
    fi
    echo ""
    echo -e "${YELLOW}Appuie sur Entrée pour l'étape suivante...${NC}"
    read -r

    # ── ÉTAPE 4 : Démarrer le serveur Metro ───────────────────────────────
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "  ${YELLOW}ÉTAPE 4/4${NC} — Démarrer le serveur de développement"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${BLUE}Démarrage de $selected_project avec tunnel Expo...${NC}"
    echo ""
    env_start "$selected_project"
    echo ""

    echo -e "  ${BLUE}⏳ Attente de l'URL du tunnel (15 sec)...${NC}"
    sleep 15

    local tunnel_url
    tunnel_url=$(pm2 logs "$selected_project" --lines 50 --nostream 2>/dev/null \
        | grep -oE 'https?://[a-zA-Z0-9._-]+\.exp\.direct[^ ]*' \
        | tail -1)

    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "  ${GREEN}✅ Tout est prêt !${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo ""
    if [ -n "$tunnel_url" ]; then
        echo -e "  ${YELLOW}URL du tunnel :${NC}"
        echo -e "  ${CYAN}$tunnel_url${NC}"
        echo ""
        echo -e "  ${BLUE}1. Ouvre l'APK dev build sur ton téléphone${NC}"
        echo -e "  ${BLUE}2. Entre cette URL ou scanne le QR${NC}"
        echo -e "  ${BLUE}3. Modifie ton code → l'app se recharge automatiquement 🎉${NC}"
    else
        echo -e "  ${YELLOW}URL pas encore visible — vérifie les logs :${NC}"
        echo -e "  ${CYAN}pm2 logs $selected_project --lines 30${NC}"
        echo ""
        echo -e "  ${BLUE}1. Ouvre l'APK dev build sur ton téléphone${NC}"
        echo -e "  ${BLUE}2. Entre l'URL exp:// depuis les logs${NC}"
        echo -e "  ${BLUE}3. Modifie ton code → l'app se recharge automatiquement 🎉${NC}"
    fi
    echo ""
    echo -e "${YELLOW}Appuie sur Entrée pour revenir au menu...${NC}"
    read -r
}
