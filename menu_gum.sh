#!/bin/bash

# ShipFlow — Menu 100% gum (nécessite gum installé)
# UI riche : sélection à flèches, spinners, confirmations stylées.
# Si gum n'est pas installé, affiche un message et quitte.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# Require gum
if ! command -v gum >/dev/null 2>&1; then
    echo "gum est requis pour ce menu. Installe-le :"
    echo "  sudo apt install gum"
    echo "  # ou : brew install gum"
    echo ""
    echo "Sinon, utilise le menu texte : ./menu_text.sh"
    exit 1
fi
HAS_GUM=true

# ── Helpers ──────────────────────────────────────────────────────────────────

gum_header() {
    local title="$1"
    local subtitle="${2:-}"
    local lines=("$title")
    [ -n "$subtitle" ] && lines+=("$subtitle")
    gum style \
        --foreground 212 --border-foreground 212 --border double \
        --align center --width 50 --margin "1 2" --padding "1 2" \
        "${lines[@]}"
}

gum_menu() {
    local prompt="$1"
    shift
    printf '%s\n' "$@" | gum choose --header "$prompt" --cursor.foreground 212
}

gum_confirm_fr() {
    gum confirm --affirmative "Oui" --negative "Non" "$1"
}

gum_pause() {
    echo ""
    gum style --faint "Appuie sur Entrée pour continuer..."
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

    gum style --faint "Libre: $free    Mises à jour: $updates"

    if [ "${MENU_STATUS_LOW_SPACE:-0}" = "1" ]; then
        gum style --foreground 196 --bold "⚠️  Espace disque faible. Lance le nettoyage."
    fi

    if [ "$SHIPFLOW_SESSION_ENABLED" = "true" ]; then
        init_session 2>/dev/null
        display_session_banner
    fi
}

# ── Main Menu ────────────────────────────────────────────────────────────────

show_main_menu() {
    local choice
    choice=$(gum_menu "ShipFlow DevServer" \
        "📊 Dashboard — Voir tous les environnements" \
        "⚡ ShipFlow — Tâches, Priorités, Changelog" \
        "─────────────────────────────" \
        "🚀 Déployer — Lancer un environnement" \
        "🔄 Redémarrer un environnement" \
        "🛑 Arrêter un environnement" \
        "🗑️  Supprimer un environnement" \
        "─────────────────────────────" \
        "▶️  Tout démarrer" \
        "⏹️  Tout arrêter" \
        "🔁 Tout redémarrer" \
        "─────────────────────────────" \
        "⚙️  Options avancées" \
        "📱 Guide Mobile — Expo + Android" \
        "🏥 Health Check" \
        "─────────────────────────────" \
        "❌ Quitter") || return 1

    # Map selection to action
    case "$choice" in
        *"Dashboard"*)      echo "1" ;;
        *"ShipFlow"*)       echo "s" ;;
        *"Déployer"*)       echo "2" ;;
        *"Redémarrer un"*)  echo "3" ;;
        *"Arrêter"*)        echo "4" ;;
        *"Supprimer"*)      echo "5" ;;
        *"Tout démarrer"*)  echo "6" ;;
        *"Tout arrêter"*)   echo "7" ;;
        *"Tout redémarrer"*) echo "8" ;;
        *"avancées"*)       echo "9" ;;
        *"Mobile"*)         echo "m" ;;
        *"Health"*)         echo "h" ;;
        *"Quitter"*)        echo "x" ;;
        *"────"*)           echo "" ;;  # separator
        *)                  echo "" ;;
    esac
}

# ── Deploy Submenu ───────────────────────────────────────────────────────────

