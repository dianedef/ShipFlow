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
        # Collect items
        local items=()
        if [ $# -gt 0 ]; then
            items=("$@")
        else
            while IFS= read -r line; do
                items+=("$line")
            done
        fi

        if [ ${#items[@]} -le 5 ]; then
            # Short list → gum choose (arrow keys)
            printf '%s\n' "${items[@]}" | gum choose --header "$prompt"
        else
            # Long list → gum filter (type to search)
            printf '%s\n' "${items[@]}" | gum filter --header "$prompt" --placeholder "Type to search..."
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

# -----------------------------------------------------------------------------
# ui_pause - "Press Enter to continue" with dual-mode support
#
# Arguments:
#   $1 - Optional message (default: "Appuie sur Entrée pour continuer...")
# -----------------------------------------------------------------------------
ui_pause() {
    local msg="${1:-Appuie sur Entrée pour continuer...}"
    if [ "$HAS_GUM" = true ]; then
        gum input --placeholder "$msg" --width 50 > /dev/null 2>&1
    else
        echo ""
        echo -e "${YELLOW}${msg}${NC}"
        read -r
    fi
}

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
# MEMORY (RAM) MONITORING UTILITIES
# ============================================================================

# mem_available_kb - Available memory in KB (MemAvailable from /proc/meminfo)
mem_available_kb() {
    awk '/^MemAvailable:/ {print $2}' /proc/meminfo 2>/dev/null
}

# mem_total_kb - Total memory in KB
mem_total_kb() {
    awk '/^MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null
}

# mem_available_human - Human-readable available memory (e.g. "20G")
mem_available_human() {
    local kb
    kb=$(mem_available_kb)
    if [ -z "$kb" ]; then
        echo "?"
        return
    fi
    local bytes=$((kb * 1024))
    if command -v numfmt >/dev/null 2>&1; then
        numfmt --to=iec "$bytes" 2>/dev/null || echo "${kb}K"
    else
        # Fallback: convert to GB
        echo "$((kb / 1024 / 1024))G"
    fi
}

# mem_total_human - Human-readable total memory
mem_total_human() {
    local kb
    kb=$(mem_total_kb)
    if [ -z "$kb" ]; then
        echo "?"
        return
    fi
    local bytes=$((kb * 1024))
    if command -v numfmt >/dev/null 2>&1; then
        numfmt --to=iec "$bytes" 2>/dev/null || echo "${kb}K"
    else
        echo "$((kb / 1024 / 1024))G"
    fi
}

# mem_is_low - Returns 0 if available memory < SHIPFLOW_MEM_WARN_GB
mem_is_low() {
    local avail_kb
    avail_kb=$(mem_available_kb)
    [ -z "$avail_kb" ] && return 1
    local warn_gb="${SHIPFLOW_MEM_WARN_GB:-4}"
    if ! [[ "$warn_gb" =~ ^[0-9]+$ ]]; then
        warn_gb=4
    fi
    local warn_kb=$((warn_gb * 1024 * 1024))
    [ "$avail_kb" -lt "$warn_kb" ]
}

# mem_top_processes - Top N processes sorted by RSS memory
# Output: USER PID %MEM RSS_HUMAN ELAPSED COMMAND
mem_top_processes() {
    local n="${1:-${SHIPFLOW_MONITOR_TOP_N:-15}}"
    # ps with RSS in KB, elapsed time, and command
    ps axo user,pid,pmem,rss,etimes,comm --sort=-rss --no-headers 2>/dev/null | head -n "$n" | while read -r user pid pmem rss etimes comm; do
        local rss_human
        if [ "$rss" -ge 1048576 ]; then
            rss_human="$(( rss / 1048576 ))G"
        elif [ "$rss" -ge 1024 ]; then
            rss_human="$(( rss / 1024 ))M"
        else
            rss_human="${rss}K"
        fi
        # Convert elapsed seconds to human readable
        local elapsed_human
        if [ "$etimes" -ge 86400 ]; then
            elapsed_human="$(( etimes / 86400 ))d$(( (etimes % 86400) / 3600 ))h"
        elif [ "$etimes" -ge 3600 ]; then
            elapsed_human="$(( etimes / 3600 ))h$(( (etimes % 3600) / 60 ))m"
        elif [ "$etimes" -ge 60 ]; then
            elapsed_human="$(( etimes / 60 ))m$(( etimes % 60 ))s"
        else
            elapsed_human="${etimes}s"
        fi
        printf "%s|%s|%s|%s|%s|%s\n" "$user" "$pid" "$pmem" "$rss_human" "$elapsed_human" "$comm"
    done
}

# mem_long_running_processes - Processes running longer than threshold
# Returns processes with etimes > SHIPFLOW_PROCESS_LONG_RUNNING_HOURS (in hours)
mem_long_running_processes() {
    local hours="${SHIPFLOW_PROCESS_LONG_RUNNING_HOURS:-24}"
    local threshold_secs=$((hours * 3600))
    # Only show processes using > 100MB RSS to filter noise
    ps axo user,pid,pmem,rss,etimes,comm --sort=-rss --no-headers 2>/dev/null | while read -r user pid pmem rss etimes comm; do
        if [ "$etimes" -ge "$threshold_secs" ] && [ "$rss" -ge 102400 ]; then
            local rss_human
            if [ "$rss" -ge 1048576 ]; then
                rss_human="$(( rss / 1048576 ))G"
            elif [ "$rss" -ge 1024 ]; then
                rss_human="$(( rss / 1024 ))M"
            else
                rss_human="${rss}K"
            fi
            local days=$(( etimes / 86400 ))
            local hours_rem=$(( (etimes % 86400) / 3600 ))
            local elapsed_human="${days}d${hours_rem}h"
            printf "%s|%s|%s|%s|%s|%s\n" "$user" "$pid" "$pmem" "$rss_human" "$elapsed_human" "$comm"
        fi
    done
}

# mem_alerts - Generate alerts for concerning memory situations
# Output: one alert per line (severity|message)
mem_alerts() {
    local alerts=()

    # Check low memory
    if mem_is_low; then
        local avail
        avail=$(mem_available_human)
        local total
        total=$(mem_total_human)
        alerts+=("critical|RAM critically low: ${avail} available of ${total} total")
    fi

    # Check for long-running heavy processes
    local long_running
    long_running=$(mem_long_running_processes)
    if [ -n "$long_running" ]; then
        local count
        count=$(echo "$long_running" | wc -l)
        alerts+=("warning|${count} process(es) running ${SHIPFLOW_PROCESS_LONG_RUNNING_HOURS:-24}h+ with >100MB RAM")
    fi

    # Check if any single process uses > 25% of total RAM
    local total_kb
    total_kb=$(mem_total_kb)
    if [ -n "$total_kb" ] && [ "$total_kb" -gt 0 ]; then
        local threshold_kb=$(( total_kb / 4 ))
        ps axo pid,rss,comm --sort=-rss --no-headers 2>/dev/null | head -5 | while read -r pid rss comm; do
            if [ "$rss" -ge "$threshold_kb" ]; then
                local rss_mb=$(( rss / 1024 ))
                echo "warning|Process '${comm}' (PID ${pid}) using ${rss_mb}MB — over 25% of total RAM"
            fi
        done
    fi

    # Print collected alerts
    for alert in "${alerts[@]}"; do
        echo "$alert"
    done
}

# system_monitor_menu - Interactive system resource monitor
system_monitor_menu() {
    echo -e "${GREEN}🖥️  System Monitor${NC}"
    echo ""

    # --- RAM Overview ---
    local avail total used_kb avail_kb total_kb used_pct
    avail=$(mem_available_human)
    total=$(mem_total_human)
    avail_kb=$(mem_available_kb)
    total_kb=$(mem_total_kb)
    if [ -n "$avail_kb" ] && [ -n "$total_kb" ] && [ "$total_kb" -gt 0 ]; then
        used_kb=$((total_kb - avail_kb))
        used_pct=$((used_kb * 100 / total_kb))
    else
        used_pct="?"
    fi

    echo -e "${BLUE}━━━ Memory Overview ━━━${NC}"
    echo -e "  Available: ${GREEN}${avail}${NC}  /  Total: ${CYAN}${total}${NC}  (${YELLOW}${used_pct}%${NC} used)"

    # Visual bar
    if [[ "$used_pct" =~ ^[0-9]+$ ]]; then
        local bar_width=30
        local filled=$(( used_pct * bar_width / 100 ))
        local empty=$(( bar_width - filled ))
        local bar_color="${GREEN}"
        if [ "$used_pct" -ge 80 ]; then
            bar_color="${RED}"
        elif [ "$used_pct" -ge 60 ]; then
            bar_color="${YELLOW}"
        fi
        printf "  [${bar_color}"
        printf '%0.s█' $(seq 1 $filled 2>/dev/null) 2>/dev/null || true
        printf "${NC}"
        printf '%0.s░' $(seq 1 $empty 2>/dev/null) 2>/dev/null || true
        printf "] %s%%\n" "$used_pct"
    fi
    echo ""

    # --- Alerts ---
    local alerts
    alerts=$(mem_alerts)
    if [ -n "$alerts" ]; then
        echo -e "${RED}━━━ Alerts ━━━${NC}"
        while IFS='|' read -r severity msg; do
            case "$severity" in
                critical) echo -e "  ${RED}🔴 $msg${NC}" ;;
                warning)  echo -e "  ${YELLOW}🟠 $msg${NC}" ;;
                info)     echo -e "  ${BLUE}🔵 $msg${NC}" ;;
            esac
        done <<< "$alerts"
        echo ""
    fi

    # --- Long-running processes ---
    local long_procs
    long_procs=$(mem_long_running_processes)
    if [ -n "$long_procs" ]; then
        echo -e "${YELLOW}━━━ Long-Running Processes (${SHIPFLOW_PROCESS_LONG_RUNNING_HOURS:-24}h+, >100MB) ━━━${NC}"
        printf "  ${CYAN}%-10s %-7s %5s %7s %8s  %-s${NC}\n" "USER" "PID" "%MEM" "RSS" "UPTIME" "COMMAND"
        while IFS='|' read -r user pid pmem rss elapsed comm; do
            printf "  ${YELLOW}%-10s %-7s %5s %7s %8s${NC}  %s\n" "$user" "$pid" "$pmem" "$rss" "$elapsed" "$comm"
        done <<< "$long_procs"
        echo ""
    fi

    # --- Top processes ---
    echo -e "${BLUE}━━━ Top Processes by Memory ━━━${NC}"
    printf "  ${CYAN}%-10s %-7s %5s %7s %8s  %-s${NC}\n" "USER" "PID" "%MEM" "RSS" "UPTIME" "COMMAND"
    local top_procs
    top_procs=$(mem_top_processes)
    if [ -n "$top_procs" ]; then
        while IFS='|' read -r user pid pmem rss elapsed comm; do
            # Highlight long-running or heavy processes
            local line_color=""
            if [[ "$elapsed" == *d* ]]; then
                line_color="${YELLOW}"
            fi
            printf "  ${line_color}%-10s %-7s %5s %7s %8s${NC}  %s\n" "$user" "$pid" "$pmem" "$rss" "$elapsed" "$comm"
        done <<< "$top_procs"
    fi
    echo ""

    # --- Swap ---
    local swap_total swap_used
    swap_total=$(awk '/^SwapTotal:/ {print $2}' /proc/meminfo 2>/dev/null)
    swap_used=$(awk '/^SwapFree:/ {print $2}' /proc/meminfo 2>/dev/null)
    if [ -n "$swap_total" ] && [ "$swap_total" -gt 0 ]; then
        local swap_used_kb=$((swap_total - swap_used))
        echo -e "${BLUE}━━━ Swap ━━━${NC}"
        echo -e "  Used: $(( swap_used_kb / 1024 ))M  /  Total: $(( swap_total / 1024 ))M"
    else
        echo -e "${BLUE}Swap:${NC} none configured"
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
    MENU_STATUS_MEM_HUMAN=""
    MENU_STATUS_LOW_MEM=0

    [ -f "$MENU_STATUS_CACHE_FILE" ] || return 1

    while IFS='=' read -r key value; do
        case "$key" in
            ts) MENU_STATUS_TS="$value" ;;
            free_human) MENU_STATUS_FREE_HUMAN="$value" ;;
            updates_total) MENU_STATUS_UPDATES_TOTAL="$value" ;;
            low_space) MENU_STATUS_LOW_SPACE="$value" ;;
            mem_human) MENU_STATUS_MEM_HUMAN="$value" ;;
            low_mem) MENU_STATUS_LOW_MEM="$value" ;;
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
    local mem_human
    mem_human=$(mem_available_human)
    local low_mem=0
    if mem_is_low; then
        low_mem=1
    fi

    local tmp_file
    tmp_file=$(mktemp "${MENU_STATUS_CACHE_FILE}.tmp.XXXXXX" 2>/dev/null) || return 1
    register_temp_file "$tmp_file"

    {
        echo "ts=$now"
        echo "free_human=$free_human"
        echo "updates_total=$updates_total"
        echo "low_space=$low_space"
        echo "mem_human=$mem_human"
        echo "low_mem=$low_mem"
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
#   tools (flox, git, jq, python3). Shows a clear visual summary so the user
#   always knows the state. Fails if critical tools are missing.
#
# Arguments:
#   $1 - "quiet" to skip the summary (default: verbose)
#
# Returns:
#   0 - All required tools present
#   1 - Missing required tools
# -----------------------------------------------------------------------------
check_prerequisites() {
    local mode="${1:-verbose}"
    local missing=()
    local warnings=()
    local ok_count=0
    local total_count=0

    # All tools: name|required|version_cmd
    local -a tools=(
        "node|required|node --version"
        "pm2|required|pm2 --version"
        "git|optional|git --version"
        "flox|optional|flox --version 2>&1 | head -1"
        "caddy|optional|caddy version 2>&1 | head -1"
        "python3|optional|python3 --version"
        "jq|optional|jq --version"
        "gh|optional|gh --version 2>&1 | head -1"
        "fuser|optional|fuser -V 2>&1 | head -1"
    )

    if [ "$mode" != "quiet" ]; then
        echo -e "${BLUE}🔍 Vérification des outils...${NC}"
        echo ""
    fi

    for entry in "${tools[@]}"; do
        local cmd="${entry%%|*}"
        local rest="${entry#*|}"
        local level="${rest%%|*}"
        local ver_cmd="${rest#*|}"
        total_count=$((total_count + 1))

        if command -v "$cmd" >/dev/null 2>&1; then
            ok_count=$((ok_count + 1))
            if [ "$mode" != "quiet" ]; then
                local ver
                ver=$(eval "$ver_cmd" 2>/dev/null | head -1 | sed 's/^[[:space:]]*//')
                echo -e "  ${GREEN}✅ $cmd${NC} — $ver"
            fi
        else
            if [ "$level" = "required" ]; then
                missing+=("$cmd")
                [ "$mode" != "quiet" ] && echo -e "  ${RED}❌ $cmd${NC} — ${RED}REQUIS, manquant !${NC}"
            else
                warnings+=("$cmd")
                [ "$mode" != "quiet" ] && echo -e "  ${YELLOW}⚠️  $cmd${NC} — optionnel, non installé"
            fi
        fi
    done

    if [ "$mode" != "quiet" ]; then
        echo ""
        if [ ${#missing[@]} -gt 0 ]; then
            echo -e "${RED}╔══════════════════════════════════════════════════════════╗${NC}"
            echo -e "${RED}║  ⛔  Outils requis manquants : ${missing[*]}${NC}"
            echo -e "${RED}║  Lancez : ${YELLOW}sudo ./install.sh${RED} pour installer${NC}"
            echo -e "${RED}╚══════════════════════════════════════════════════════════╝${NC}"
        elif [ ${#warnings[@]} -gt 0 ]; then
            echo -e "  ${GREEN}$ok_count/$total_count outils OK${NC} — ${YELLOW}${#warnings[@]} optionnel(s) manquant(s)${NC}"
        else
            echo -e "  ${GREEN}✅ $ok_count/$total_count outils OK — tout est prêt !${NC}"
        fi
        echo ""
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        return 1
    fi

    return 0
}

# show_tools_status - Display full tools status (for menu use)
show_tools_status() {
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "              ${YELLOW}État des outils${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo ""
    check_prerequisites "verbose"
    echo -e "${BLUE}💡 Pour installer les outils manquants :${NC}"
    echo -e "   ${CYAN}sudo ./install.sh${NC}"
    echo ""
}

# -----------------------------------------------------------------------------
# install_sdk_menu - Interactive menu to install optional development SDKs
#
# Description:
#   Allows manual installation of global SDKs that are NOT required by ShipFlow
#   but useful for development (Flutter/Dart, etc.).
#   Requires sudo for system-wide installation.
# -----------------------------------------------------------------------------
install_sdk_menu() {
    local flutter_install_dir="/opt/flutter"
    local flutter_profile="/etc/profile.d/flutter.sh"

    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "              ${YELLOW}Install SDK${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo ""

    # Flutter status
    local flutter_status
    if command -v flutter >/dev/null 2>&1; then
        local flutter_ver
        flutter_ver=$(flutter --version 2>&1 | head -n1)
        flutter_status="${GREEN}installed${NC} — $flutter_ver"
    else
        flutter_status="${YELLOW}not installed${NC}"
    fi

    echo -e "  ${CYAN}1)${NC} Flutter + Dart  [$flutter_status]"
    echo -e "  ${CYAN}0)${NC} Back"
    echo ""
    echo -e "${YELLOW}Your choice:${NC} \c"
    read -r sdk_choice

    case $sdk_choice in
        1)
            if command -v flutter >/dev/null 2>&1; then
                echo -e "${GREEN}Flutter is already installed.${NC}"
                echo -e "  Version: $(flutter --version 2>&1 | head -n1)"
                echo -e "  Dart:    $(dart --version 2>&1)"
                echo ""
                echo -e "${BLUE}To update: flutter upgrade${NC}"
                return 0
            fi

            # Requires root
            if [ "$EUID" -ne 0 ]; then
                echo -e "${RED}Installation requires root privileges.${NC}"
                echo -e "${YELLOW}Run: ${CYAN}sudo sf${YELLOW} then Advanced > Install SDK${NC}"
                return 1
            fi

            echo -e "${BLUE}Installing Flutter SDK to $flutter_install_dir...${NC}"
            echo ""

            # Migration: move existing per-user SDK if present
            local old_sdk="$HOME/.flutter-sdk"
            if [ -d "$old_sdk" ] && [ ! -d "$flutter_install_dir" ]; then
                echo -e "${YELLOW}Found existing SDK at $old_sdk${NC}"
                if ui_confirm "Migrate to $flutter_install_dir?"; then
                    mv "$old_sdk" "$flutter_install_dir"
                    chown -R root:root "$flutter_install_dir"
                    chmod -R a+rX "$flutter_install_dir"
                    echo -e "${GREEN}SDK migrated.${NC}"
                fi
            fi

            # Fresh install if not yet present
            if [ ! -d "$flutter_install_dir" ]; then
                git clone -b stable https://github.com/flutter/flutter.git "$flutter_install_dir"
            fi

            # Configure system-wide PATH
            echo "export PATH=\"$flutter_install_dir/bin:\$PATH\"" > "$flutter_profile"
            export PATH="$flutter_install_dir/bin:$PATH"

            if command -v flutter >/dev/null 2>&1; then
                # Disable telemetry
                flutter config --no-analytics >/dev/null 2>&1 || true
                dart --disable-analytics >/dev/null 2>&1 || true
                # Pre-cache web tools (main use case on server)
                echo -e "${BLUE}Running flutter precache --web...${NC}"
                flutter precache --web >/dev/null 2>&1 || true
                echo ""
                echo -e "${GREEN}Flutter installed successfully!${NC}"
                echo -e "  $(flutter --version 2>&1 | head -n1)"
                echo -e "  $(dart --version 2>&1)"
                echo ""
                echo -e "${BLUE}All users will have flutter/dart in PATH after next login.${NC}"
                echo -e "${BLUE}For current session: ${CYAN}source $flutter_profile${NC}"
            else
                echo -e "${RED}Flutter installation failed.${NC}"
                echo -e "${YELLOW}Manual install: git clone -b stable https://github.com/flutter/flutter.git $flutter_install_dir${NC}"
            fi
            ;;
        *)
            ;;
    esac
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

# Detect whether a pubspec project is Flutter or plain Dart
detect_pubspec_kind() {
    local project_dir=$1

    cd "$project_dir" || return 1

    if [ ! -f "pubspec.yaml" ]; then
        return 1
    fi

    if grep -Eq '^[[:space:]]*flutter:' "pubspec.yaml"; then
        echo "flutter"
    else
        echo "dart"
    fi
}

# Detect a likely Dart entrypoint for server-style apps
detect_dart_entrypoint() {
    local project_dir=$1

    cd "$project_dir" || return 1

    if [ -f "bin/server.dart" ]; then
        echo "bin/server.dart"
    elif [ -f "bin/main.dart" ]; then
        echo "bin/main.dart"
    elif [ -f "main.dart" ]; then
        echo "main.dart"
    elif [ -f "bin/${project_dir##*/}.dart" ]; then
        echo "bin/${project_dir##*/}.dart"
    fi
}

# Detect project type and return package manager info
detect_project_type() {
    local project_dir=$1
    local pubspec_kind=""
    
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
    elif [ -f "pubspec.yaml" ]; then
        pubspec_kind=$(detect_pubspec_kind "$project_dir")
        if [ "$pubspec_kind" = "dart" ]; then
            echo "dart:dart"
        else
            echo "flutter:flutter"
        fi
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
        dart)
            echo -e "${BLUE}🎯 Projet Dart détecté — installation de Dart...${NC}"
            flox install dart
            ;;
        flutter)
            if command -v flutter >/dev/null 2>&1; then
                echo -e "${BLUE}🦋 Projet Flutter détecté — SDK Flutter disponible${NC}"
            else
                echo -e "${YELLOW}⚠️ Projet Flutter détecté mais SDK non trouvé dans le PATH${NC}"
                echo -e "${YELLOW}   Installez via : sf → Advanced → Install SDK${NC}"
            fi
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
    local pubspec_kind=""
    
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
    elif [ -f "pubspec.yaml" ]; then
        pubspec_kind=$(detect_pubspec_kind "$project_dir")
        if [ "$pubspec_kind" = "dart" ]; then
            local dart_entrypoint=""
            dart_entrypoint=$(detect_dart_entrypoint "$project_dir")
            if [ -n "$dart_entrypoint" ]; then
                echo "dart pub get && dart run $dart_entrypoint"
            else
                echo "dart pub get && dart run"
            fi
        elif [ -x "./pm2-web.sh" ]; then
            echo "./pm2-web.sh"
        elif [ -x "./build.sh" ]; then
            echo "./build.sh --serve"
        elif [ -d "web" ]; then
            echo "flutter config --enable-web >/dev/null 2>&1 || true && flutter pub get && flutter run -d web-server --web-hostname 0.0.0.0 --web-port \$PORT"
        else
            echo "echo 'Flutter project detected but no web target or pm2 entrypoint found' && exit 1"
        fi
    else
        echo "echo 'No dev command detected'"
    fi
}

escape_single_quotes_for_bash() {
    printf "%s" "$1" | sed "s/'/'\"'\"'/g"
}

project_has_doppler_manifest() {
    local project_dir=$1

    [ -f "$project_dir/doppler.yaml" ] || [ -f "$project_dir/.doppler.yaml" ]
}

project_has_doppler_scope() {
    local project_dir=$1
    local doppler_state_file="$HOME/.doppler/.doppler.yaml"
    local current_dir=""

    [ -f "$doppler_state_file" ] || return 1

    current_dir="$project_dir"
    while [ -n "$current_dir" ] && [ "$current_dir" != "/" ]; do
        if grep -Fq "    $current_dir:" "$doppler_state_file"; then
            return 0
        fi
        current_dir=$(dirname "$current_dir")
    done

    return 1
}

should_enable_doppler() {
    local project_dir=$1
    local mode="${SHIPFLOW_DOPPLER_MODE:-auto}"

    if ! command -v doppler >/dev/null 2>&1; then
        return 1
    fi

    case "$mode" in
        always)
            return 0
            ;;
        never)
            return 1
            ;;
        auto|*)
            if project_has_doppler_manifest "$project_dir" || project_has_doppler_scope "$project_dir"; then
                return 0
            fi
            return 1
            ;;
    esac
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
    local doppler_enabled=false
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
                doppler_enabled=true
            fi
        fi
    fi

    if [ "$doppler_enabled" != "true" ] && should_enable_doppler "$project_dir"; then
        doppler_prefix="doppler run -- "
        doppler_enabled=true
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
    if [ "$doppler_enabled" = "true" ]; then
        echo -e "${BLUE}🔐 Doppler: activé (${SHIPFLOW_DOPPLER_MODE:-auto})${NC}"
    else
        echo -e "${BLUE}🔐 Doppler: désactivé${NC}"
    fi

    # Replace $PORT in dev_cmd with actual port value
    local final_cmd="${dev_cmd//\$PORT/$port}"
    local runtime_cmd="$final_cmd"

    # For Doppler projects, override PORT after doppler injects its env vars
    # to prevent Doppler's PORT value from taking precedence over ShipFlow's assignment
    if [ -n "$doppler_prefix" ]; then
        runtime_cmd="env PORT=$port $final_cmd"
    fi

    local escaped_runtime_cmd
    escaped_runtime_cmd=$(escape_single_quotes_for_bash "$runtime_cmd")

    local pm2_launch_cmd=""
    if [ "$is_expo" = "true" ]; then
        pm2_launch_cmd="flox activate -- bash -lc '$escaped_runtime_cmd'"
    else
        pm2_launch_cmd="export PORT=$port && flox activate -- ${doppler_prefix}bash -lc '$escaped_runtime_cmd'"
    fi

    # Create persistent ecosystem file (Expo has no PORT)
    if [ "$is_expo" = "true" ]; then
        cat > "$pm2_config" <<EOF
