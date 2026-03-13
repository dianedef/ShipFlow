#!/bin/bash

# ShipFlow - Development Environment Manager
# Manages Flox environments, PM2 processes, and Caddy reverse proxy

# Load shared library (includes ui_* wrappers, select_environment, etc.)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# Header display
print_header() {
    # Show cached status immediately, then refresh in background if stale.
    read_menu_status_cache >/dev/null 2>&1 || true
    refresh_menu_status_cache_async_if_stale

    local status_left="Free: ..."
    local status_right="Up: ..."
    if [ -n "$MENU_STATUS_FREE_HUMAN" ]; then
        status_left="Free: $MENU_STATUS_FREE_HUMAN"
    fi
    if [ -n "$MENU_STATUS_UPDATES_TOTAL" ]; then
        status_right="Up: $MENU_STATUS_UPDATES_TOTAL"
    fi

    ui_header "Shipflow DevServer" "Development Environment" "$status_left" "$status_right"

    if [ "${MENU_STATUS_LOW_SPACE:-0}" = "1" ]; then
        echo -e "${RED}⚠️  Low disk space. Consider running Disk Cleanup.${NC}"
    fi

    # Display session identity banner if enabled
    if [ "$SHIPFLOW_SESSION_ENABLED" = "true" ]; then
        init_session 2>/dev/null
        display_session_banner
        echo ""
    fi
}

# Main menu display
show_menu() {
    echo -e "${BLUE}📊 OVERVIEW${NC}"
    echo -e "  ${CYAN}1)${NC} Dashboard - View all environments at once"
    echo -e "  ${CYAN}s)${NC} ShipFlow - Tasks · Priorities · Changelog · Audit"
    echo ""
    echo -e "${BLUE}🚀 MANAGE${NC}"
    echo -e "  ${CYAN}2)${NC} Deploy - Launch or deploy environment"
    echo -e "  ${CYAN}3)${NC} Restart - Restart an environment"
    echo -e "  ${CYAN}4)${NC} Stop - Stop an environment"
    echo -e "  ${CYAN}5)${NC} Remove - Delete an environment"
    echo ""
    echo -e "${BLUE}⚡ BATCH${NC}"
    echo -e "  ${CYAN}6)${NC} Start All - Start all environments"
    echo -e "  ${CYAN}7)${NC} Stop All - Stop all environments"
    echo -e "  ${CYAN}8)${NC} Restart All - Restart all environments"
    echo ""
    echo -e "${BLUE}⚙️  ADVANCED${NC}"
    echo -e "  ${CYAN}9)${NC} More Options - Publish, Logs, Help..."
    echo -e "  ${CYAN}m)${NC} Mobile Guide - Setup Android + Expo pas à pas"
    echo -e "  ${CYAN}h)${NC} Health Check - Detect crash loops & auto-fix"
    echo ""
    echo -e "  ${CYAN}x)${NC} Exit"
    echo ""
}