menu_deploy() {
    local choice
    choice=$(gum_menu "Source du déploiement" \
        "🔍 Auto-detect — Scanner /root" \
        "📁 Chemin personnalisé" \
        "🐙 Depuis GitHub" \
        "← Annuler") || return

    case "$choice" in
        *"Auto-detect"*)
            gum spin --spinner dot --title "Scan de $PROJECTS_DIR..." -- sleep 1

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
                gum style --foreground 214 "Aucun projet détecté"
            else
                SELECTED_PROJECT=$(echo "$PROJECTS" | gum choose --header "Choisis un projet :")
                if [ -n "$SELECTED_PROJECT" ]; then
                    log INFO "Menu: starting project $SELECTED_PROJECT"
                    gum style --foreground 46 "Démarrage : $SELECTED_PROJECT"
                    env_start "$SELECTED_PROJECT"
                fi
            fi
            ;;
        *"Chemin"*)
            CUSTOM_PATH=$(gum input --placeholder "/root/mon-projet" --header "Chemin absolu du projet :")
            if [ -z "$CUSTOM_PATH" ]; then
                gum style --foreground 196 "Chemin requis"
            elif ! validate_project_path "$CUSTOM_PATH"; then
                gum style --foreground 196 "Chemin invalide ou non sécurisé"
            else
                env_start "$CUSTOM_PATH"
            fi
            ;;
        *"GitHub"*)
            gum spin --spinner dot --title "Récupération des repos GitHub..." -- sleep 1
            GITHUB_REPOS=$(list_github_repos)
            if [ -z "$GITHUB_REPOS" ]; then
                gum style --foreground 214 "Tous tes repos sont déjà déployés."
            else
                SELECTED_REPO=$(echo "$GITHUB_REPOS" | cut -d':' -f1 | gum choose --header "Repos disponibles :")
                if [ -n "$SELECTED_REPO" ]; then
                    validate_repo_name "$SELECTED_REPO" || { gum style --foreground 196 "Nom de repo invalide"; return; }
                    gum style --foreground 46 "Déploiement de $SELECTED_REPO..."
                    deploy_github_project "$SELECTED_REPO"
                fi
            fi
            ;;
        *"Annuler"*) ;;
    esac
}

# ── Advanced Submenu ─────────────────────────────────────────────────────────

menu_advanced() {
    while true; do
        clear
        gum_header "Options avancées"

        local choice
        choice=$(gum_menu "Que veux-tu faire ?" \
            "📝 Logs — Voir les logs d'une app" \
            "📁 Naviguer — Parcourir /root" \
            "📂 Ouvrir — cd dans un projet" \
            "🛠️  Outils Dev — Inspecteur & Eruda" \
            "🔐 Session — Identité de session" \
            "🌐 Publier — HTTPS (Caddy + DuckDNS)" \
            "📖 Aide — Comment ShipFlow fonctionne" \
            "🧹 Nettoyage — Libérer de l'espace" \
            "⬆️  Mises à jour — Vérifier les paquets" \
            "← Retour") || return 0

        case "$choice" in
            *"Logs"*)
                ENV_NAME=$(select_environment "Choisis un environnement")
                [ -n "$ENV_NAME" ] && view_environment_logs "$ENV_NAME"
                ;;
            *"Naviguer"*)
                FOLDERS=$(find /root -maxdepth 1 -type d ! -name ".*" ! -path /root 2>/dev/null | sort)
                if [ -z "$FOLDERS" ]; then
                    gum style --foreground 196 "Aucun dossier trouvé"
                else
                    SELECTED=$(echo "$FOLDERS" | gum choose --header "Dossiers disponibles :")
                    [ -n "$SELECTED" ] && cd "$SELECTED" && exec $SHELL
                fi
                ;;
            *"Ouvrir"*)
                ENV_NAME=$(select_environment "Choisis un environnement")
                if [ -n "$ENV_NAME" ]; then
                    PROJECT_DIR=$(resolve_project_path "$ENV_NAME")
                    [ -z "$PROJECT_DIR" ] && gum style --foreground 196 "Répertoire introuvable" || { cd "$PROJECT_DIR" && exec $SHELL; }
                fi
                ;;
            *"Outils Dev"*) menu_dev_tools ;;
            *"Session"*)
                display_session_banner
                echo ""
                get_session_info
                echo ""
                local sess_choice
                sess_choice=$(gum_menu "Options" \
                    "🔄 Réinitialiser l'identité" \
                    "← Retour") || continue
                case "$sess_choice" in
                    *"Réinitialiser"*) reset_session; gum style --foreground 46 "Nouvelle identité :"; display_session_banner ;;
                esac
                ;;
            *"Publier"*) menu_publish ;;
            *"Aide"*) show_help ;;
            *"Nettoyage"*) disk_cleanup_menu; refresh_menu_status_cache_sync >/dev/null 2>&1 || true ;;
            *"Mises à jour"*) updates_menu; refresh_menu_status_cache_sync >/dev/null 2>&1 || true ;;
            *"Retour"*) return 0 ;;
        esac

        gum_pause
    done
}

