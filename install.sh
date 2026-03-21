#!/bin/bash

# Script d'installation ShipFlow — DOIT être lancé en root (sudo ./install.sh)
# Installe les paquets système puis configure TOUS les utilisateurs

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}          ${YELLOW}ShipFlow Installation${NC}             ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# Fonction helper
success() {
    echo -e "${GREEN}✅${NC} $1"
}

error() {
    echo -e "${RED}❌${NC} $1"
}

info() {
    echo -e "${BLUE}ℹ️${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

# Root check — système packages need root, no silent elevation
if [ "$EUID" -ne 0 ]; then
    echo ""
    echo -e "${RED}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                                                          ║${NC}"
    echo -e "${RED}║   ⛔  CE SCRIPT DOIT ÊTRE LANCÉ EN ROOT !  ⛔           ║${NC}"
    echo -e "${RED}║                                                          ║${NC}"
    echo -e "${RED}║   L'installation des paquets système (Node.js, PM2,      ║${NC}"
    echo -e "${RED}║   Flox, Caddy, etc.) nécessite les droits root.          ║${NC}"
    echo -e "${RED}║                                                          ║${NC}"
    echo -e "${RED}║   Relancez avec :                                        ║${NC}"
    echo -e "${RED}║     ${YELLOW}sudo ./install.sh${RED}                                    ║${NC}"
    echo -e "${RED}║                                                          ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    exit 1
fi

# Remember who invoked sudo so we configure their account too
INVOKING_USER="${SUDO_USER:-}"

echo -e "${BLUE}🔍 Vérification des dépendances...${NC}"
echo ""

# 1. Installer Node.js (pour PM2)
if command -v node >/dev/null 2>&1; then
    NODE_VERSION=$(node --version)
    success "Node.js déjà installé: $NODE_VERSION"
else
    info "Installation de Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
    apt-get install -y nodejs
    
    if command -v node >/dev/null 2>&1; then
        success "Node.js installé: $(node --version)"
    else
        error "Échec de l'installation de Node.js"
        exit 1
    fi
fi

echo ""

# 2. Installer PM2
if command -v pm2 >/dev/null 2>&1; then
    PM2_VERSION=$(pm2 --version)
    success "PM2 déjà installé: $PM2_VERSION"
else
    info "Installation de PM2..."
    npm config set prefix /usr/local
    npm install -g pm2
    hash -r 2>/dev/null

    if command -v pm2 >/dev/null 2>&1; then
        success "PM2 installé: $(pm2 --version)"
    else
        error "Échec de l'installation de PM2"
        exit 1
    fi
fi

echo ""

# 3. Configurer PM2 pour démarrer au boot
info "Configuration de PM2 pour démarrage automatique..."
pm2 startup systemd -u root --hp /root >/dev/null 2>&1
success "PM2 configuré pour démarrer automatiquement"

echo ""

# 4. Installer Flox
if command -v flox >/dev/null 2>&1; then
    FLOX_VERSION=$(flox --version 2>&1 | head -n1)
    success "Flox déjà installé: $FLOX_VERSION"
else
    info "Installation de Flox..."
    ARCH=$(uname -m)
    FLOX_VERSION="1.8.1"
    
    # Télécharger et installer le package Flox selon l'architecture
    cd /tmp
    if [ "$ARCH" = "aarch64" ]; then
        FLOX_DEB="flox-${FLOX_VERSION}.aarch64-linux.deb"
    else
        FLOX_DEB="flox-${FLOX_VERSION}.x86_64-linux.deb"
    fi
    
    curl -L -o "$FLOX_DEB" "https://downloads.flox.dev/by-env/stable/deb/$FLOX_DEB"
    dpkg -i "$FLOX_DEB"
    rm -f "$FLOX_DEB"
    
    if command -v flox >/dev/null 2>&1; then
        success "Flox installé: $(flox --version)"
    else
        error "Échec de l'installation de Flox"
        warning "Installation manuelle requise: https://flox.dev/docs/install-flox/"
    fi
fi

echo ""

# 5. Installer les outils système nécessaires
info "Vérification des outils système..."

TOOLS_TO_CHECK=("git" "curl" "python3" "ss" "jq" "fuser")
MISSING_TOOLS=()

for tool in "${TOOLS_TO_CHECK[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        success "$tool installé"
    else
        MISSING_TOOLS+=("$tool")
    fi
done

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    info "Installation des outils manquants: ${MISSING_TOOLS[*]}"
    apt-get update >/dev/null 2>&1
    for tool in "${MISSING_TOOLS[@]}"; do
        case $tool in
            "ss")
                apt-get install -y iproute2
                ;;
            "jq")
                apt-get install -y jq
                ;;
            "fuser")
                apt-get install -y psmisc
                ;;
            *)
                apt-get install -y "$tool"
                ;;
        esac
    done
    success "Outils système installés"
