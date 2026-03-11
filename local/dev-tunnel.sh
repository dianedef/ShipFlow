#!/bin/bash
# dev-tunnel.sh - Crée des tunnels SSH automatiques pour tous les ports PM2 actifs

set -e

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../config.sh" ]; then
    source "$SCRIPT_DIR/../config.sh"
fi

# Configuration directory
CONFIG_DIR="$HOME/.shipflow"
CURRENT_CONNECTION_FILE="$CONFIG_DIR/current_connection"

# Load saved connection or use default
if [ -f "$CURRENT_CONNECTION_FILE" ]; then
    REMOTE_HOST=$(cat "$CURRENT_CONNECTION_FILE")
else
    REMOTE_HOST="${REMOTE_HOST:-$SHIPFLOW_SSH_REMOTE_HOST}"
    REMOTE_HOST="${REMOTE_HOST:-hetzner}"
fi

SSH_CONFIG="$HOME/.ssh/config"

# Validate remote host (can include user@host format)
if [[ ! "$REMOTE_HOST" =~ ^[a-zA-Z0-9._@-]+$ ]]; then
    echo -e "${RED}✗ Invalid REMOTE_HOST: $REMOTE_HOST${NC}"
    echo -e "${YELLOW}  Format: user@host or ssh-alias${NC}"
    exit 1
fi

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚇 Dev Tunnel Manager${NC}"
echo ""

