#!/bin/bash

# ShipFlow — Menu 100% texte (echo + read, aucune dépendance externe)
# Aucun usage de gum. Fonctionne partout.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# Force text mode — disable gum even if available
HAS_GUM=false

# ── Helpers ──────────────────────────────────────────────────────────────────

# Centered text header
text_header() {
    local title="$1"
    local subtitle="${2:-}"
    local width=50
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
    local pad=$(( (width - ${#title}) / 2 ))
    printf "${YELLOW}%*s%s${NC}\n" "$pad" "" "$title"
    if [ -n "$subtitle" ]; then
        pad=$(( (width - ${#subtitle}) / 2 ))
        printf "${BLUE}%*s%s${NC}\n" "$pad" "" "$subtitle"
    fi
    echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
}

# Numbered menu — displays options, reads choice, returns selected label
# Usage: result=$(text_menu "Title" "opt1" "opt2" "opt3")
text_menu() {
    local prompt="$1"
    shift
    local options=("$@")

    echo ""
    echo -e "${BLUE}$prompt${NC}"
    echo ""
    local i=1
    for opt in "${options[@]}"; do
        echo -e "  ${CYAN}${i})${NC} $opt"
        ((i++))
    done
    echo ""
    echo -e "  ${CYAN}0)${NC} Retour"
    echo ""
    echo -e "${YELLOW}Ton choix (0-$((i-1))) :${NC} \c"
    read -r choice

    if [[ "$choice" == "0" ]] || [ -z "$choice" ]; then
        return 1
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le $((i-1)) ]; then
        echo "${options[$((choice-1))]}"
        return 0
    else
        echo -e "${RED}Choix invalide${NC}" >&2
        return 1
    fi
}

# Yes/no confirmation
text_confirm() {
    local prompt="$1"
    echo -e "${YELLOW}${prompt} (o/N) :${NC} \c" >&2
    read -r answer
    case "$answer" in
        [oOyY]|[oO][uU][iI]|[yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

# Text input
text_input() {
    local prompt="$1"
    local password="${2:-}"
    if [ "$password" = "--password" ]; then
        echo -e "${YELLOW}${prompt}${NC} \c" >&2
        read -rs value
        echo "" >&2
    else
        echo -e "${YELLOW}${prompt}${NC} \c" >&2
        read -r value
    fi
    echo "$value"
}

# Wait for Enter
text_pause() {
    echo ""
    echo -e "${YELLOW}Appuie sur Entrée pour continuer...${NC}"
    read -r
}

# ── Status Bar ───────────────────────────────────────────────────────────────

print_status_bar() {
    read_menu_status_cache >/dev/null 2>&1 || true
    refresh_menu_status_cache_async_if_stale

    local free="?"
    local updates="?"
    [ -n "$MENU_STATUS_FREE_HUMAN" ] && free="$MENU_STATUS_FREE_HUMAN"
    [ -n "$MENU_STATUS_UPDATES_TOTAL" ] && updates="$MENU_STATUS_UPDATES_TOTAL"

    echo -e "${GREEN} Libre: $free${NC}                        ${GREEN}Maj: $updates${NC}"
    echo -e "${CYAN}──────────────────────────────────────────────────${NC}"

    if [ "${MENU_STATUS_LOW_SPACE:-0}" = "1" ]; then
        echo -e "${RED}  ⚠️  Espace disque faible. Lance le nettoyage.${NC}"
    fi

    if [ "$SHIPFLOW_SESSION_ENABLED" = "true" ]; then
        init_session 2>/dev/null
        display_session_banner
    fi
}

# ── Main Menu ────────────────────────────────────────────────────────────────

show_main_menu() {
    text_header "ShipFlow DevServer"
    print_status_bar
    echo ""

    echo -e "${BLUE}  APERCU${NC}"
    echo -e "  ${CYAN}1)${NC}  Dashboard — Voir tous les environnements"
    echo -e "  ${CYAN}s)${NC}  ShipFlow — Tâches, Priorités, Changelog"
    echo ""
    echo -e "${BLUE}  GERER${NC}"
    echo -e "  ${CYAN}2)${NC}  Déployer — Lancer un environnement"
    echo -e "  ${CYAN}3)${NC}  Redémarrer un environnement"
    echo -e "  ${CYAN}4)${NC}  Arrêter un environnement"
    echo -e "  ${CYAN}5)${NC}  Supprimer un environnement"
    echo ""
    echo -e "${BLUE}  BATCH${NC}"
    echo -e "  ${CYAN}6)${NC}  Tout démarrer"
    echo -e "  ${CYAN}7)${NC}  Tout arrêter"
    echo -e "  ${CYAN}8)${NC}  Tout redémarrer"
    echo ""
    echo -e "${BLUE}  AVANCE${NC}"
    echo -e "  ${CYAN}9)${NC}  Options avancées — Publier, Logs, Outils..."
    echo -e "  ${CYAN}m)${NC}  Guide Mobile — Expo + Android"
    echo -e "  ${CYAN}h)${NC}  Health Check — Détection crash loops"
    echo ""
    echo -e "  ${CYAN}x)${NC}  Quitter"
    echo ""
    echo -e "${YELLOW}Ton choix :${NC} \c"
}

# ── Deploy Submenu ───────────────────────────────────────────────────────────

menu_deploy() {
    echo ""
    echo -e "${BLUE}Source du déploiement :${NC}"
    echo ""
    echo -e "  ${CYAN}1)${NC} Auto-detect — Scanner /root"
    echo -e "  ${CYAN}2)${NC} Chemin personnalisé"
    echo -e "  ${CYAN}3)${NC} Depuis GitHub"
    echo -e "  ${CYAN}0)${NC} Annuler"
    echo ""
    echo -e "${YELLOW}Ton choix :${NC} \c"
    read -r deploy_choice

    case $deploy_choice in
        1)
            echo -e "${BLUE}Scan de $PROJECTS_DIR...${NC}"
            EXISTING_ENVS=$(find "$PROJECTS_DIR" -maxdepth 4 \
                \( -name "node_modules" -o -name ".git" -o -name "venv" -o -name ".venv" \
                   -o -name "__pycache__" -o -name "target" -o -name ".next" -o -name ".nuxt" \
                   -o -name "dist" -o -name ".cache" -o -name ".pnpm" -o -name ".yarn" \) -prune \
                -o -type d -name ".flox" -print 2>/dev/null | while read -r flox_dir; do
                proj_dir=$(dirname "$flox_dir")
                case "$proj_dir" in "$PROJECTS_DIR"/.*) continue ;; *) echo "$proj_dir" ;; esac
            done | sort -u)

            NEW_PROJECTS=$(find "$PROJECTS_DIR" -maxdepth 4 \
                \( -name "node_modules" -o -name ".git" -o -name "venv" -o -name ".venv" \
                   -o -name "__pycache__" -o -name "target" -o -name ".next" -o -name ".nuxt" \
                   -o -name "dist" -o -name ".cache" -o -name ".pnpm" -o -name ".yarn" \) -prune \
                -o -type f \( -name "package.json" -o -name "requirements.txt" -o -name "Cargo.toml" -o -name "go.mod" \) -print 2>/dev/null | while read -r manifest; do
                proj_dir=$(dirname "$manifest")
                case "$proj_dir" in "$PROJECTS_DIR"/.*) continue ;; esac
                [ ! -d "$proj_dir/.flox" ] && echo "$proj_dir"
            done | sort -u)

            PROJECTS=$(printf "%s\n%s" "$EXISTING_ENVS" "$NEW_PROJECTS" | grep -v "^$" | sort -u)
            if [ -z "$PROJECTS" ]; then
                echo -e "${YELLOW}Aucun projet détecté${NC}"
            else
                SELECTED_PROJECT=$(echo "$PROJECTS" | text_menu "Projets détectés :")
                if [ -n "$SELECTED_PROJECT" ]; then
                    log INFO "Menu: starting project $SELECTED_PROJECT"
                    echo -e "${GREEN}Démarrage : $SELECTED_PROJECT${NC}"
                    env_start "$SELECTED_PROJECT"
                fi
            fi
            ;;
        2)
            CUSTOM_PATH=$(text_input "Chemin absolu :")
            if [ -z "$CUSTOM_PATH" ]; then
                echo -e "${RED}Chemin requis${NC}"
            elif ! validate_project_path "$CUSTOM_PATH"; then
                echo -e "${RED}Chemin invalide ou non sécurisé${NC}"
            else
                env_start "$CUSTOM_PATH"
            fi
            ;;
        3)
            echo -e "${BLUE}Récupération des repos GitHub...${NC}"
            GITHUB_REPOS=$(list_github_repos)
            if [ -z "$GITHUB_REPOS" ]; then
                echo -e "${YELLOW}Tous tes repos sont déjà déployés (ou aucun trouvé).${NC}"
            else
                SELECTED_REPO=$(echo "$GITHUB_REPOS" | cut -d':' -f1 | text_menu "Repos disponibles :")
                if [ -n "$SELECTED_REPO" ]; then
                    validate_repo_name "$SELECTED_REPO" || { echo -e "${RED}Nom de repo invalide${NC}"; return; }
                    echo -e "${GREEN}Déploiement de $SELECTED_REPO...${NC}"
                    deploy_github_project "$SELECTED_REPO"
                fi
            fi
            ;;
        0|"") echo -e "${BLUE}Annulé${NC}" ;;
        *) echo -e "${RED}Choix invalide${NC}" ;;
    esac
}

# ── Advanced Submenu ─────────────────────────────────────────────────────────

menu_advanced() {
    while true; do
        clear
        text_header "Options avancées"
        echo ""
        echo -e "  ${CYAN}1)${NC} Logs — Voir les logs d'une app"
        echo -e "  ${CYAN}2)${NC} Naviguer — Parcourir /root"
        echo -e "  ${CYAN}3)${NC} Ouvrir — cd dans un projet"
        echo -e "  ${CYAN}4)${NC} Outils Dev — Inspecteur & Eruda (par projet)"
        echo -e "  ${CYAN}5)${NC} Session — Identité de session"
        echo -e "  ${CYAN}6)${NC} Publier — HTTPS (Caddy + DuckDNS)"
        echo -e "  ${CYAN}7)${NC} Aide — Comment ShipFlow fonctionne"
        echo -e "  ${CYAN}8)${NC} Nettoyage — Libérer de l'espace"
        echo -e "  ${CYAN}9)${NC} Mises à jour — Vérifier les paquets"
        echo ""
        echo -e "  ${CYAN}x)${NC} Retour au menu principal"
        echo ""
        echo -e "${YELLOW}Ton choix :${NC} \c"
        read -r adv_choice

        case $adv_choice in
            1)
                ENV_NAME=$(select_environment "Choisis un environnement")
                [ -n "$ENV_NAME" ] && view_environment_logs "$ENV_NAME"
                ;;
            2)
                FOLDERS=$(find /root -maxdepth 1 -type d ! -name ".*" ! -path /root 2>/dev/null | sort)
                if [ -z "$FOLDERS" ]; then
                    echo -e "${RED}Aucun dossier trouvé${NC}"
                else
                    SELECTED=$(echo "$FOLDERS" | text_menu "Dossiers disponibles :")
                    [ -n "$SELECTED" ] && cd "$SELECTED" && exec $SHELL
                fi
                ;;
            3)
                ENV_NAME=$(select_environment "Choisis un environnement")
                if [ -n "$ENV_NAME" ]; then
                    PROJECT_DIR=$(resolve_project_path "$ENV_NAME")
                    if [ -z "$PROJECT_DIR" ]; then
                        echo -e "${RED}Répertoire introuvable : $ENV_NAME${NC}"
                    else
                        cd "$PROJECT_DIR" && exec $SHELL
                    fi
                fi
                ;;
            4) menu_dev_tools ;;
            5)
                display_session_banner
                echo ""
                get_session_info
                echo ""
                echo -e "  ${CYAN}1)${NC} Réinitialiser l'identité de session"
                echo -e "  ${CYAN}x)${NC} Retour"
                echo ""
                echo -e "${YELLOW}Ton choix :${NC} \c"
                read -r session_choice
                case $session_choice in
                    1) reset_session; echo -e "${GREEN}Nouvelle identité :${NC}"; display_session_banner ;;
                esac
                ;;
            6) menu_publish ;;
            7) show_help ;;
            8) disk_cleanup_menu; refresh_menu_status_cache_sync >/dev/null 2>&1 || true ;;
            9) updates_menu; refresh_menu_status_cache_sync >/dev/null 2>&1 || true ;;
            x|X) return 0 ;;
            *) echo -e "${RED}Choix invalide${NC}" ;;
        esac

        text_pause
    done
}