module.exports = {
  apps: [{
    name: "$env_name",
    cwd: "$project_dir",
    script: "bash",
    args: ["-lc", "$pm2_launch_cmd"],
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
    args: ["-lc", "$pm2_launch_cmd"],
    env: {
      PORT: $port
    },
    autorestart: true,
    watch: false
  }]
};
EOF
    fi

    if [ ! -f "$pm2_config" ]; then
        error "Impossible de créer $pm2_config"
        return 1
    fi

    echo -e "${GREEN}✅ Fichier ecosystem.config.cjs créé/mis à jour${NC}"

    # Atomic cleanup of existing process (Priority 3 #11: Fix race condition)
    # Use pm2 delete with idempotent operation (no check-then-act)
    pm2 delete "$env_name" 2>/dev/null || true

    # Kill any lingering processes on the port to avoid zombies (skip for Expo)
    if [ "$is_expo" = "false" ] && command -v fuser >/dev/null 2>&1; then
        fuser -k "$port/tcp" 2>/dev/null || true
    fi

    # Small delay to ensure port is fully released
    sleep 0.5

    if ! pm2 start "$pm2_config"; then
        error "Échec du démarrage PM2 pour $env_name"
        return 1
    fi
    pm2 save >/dev/null 2>&1

    # Invalidate cache after PM2 state change
    invalidate_pm2_cache

    local started_status
    started_status=$(get_pm2_status "$env_name")
    if [ "$started_status" != "online" ] && [ "$started_status" != "launching" ]; then
        error "PM2 n'a pas démarré $env_name correctement (statut: ${started_status:-unknown})"
        return 1
    fi

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