# Resolve the server-side library from ShipFlow install paths.
fetch_server_session_info() {
    ssh -o ConnectTimeout=5 "$REMOTE_HOST" "bash -lc '
        for lib_path in \
            \"\$HOME/ShipFlow/lib.sh\" \
            \"/home/claude/ShipFlow/lib.sh\" \
            \"/root/ShipFlow/lib.sh\"
        do
            if [ -f \"\$lib_path\" ]; then
                source \"\$lib_path\" 2>/dev/null
                get_session_info_for_ssh 2>/dev/null
                exit 0
            fi
        done

        echo SESSION_NOT_FOUND
    '" 2>/dev/null
}

# Retrieve and display server session identity
echo -e "${BLUE}🔐 Retrieving server session identity...${NC}"
SESSION_INFO=$(fetch_server_session_info)

if echo "$SESSION_INFO" | grep -q "SESSION_START"; then
    # Parse session info
    SESSION_USER=$(echo "$SESSION_INFO" | grep "^USER:" | cut -d: -f2)
    SESSION_HOST=$(echo "$SESSION_INFO" | grep "^HOST:" | cut -d: -f2)
    SESSION_CODE=$(echo "$SESSION_INFO" | grep "^CODE:" | cut -d: -f2)
    HASH_ART=$(echo "$SESSION_INFO" | sed -n '/---HASH_ART_START---/,/---HASH_ART_END---/p' | grep -v "^---")

    echo -e "             ${MAGENTA}Server Session Identity${NC}"
    echo -e "${CYAN}──────────────────────────────────────────────────${NC}"

    # Display hash art
    while IFS= read -r line; do
        echo -e "              ${BLUE}$line${NC}"
    done <<< "$HASH_ART"

    echo -e "        ${GREEN}$SESSION_USER@$SESSION_HOST${NC}    ${YELLOW}$SESSION_CODE${NC}"
    echo -e "${CYAN}──────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "${GREEN}✓ Verify this pattern matches the server menu${NC}"
    echo ""
elif echo "$SESSION_INFO" | grep -q "SESSION_DISABLED"; then
    echo -e "${YELLOW}⚠ Session identity is disabled on the server${NC}"
    echo ""
elif echo "$SESSION_INFO" | grep -q "SESSION_NOT_FOUND"; then
    echo -e "${YELLOW}⚠ ShipFlow not found on server (session identity unavailable)${NC}"
    echo ""
else
    echo -e "${YELLOW}⚠ Could not retrieve session identity${NC}"
    echo ""
fi

# Vérifier que autossh est installé
if ! command -v autossh &> /dev/null; then
    echo -e "${RED}✗ autossh n'est pas installé${NC}"
    echo -e "${YELLOW}  Installation: brew install autossh (macOS) ou apt install autossh (Linux)${NC}"
    exit 1
fi

# Vérifier la connexion SSH (test rapide)
# On accepte user@host ou alias SSH
SSH_HOST_ONLY="${REMOTE_HOST#*@}"  # Remove user@ if present
if [[ "$REMOTE_HOST" != *"@"* ]]; then
    # C'est un alias, vérifier dans la config SSH
    if ! grep -q "Host $REMOTE_HOST" "$SSH_CONFIG" 2>/dev/null; then
        echo -e "${YELLOW}⚠ Configuration SSH manquante pour '$REMOTE_HOST'${NC}"
        echo -e "${YELLOW}  Ajoutez la configuration dans $SSH_CONFIG ou utilisez user@host${NC}"
    fi
fi
echo -e "${BLUE}🔌 Connexion: ${GREEN}$REMOTE_HOST${NC}"
echo ""

# Récupérer les ports actifs depuis PM2 sur le serveur distant
echo -e "${BLUE}📡 Récupération des ports actifs depuis PM2...${NC}"

PORTS=$(ssh "$REMOTE_HOST" "pm2 jlist 2>/dev/null | python3 -c \"
import sys, json
try:
    apps = json.load(sys.stdin)
    ports = []
    for app in apps:
        if app['pm2_env']['status'] == 'online':
            env = app['pm2_env'].get('env', {})
            port = env.get('PORT') or env.get('port')
            if port:
                name = app['name']
                ports.append(f'{port}:{name}')
    print(','.join(ports))
except:
    pass
\"" 2>/dev/null)

if [ -z "$PORTS" ]; then
    echo -e "${RED}✗ Aucun port trouvé ou PM2 n'est pas accessible${NC}"
    echo -e "${YELLOW}  Vérifiez que PM2 tourne sur le serveur distant${NC}"
    exit 1
fi

# Detect port collisions before creating tunnels
declare -A PORT_MAP
COLLISION=false
IFS=',' read -ra CHECK_ARRAY <<< "$PORTS"
for port_info in "${CHECK_ARRAY[@]}"; do
    IFS=':' read -r port name <<< "$port_info"
    if [ -n "${PORT_MAP[$port]+x}" ]; then
        echo -e "${RED}⚠ COLLISION: port $port utilisé par ${PORT_MAP[$port]} ET $name${NC}"
        COLLISION=true
    fi
    PORT_MAP[$port]="$name"
done
if [ "$COLLISION" = true ]; then
    echo -e "${YELLOW}⚠ Des collisions de ports ont été détectées!${NC}"
    echo -e "${YELLOW}  Relancez les apps en conflit sur le serveur avec: env_start \"app_name\"${NC}"
fi

# Arrêter les tunnels existants
echo -e "${BLUE}🛑 Arrêt des tunnels existants...${NC}"
pkill -f "autossh.*$REMOTE_HOST" 2>/dev/null || true
sleep 1

# Créer les tunnels
echo -e "${GREEN}✓ Création des tunnels SSH${NC}"
echo ""

IFS=',' read -ra PORT_ARRAY <<< "$PORTS"
for port_info in "${PORT_ARRAY[@]}"; do
    IFS=':' read -r port name <<< "$port_info"
    
    echo -e "${GREEN}  ✓ localhost:${port} → ${name}${NC}"
    
    # Créer le tunnel avec autossh (maintient la connexion)
    autossh -M 0 -f -N \
        -o "ServerAliveInterval=${SHIPFLOW_SSH_KEEPALIVE_INTERVAL:-30}" \
        -o "ServerAliveCountMax=${SHIPFLOW_SSH_KEEPALIVE_MAX:-3}" \
        -o "ExitOnForwardFailure=yes" \
        -L "${port}:localhost:${port}" \
        "$REMOTE_HOST" 2>/dev/null
done

echo ""
echo -e "${GREEN}✓ Tunnels actifs !${NC}"
echo ""
echo -e "${BLUE}📋 URLs disponibles :${NC}"

for port_info in "${PORT_ARRAY[@]}"; do
    IFS=':' read -r port name <<< "$port_info"
    echo -e "  • http://localhost:${port} ${YELLOW}(${name})${NC}"
done

echo ""
echo -e "${YELLOW}💡 Les tunnels restent actifs en arrière-plan${NC}"
echo -e "${YELLOW}   Pour les arrêter : pkill -f 'autossh.*$REMOTE_HOST'${NC}"