# ── Dev Tools Submenu ────────────────────────────────────────────────────────

menu_dev_tools() {
    ENV_NAME=$(select_environment "Choisis un projet")
    [ -z "$ENV_NAME" ] && return

    PROJECT_DIR=$(resolve_project_path "$ENV_NAME")
    if [ -z "$PROJECT_DIR" ]; then
        echo -e "${RED}Projet introuvable : $ENV_NAME${NC}"
        return
    fi

    local insp_state eruda_state
    insp_state=$(get_tools_pref "$PROJECT_DIR" "inspector")
    eruda_state=$(get_tools_pref "$PROJECT_DIR" "eruda")

    local insp_icon eruda_icon
    [ "$insp_state" = "enabled" ] && insp_icon="ON " || insp_icon="OFF"
    [ "$eruda_state" = "enabled" ] && eruda_icon="ON " || eruda_icon="OFF"

    local insp_action eruda_action
    [ "$insp_state" = "enabled" ] && insp_action="Desactiver" || insp_action="Activer"
    [ "$eruda_state" = "enabled" ] && eruda_action="Desactiver" || eruda_action="Activer"

    echo ""
    text_header "Outils Dev — $ENV_NAME"
    echo ""
    echo -e "  Etat actuel :"
    echo -e "    Inspecteur visuel : [$insp_icon] $(echo "$insp_state" | sed 's/enabled/Active/;s/disabled/Desactive/')"
    echo -e "    Console Eruda     : [$eruda_icon] $(echo "$eruda_state" | sed 's/enabled/Active/;s/disabled/Desactive/')"
    echo ""
    echo -e "  ${CYAN}1)${NC} Inspecteur visuel — $insp_action"
    echo -e "  ${CYAN}2)${NC} Console Eruda — $eruda_action"
    echo -e "  ${CYAN}3)${NC} Tout activer"
    echo -e "  ${CYAN}4)${NC} Tout desactiver"
    echo ""
    echo -e "  ${CYAN}x)${NC} Retour"
    echo ""
    echo -e "${YELLOW}Ton choix :${NC} \c"
    read -r tools_choice

    local needs_restart=false

    case $tools_choice in
        1)
            local new_state; [ "$insp_state" = "enabled" ] && new_state="disabled" || new_state="enabled"
            set_tool_state "$PROJECT_DIR" "inspector" "$new_state"
            echo -e "${GREEN}Inspecteur visuel : $new_state${NC}"
            needs_restart=true ;;
        2)
            local new_state; [ "$eruda_state" = "enabled" ] && new_state="disabled" || new_state="enabled"
            set_tool_state "$PROJECT_DIR" "eruda" "$new_state"
            echo -e "${GREEN}Console Eruda : $new_state${NC}"
            needs_restart=true ;;
        3)
            set_tool_state "$PROJECT_DIR" "inspector" "enabled"
            set_tool_state "$PROJECT_DIR" "eruda" "enabled"
            echo -e "${GREEN}Tous les outils actives${NC}"
            needs_restart=true ;;
        4)
            set_tool_state "$PROJECT_DIR" "inspector" "disabled"
            set_tool_state "$PROJECT_DIR" "eruda" "disabled"
            echo -e "${GREEN}Tous les outils desactives${NC}"
            needs_restart=true ;;
        x|X) return ;;
        *) echo -e "${RED}Choix invalide${NC}"; return ;;
    esac

    if [ "$needs_restart" = true ]; then
        echo ""
        if text_confirm "Redemarrer $ENV_NAME pour appliquer ?"; then
            env_restart "$ENV_NAME"
            echo -e "${GREEN}$ENV_NAME redemarre${NC}"
        else
            echo -e "${YELLOW}Les changements seront appliques au prochain redemarrage${NC}"
        fi
    fi
}

