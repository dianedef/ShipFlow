# ShipFlow CLI

Menu interactif pour gerer vos environnements de developpement avec Flox + PM2 + Caddy.

## Installation

```bash
# Via le bootstrap dotfiles (recommande — installe tout)
curl -fsSL https://raw.githubusercontent.com/dianedef/dotfiles/main/bootstrap.sh | bash

# Ou manuellement
cd ~/ShipFlow
sudo ./install.sh
```

## Utilisation

```bash
sf          # Lance le menu interactif (alias)
shipflow    # Idem
```

**Commandes du menu :**
- Dashboard — statut PM2
- Deploy / Restart / Stop / Remove — gestion des environnements
- Publish — URLs publiques HTTPS (Caddy + DuckDNS)
- Health Check — detection crash loops

## Architecture

```
ShipFlow/
├── shipflow.sh             # Point d'entree principal (menu)
├── lib.sh                  # Bibliotheque partagee (ports, PM2, Flox, Caddy)
├── config.sh               # Configuration (130+ variables)
├── install.sh              # Installation dependances (PM2, Flox, Caddy, etc.)
├── .claude/skills/         # 39 skills Claude Code (shipflow-*, openspec-*)
├── .claude/statusline-starship.sh  # Status bar Claude Code
├── local/                  # Tunnels SSH (machine locale)
│   ├── dev-tunnel.sh       # Creation auto des tunnels
│   ├── local.sh            # Menu gestion tunnels
│   └── install.sh          # Installation locale
└── injectors/
    └── web-inspector.js    # Inspecteur visuel navigateur
```

## Fonctionnalites

- Allocation intelligente des ports (3000-3100, anti-collision)
- Fichiers `ecosystem.config.cjs` persistants avec PORT
- Detection framework auto (Astro, Vite, Next.js, Nuxt, Expo)
- Environnements Flox isoles
- Publication web HTTPS (Caddy + DuckDNS gratuit)
- Cache PM2 (32x plus rapide)
- 39 skills Claude Code integres

## Technologies

- **Flox** — environnements isoles
- **PM2** — gestion de processus
- **Caddy** — reverse proxy + HTTPS auto
- **DuckDNS** — DNS dynamique gratuit
- **SSH/autossh** — tunnels dev local