# ── Dev Tools Submenu ────────────────────────────────────────────────────────

menu_dev_tools() {
    ENV_NAME=$(select_environment "Choisis un projet")
    [ -z "$ENV_NAME" ] && return

    PROJECT_DIR=$(resolve_project_path "$ENV_NAME")
    if [ -z "$PROJECT_DIR" ]; then
        gum style --foreground 196 "Projet introuvable : $ENV_NAME"
        return
    fi

    local insp_state eruda_state
    insp_state=$(get_tools_pref "$PROJECT_DIR" "inspector")
    eruda_state=$(get_tools_pref "$PROJECT_DIR" "eruda")

    local insp_label eruda_label
    [ "$insp_state" = "enabled" ] && insp_label="✅ ON" || insp_label="❌ OFF"
    [ "$eruda_state" = "enabled" ] && eruda_label="✅ ON" || eruda_label="❌ OFF"

    local insp_action eruda_action
    [ "$insp_state" = "enabled" ] && insp_action="Désactiver" || insp_action="Activer"
    [ "$eruda_state" = "enabled" ] && eruda_action="Désactiver" || eruda_action="Activer"

    gum_header "Outils Dev — $ENV_NAME"
    echo ""
    gum style "  Inspecteur visuel : $insp_label"
    gum style "  Console Eruda     : $eruda_label"
    echo ""

    local choice
    choice=$(gum_menu "Que veux-tu modifier ?" \
        "🔍 Inspecteur visuel — $insp_action" \
        "🖥️  Console Eruda — $eruda_action" \
        "🔄 Tout activer" \
        "❌ Tout désactiver" \
        "← Retour") || return

    local needs_restart=false

    case "$choice" in
        *"Inspecteur"*)
            local new_state; [ "$insp_state" = "enabled" ] && new_state="disabled" || new_state="enabled"
            set_tool_state "$PROJECT_DIR" "inspector" "$new_state"
            gum style --foreground 46 "Inspecteur visuel : $new_state"
            needs_restart=true ;;
        *"Eruda"*)
            local new_state; [ "$eruda_state" = "enabled" ] && new_state="disabled" || new_state="enabled"
            set_tool_state "$PROJECT_DIR" "eruda" "$new_state"
            gum style --foreground 46 "Console Eruda : $new_state"
            needs_restart=true ;;
        *"Tout activer"*)
            set_tool_state "$PROJECT_DIR" "inspector" "enabled"
            set_tool_state "$PROJECT_DIR" "eruda" "enabled"
            gum style --foreground 46 "Tous les outils activés"
            needs_restart=true ;;
        *"Tout désactiver"*)
            set_tool_state "$PROJECT_DIR" "inspector" "disabled"
            set_tool_state "$PROJECT_DIR" "eruda" "disabled"
            gum style --foreground 46 "Tous les outils désactivés"
            needs_restart=true ;;
        *"Retour"*) return ;;
    esac

    if [ "$needs_restart" = true ]; then
        echo ""
        if gum_confirm_fr "Redémarrer $ENV_NAME pour appliquer ?"; then
            env_restart "$ENV_NAME"
            gum style --foreground 46 "✅ $ENV_NAME redémarré"
        else
            gum style --foreground 214 "💡 Les changements seront appliqués au prochain redémarrage"
        fi
    fi
}

# ── Publish Submenu ──────────────────────────────────────────────────────────