# Web Inspector Functions
# Generate CSS selector for an element
generate_css_selector() {
    local element="$1"
    echo "css-selector-for-$element" | sed 's/[^a-zA-Z0-9_-]/-/g'
}

remove_next_script_import_if_unused() {
    local layout_file=$1

    [ -f "$layout_file" ] || return 0

    if grep -q 'shipflow-inspector' "$layout_file"; then
        return 0
    fi

    if grep -q 'import Script from "next/script";' "$layout_file" && ! grep -q '<Script' "$layout_file"; then
        sed -i '/import Script from "next\/script";/d' "$layout_file"
    fi
}

remove_web_inspector_snippet() {
    local target_file=$1

    [ -f "$target_file" ] || return 0

    perl -0pi -e 's/\s*<!-- shipflow-inspector -->\s*<script src="\/shipflow-inspector\.js" defer><\/script>\s*//g' "$target_file"
    perl -0pi -e 's/\s*<Script src="\/shipflow-inspector\.js" strategy="afterInteractive" id="shipflow-inspector" \/>\s*//g' "$target_file"
}

web_inspector_is_enabled() {
    if [ -f "public/shipflow-inspector.js" ]; then
        return 0
    fi

    if [ -f "index.html" ] && grep -q 'shipflow-inspector' "index.html"; then
        return 0
    fi

    local layout=""
    for layout in src/layouts/*.astro \
        app/layout.tsx app/layout.jsx src/app/layout.tsx src/app/layout.jsx \
        apps/*/app/layout.tsx apps/*/app/layout.jsx apps/*/src/app/layout.tsx apps/*/src/app/layout.jsx \
        packages/*/app/layout.tsx packages/*/app/layout.jsx packages/*/src/app/layout.tsx packages/*/src/app/layout.jsx; do
        [ -f "$layout" ] || continue
        if grep -q 'shipflow-inspector' "$layout"; then
            return 0
        fi
    done

    local app_dir=""
    for app_dir in apps/* packages/*; do
        [ -d "$app_dir" ] || continue
        if [ -f "$app_dir/public/shipflow-inspector.js" ]; then
            return 0
        fi
    done

    return 1
}

# Initialize web inspector
init_web_inspector() {
    local script_path="${SCRIPT_DIR}/injectors/web-inspector.js"
    local script_name="shipflow-inspector.js"
    local marker="<!-- shipflow-inspector -->"
    local script_tag='<script src="/shipflow-inspector.js" defer></script>'

    if [ ! -f "$script_path" ]; then
        log ERROR "Web inspector script not found at $script_path"
        echo "Error: Web inspector script not found at $script_path"
        return 1
    fi

    # Step 1: Copy script to project's public/ directory
    mkdir -p public
    cp "$script_path" "public/$script_name"
    echo "Copied web inspector to public/$script_name"

    # Step 2: Add script tag to the appropriate file
    if [ -f "index.html" ]; then
        # Vite/React/Vue projects with root index.html
        if ! grep -q "shipflow-inspector" "index.html"; then
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
            if grep -q "</body>" "$layout" && ! grep -q "shipflow-inspector" "$layout"; then
                sed -i "s|</body>|  ${marker}\n  ${script_tag}\n</body>|" "$layout"
                echo "Injected script tag into $layout"
                injected=true
            elif grep -q "shipflow-inspector" "$layout"; then
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
                                cp "$script_path" "$app_dir/public/$script_name"
                                echo "Copied web inspector to $app_dir/public/$script_name"
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
            elif grep -q "shipflow-inspector" "$layout_file"; then
                echo "Script already present in $layout_file"
            else
                # Add Script import if not present
                if ! grep -q "from ['\"]next/script['\"]" "$layout_file"; then
                    # Add import after the first import line
                    sed -i '0,/^import /s//import Script from "next\/script";\n&/' "$layout_file"
                    echo "Added Script import to $layout_file"
                fi

                # Add Script component before </body>
                local nextjs_script='<Script src="/shipflow-inspector.js" strategy="afterInteractive" id="shipflow-inspector" />'
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

    if web_inspector_is_enabled; then
        # Disable: remove JS file
        rm -f "public/shipflow-inspector.js"

        # Remove injected lines from index.html
        if [ -f "index.html" ]; then
            remove_web_inspector_snippet "index.html"
        fi

        # Remove from Astro layouts
        for layout in src/layouts/*.astro; do
            [ -f "$layout" ] || continue
            remove_web_inspector_snippet "$layout"
        done

        # Remove from Next.js layouts
        for candidate in "app/layout.tsx" "app/layout.jsx" "src/app/layout.tsx" "src/app/layout.jsx"; do
            [ -f "$candidate" ] || continue
            remove_web_inspector_snippet "$candidate"
            remove_next_script_import_if_unused "$candidate"
        done

        # Remove from monorepo app layouts
        for app_dir in apps/* packages/*; do
            [ -d "$app_dir" ] || continue
            rm -f "$app_dir/public/shipflow-inspector.js" 2>/dev/null
            for candidate in "$app_dir/app/layout.tsx" "$app_dir/app/layout.jsx" "$app_dir/src/app/layout.tsx" "$app_dir/src/app/layout.jsx"; do
                [ -f "$candidate" ] || continue
                remove_web_inspector_snippet "$candidate"
                remove_next_script_import_if_unused "$candidate"
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
    local idle_names=""
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

        # Compute uptime from pm_uptime (epoch ms when app started)
        local uptime_tag=""
        local uptime_human=""
        local idle_flag=false
        if [ -n "$health_data" ] && [ -n "$app_health_line" ]; then
            local pm_uptime_ms
            pm_uptime_ms=$(echo "$app_health_line" | cut -d'|' -f4)
            if [ -n "$pm_uptime_ms" ] && [ "$pm_uptime_ms" != "0" ] && [ "$status" = "online" ]; then
                local now_ms=$(( $(date +%s) * 1000 ))
                local running_ms=$(( now_ms - pm_uptime_ms ))
                local running_secs=$(( running_ms / 1000 ))
                if [ "$running_secs" -ge 86400 ]; then
                    local days=$(( running_secs / 86400 ))
                    local hours=$(( (running_secs % 86400) / 3600 ))
                    uptime_human="${days}d${hours}h"
                elif [ "$running_secs" -ge 3600 ]; then
                    local hours=$(( running_secs / 3600 ))
                    local mins=$(( (running_secs % 3600) / 60 ))
                    uptime_human="${hours}h${mins}m"
                elif [ "$running_secs" -ge 60 ]; then
                    uptime_human="$(( running_secs / 60 ))m"
                else
                    uptime_human="${running_secs}s"
                fi
                # Flag as idle if running longer than threshold
                local idle_hours="${SHIPFLOW_PROCESS_LONG_RUNNING_HOURS:-24}"
                local idle_secs=$(( idle_hours * 3600 ))
                if [ "$running_secs" -ge "$idle_secs" ]; then
                    idle_flag=true
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

        # Append uptime
        if [ -n "$uptime_human" ]; then
            if [ "$idle_flag" = true ]; then
                printf "  ${YELLOW}⏱ %s${NC}" "$uptime_human"
            else
                printf "  ${GREEN}⏱ %s${NC}" "$uptime_human"
            fi
        fi

        # Append crash loop tag
        if [ -n "$restart_tag" ]; then
            printf "%b" "$restart_tag"
        fi

        echo ""

        if [ "$idle_flag" = true ]; then
            idle_names+="$name "
        fi
    done <<< "$all_envs"

    echo ""
    echo -e "${BLUE}Total: $count environment(s)${NC}"

    # Idle apps — propose stopping directly
    if [ -n "${idle_names:-}" ]; then
        echo ""
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}💤 Long-running apps (${SHIPFLOW_PROCESS_LONG_RUNNING_HOURS:-24}h+):${NC} ${idle_names}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""

        # Build list for selection
        local idle_arr=()
        for n in $idle_names; do
            idle_arr+=("$n")
        done

        local stop_options=""
        for n in "${idle_arr[@]}"; do
            stop_options+="${n}"$'\n'
        done
        if [ "${#idle_arr[@]}" -gt 1 ]; then
            stop_options+="Stop all idle"$'\n'
        fi
        stop_options+="Skip"

        local stop_choice
        stop_choice=$(echo "$stop_options" | ui_choose "Stop an idle app to free RAM:")

        if [ -n "$stop_choice" ] && [ "$stop_choice" != "Skip" ]; then
            if [ "$stop_choice" = "Stop all idle" ]; then
                for n in "${idle_arr[@]}"; do
                    echo -e "${YELLOW}🛑 Stopping $n...${NC}"
                    env_stop "$n"
                    echo -e "${GREEN}✅ $n stopped${NC}"
                done
                log INFO "Dashboard: stopped all idle apps: ${idle_names}"
            else
                echo -e "${YELLOW}🛑 Stopping $stop_choice...${NC}"
                env_stop "$stop_choice"
                echo -e "${GREEN}✅ $stop_choice stopped${NC}"
                log INFO "Dashboard: stopped idle app $stop_choice"
            fi
        fi
    fi

    # Health alert banner
    if [ -n "$unhealthy_names" ]; then
        echo ""
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED}⚠️  Unhealthy apps detected!${NC} Run ${CYAN}health check${NC} (${CYAN}h${NC}) for diagnostics & auto-fix."
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
<!-- Populated by /sf-audit — dated sections added automatically -->
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
# HEADER & STATUS DISPLAY
# ============================================================================

print_header() {
    read_menu_status_cache >/dev/null 2>&1 || true
    refresh_menu_status_cache_async_if_stale

    local status_left="Free: ..."
    local status_right="Up: ..."
    if [ -n "$MENU_STATUS_FREE_HUMAN" ]; then
        status_left="Free: $MENU_STATUS_FREE_HUMAN"
        if [ -n "$MENU_STATUS_MEM_HUMAN" ]; then
            status_left="${status_left} | Mem: $MENU_STATUS_MEM_HUMAN"
        fi
    fi
    if [ -n "$MENU_STATUS_UPDATES_TOTAL" ]; then
        status_right="Up: $MENU_STATUS_UPDATES_TOTAL"
    fi

    ui_header "Shipflow DevServer" "Development Environment" "$status_left" "$status_right"

    if [ "${MENU_STATUS_LOW_SPACE:-0}" = "1" ]; then
        echo -e "${RED}⚠️  Low disk space. Consider running Disk Cleanup.${NC}"
    fi
    if [ "${MENU_STATUS_LOW_MEM:-0}" = "1" ]; then
        echo -e "${RED}⚠️  Low memory (RAM). Press h) Health Check.${NC}"
    fi

    local long_count
    long_count=$(mem_long_running_processes 2>/dev/null | wc -l)
    if [ "${long_count:-0}" -gt 0 ]; then
        echo -e "${YELLOW}⚠️  ${long_count} process(es) running ${SHIPFLOW_PROCESS_LONG_RUNNING_HOURS:-24}h+ — press h) Health Check${NC}"
    fi

    if [ "$SHIPFLOW_SESSION_ENABLED" = "true" ]; then
        init_session 2>/dev/null
        display_session_banner
        echo ""
    fi
}

# ============================================================================
# ACTION HANDLERS — Main Menu
# ============================================================================

action_dashboard() { show_dashboard; }
action_shipflow_overview() { show_shipflow_menu; }

action_deploy() {
    echo -e "${GREEN}🚀 Deploy Environment${NC}"
    echo ""

    local deploy_choice
    deploy_choice=$(printf '%s\n' \
        "🔍 Auto-detect project in /root" \
        "📁 Custom local path" \
        "🚀 Deploy from GitHub" \
        "Cancel" | ui_choose "Choose source:")

    case "$deploy_choice" in
        *Auto-detect*)
            echo -e "${BLUE}🔍 Scanning $PROJECTS_DIR for projects...${NC}"

            EXISTING_ENVS=$(find "$PROJECTS_DIR" -maxdepth 4 \
                \( -name "node_modules" -o -name ".git" -o -name "venv" -o -name ".venv" \
                   -o -name "__pycache__" -o -name "target" -o -name ".next" -o -name ".nuxt" \
                   -o -name "dist" -o -name ".cache" -o -name ".pnpm" -o -name ".yarn" \) -prune \
                -o -type d -name ".flox" -print 2>/dev/null | while read -r flox_dir; do
                proj_dir=$(dirname "$flox_dir")
                case "$proj_dir" in
                    "$PROJECTS_DIR"/.*) continue ;;
                    *) echo "$proj_dir" ;;
                esac
            done | sort -u)

            NEW_PROJECTS=$(find "$PROJECTS_DIR" -maxdepth 4 \
                \( -name "node_modules" -o -name ".git" -o -name "venv" -o -name ".venv" \
                   -o -name "__pycache__" -o -name "target" -o -name ".next" -o -name ".nuxt" \
                   -o -name "dist" -o -name ".cache" -o -name ".pnpm" -o -name ".yarn" \) -prune \
                -o -type f \( -name "package.json" -o -name "requirements.txt" -o -name "Cargo.toml" -o -name "go.mod" -o -name "pubspec.yaml" \) -print 2>/dev/null | while read -r manifest; do
                proj_dir=$(dirname "$manifest")
                case "$proj_dir" in
                    "$PROJECTS_DIR"/.*) continue ;;
                esac
                if [ ! -d "$proj_dir/.flox" ]; then
                    echo "$proj_dir"
                fi
            done | sort -u)

            PROJECTS=$(printf "%s\n%s" "$EXISTING_ENVS" "$NEW_PROJECTS" | grep -v "^$" | sort -u)

            if [ -z "$PROJECTS" ]; then
                echo -e "${YELLOW}⚠️  No projects detected${NC}"
                echo -e "${BLUE}💡 Tip: Use Custom path or Deploy from GitHub${NC}"
            else
                SELECTED_PROJECT=$(echo "$PROJECTS" | ui_choose "Detected projects:")
                if [ -n "$SELECTED_PROJECT" ]; then
                    log INFO "Menu: starting project $SELECTED_PROJECT"
                    echo -e "${GREEN}✅ Starting: $SELECTED_PROJECT${NC}"
                    env_start "$SELECTED_PROJECT"
                fi
            fi
            ;;
        *Custom*)
            CUSTOM_PATH=$(ui_input "Path (absolute):" "/root/my-project")
            if [ -z "$CUSTOM_PATH" ]; then
                echo -e "${RED}❌ Path required${NC}"
            elif ! validate_project_path "$CUSTOM_PATH"; then
                echo -e "${RED}❌ Invalid or unsafe path${NC}"
            else
                env_start "$CUSTOM_PATH"
            fi
            ;;
        *GitHub*)
            echo -e "${GREEN}🚀 Deploy from GitHub${NC}"
            echo ""
            echo -e "${BLUE}🔍 Fetching your GitHub repos...${NC}"
            echo ""
            GITHUB_REPOS=$(list_github_repos)
            if [ -z "$GITHUB_REPOS" ]; then
                echo -e "${YELLOW}All your GitHub repos are already deployed (or no repos found).${NC}"
                return
            fi
            SELECTED_REPO=$(echo "$GITHUB_REPOS" | cut -d':' -f1 | ui_choose "Available repos:")
            if [ -n "$SELECTED_REPO" ]; then
                if ! validate_repo_name "$SELECTED_REPO"; then
                    echo -e "${RED}❌ Invalid repository name${NC}"
                    return
                fi
                echo ""
                echo -e "${GREEN}📦 Selected repo: $SELECTED_REPO${NC}"
                echo -e "${BLUE}🚀 Deploying...${NC}"
                echo ""
                deploy_github_project "$SELECTED_REPO"
            fi
            ;;
        *) echo -e "${BLUE}Cancelled${NC}" ;;
    esac
}

action_restart() {
    echo -e "${GREEN}🔄 Restart Environment${NC}"
    ENV_NAME=$(select_environment "Select environment to restart")
    if [ -n "$ENV_NAME" ]; then
        log INFO "Menu: restarting $ENV_NAME"
        env_restart "$ENV_NAME"
    fi
}

action_stop() {
    echo -e "${GREEN}🛑 Stop Environment${NC}"
    ENV_NAME=$(select_environment "Select environment to stop")
    if [ -n "$ENV_NAME" ]; then
        log INFO "Menu: stopping $ENV_NAME"
        echo -e "${YELLOW}🛑 Stopping $ENV_NAME...${NC}"
        env_stop "$ENV_NAME"
        echo -e "${GREEN}✅ Environment $ENV_NAME stopped!${NC}"
    fi
}

action_remove() {
    echo -e "${GREEN}🗑️  Remove Environment${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  WARNING: This will permanently delete the project!${NC}"
    echo ""
    ENV_NAME=$(select_environment "Select environment to remove")
    if [ -n "$ENV_NAME" ]; then
        PROJECT_DIR=$(resolve_project_path "$ENV_NAME")
        echo ""
        echo -e "${RED}⚠️  You are about to delete:${NC}"
        echo -e "${YELLOW}   Environment: $ENV_NAME${NC}"
        echo -e "${YELLOW}   Directory: $PROJECT_DIR${NC}"
        echo ""
        if ui_confirm "Type 'yes' to confirm deletion"; then
            log INFO "Menu: removing environment $ENV_NAME (dir: $PROJECT_DIR)"
            env_remove "$ENV_NAME"
            echo -e "${GREEN}✅ Environment removed!${NC}"
        else
            echo -e "${BLUE}Cancelled - nothing was deleted${NC}"
        fi
    fi
}

action_start_all() { echo -e "${GREEN}🚀 Start All Environments${NC}"; batch_start_all; }
action_stop_all() { echo -e "${GREEN}🛑 Stop All Environments${NC}"; batch_stop_all; }
action_restart_all() { echo -e "${GREEN}🔄 Restart All Environments${NC}"; batch_restart_all; }
action_mobile() { show_mobile_guide; }

action_health() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}              ${YELLOW}Health Check${NC}                      ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    system_monitor_menu
    echo ""
    echo -e "${BLUE}━━━ App Health (PM2) ━━━${NC}"
    health_check_all verbose
    echo ""
    local fix_choice
    fix_choice=$(printf '%s\n' "Auto-fix known issues" "Back to menu" | ui_choose "Options:")
    if [ "$fix_choice" = "Auto-fix known issues" ]; then
        echo ""
        auto_fix_known_issues
        echo ""
        echo -e "${BLUE}Updated health status:${NC}"
        echo ""
        health_check_all verbose
    fi
}

action_exit() { echo -e "${GREEN}👋 Goodbye!${NC}"; exit 0; }

# ============================================================================
# ACTION HANDLERS — Advanced Menu
# ============================================================================

action_view_logs() {
    echo -e "${GREEN}📝 View Application Logs${NC}"
    ENV_NAME=$(select_environment "Select environment to view logs")
    if [ -n "$ENV_NAME" ]; then view_environment_logs "$ENV_NAME"; fi
}

action_navigate() {
    echo -e "${GREEN}📁 Navigate Projects in /root${NC}"
    FOLDERS=$(find /root -maxdepth 1 -type d ! -name ".*" ! -path /root 2>/dev/null | sort)
    if [ -z "$FOLDERS" ]; then
        echo -e "${RED}❌ No folders found${NC}"
    else
        SELECTED=$(echo "$FOLDERS" | ui_choose "Available folders:")
        if [ -n "$SELECTED" ]; then
            echo -e "${GREEN}📁 Selected folder: $SELECTED${NC}"
            echo -e "${GREEN}Opening shell...${NC}"
            cd "$SELECTED" && exec $SHELL
        fi
    fi
}

action_open_code() {
    echo -e "${GREEN}📂 Open Code Directory${NC}"
    ENV_NAME=$(select_environment "Select environment to open")
    if [ -n "$ENV_NAME" ]; then
        PROJECT_DIR=$(resolve_project_path "$ENV_NAME")
        if [ -z "$PROJECT_DIR" ]; then
            echo -e "${RED}❌ Directory not found: $ENV_NAME${NC}"
        else
            echo -e "${GREEN}📂 Project directory: $PROJECT_DIR${NC}"
            echo -e "${GREEN}Opening shell...${NC}"
            cd "$PROJECT_DIR" && exec $SHELL
        fi
    fi
}

action_inspector() {
    echo -e "${GREEN}🔍 Toggle Web Inspector${NC}"
    ENV_NAME=$(select_environment "Select environment for web inspector")
    if [ -n "$ENV_NAME" ]; then
        PROJECT_DIR=$(resolve_project_path "$ENV_NAME")
        if [ -z "$PROJECT_DIR" ]; then
            echo -e "${RED}❌ Project not found: $ENV_NAME${NC}"
        else
            log INFO "Menu: toggling web inspector for $ENV_NAME ($PROJECT_DIR)"
            toggle_web_inspector "$PROJECT_DIR"
            env_restart "$ENV_NAME"
        fi
    fi
}

action_session() {
    echo -e "${GREEN}🔐 Session Identity Management${NC}"
    echo ""
    display_session_banner
    echo ""
    get_session_info
    echo ""
    local session_choice
    session_choice=$(printf '%s\n' "Reset Session Identity" "Back" | ui_choose "Options:")
    if [ "$session_choice" = "Reset Session Identity" ]; then
        reset_session
        echo ""
        echo -e "${GREEN}New session identity:${NC}"
        display_session_banner
    fi
}

action_publish() {
    echo -e "${GREEN}🌐 Publish to Web (HTTPS via Caddy + DuckDNS)${NC}"
    echo ""
    if ! command -v caddy >/dev/null 2>&1; then
        echo -e "${RED}❌ Caddy not installed${NC}"
        echo -e "${YELLOW}Install with: sudo apt install caddy${NC}"
        return
    fi
    echo -e "${BLUE}📡 Detecting public IP...${NC}"
    PUBLIC_IP=$(curl -4 -s https://ip.me 2>/dev/null)
    if [ -n "$PUBLIC_IP" ]; then
        echo -e "${BLUE}📡 Detected Public IP: ${GREEN}$PUBLIC_IP${NC}"
    else
        echo -e "${YELLOW}⚠️  Could not detect public IP${NC}"
        PUBLIC_IP=$(ui_input "Enter public IP:")
    fi
    echo ""
    CACHED_SUBDOMAIN=$(load_secret "DUCKDNS_SUBDOMAIN" 2>/dev/null) || true
    CACHED_TOKEN=$(load_secret "DUCKDNS_TOKEN" 2>/dev/null) || true
    if [ -n "$CACHED_SUBDOMAIN" ] && [ -n "$CACHED_TOKEN" ]; then
        echo -e "${GREEN}📋 Cached subdomain: ${CYAN}$CACHED_SUBDOMAIN${NC}"
        if ui_confirm "Use cached DuckDNS credentials?"; then
            DUCKDNS_SUBDOMAIN="$CACHED_SUBDOMAIN"
            DUCKDNS_TOKEN="$CACHED_TOKEN"
        else
            CACHED_SUBDOMAIN=""
            CACHED_TOKEN=""
        fi
    fi
    if [ -z "$CACHED_SUBDOMAIN" ] || [ -z "$CACHED_TOKEN" ]; then
        DUCKDNS_SUBDOMAIN=$(ui_input "DuckDNS Subdomain (without .duckdns.org):" "my-subdomain")
        if [ -z "$DUCKDNS_SUBDOMAIN" ]; then echo -e "${RED}❌ Subdomain required${NC}"; return; fi
        DUCKDNS_TOKEN=$(ui_input "DuckDNS Token:" "your-token-here" "--password")
        if [ -z "$DUCKDNS_TOKEN" ]; then echo -e "${RED}❌ Token required${NC}"; return; fi
        save_secret "DUCKDNS_SUBDOMAIN" "$DUCKDNS_SUBDOMAIN"
        save_secret "DUCKDNS_TOKEN" "$DUCKDNS_TOKEN"
    fi
    echo ""
    echo -e "${BLUE}🌐 Updating DuckDNS...${NC}"
    DUCKDNS_RESPONSE=$(curl -s "https://www.duckdns.org/update?domains=$DUCKDNS_SUBDOMAIN&token=$DUCKDNS_TOKEN&ip=$PUBLIC_IP")
    if [ "$DUCKDNS_RESPONSE" = "OK" ]; then
        log INFO "DuckDNS updated: $DUCKDNS_SUBDOMAIN → $PUBLIC_IP"
        echo -e "${GREEN}✅ DuckDNS updated successfully${NC}"
    else
        log ERROR "DuckDNS update failed for $DUCKDNS_SUBDOMAIN: $DUCKDNS_RESPONSE"
        echo -e "${RED}❌ DuckDNS update failed: $DUCKDNS_RESPONSE${NC}"
        return
    fi
    echo ""
    ENV_NAME=$(select_environment "Select environment to publish")
    [ -z "$ENV_NAME" ] && return
    PORT=$(get_port_from_pm2 "$ENV_NAME")
    if [ -z "$PORT" ]; then echo -e "${RED}❌ Could not get port for $ENV_NAME${NC}"; return; fi
    DOMAIN="${DUCKDNS_SUBDOMAIN}.duckdns.org"
    CADDYFILE="/etc/caddy/Caddyfile"
    [ -f "$CADDYFILE" ] && sudo cp "$CADDYFILE" "${CADDYFILE}.backup.$(date +%s)" 2>/dev/null
    echo -e "${BLUE}🔧 Generating Caddyfile with all online environments...${NC}"
    ROUTES=""
    ALL_ENVS=$(list_all_environments)
    SELECTED_INCLUDED=false
    if [ -n "$ALL_ENVS" ]; then
        while IFS= read -r env; do
            [ -z "$env" ] && continue
            local env_status=$(get_pm2_status "$env")
            local env_port=$(get_port_from_pm2 "$env")
            if [ "$env_status" = "online" ] && [ -n "$env_port" ]; then
                ROUTES="${ROUTES}    reverse_proxy /${env}* localhost:${env_port}"$'\n'
                echo -e "  ${GREEN}✓${NC} /${env} → localhost:${env_port}"
                [ "$env" = "$ENV_NAME" ] && SELECTED_INCLUDED=true
            fi
        done <<< "$ALL_ENVS"
    fi
    if [ "$SELECTED_INCLUDED" = "false" ]; then
        ROUTES="${ROUTES}    reverse_proxy /${ENV_NAME}* localhost:${PORT}"$'\n'
        echo -e "  ${GREEN}✓${NC} /${ENV_NAME} → localhost:${PORT} (selected)"
    fi
    sudo tee "$CADDYFILE" > /dev/null << EOF
${DOMAIN} {
${ROUTES}    encode gzip
}
EOF
    log INFO "Caddyfile generated for $DOMAIN with routes for all online environments"
    echo -e "${GREEN}✅ Caddyfile generated with all routes${NC}"
    echo -e "${BLUE}🔄 Reloading Caddy...${NC}"
    if sudo systemctl reload caddy; then
        log INFO "Caddy reloaded successfully for $DOMAIN"
        echo -e "${GREEN}✅ Caddy reloaded${NC}"
        echo ""
        echo -e "${GREEN}🎉 SUCCESS! Published URLs:${NC}"
        if [ -n "$ALL_ENVS" ]; then
            while IFS= read -r env; do
                [ -z "$env" ] && continue
                local env_s=$(get_pm2_status "$env")
                local env_p=$(get_port_from_pm2 "$env")
                [ "$env_s" = "online" ] && [ -n "$env_p" ] && echo -e "${CYAN}   https://$DOMAIN/$env${NC}"
            done <<< "$ALL_ENVS"
        fi
        if ! echo "$ALL_ENVS" | grep -q "^${ENV_NAME}$" || [ "$(get_pm2_status "$ENV_NAME")" != "online" ]; then
            echo -e "${CYAN}   https://$DOMAIN/$ENV_NAME${NC} (selected)"
        fi
        echo ""
    else
        log ERROR "Failed to reload Caddy for $DOMAIN"
        echo -e "${RED}❌ Failed to reload Caddy${NC}"
        echo -e "${YELLOW}Check logs with: sudo journalctl -u caddy -n 50${NC}"
    fi
}

action_adv_help() { show_help; }
action_cleanup() { disk_cleanup_menu; refresh_menu_status_cache_sync >/dev/null 2>&1 || true; }
action_updates() { updates_menu; refresh_menu_status_cache_sync >/dev/null 2>&1 || true; }
action_tools() { show_tools_status; }
action_install_sdk() { install_sdk_menu; }

# ============================================================================
# MENU ITEM DEFINITIONS (shared between gum and bash menus)
# ============================================================================

MAIN_MENU_ITEMS=(
    "---|📊 OVERVIEW|"
    "d|Dashboard - View all environments|action_dashboard"
    "s|ShipFlow - Tasks · Priorities · Changelog|action_shipflow_overview"
    "---|🚀 MANAGE|"
    "e|Deploy - Launch or deploy environment|action_deploy"
    "r|Restart - Restart an environment|action_restart"
    "t|Stop - Stop an environment|action_stop"
    "w|Remove - Delete an environment|action_remove"
    "---|⚡ BATCH|"
    "a|Start All - Start all environments|action_start_all"
    "o|Stop All - Stop all environments|action_stop_all"
    "b|Restart All - Restart all environments|action_restart_all"
    "---|⚙️  ADVANCED|"
    "g|More Options - Publish, Logs, Help...|action_advanced"
    "m|Mobile Guide - Setup Android + Expo|action_mobile"
    "h|Health Check - RAM, processes, crash loops|action_health"
    "x|Exit|action_exit"
)

ADVANCED_MENU_ITEMS=(
    "l|📝 View Logs - Display application logs|action_view_logs"
    "n|📁 Navigate Projects - Browse /root directory|action_navigate"
    "o|📂 Open Code Directory - cd into project|action_open_code"
    "i|🔍 Toggle Web Inspector - Enable/disable browser inspector|action_inspector"
    "e|🔐 Session Identity - View or reset session|action_session"
    "p|🌐 Publish to Web - Configure HTTPS (Caddy + DuckDNS)|action_publish"
    "?|📖 Help - How ShipFlow works|action_adv_help"
    "c|🧹 CleanUp Space - Free space (light/aggressive)|action_cleanup"
    "u|⬆️  Updates - Check & update packages|action_updates"
    "t|🔧 Tools Status - Voir les outils installés|action_tools"
    "f|📦 Install SDK - Flutter, Dart...|action_install_sdk"
    "x|← Back to Main Menu|__EXIT__"
)

# action_advanced needs to be defined after ADVANCED_MENU_ITEMS
# Each menu file (menu_gum.sh / menu_bash.sh) provides its own implementation
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
| 🟡 | Add first project with /sf-init | 📋 todo |
TASKS_EOF
        cat > "$SHIPFLOW_DATA/AUDIT_LOG.md" << 'AUDIT_EOF'
# Audit Log

> Populated by `/sf-audit` skills. Each entry follows the format:
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
    local CHANGELOG_FILE="$(dirname "${BASH_SOURCE[0]}")/CHANGELOG.md"

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

        echo -e "${GREEN}Choose:${NC}"
        echo ""
        echo -e "  ${CYAN}1)${NC} 📋 Tasks       — Browse all projects & tasks"
        echo -e "  ${CYAN}2)${NC} 🔴 Priorities  — Show P0 & P1 tasks only"
        echo -e "  ${CYAN}3)${NC} 📝 Changelog   — View recent changes"
        echo -e "  ${CYAN}4)${NC} 📊 Audit Log   — Review quality scores"
        echo ""
        echo -e "  ${CYAN}x)${NC} ← Back"
        echo ""
        echo -e "${YELLOW}Your choice:${NC} \c"
        read -r sf_choice

        case $sf_choice in
            1)
                if [ -f "$TASKS_FILE" ]; then
                    less -R "$TASKS_FILE"
                else
                    echo -e "${RED}❌ TASKS.md not found at:${NC} $TASKS_FILE"
                    sleep 2
                fi
                ;;
            2)
                if [ -f "$TASKS_FILE" ]; then
                    clear
                    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
                    echo -e "       ${RED}🔴 P0 Blockers${NC}  &  ${YELLOW}🟠 P1 High Priority${NC}"
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
                    ui_pause "Press Enter to continue..."
                else
                    echo -e "${RED}❌ TASKS.md not found${NC}"
                    sleep 2
                fi
                ;;
            3)
                if [ -f "$CHANGELOG_FILE" ]; then
                    less -R "$CHANGELOG_FILE"
                else
                    echo -e "${RED}❌ CHANGELOG.md not found at:${NC} $CHANGELOG_FILE"
                    sleep 2
                fi
                ;;
            4)
                if [ -f "$AUDIT_FILE" ]; then
                    less -R "$AUDIT_FILE"
                else
                    echo -e "${RED}❌ AUDIT_LOG.md not found at:${NC} $AUDIT_FILE"
                    sleep 2
                fi
                ;;
            x|X|q|Q)
                return 0
                ;;
            *)
                echo -e "${RED}❌ Invalid option${NC}"
                sleep 1
                ;;
        esac
    done
}

# Help documentation (paginated)
show_help() {
    local page=1
    local total_pages=4

    while true; do
        clear
        echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
        echo -e "              ${YELLOW}ShipFlow Help${NC} (Page $page/$total_pages)"
        echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
        echo ""

        case $page in
            1)
                echo -e "${GREEN}🚀 QUICKSTART GUIDE${NC}"
                echo ""
                echo -e "${YELLOW}First time? Follow these steps:${NC}"
                echo ""
                echo -e "  ${CYAN}Step 1:${NC} ${GREEN}Have a project ready${NC}"
                echo -e "         Place your project in ${YELLOW}/root/${NC} directory"
                echo -e "         (or clone from GitHub using Deploy → option 3)"
                echo ""
                echo -e "  ${CYAN}Step 2:${NC} ${GREEN}Start your project${NC}"
                echo -e "         From main menu, press ${YELLOW}e${NC} (Deploy)"
                echo -e "         Then press ${YELLOW}1${NC} (Auto-detect)"
                echo -e "         Select your project from the list"
                echo ""
                echo -e "  ${CYAN}Step 3:${NC} ${GREEN}Access your app${NC}"
                echo -e "         Your app runs on ${YELLOW}http://localhost:<port>${NC}"
                echo -e "         Check the Dashboard (${YELLOW}d${NC}) to see the port"
                echo ""
                echo -e "  ${CYAN}Step 4:${NC} ${GREEN}Publish to web (optional)${NC}"
                echo -e "         Press ${YELLOW}g${NC} (More Options) then ${YELLOW}p${NC} (Publish)"
                echo ""
                echo -e "${BLUE}┌───────────────────────────────────────────────────────────────┐${NC}"
                echo -e "${BLUE}│${NC} ${YELLOW}Quick Reference:${NC}                                              ${BLUE}│${NC}"
                echo -e "${BLUE}│${NC}   ${CYAN}d${NC} Dashboard  ${CYAN}e${NC} Deploy  ${CYAN}r${NC} Restart  ${CYAN}t${NC} Stop  ${CYAN}w${NC} Remove     ${BLUE}│${NC}"
                echo -e "${BLUE}│${NC}   ${CYAN}a${NC} StartAll  ${CYAN}o${NC} StopAll  ${CYAN}b${NC} RestartAll              ${BLUE}│${NC}"
                echo -e "${BLUE}│${NC}   ${CYAN}g${NC} Advanced  ${CYAN}m${NC} Mobile  ${CYAN}h${NC} Health  ${CYAN}x${NC} Exit          ${BLUE}│${NC}"
                echo -e "${BLUE}└───────────────────────────────────────────────────────────────┘${NC}"
                ;;
            2)
                echo -e "${GREEN}📐 HOW SHIPFLOW WORKS${NC}"
                echo ""
                echo -e "${BLUE}┌─────────────────────────────────────────────────────────┐${NC}"
                echo -e "${BLUE}│${NC}  You select a project from the menu                      ${BLUE}│${NC}"
                echo -e "${BLUE}└─────────────────────────────────────────────────────────┘${NC}"
                echo -e "                              ${YELLOW}│${NC}"
                echo -e "                              ${YELLOW}▼${NC}"
                echo -e "${BLUE}┌─────────────────────────────────────────────────────────┐${NC}"
                echo -e "${BLUE}│${NC}  ShipFlow checks: does project have ${CYAN}.flox${NC} directory?    ${BLUE}│${NC}"
                echo -e "${BLUE}│${NC}  ${GREEN}✓ Yes${NC} → use existing    ${YELLOW}✗ No${NC} → create & configure     ${BLUE}│${NC}"
                echo -e "${BLUE}└─────────────────────────────────────────────────────────┘${NC}"
                echo -e "                              ${YELLOW}│${NC}"
                echo -e "                              ${YELLOW}▼${NC}"
                echo -e "${BLUE}┌─────────────────────────────────────────────────────────┐${NC}"
                echo -e "${BLUE}│${NC}  Auto-detect project type & dev command:                 ${BLUE}│${NC}"
                echo -e "${BLUE}│${NC}  • package.json → ${CYAN}npm/yarn/pnpm dev${NC}                     ${BLUE}│${NC}"
                echo -e "${BLUE}│${NC}  • requirements.txt → ${CYAN}./venv/bin/python main.py${NC}        ${BLUE}│${NC}"
                echo -e "${BLUE}│${NC}  • Cargo.toml → ${CYAN}cargo run${NC}                              ${BLUE}│${NC}"
                echo -e "${BLUE}└─────────────────────────────────────────────────────────┘${NC}"
                echo -e "                              ${YELLOW}│${NC}"
                echo -e "                              ${YELLOW}▼${NC}"
                echo -e "${BLUE}┌─────────────────────────────────────────────────────────┐${NC}"
                echo -e "${BLUE}│${NC}  Create ${CYAN}ecosystem.config.cjs${NC} for PM2:                   ${BLUE}│${NC}"
                echo -e "${BLUE}│${NC}  ${YELLOW}script:${NC} bash -c \"flox activate -- <dev command>\"       ${BLUE}│${NC}"
                echo -e "${BLUE}└─────────────────────────────────────────────────────────┘${NC}"
                echo -e "                              ${YELLOW}│${NC}"
                echo -e "                              ${YELLOW}▼${NC}"
                echo -e "${BLUE}┌─────────────────────────────────────────────────────────┐${NC}"
                echo -e "${BLUE}│${NC}  PM2 manages the process:                                ${BLUE}│${NC}"
                echo -e "${BLUE}│${NC}  ${GREEN}• Auto-restart on crash${NC}                                ${BLUE}│${NC}"
                echo -e "${BLUE}│${NC}  ${GREEN}• Logs captured${NC}                                        ${BLUE}│${NC}"
                echo -e "${BLUE}│${NC}  ${GREEN}• Port management${NC}                                      ${BLUE}│${NC}"
                echo -e "${BLUE}└─────────────────────────────────────────────────────────┘${NC}"
                ;;
            3)
                echo -e "${GREEN}🛠️  SUPPORTED TECHNOLOGIES${NC}"
                echo ""
                echo -e "${BLUE}┌──────────────────┬────────────────────────────────────┐${NC}"
                echo -e "${BLUE}│${NC} ${YELLOW}Language/Stack${NC}   ${BLUE}│${NC} ${YELLOW}Detection & Commands${NC}               ${BLUE}│${NC}"
                echo -e "${BLUE}├──────────────────┼────────────────────────────────────┤${NC}"
                echo -e "${BLUE}│${NC} ${CYAN}Node.js${NC}          ${BLUE}│${NC} package.json                       ${BLUE}│${NC}"
                echo -e "${BLUE}│${NC}                  ${BLUE}│${NC} → npm/yarn/pnpm install & dev      ${BLUE}│${NC}"
                echo -e "${BLUE}├──────────────────┼────────────────────────────────────┤${NC}"
                echo -e "${BLUE}│${NC} ${CYAN}Python${NC}           ${BLUE}│${NC} requirements.txt / pyproject.toml  ${BLUE}│${NC}"
                echo -e "${BLUE}│${NC}                  ${BLUE}│${NC} → venv + pip install + python      ${BLUE}│${NC}"
                echo -e "${BLUE}├──────────────────┼────────────────────────────────────┤${NC}"
                echo -e "${BLUE}│${NC} ${CYAN}Rust${NC}             ${BLUE}│${NC} Cargo.toml                         ${BLUE}│${NC}"
                echo -e "${BLUE}│${NC}                  ${BLUE}│${NC} → cargo run                        ${BLUE}│${NC}"
                echo -e "${BLUE}├──────────────────┼────────────────────────────────────┤${NC}"
                echo -e "${BLUE}│${NC} ${CYAN}Go${NC}               ${BLUE}│${NC} go.mod                             ${BLUE}│${NC}"
                echo -e "${BLUE}│${NC}                  ${BLUE}│${NC} → go run .                         ${BLUE}│${NC}"
                echo -e "${BLUE}├──────────────────┼────────────────────────────────────┤${NC}"
                echo -e "${BLUE}│${NC} ${CYAN}Flutter/Dart${NC}     ${BLUE}│${NC} pubspec.yaml                       ${BLUE}│${NC}"
                echo -e "${BLUE}│${NC}                  ${BLUE}│${NC} → flutter web / dart run          ${BLUE}│${NC}"
                echo -e "${BLUE}└──────────────────┴────────────────────────────────────┘${NC}"
                echo ""
                echo -e "${GREEN}📦 FRAMEWORKS AUTO-DETECTED${NC}"
                echo ""
                echo -e "  ${CYAN}•${NC} Next.js     → ${YELLOW}npm dev -p \$PORT${NC}"
                echo -e "  ${CYAN}•${NC} Astro       → ${YELLOW}npm dev -- --port \$PORT --host${NC}"
                echo -e "  ${CYAN}•${NC} Vite        → ${YELLOW}npm dev -- --port \$PORT --host${NC}"
                echo -e "  ${CYAN}•${NC} Nuxt        → ${YELLOW}npm dev --port \$PORT${NC}"
                echo -e "  ${CYAN}•${NC} Expo        → ${YELLOW}npx expo start --dev-client --tunnel${NC}"
                echo -e "  ${CYAN}•${NC} Flutter Web → ${YELLOW}flutter run -d web-server --web-port \$PORT${NC}"
                echo -e "  ${CYAN}•${NC} Dart        → ${YELLOW}dart pub get && dart run${NC}"
                echo -e "  ${CYAN}•${NC} Django      → ${YELLOW}python manage.py runserver 0.0.0.0:\$PORT${NC}"
                echo -e "  ${CYAN}•${NC} Flask/FastAPI → ${YELLOW}python app.py${NC} or ${YELLOW}python main.py${NC}"
                echo ""
                echo -e "${GREEN}🔧 ENVIRONMENT ISOLATION${NC}"
                echo ""
                echo -e "  ${CYAN}Flox${NC} provides reproducible, isolated environments"
                echo -e "  Each project gets its own dependencies via Nix"
                ;;
            4)
                echo -e "${GREEN}🔍 WEB INSPECTOR (Visual Selection)${NC}"
                echo ""
                echo -e "  Inject a visual element selector into your web app:"
                echo ""
                echo -e "  ${CYAN}•${NC} Inject/remove manually via ${YELLOW}Advanced → Toggle Web Inspector${NC}"
                echo -e "  ${CYAN}•${NC} Shows numbered buttons on every ${YELLOW}<div>${NC} element"
                echo -e "  ${CYAN}•${NC} ${GREEN}Click${NC} → Copy XPath to clipboard"
                echo -e "  ${CYAN}•${NC} ${GREEN}Long-press${NC} → Screenshot menu:"
                echo -e "      - Copy to clipboard"
                echo -e "      - Download PNG"
                echo -e "      - Upload & copy URL (imgbb)"
                echo ""
                echo -e "${GREEN}🖥️  ERUDA CONSOLE${NC}"
                echo ""
                echo -e "  Mobile-friendly developer console injected with the inspector script:"
                echo ""
                echo -e "  ${CYAN}•${NC} View console.log output"
                echo -e "  ${CYAN}•${NC} Inspect network requests"
                echo -e "  ${CYAN}•${NC} View DOM elements"
                echo -e "  ${CYAN}•${NC} Debug JavaScript errors"
                echo -e "  ${CYAN}•${NC} Check storage (localStorage, cookies)"
                echo ""
                echo -e "${YELLOW}💡 Both tools are injected via:${NC}"
                echo -e "   ${CYAN}injectors/web-inspector.js${NC}"
                ;;
        esac

        echo ""
        echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
        echo -e "  ${CYAN}p${NC} Previous   ${CYAN}Enter/n${NC} Next   ${CYAN}1-4${NC} Jump   ${CYAN}0${NC} Back"
        echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
        echo ""
        echo -e "${YELLOW}[$page/$total_pages]:${NC} \c"
        read -r help_choice

        case $help_choice in
            ""|n|N)
                if [ $page -lt $total_pages ]; then
                    page=$((page + 1))
                fi
                ;;
            p|P|b|B)
                if [ $page -gt 1 ]; then
                    page=$((page - 1))
                fi
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
show_mobile_guide() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo -e "          ${YELLOW}📱 Guide Mobile — Expo + Android${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "Ce guide configure ton téléphone Android pour le dev en live."
    echo -e "Suis les étapes dans l'ordre. Ce qui est déjà fait sera ignoré."
    echo ""
    ui_pause "Appuie sur Entrée pour commencer..."

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
            ui_pause "Appuie sur Entrée pour quitter le guide..."
            return 1
        fi
    fi
    echo ""
    ui_pause "Appuie sur Entrée pour l'étape suivante..."

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
            ui_pause "Appuie sur Entrée pour quitter..."
            return 1
        fi
    fi
    echo ""
    ui_pause "Appuie sur Entrée pour l'étape suivante..."

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

    # Lister les projets Expo disponibles
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
        echo -e "  ${BLUE}   Déploie d'abord ton projet depuis le menu principal (e = Deploy).${NC}"
        echo ""
        ui_pause "Appuie sur Entrée pour quitter..."
        return 0
    fi

    local selected_project
    selected_project=$(echo "$expo_projects" | ui_choose "Sélectionne ton projet Expo:")

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
    ui_pause "Appuie sur Entrée pour l'étape suivante..."

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

    # Attendre quelques secondes que le tunnel s'initialise
    echo -e "  ${BLUE}⏳ Attente de l'URL du tunnel (15 sec)...${NC}"
    sleep 15

    # Extraire l'URL du tunnel depuis les logs PM2
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
        echo -e "  ${YELLOW}URL du tunnel:${NC}"
        echo -e "  ${CYAN}$tunnel_url${NC}"
        echo ""
        echo -e "  ${BLUE}1. Ouvre l'APK dev build sur ton téléphone${NC}"
        echo -e "  ${BLUE}2. Entre cette URL ou scanne le QR${NC}"
        echo -e "  ${BLUE}3. Modifie ton code → l'app se recharge automatiquement 🎉${NC}"
    else
        echo -e "  ${YELLOW}URL pas encore visible — vérifie les logs:${NC}"
        echo -e "  ${CYAN}pm2 logs $selected_project --lines 30${NC}"
        echo ""
        echo -e "  ${BLUE}1. Ouvre l'APK dev build sur ton téléphone${NC}"
        echo -e "  ${BLUE}2. Entre l'URL exp:// depuis les logs${NC}"
        echo -e "  ${BLUE}3. Modifie ton code → l'app se recharge automatiquement 🎉${NC}"
    fi
    echo ""
    ui_pause "Appuie sur Entrée pour revenir au menu..."
}