fi

echo ""

# 6. Vérifier/Installer GitHub CLI
if command -v gh >/dev/null 2>&1; then
    GH_VERSION=$(gh --version | head -n1)
    success "GitHub CLI déjà installé: $GH_VERSION"
else
    info "Installation de GitHub CLI..."
    # Try apt repo first, fallback to direct .deb download
    gh_installed=false
    if type -p curl >/dev/null; then
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
        chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        apt-get update -qq 2>/dev/null && apt-get install -y gh 2>/dev/null && gh_installed=true
    fi
    # Fallback: direct .deb download (handles GPG key issues)
    if [ "$gh_installed" != "true" ]; then
        info "Fallback: telechargement direct du .deb..."
        gh_arch="amd64"
        [ "$(uname -m)" = "aarch64" ] && gh_arch="arm64"
        gh_version=""
        gh_version=$(curl -s https://api.github.com/repos/cli/cli/releases/latest | jq -r '.tag_name' 2>/dev/null || echo "v2.67.0")
        curl -fsSL "https://github.com/cli/cli/releases/download/${gh_version}/gh_${gh_version#v}_linux_${gh_arch}.deb" -o /tmp/gh.deb 2>/dev/null
        dpkg -i /tmp/gh.deb 2>/dev/null || true
        rm -f /tmp/gh.deb
    fi
    
    if command -v gh >/dev/null 2>&1; then
        success "GitHub CLI installé: $(gh --version | head -n1)"
    else
        error "Échec de l'installation de GitHub CLI"
    fi
fi

echo ""

# 7. Installer PyYAML pour la gestion des fichiers compose
info "Installation de PyYAML..."
if python3 -c "import yaml" 2>/dev/null; then
    success "PyYAML déjà installé"
else
    apt-get install -y python3-pip >/dev/null 2>&1
    pip3 install pyyaml >/dev/null 2>&1
    success "PyYAML installé"
fi

echo ""

# 8. Installer Caddy (pour publication web)
if command -v caddy >/dev/null 2>&1; then
    CADDY_VERSION=$(caddy version | head -n1)
    success "Caddy déjà installé: $CADDY_VERSION"
else
    info "Installation de Caddy..."
    apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl >/dev/null 2>&1
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list > /dev/null
    apt-get update >/dev/null 2>&1
    apt-get install -y caddy >/dev/null 2>&1
    
    if command -v caddy >/dev/null 2>&1; then
        success "Caddy installé: $(caddy version | head -n1)"
    else
        error "Échec de l'installation de Caddy"
        warning "Installation manuelle requise: https://caddyserver.com/docs/install"
    fi
fi

echo ""

# 9. Créer le répertoire de configuration
DOKPLOY_DIR="/etc/dokploy/compose"
if [ ! -d "$DOKPLOY_DIR" ]; then
    info "Création du répertoire de configuration..."
    mkdir -p "$DOKPLOY_DIR"
    success "Répertoire créé: $DOKPLOY_DIR"
else
    success "Répertoire de configuration existe: $DOKPLOY_DIR"
fi

# ──────────────────────────────────────────────────────────────
# Per-user setup: Claude Code, skills, aliases, data
# Runs for root + ALL regular users in /home/
# ──────────────────────────────────────────────────────────────

SHIPFLOW_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# StatusLine — pointer vers le script ShipFlow
configure_statusline() {
    local target_home="$1"
    local settings_file="$target_home/.claude/settings.json"
    mkdir -p "$target_home/.claude"
    if [ ! -f "$settings_file" ]; then
        echo '{}' > "$settings_file"
    fi
    if command -v jq >/dev/null 2>&1; then
        jq --arg cmd "bash $SHIPFLOW_DIR/.claude/statusline-starship.sh" \
            '.statusLine = {"type": "command", "command": $cmd}' \
            "$settings_file" > "${settings_file}.tmp" \
            && mv "${settings_file}.tmp" "$settings_file"
    fi
}

# Configure skills symlinks for a user
configure_skills() {
    local target_home="$1"
    if [ -d "$SHIPFLOW_DIR/.claude/skills" ]; then
        mkdir -p "$target_home/.claude/skills"
        for skill_dir in "$SHIPFLOW_DIR/.claude/skills"/*/; do
            local skill_name
            skill_name=$(basename "$skill_dir")
            if [ ! -e "$target_home/.claude/skills/$skill_name" ]; then
                ln -s "$skill_dir" "$target_home/.claude/skills/$skill_name"
            fi
        done
    fi
}

# Configure aliases in bashrc
configure_aliases() {
    local bashrc="$1/.bashrc"
    [ -f "$bashrc" ] || return 0
    if ! grep -q "alias shipflow=" "$bashrc" 2>/dev/null; then
        cat >> "$bashrc" << ALIASES

# ShipFlow
alias shipflow='$SHIPFLOW_DIR/shipflow.sh'
alias sf='$SHIPFLOW_DIR/shipflow.sh'
ALIASES
    fi
}

# Create shipflow_data for a user
configure_data() {
    local data_dir="$1/shipflow_data"
    if [ ! -d "$data_dir" ]; then
        mkdir -p "$data_dir"
        echo "# Tasks" > "$data_dir/TASKS.md"
        echo "# Audit Log" > "$data_dir/AUDIT_LOG.md"
        echo "# Projects" > "$data_dir/PROJECTS.md"
    fi
}

# Full per-user setup
setup_user() {
    local user_home="$1"
    local username="$2"

    configure_statusline "$user_home"
    configure_skills "$user_home"
    configure_aliases "$user_home"
    configure_data "$user_home"

    # Fix ownership — everything we created must belong to the user
    if [ "$username" != "root" ]; then
        chown -R "$username:$username" "$user_home/.claude" 2>/dev/null || true
        chown -R "$username:$username" "$user_home/shipflow_data" 2>/dev/null || true
    fi

    echo -e "  ${GREEN}✅ Utilisateur configuré :${NC} $username"
}

echo ""
echo -e "${BLUE}👥 Configuration par utilisateur...${NC}"

# Configure root
setup_user "$HOME" "root"

# Configure ALL regular users in /home/
for user_home in /home/*/; do
    [ -d "$user_home" ] || continue
    username=$(basename "$user_home")
    # Skip if not a real user (no passwd entry)
    id "$username" &>/dev/null || continue
    setup_user "$user_home" "$username"
done

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${NC}          ${YELLOW}Installation terminée !${NC}              ${CYAN}║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${BLUE}📝 Prochaines étapes :${NC}"
echo ""
echo -e "1. ${YELLOW}Authentification GitHub${NC} (si pas déjà fait) :"
echo -e "   ${CYAN}gh auth login${NC}"
echo ""
echo -e "2. ${YELLOW}Lancer ShipFlow${NC} :"
echo -e "   ${CYAN}shipflow${NC}  ou  ${CYAN}sf${NC}"
echo ""

# Résumé des installations
echo -e "${BLUE}🎯 Résumé :${NC}"
echo -e "  • Node.js: $(command -v node >/dev/null 2>&1 && echo '✅' || echo '❌')"
echo -e "  • PM2: $(command -v pm2 >/dev/null 2>&1 && echo '✅' || echo '❌')"
echo -e "  • Flox: $(command -v flox >/dev/null 2>&1 && echo '✅' || echo '⚠️ Installation manuelle requise')"
echo -e "  • GitHub CLI: $(command -v gh >/dev/null 2>&1 && echo '✅' || echo '❌')"
echo -e "  • Caddy: $(command -v caddy >/dev/null 2>&1 && echo '✅' || echo '⚠️ Installation manuelle requise')"
echo -e "  • Python3: $(command -v python3 >/dev/null 2>&1 && echo '✅' || echo '❌')"
echo -e "  • PyYAML: $(python3 -c 'import yaml' 2>/dev/null && echo '✅' || echo '❌')"
echo -e "  • Git: $(command -v git >/dev/null 2>&1 && echo '✅' || echo '❌')"
echo -e "  • jq: $(command -v jq >/dev/null 2>&1 && echo '✅ (2-5x faster JSON)' || echo '❌')"
echo -e "  • fuser: $(command -v fuser >/dev/null 2>&1 && echo '✅ (port cleanup)' || echo '❌')"
echo ""

success "Installation complète pour tous les utilisateurs !"