# ShipFlow overview — Tasks, Priorities, Changelog, Audit Log
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
                    echo -e "${YELLOW}Press Enter to continue...${NC}"
                    read -r
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
                echo -e "         (or clone from GitHub using option 2 → 3)"
                echo ""
                echo -e "  ${CYAN}Step 2:${NC} ${GREEN}Start your project${NC}"
                echo -e "         From main menu, press ${YELLOW}2${NC} (Deploy)"
                echo -e "         Then press ${YELLOW}1${NC} (Auto-detect)"
                echo -e "         Select your project from the list"
                echo ""
                echo -e "  ${CYAN}Step 3:${NC} ${GREEN}Access your app${NC}"
                echo -e "         Your app runs on ${YELLOW}http://localhost:<port>${NC}"
                echo -e "         Check the Dashboard (${YELLOW}1${NC}) to see the port"
                echo ""
                echo -e "  ${CYAN}Step 4:${NC} ${GREEN}Publish to web (optional)${NC}"
                echo -e "         Press ${YELLOW}9${NC} (Advanced) to configure HTTPS with DuckDNS"
                echo ""
                echo -e "${BLUE}┌───────────────────────────────────────────────────────────────┐${NC}"
                echo -e "${BLUE}│${NC} ${YELLOW}Quick Reference:${NC}                                              ${BLUE}│${NC}"
                echo -e "${BLUE}│${NC}   ${CYAN}1${NC} Dashboard  ${CYAN}2${NC} Deploy  ${CYAN}3${NC} Restart  ${CYAN}4${NC} Stop  ${CYAN}5${NC} Remove     ${BLUE}│${NC}"
                echo -e "${BLUE}│${NC}   ${CYAN}6${NC} StopAll  ${CYAN}7${NC} StartAll  ${CYAN}8${NC} RestartAll              ${BLUE}│${NC}"
                echo -e "${BLUE}│${NC}   ${CYAN}9${NC} Advanced  ${CYAN}m${NC} Mobile  ${CYAN}0${NC} Exit                    ${BLUE}│${NC}"
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
                echo -e "${BLUE}└──────────────────┴────────────────────────────────────┘${NC}"
                echo ""
                echo -e "${GREEN}📦 FRAMEWORKS AUTO-DETECTED${NC}"
                echo ""
                echo -e "  ${CYAN}•${NC} Next.js     → ${YELLOW}npm dev -p \$PORT${NC}"
                echo -e "  ${CYAN}•${NC} Astro       → ${YELLOW}npm dev -- --port \$PORT --host${NC}"
                echo -e "  ${CYAN}•${NC} Vite        → ${YELLOW}npm dev -- --port \$PORT --host${NC}"
                echo -e "  ${CYAN}•${NC} Nuxt        → ${YELLOW}npm dev --port \$PORT${NC}"
                echo -e "  ${CYAN}•${NC} Expo        → ${YELLOW}npx expo start --dev-client --tunnel${NC}"
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
                echo -e "  ${CYAN}•${NC} Toggle via ${YELLOW}Advanced → Toggle Web Inspector${NC}"
                echo -e "  ${CYAN}•${NC} Shows numbered buttons on every ${YELLOW}<div>${NC} element"
                echo -e "  ${CYAN}•${NC} ${GREEN}Click${NC} → Copy XPath to clipboard"
                echo -e "  ${CYAN}•${NC} ${GREEN}Long-press${NC} → Screenshot menu:"
                echo -e "      - Copy to clipboard"
                echo -e "      - Download PNG"
                echo -e "      - Upload & copy URL (imgbb)"
                echo ""
                echo -e "${GREEN}🖥️  ERUDA CONSOLE${NC}"
                echo ""
                echo -e "  Mobile-friendly developer console injected automatically:"
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