# ── Publish Submenu ──────────────────────────────────────────────────────────

menu_publish() {
    echo -e "${GREEN}Publier sur le Web (HTTPS via Caddy + DuckDNS)${NC}"
    echo ""

    if ! command -v caddy >/dev/null 2>&1; then
        echo -e "${RED}Caddy non installe${NC}"
        echo -e "${YELLOW}Installe avec : sudo apt install caddy${NC}"
        return
    fi

    echo -e "${BLUE}Detection de l'IP publique...${NC}"
    PUBLIC_IP=$(curl -4 -s https://ip.me 2>/dev/null)
    if [ -n "$PUBLIC_IP" ]; then
        echo -e "${BLUE}IP publique : ${GREEN}$PUBLIC_IP${NC}"
    else
        PUBLIC_IP=$(text_input "Entre ton IP publique :")
    fi

    echo ""
    CACHED_SUBDOMAIN=$(load_secret "DUCKDNS_SUBDOMAIN" 2>/dev/null) || true
    CACHED_TOKEN=$(load_secret "DUCKDNS_TOKEN" 2>/dev/null) || true

    if [ -n "$CACHED_SUBDOMAIN" ] && [ -n "$CACHED_TOKEN" ]; then
        echo -e "${GREEN}Sous-domaine cache : ${CYAN}$CACHED_SUBDOMAIN${NC}"
        if text_confirm "Utiliser les identifiants caches ?"; then
            DUCKDNS_SUBDOMAIN="$CACHED_SUBDOMAIN"
            DUCKDNS_TOKEN="$CACHED_TOKEN"
        else
            CACHED_SUBDOMAIN=""
            CACHED_TOKEN=""
        fi
    fi

    if [ -z "$CACHED_SUBDOMAIN" ] || [ -z "$CACHED_TOKEN" ]; then
        DUCKDNS_SUBDOMAIN=$(text_input "Sous-domaine DuckDNS (sans .duckdns.org) :")
        [ -z "$DUCKDNS_SUBDOMAIN" ] && { echo -e "${RED}Sous-domaine requis${NC}"; return; }
        DUCKDNS_TOKEN=$(text_input "Token DuckDNS :" "--password")
        [ -z "$DUCKDNS_TOKEN" ] && { echo -e "${RED}Token requis${NC}"; return; }
        save_secret "DUCKDNS_SUBDOMAIN" "$DUCKDNS_SUBDOMAIN"
        save_secret "DUCKDNS_TOKEN" "$DUCKDNS_TOKEN"
    fi

    echo ""
    echo -e "${BLUE}Mise a jour DuckDNS...${NC}"
    DUCKDNS_RESPONSE=$(curl -s "https://www.duckdns.org/update?domains=$DUCKDNS_SUBDOMAIN&token=$DUCKDNS_TOKEN&ip=$PUBLIC_IP")
    if [ "$DUCKDNS_RESPONSE" = "OK" ]; then
        log INFO "DuckDNS updated: $DUCKDNS_SUBDOMAIN → $PUBLIC_IP"
        echo -e "${GREEN}DuckDNS mis a jour${NC}"
    else
        log ERROR "DuckDNS update failed for $DUCKDNS_SUBDOMAIN: $DUCKDNS_RESPONSE"
        echo -e "${RED}Echec DuckDNS : $DUCKDNS_RESPONSE${NC}"
        return
    fi

    echo ""
    ENV_NAME=$(select_environment "Choisis l'environnement a publier")
    [ -z "$ENV_NAME" ] && return

    PORT=$(get_port_from_pm2 "$ENV_NAME")
    [ -z "$PORT" ] && { echo -e "${RED}Port introuvable pour $ENV_NAME${NC}"; return; }

    DOMAIN="${DUCKDNS_SUBDOMAIN}.duckdns.org"
    CADDYFILE="/etc/caddy/Caddyfile"

    [ -f "$CADDYFILE" ] && sudo cp "$CADDYFILE" "${CADDYFILE}.backup.$(date +%s)" 2>/dev/null

    echo -e "${BLUE}Generation du Caddyfile...${NC}"
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
                echo -e "  ${GREEN}+${NC} /${env} -> localhost:${env_port}"
                [ "$env" = "$ENV_NAME" ] && SELECTED_INCLUDED=true
            fi
        done <<< "$ALL_ENVS"
    fi

    if [ "$SELECTED_INCLUDED" = "false" ]; then
        ROUTES="${ROUTES}    reverse_proxy /${ENV_NAME}* localhost:${PORT}"$'\n'
        echo -e "  ${GREEN}+${NC} /${ENV_NAME} -> localhost:${PORT} (selectionne)"
    fi

    sudo tee "$CADDYFILE" > /dev/null << EOF
${DOMAIN} {
${ROUTES}    encode gzip
}
EOF

    log INFO "Caddyfile generated for $DOMAIN"
    echo -e "${GREEN}Caddyfile genere${NC}"

    echo -e "${BLUE}Rechargement de Caddy...${NC}"
    if sudo systemctl reload caddy; then
        echo -e "${GREEN}Caddy recharge${NC}"
        echo ""
        echo -e "${GREEN}URLs publiees :${NC}"
        if [ -n "$ALL_ENVS" ]; then
            while IFS= read -r env; do
                [ -z "$env" ] && continue
                local env_s=$(get_pm2_status "$env")
                local env_p=$(get_port_from_pm2 "$env")
                [ "$env_s" = "online" ] && [ -n "$env_p" ] && echo -e "  ${CYAN}https://$DOMAIN/$env${NC}"
            done <<< "$ALL_ENVS"
        fi
        if ! echo "$ALL_ENVS" | grep -q "^${ENV_NAME}$" || [ "$(get_pm2_status "$ENV_NAME")" != "online" ]; then
            echo -e "  ${CYAN}https://$DOMAIN/$ENV_NAME${NC}"
        fi
    else
        echo -e "${RED}Echec du rechargement Caddy${NC}"
        echo -e "${YELLOW}Verifie les logs : sudo journalctl -u caddy -n 50${NC}"
    fi
}

# ── Health Check ─────────────────────────────────────────────────────────────

menu_health() {
    text_header "Health Check"
    echo ""
    health_check_all verbose
    echo ""
    echo -e "  ${CYAN}f)${NC} Auto-fix les problemes connus"
    echo -e "  ${CYAN}x)${NC} Retour"
    echo ""
    echo -e "${YELLOW}Ton choix :${NC} \c"
    read -r health_choice
    case $health_choice in
        f|F)
            echo ""
            auto_fix_known_issues
            echo ""
            echo -e "${BLUE}Etat mis a jour :${NC}"
            health_check_all verbose
            ;;
    esac
}