menu_publish() {
    gum style --bold --foreground 46 "Publier sur le Web (HTTPS via Caddy + DuckDNS)"
    echo ""

    if ! command -v caddy >/dev/null 2>&1; then
        gum style --foreground 196 "Caddy non installé"
        gum style --foreground 214 "Installe avec : sudo apt install caddy"
        return
    fi

    PUBLIC_IP=$(gum spin --spinner dot --title "Détection de l'IP publique..." -- curl -4 -s https://ip.me 2>/dev/null)
    if [ -n "$PUBLIC_IP" ]; then
        gum style "IP publique : $PUBLIC_IP"
    else
        PUBLIC_IP=$(gum input --placeholder "123.45.67.89" --header "Entre ton IP publique :")
    fi

    echo ""
    CACHED_SUBDOMAIN=$(load_secret "DUCKDNS_SUBDOMAIN" 2>/dev/null) || true
    CACHED_TOKEN=$(load_secret "DUCKDNS_TOKEN" 2>/dev/null) || true

    if [ -n "$CACHED_SUBDOMAIN" ] && [ -n "$CACHED_TOKEN" ]; then
        gum style "Sous-domaine caché : $CACHED_SUBDOMAIN"
        if gum_confirm_fr "Utiliser les identifiants cachés ?"; then
            DUCKDNS_SUBDOMAIN="$CACHED_SUBDOMAIN"
            DUCKDNS_TOKEN="$CACHED_TOKEN"
        else
            CACHED_SUBDOMAIN=""
            CACHED_TOKEN=""
        fi
    fi

    if [ -z "$CACHED_SUBDOMAIN" ] || [ -z "$CACHED_TOKEN" ]; then
        DUCKDNS_SUBDOMAIN=$(gum input --placeholder "mon-sous-domaine" --header "Sous-domaine DuckDNS (sans .duckdns.org) :")
        [ -z "$DUCKDNS_SUBDOMAIN" ] && { gum style --foreground 196 "Sous-domaine requis"; return; }
        DUCKDNS_TOKEN=$(gum input --placeholder "ton-token" --password --header "Token DuckDNS :")
        [ -z "$DUCKDNS_TOKEN" ] && { gum style --foreground 196 "Token requis"; return; }
        save_secret "DUCKDNS_SUBDOMAIN" "$DUCKDNS_SUBDOMAIN"
        save_secret "DUCKDNS_TOKEN" "$DUCKDNS_TOKEN"
    fi

    echo ""
    DUCKDNS_RESPONSE=$(gum spin --spinner dot --title "Mise à jour DuckDNS..." -- \
        curl -s "https://www.duckdns.org/update?domains=$DUCKDNS_SUBDOMAIN&token=$DUCKDNS_TOKEN&ip=$PUBLIC_IP")
    if [ "$DUCKDNS_RESPONSE" = "OK" ]; then
        log INFO "DuckDNS updated: $DUCKDNS_SUBDOMAIN → $PUBLIC_IP"
        gum style --foreground 46 "✅ DuckDNS mis à jour"
    else
        log ERROR "DuckDNS update failed: $DUCKDNS_RESPONSE"
        gum style --foreground 196 "❌ Échec DuckDNS : $DUCKDNS_RESPONSE"
        return
    fi

    echo ""
    ENV_NAME=$(select_environment "Choisis l'environnement à publier")
    [ -z "$ENV_NAME" ] && return

    PORT=$(get_port_from_pm2 "$ENV_NAME")
    [ -z "$PORT" ] && { gum style --foreground 196 "Port introuvable pour $ENV_NAME"; return; }

    DOMAIN="${DUCKDNS_SUBDOMAIN}.duckdns.org"
    CADDYFILE="/etc/caddy/Caddyfile"

    [ -f "$CADDYFILE" ] && sudo cp "$CADDYFILE" "${CADDYFILE}.backup.$(date +%s)" 2>/dev/null

    gum spin --spinner dot --title "Génération du Caddyfile..." -- sleep 0.5

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
                gum style --foreground 46 "  ✓ /${env} → localhost:${env_port}"
                [ "$env" = "$ENV_NAME" ] && SELECTED_INCLUDED=true
            fi
        done <<< "$ALL_ENVS"
    fi

    if [ "$SELECTED_INCLUDED" = "false" ]; then
        ROUTES="${ROUTES}    reverse_proxy /${ENV_NAME}* localhost:${PORT}"$'\n'
        gum style --foreground 46 "  ✓ /${ENV_NAME} → localhost:${PORT} (sélectionné)"
    fi

    sudo tee "$CADDYFILE" > /dev/null << EOF
${DOMAIN} {
${ROUTES}    encode gzip
}
EOF

    log INFO "Caddyfile generated for $DOMAIN"

    if sudo systemctl reload caddy; then
        echo ""
        gum style --bold --foreground 46 "🎉 URLs publiées :"
        if [ -n "$ALL_ENVS" ]; then
            while IFS= read -r env; do
                [ -z "$env" ] && continue
                local env_s=$(get_pm2_status "$env")
                local env_p=$(get_port_from_pm2 "$env")
                [ "$env_s" = "online" ] && [ -n "$env_p" ] && gum style --foreground 81 "  https://$DOMAIN/$env"
            done <<< "$ALL_ENVS"
        fi
        if ! echo "$ALL_ENVS" | grep -q "^${ENV_NAME}$" || [ "$(get_pm2_status "$ENV_NAME")" != "online" ]; then
            gum style --foreground 81 "  https://$DOMAIN/$ENV_NAME"
        fi
    else
        gum style --foreground 196 "❌ Échec du rechargement Caddy"
        gum style --foreground 214 "Vérifie : sudo journalctl -u caddy -n 50"
    fi
}

# ── Health Check ─────────────────────────────────────────────────────────────

menu_health() {
    gum_header "Health Check"
    echo ""
    health_check_all verbose
    echo ""

    local choice
    choice=$(gum_menu "Action ?" \
        "🔧 Auto-fix les problèmes connus" \
        "← Retour") || return

    case "$choice" in
        *"Auto-fix"*)
            echo ""
            auto_fix_known_issues
            echo ""
            gum style --bold "État mis à jour :"
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
        gum_header "ShipFlow DevServer" "Development Environment"
        print_status_bar
        echo ""

        CHOICE=$(show_main_menu)
        [ -z "$CHOICE" ] && continue

        case $CHOICE in
            1) show_dashboard ;;
            s) show_shipflow_menu ;;
            2) menu_deploy ;;
            3)
                ENV_NAME=$(select_environment "Choisis un environnement à redémarrer")
                [ -n "$ENV_NAME" ] && { log INFO "Menu: restarting $ENV_NAME"; env_restart "$ENV_NAME"; }
                ;;
            4)
                ENV_NAME=$(select_environment "Choisis un environnement à arrêter")
                [ -n "$ENV_NAME" ] && { log INFO "Menu: stopping $ENV_NAME"; env_stop "$ENV_NAME"; gum style --foreground 46 "✅ $ENV_NAME arrêté"; }
                ;;
            5)
                gum style --foreground 214 --bold "⚠️  ATTENTION : Suppression définitive !"
                echo ""
                ENV_NAME=$(select_environment "Choisis un environnement à supprimer")
                if [ -n "$ENV_NAME" ]; then
                    PROJECT_DIR=$(resolve_project_path "$ENV_NAME")
                    echo ""
                    gum style --foreground 196 "Tu vas supprimer :"
                    gum style "  Environnement : $ENV_NAME"
                    gum style "  Répertoire    : $PROJECT_DIR"

                    if [ -d "$PROJECT_DIR" ]; then
                        local git_warnings
                        git_warnings=$(env_check_git_safety "$PROJECT_DIR" 2>&1)
                        if [ $? -ne 0 ]; then
                            echo ""
                            gum style --foreground 196 "Travail non sauvegardé détecté :"
                            echo "$git_warnings"
                        fi
                    fi

                    echo ""
                    if gum_confirm_fr "Confirmer la suppression ?"; then
                        log INFO "Menu: removing environment $ENV_NAME"
                        env_remove "$ENV_NAME" --force
                        gum style --foreground 46 "✅ Environnement supprimé"
                    else
                        gum style --foreground 81 "Annulé — rien n'a été supprimé"
                    fi
                fi
                ;;
            6) batch_start_all ;;
            7) batch_stop_all ;;
            8) batch_restart_all ;;
            9) menu_advanced ;;
            m) show_mobile_guide ;;
            h) menu_health ;;
            x) gum style --foreground 46 "👋 À bientôt !"; exit 0 ;;
        esac

        gum_pause
    done
}

main