# Submenu "More Options"
show_advanced_menu() {
    while true; do
        clear
        echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
        echo -e "                 ${YELLOW}Advanced Options${NC}"
        echo -e "${CYAN}══════════════════════════════════════════════════${NC}"

        echo -e "${GREEN}Choose an option:${NC}"
        echo ""
        echo -e "  ${CYAN}1)${NC} 📝 View Logs - Display application logs"
        echo -e "  ${CYAN}2)${NC} 📁 Navigate Projects - Browse /root directory"
        echo -e "  ${CYAN}3)${NC} 📂 Open Code Directory - cd into project"
        echo -e "  ${CYAN}4)${NC} 🛠️  Outils Dev - Inspecteur & Console Eruda (par projet)"
        echo -e "  ${CYAN}5)${NC} 🔐 Session Identity - View or reset session"
        echo -e "  ${CYAN}6)${NC} 🌐 Publish to Web - Configure HTTPS (Caddy + DuckDNS)"
        echo -e "  ${CYAN}7)${NC} 📖 Help - How ShipFlow works"
        echo -e "  ${CYAN}8)${NC} 🧹 CleanUp Space - Free space (light/aggressive)"
        echo -e "  ${CYAN}9)${NC} ⬆️  Updates - Check & update packages"
        echo ""
        echo -e "  ${CYAN}x)${NC} ← Back to Main Menu"
        echo ""

        echo -e "${YELLOW}Your choice:${NC} \c"
        read -r adv_choice

        case $adv_choice in
            1)
                # View Logs
                echo -e "${GREEN}📝 View Application Logs${NC}"
                ENV_NAME=$(select_environment "Select environment to view logs")

                if [ -n "$ENV_NAME" ]; then
                    view_environment_logs "$ENV_NAME"
                fi
                ;;
            2)
                # Navigate Projects
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
                ;;
            3)
                # Open Code Directory
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
                ;;
            4)
                # Dev Tools submenu (per-project inspector & eruda)
                echo -e "${GREEN}🛠️  Outils Dev${NC}"
                ENV_NAME=$(select_environment "Choisis un projet")

                if [ -n "$ENV_NAME" ]; then
                    PROJECT_DIR=$(resolve_project_path "$ENV_NAME")

                    if [ -z "$PROJECT_DIR" ]; then
                        echo -e "${RED}❌ Projet introuvable : $ENV_NAME${NC}"
                    else
                        # Read current preferences
                        local insp_state eruda_state
                        insp_state=$(get_tools_pref "$PROJECT_DIR" "inspector")
                        eruda_state=$(get_tools_pref "$PROJECT_DIR" "eruda")

                        local insp_icon eruda_icon
                        [ "$insp_state" = "enabled" ] && insp_icon="✅" || insp_icon="❌"
                        [ "$eruda_state" = "enabled" ] && eruda_icon="✅" || eruda_icon="❌"

                        local insp_action eruda_action
                        [ "$insp_state" = "enabled" ] && insp_action="Désactiver" || insp_action="Activer"
                        [ "$eruda_state" = "enabled" ] && eruda_action="Désactiver" || eruda_action="Activer"

                        echo ""
                        echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
                        echo -e "          ${YELLOW}Outils Dev — $ENV_NAME${NC}"
                        echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
                        echo ""
                        echo -e "  État actuel :"
                        echo -e "    Inspecteur visuel : $insp_icon $(echo "$insp_state" | sed 's/enabled/Activé/;s/disabled/Désactivé/')"
                        echo -e "    Console Eruda     : $eruda_icon $(echo "$eruda_state" | sed 's/enabled/Activé/;s/disabled/Désactivé/')"
                        echo ""
                        echo -e "  ${CYAN}1)${NC} 🔍 Inspecteur visuel — $insp_action"
                        echo -e "  ${CYAN}2)${NC} 🖥️  Console Eruda — $eruda_action"
                        echo -e "  ${CYAN}3)${NC} 🔄 Tout activer"
                        echo -e "  ${CYAN}4)${NC} ❌ Tout désactiver"
                        echo ""
                        echo -e "  ${CYAN}x)${NC} ← Retour"
                        echo ""
                        echo -e "${YELLOW}Ton choix :${NC} \c"
                        read -r tools_choice

                        local needs_restart=false

                        case $tools_choice in
                            1)
                                local new_state
                                [ "$insp_state" = "enabled" ] && new_state="disabled" || new_state="enabled"
                                set_tool_state "$PROJECT_DIR" "inspector" "$new_state"
                                echo -e "${GREEN}Inspecteur visuel : $new_state${NC}"
                                needs_restart=true
                                ;;
                            2)
                                local new_state
                                [ "$eruda_state" = "enabled" ] && new_state="disabled" || new_state="enabled"
                                set_tool_state "$PROJECT_DIR" "eruda" "$new_state"
                                echo -e "${GREEN}Console Eruda : $new_state${NC}"
                                needs_restart=true
                                ;;
                            3)
                                set_tool_state "$PROJECT_DIR" "inspector" "enabled"
                                set_tool_state "$PROJECT_DIR" "eruda" "enabled"
                                echo -e "${GREEN}Tous les outils activés${NC}"
                                needs_restart=true
                                ;;
                            4)
                                set_tool_state "$PROJECT_DIR" "inspector" "disabled"
                                set_tool_state "$PROJECT_DIR" "eruda" "disabled"
                                echo -e "${GREEN}Tous les outils désactivés${NC}"
                                needs_restart=true
                                ;;
                            x|X) ;;
                            *) echo -e "${RED}Choix invalide${NC}" ;;
                        esac

                        if [ "$needs_restart" = true ]; then
                            echo ""
                            if ui_confirm "Redémarrer $ENV_NAME pour appliquer ?"; then
                                env_restart "$ENV_NAME"
                                echo -e "${GREEN}✅ $ENV_NAME redémarré${NC}"
                            else
                                echo -e "${YELLOW}💡 Les changements seront appliqués au prochain redémarrage${NC}"
                            fi
                        fi
                    fi
                fi
                ;;
            5)
                # Session Identity Management
                echo -e "${GREEN}🔐 Session Identity Management${NC}"
                echo ""

                display_session_banner
                echo ""
                get_session_info
                echo ""

                echo -e "${BLUE}Options:${NC}"
                echo -e "  ${CYAN}1)${NC} 🔄 Reset Session Identity (generate new pattern)"
                echo -e "  ${CYAN}x)${NC} ← Back"
                echo ""
                echo -e "${YELLOW}Your choice:${NC} \c"
                read -r session_choice

                case $session_choice in
                    1)
                        reset_session
                        echo ""
                        echo -e "${GREEN}New session identity:${NC}"
                        display_session_banner
                        ;;
                    *)
                        ;;
                esac
                ;;
            6)
                # Publish to Web with credential cache
                echo -e "${GREEN}🌐 Publish to Web (HTTPS via Caddy + DuckDNS)${NC}"
                echo ""

                # Check if Caddy is installed
                if ! command -v caddy >/dev/null 2>&1; then
                    echo -e "${RED}❌ Caddy not installed${NC}"
                    echo -e "${YELLOW}Install with: sudo apt install caddy${NC}"
                    continue
                fi

                # Get public IP
                echo -e "${BLUE}📡 Detecting public IP...${NC}"
                PUBLIC_IP=$(curl -4 -s https://ip.me 2>/dev/null)
                if [ -n "$PUBLIC_IP" ]; then
                    echo -e "${BLUE}📡 Detected Public IP: ${GREEN}$PUBLIC_IP${NC}"
                else
                    echo -e "${YELLOW}⚠️  Could not detect public IP${NC}"
                    PUBLIC_IP=$(ui_input "Enter public IP:")
                fi

                echo ""

                # Try loading cached credentials
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

                # Prompt if no cached credentials
                if [ -z "$CACHED_SUBDOMAIN" ] || [ -z "$CACHED_TOKEN" ]; then
                    DUCKDNS_SUBDOMAIN=$(ui_input "DuckDNS Subdomain (without .duckdns.org):" "my-subdomain")

                    if [ -z "$DUCKDNS_SUBDOMAIN" ]; then
                        echo -e "${RED}❌ Subdomain required${NC}"
                        continue
                    fi

                    DUCKDNS_TOKEN=$(ui_input "DuckDNS Token:" "your-token-here" "--password")

                    if [ -z "$DUCKDNS_TOKEN" ]; then
                        echo -e "${RED}❌ Token required${NC}"
                        continue
                    fi

                    # Save credentials for next time
                    save_secret "DUCKDNS_SUBDOMAIN" "$DUCKDNS_SUBDOMAIN"
                    save_secret "DUCKDNS_TOKEN" "$DUCKDNS_TOKEN"
                fi

                # Update DuckDNS
                echo ""
                echo -e "${BLUE}🌐 Updating DuckDNS...${NC}"
                DUCKDNS_RESPONSE=$(curl -s "https://www.duckdns.org/update?domains=$DUCKDNS_SUBDOMAIN&token=$DUCKDNS_TOKEN&ip=$PUBLIC_IP")

                if [ "$DUCKDNS_RESPONSE" = "OK" ]; then
                    log INFO "DuckDNS updated: $DUCKDNS_SUBDOMAIN → $PUBLIC_IP"
                    echo -e "${GREEN}✅ DuckDNS updated successfully${NC}"
                else
                    log ERROR "DuckDNS update failed for $DUCKDNS_SUBDOMAIN: $DUCKDNS_RESPONSE"
                    echo -e "${RED}❌ DuckDNS update failed: $DUCKDNS_RESPONSE${NC}"
                    continue
                fi

                # Select environment
                echo ""
                ENV_NAME=$(select_environment "Select environment to publish")

                if [ -z "$ENV_NAME" ]; then
                    continue
                fi

                PORT=$(get_port_from_pm2 "$ENV_NAME")
                if [ -z "$PORT" ]; then
                    echo -e "${RED}❌ Could not get port for $ENV_NAME${NC}"
                    continue
                fi

                # Generate Caddyfile
                DOMAIN="${DUCKDNS_SUBDOMAIN}.duckdns.org"
                CADDYFILE="/etc/caddy/Caddyfile"

                # Backup existing Caddyfile
                if [ -f "$CADDYFILE" ]; then
                    sudo cp "$CADDYFILE" "${CADDYFILE}.backup.$(date +%s)" 2>/dev/null
                fi

                echo -e "${BLUE}🔧 Generating Caddyfile with all online environments...${NC}"

                # Build reverse_proxy routes for ALL online environments with ports
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
                            if [ "$env" = "$ENV_NAME" ]; then
                                SELECTED_INCLUDED=true
                            fi
                        fi
                    done <<< "$ALL_ENVS"
                fi

                # Also include the selected environment even if not yet online
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

                # Reload Caddy
                echo -e "${BLUE}🔄 Reloading Caddy...${NC}"
                if sudo systemctl reload caddy; then
                    log INFO "Caddy reloaded successfully for $DOMAIN"
                    echo -e "${GREEN}✅ Caddy reloaded${NC}"
                    echo ""
                    echo -e "${GREEN}🎉 SUCCESS! Published URLs:${NC}"
                    # Show all published routes
                    if [ -n "$ALL_ENVS" ]; then
                        while IFS= read -r env; do
                            [ -z "$env" ] && continue
                            local env_s=$(get_pm2_status "$env")
                            local env_p=$(get_port_from_pm2 "$env")
                            if [ "$env_s" = "online" ] && [ -n "$env_p" ]; then
                                echo -e "${CYAN}   https://$DOMAIN/$env${NC}"
                            fi
                        done <<< "$ALL_ENVS"
                    fi
                    # Ensure selected env is shown
                    if ! echo "$ALL_ENVS" | grep -q "^${ENV_NAME}$" || [ "$(get_pm2_status "$ENV_NAME")" != "online" ]; then
                        echo -e "${CYAN}   https://$DOMAIN/$ENV_NAME${NC} (selected)"
                    fi
                    echo ""
                else
                    log ERROR "Failed to reload Caddy for $DOMAIN"
                    echo -e "${RED}❌ Failed to reload Caddy${NC}"
                    echo -e "${YELLOW}Check logs with: sudo journalctl -u caddy -n 50${NC}"
                fi
                ;;
            7)
                # Help
                show_help
                ;;
            8)
                # Disk Cleanup
                disk_cleanup_menu
                refresh_menu_status_cache_sync >/dev/null 2>&1 || true
                ;;
            9)
                # Updates
                updates_menu
                refresh_menu_status_cache_sync >/dev/null 2>&1 || true
                ;;
            x|X)
                return 0
                ;;
            *)
                echo -e "${RED}❌ Invalid option${NC}"
                ;;
        esac

        echo ""
        echo -e "${YELLOW}Press Enter to continue...${NC}"
        read -r
    done
}