# ── Main Loop ────────────────────────────────────────────────────────────────

main() {
    check_prerequisites || exit 1
    cleanup_orphan_projects

    while true; do
        clear
        show_main_menu
        read -r CHOICE

        case $CHOICE in
            1) show_dashboard ;;
            s|S) show_shipflow_menu ;;
            2) menu_deploy ;;
            3)
                ENV_NAME=$(select_environment "Choisis un environnement a redemarrer")
                [ -n "$ENV_NAME" ] && { log INFO "Menu: restarting $ENV_NAME"; env_restart "$ENV_NAME"; }
                ;;
            4)
                ENV_NAME=$(select_environment "Choisis un environnement a arreter")
                [ -n "$ENV_NAME" ] && { log INFO "Menu: stopping $ENV_NAME"; env_stop "$ENV_NAME"; echo -e "${GREEN}$ENV_NAME arrete${NC}"; }
                ;;
            5)
                echo -e "${YELLOW}ATTENTION : Suppression definitive !${NC}"
                echo ""
                ENV_NAME=$(select_environment "Choisis un environnement a supprimer")
                if [ -n "$ENV_NAME" ]; then
                    PROJECT_DIR=$(resolve_project_path "$ENV_NAME")
                    echo ""
                    echo -e "${RED}Tu vas supprimer :${NC}"
                    echo -e "  Environnement : $ENV_NAME"
                    echo -e "  Repertoire    : $PROJECT_DIR"

                    if [ -d "$PROJECT_DIR" ]; then
                        local git_warnings
                        git_warnings=$(env_check_git_safety "$PROJECT_DIR" 2>&1)
                        if [ $? -ne 0 ]; then
                            echo ""
                            echo -e "${RED}Travail non sauvegarde detecte :${NC}"
                            echo "$git_warnings"
                        fi
                    fi

                    echo ""
                    if text_confirm "Confirmer la suppression ?"; then
                        log INFO "Menu: removing environment $ENV_NAME"
                        env_remove "$ENV_NAME" --force
                        echo -e "${GREEN}Environnement supprime${NC}"
                    else
                        echo -e "${BLUE}Annule — rien n'a ete supprime${NC}"
                    fi
                fi
                ;;
            6) batch_start_all ;;
            7) batch_stop_all ;;
            8) batch_restart_all ;;
            9) menu_advanced ;;
            m|M) show_mobile_guide ;;
            h|H) menu_health ;;
            x|X) echo -e "${GREEN}A bientot !${NC}"; exit 0 ;;
            *) echo -e "${RED}Choix invalide${NC}" ;;
        esac

        text_pause
    done
}

main