# Main function
main() {
    # Check prerequisites on first run
    if ! check_prerequisites; then
        exit 1
    fi

    # Clean up orphan projects at startup
    cleanup_orphan_projects

    while true; do
        clear
        print_header
        show_menu

        echo -e "${YELLOW}Your choice:${NC} \c"
        read -r CHOICE

        case $CHOICE in
            1)
                # Dashboard
                show_dashboard
                ;;

            s|S)
                # ShipFlow overview
                show_shipflow_menu
                ;;

            2)
                # Deploy
                echo -e "${GREEN}🚀 Deploy Environment${NC}"
                echo ""
                echo -e "${BLUE}Choose source:${NC}"
                echo ""
                echo -e "  ${CYAN}1)${NC} 🔍 Auto-detect project in /root"
                echo -e "  ${CYAN}2)${NC} 📁 Custom local path"
                echo -e "  ${CYAN}3)${NC} 🚀 Deploy from GitHub"
                echo -e "  ${CYAN}x)${NC} Cancel"
                echo ""
                echo -e "${YELLOW}Your choice:${NC} \c"
                read -r deploy_choice

                case $deploy_choice in
                    1)
                        # Auto-detect projects
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
                            -o -type f \( -name "package.json" -o -name "requirements.txt" -o -name "Cargo.toml" -o -name "go.mod" \) -print 2>/dev/null | while read -r manifest; do
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
                            echo -e "${BLUE}💡 Tip: Use option 2 for custom path or option 3 for GitHub${NC}"
                        else
                            SELECTED_PROJECT=$(echo "$PROJECTS" | ui_choose "Detected projects:")
                            if [ -n "$SELECTED_PROJECT" ]; then
                                log INFO "Menu: starting project $SELECTED_PROJECT"
                                echo -e "${GREEN}✅ Starting: $SELECTED_PROJECT${NC}"
                                env_start "$SELECTED_PROJECT"
                            fi
                        fi
                        ;;
                    2)
                        # Custom path
                        CUSTOM_PATH=$(ui_input "Path (absolute):" "/root/my-project")

                        if [ -z "$CUSTOM_PATH" ]; then
                            echo -e "${RED}❌ Path required${NC}"
                        elif ! validate_project_path "$CUSTOM_PATH"; then
                            echo -e "${RED}❌ Invalid or unsafe path${NC}"
                        else
                            env_start "$CUSTOM_PATH"
                        fi
                        ;;
                    3)
                        # Deploy from GitHub
                        echo -e "${GREEN}🚀 Deploy from GitHub${NC}"
                        echo ""
                        echo -e "${BLUE}🔍 Fetching your GitHub repos...${NC}"
                        echo ""

                        GITHUB_REPOS=$(list_github_repos)

                        if [ -z "$GITHUB_REPOS" ]; then
                            echo -e "${YELLOW}All your GitHub repos are already deployed (or no repos found).${NC}"
                            continue
                        fi

                        SELECTED_REPO=$(echo "$GITHUB_REPOS" | cut -d':' -f1 | ui_choose "Available repos:")

                        if [ -n "$SELECTED_REPO" ]; then
                            if ! validate_repo_name "$SELECTED_REPO"; then
                                echo -e "${RED}❌ Invalid repository name${NC}"
                                continue
                            fi

                            echo ""
                            echo -e "${GREEN}📦 Selected repo: $SELECTED_REPO${NC}"
                            echo -e "${BLUE}🚀 Deploying...${NC}"
                            echo ""

                            deploy_github_project "$SELECTED_REPO"
                        fi
                        ;;
                    x|X)
                        echo -e "${BLUE}Cancelled${NC}"
                        ;;
                    *)
                        echo -e "${RED}❌ Invalid option${NC}"
                        ;;
                esac
                ;;

            3)
                # Restart
                echo -e "${GREEN}🔄 Restart Environment${NC}"
                ENV_NAME=$(select_environment "Select environment to restart")

                if [ -n "$ENV_NAME" ]; then
                    log INFO "Menu: restarting $ENV_NAME"
                    env_restart "$ENV_NAME"
                fi
                ;;

            4)
                # Stop
                echo -e "${GREEN}🛑 Stop Environment${NC}"
                ENV_NAME=$(select_environment "Select environment to stop")

                if [ -n "$ENV_NAME" ]; then
                    log INFO "Menu: stopping $ENV_NAME"
                    echo -e "${YELLOW}🛑 Stopping $ENV_NAME...${NC}"
                    env_stop "$ENV_NAME"
                    echo -e "${GREEN}✅ Environment $ENV_NAME stopped!${NC}"
                fi
                ;;

            5)
                # Remove
                echo -e "${GREEN}🗑️  Remove Environment${NC}"
                echo ""
                echo -e "${YELLOW}⚠️  WARNING: This will permanently delete the project!${NC}"
                echo ""
                ENV_NAME=$(select_environment "Select environment to remove")

                if [ -n "$ENV_NAME" ]; then
                    PROJECT_DIR=$(resolve_project_path "$ENV_NAME")

                    echo ""
                    echo -e "${RED}⚠️  Tu vas supprimer :${NC}"
                    echo -e "${YELLOW}   Environnement : $ENV_NAME${NC}"
                    echo -e "${YELLOW}   Répertoire : $PROJECT_DIR${NC}"

                    # Show git safety warnings before asking for confirmation
                    if [ -d "$PROJECT_DIR" ]; then
                        local git_warnings
                        git_warnings=$(env_check_git_safety "$PROJECT_DIR" 2>&1)
                        if [ $? -ne 0 ]; then
                            echo ""
                            echo -e "${RED}⚠️  Travail non sauvegardé détecté :${NC}"
                            echo "$git_warnings"
                        fi
                    fi

                    echo ""
                    if ui_confirm "Confirmer la suppression ?"; then
                        log INFO "Menu: removing environment $ENV_NAME (dir: $PROJECT_DIR)"
                        env_remove "$ENV_NAME" --force
                        echo -e "${GREEN}✅ Environnement supprimé !${NC}"
                    else
                        echo -e "${BLUE}Annulé — rien n'a été supprimé${NC}"
                    fi
                fi
                ;;

            6)
                # Start All
                echo -e "${GREEN}🚀 Start All Environments${NC}"
                batch_start_all
                ;;

            7)
                # Stop All
                echo -e "${GREEN}🛑 Stop All Environments${NC}"
                batch_stop_all
                ;;

            8)
                # Restart All
                echo -e "${GREEN}🔄 Restart All Environments${NC}"
                batch_restart_all
                ;;

            9)
                # Advanced Options Submenu
                show_advanced_menu
                ;;

            m|M)
                # Mobile Guide
                show_mobile_guide
                ;;

            h|H)
                # Health Check
                echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
                echo -e "${CYAN}║${NC}              ${YELLOW}Health Check${NC}                      ${CYAN}║${NC}"
                echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
                echo ""
                health_check_all verbose
                echo ""
                echo -e "${BLUE}Options:${NC}"
                echo -e "  ${CYAN}f)${NC} Auto-fix known issues"
                echo -e "  ${CYAN}*)${NC} Back to menu"
                echo ""
                echo -e "${YELLOW}Your choice:${NC} \c"
                read -r health_choice
                case $health_choice in
                    f|F)
                        echo ""
                        auto_fix_known_issues
                        echo ""
                        echo -e "${BLUE}Updated health status:${NC}"
                        echo ""
                        health_check_all verbose
                        ;;
                esac
                ;;

            x|X)
                echo -e "${GREEN}👋 Goodbye!${NC}"
                exit 0
                ;;

            *)
                echo -e "${RED}❌ Invalid option${NC}"
                ;;
        esac

        echo ""
        echo -e "${YELLOW}Press Enter to continue...${NC}"
        read -r
    done
}

# ---------------------------------------------------------------------------
# show_mobile_guide - Guide interactif pas à pas pour Expo + Android
# ---------------------------------------------------------------------------
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
        echo -e "  ${BLUE}   Déploie d'abord ton projet depuis le menu principal (option 2).${NC}"
        echo ""
        echo -e "${YELLOW}Appuie sur Entrée pour quitter...${NC}"
        read -r
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
    echo -e "${YELLOW}Appuie sur Entrée pour revenir au menu...${NC}"
    read -r
}

# Launch menu
main
