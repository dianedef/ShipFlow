---
artifact: documentation
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: "shipflow"
created: "2026-04-25"
updated: "2026-04-25"
status: draft
source_skill: manual
scope: "context"
owner: "unknown"
confidence: "high"
risk_level: "medium"
security_impact: "none"
docs_impact: "yes"
linked_systems: ["shipflow.sh", "lib.sh", "config.sh", "install.sh", "local/local.sh", "skills/", "shipflow-spec-driven-workflow.md", "CONTEXT-FUNCTION-TREE.md"]
depends_on: []
supersedes: []
evidence: ["README.md", "CLAUDE.md", function extraction from core shell scripts"]
next_step: "/sf-docs update CONTEXT.md"
---

# CONTEXT

## Purpose

Ce fichier donne la carte operative minimale de ShipFlow. Il sert a gagner du temps au debut d'un nouveau thread et a orienter vers le bon sous-contexte.

## What ShipFlow Is

ShipFlow combine deux couches :

- un gestionnaire d'environnements de dev cote serveur base sur Flox, PM2, Caddy et DuckDNS
- un systeme de skills pour travail spec-first, verification, audit, documentation et shipping

## Entry Points

- `shipflow.sh`: point d'entree du CLI.
- `lib.sh`: coeur des actions, validations, integrations systeme et menus.
- `config.sh`: configuration centralisee et validation.
- `install.sh`: bootstrap serveur et configuration de l'environnement utilisateur.
- `local/local.sh`: UX locale des tunnels SSH.
- `skills/`: workflows AI orientes taches.

## Repo Map

- `shipflow.sh`, `lib.sh`, `config.sh`, `install.sh`: couche serveur/CLI.
- `local/`: outils locaux d'acces a un serveur ShipFlow.
- `skills/`: skills ShipFlow pour exploration, spec, execution, verif, docs, audits.
- `templates/artifacts/`: templates d'artefacts versionnes.
- `tools/shipflow_metadata_lint.py`: linter des frontmatters ShipFlow.
- `shipflow-spec-driven-workflow.md`: doctrine de workflow.
- `shipflow-metadata-migration-guide.md`: doctrine de migration metadata.
- `BUSINESS.md`, `PRODUCT.md`, `BRANDING.md`, `GTM.md`: contrats business, produit et promesse publique.
- `ARCHITECTURE.md`, `GUIDELINES.md`: contrats structurels et techniques.

## Core Flows

### 1. Server CLI Flow

```text
shipflow.sh
  -> source lib.sh
  -> select menu frontend
  -> main()
  -> check_prerequisites()
  -> cleanup_orphan_projects()
  -> run_menu()
  -> action_* handlers
  -> env_start / env_stop / env_restart / env_remove / publish / dashboard
```

### 2. Environment Lifecycle

```text
project path
  -> validate_project_path
  -> detect_project_type
  -> init_flox_env
  -> detect_dev_command
  -> find_available_port
  -> PM2 start/update
  -> invalidate_pm2_cache
  -> dashboard / health / publish
```

### 3. Local Tunnel Flow

```text
local/local.sh
  -> select connection
  -> fetch remote session identity
  -> inspect active remote ports
  -> start_tunnels / stop_tunnels / show_status
```

### 4. Skill Workflow

```text
sf-explore -> sf-spec -> sf-ready -> sf-start -> sf-verify -> sf-end
```

Fast paths existent aussi :

- `sf-fix` pour bug-first
- `sf-start` pour tache petite et claire
- `sf-docs metadata` pour migration frontmatter

## Technical Decisions

- PM2 est la source d'etat d'execution. Le cache PM2 doit etre invalide apres mutation.
- L'allocation de port doit eviter collisions runtime et collisions PM2 cachees.
- Les operations destructives doivent rester idempotentes.
- Les paths projet doivent etre absolus et valides.
- Les docs ShipFlow actives doivent avoir un frontmatter versionne.
- Les trackers operationnels (`TASKS.md`, `AUDIT_LOG.md`, `PROJECTS.md`) ne recoivent pas de frontmatter.
- Les contenus runtime applicatifs gardent leur propre schema de frontmatter.

## Invariants

- Appeler `invalidate_pm2_cache` apres `start`, `stop`, `delete`, `restart` ou tout changement PM2.
- Ne pas parser la structure JS/JSON a coups de grep si une voie fiable existe deja.
- Ne pas editer manuellement des fichiers regeneres comme les configs d'ecosystem runtime.
- Ne pas transformer une passe metadata en rewrite complet de documentation.
- Un succes utilisateur doit etre observable ; un echec doit etre observable ou recuperable, sauf justification explicite.

## Hotspots

- `lib.sh::env_start`: plus gros noeud fonctionnel.
- `lib.sh::show_dashboard`: aggregation d'etat.
- `lib.sh::deploy_github_project`: deploy depuis GitHub.
- `lib.sh::action_publish`: integration Caddy + DuckDNS.
- `local/local.sh::main`: UX locale complete pour tunnels.
- `skills/sf-docs/SKILL.md`: logique de migration metadata et audit documentaire.

## Where To Edit What

- Changer le comportement de lancement d'app : `lib.sh` autour de `env_start`, `detect_project_type`, `detect_dev_command`, `fix_port_config`.
- Changer le dashboard ou la sante : `lib.sh` autour de `show_dashboard`, `health_check_all`, `diagnose_app_errors`.
- Changer la publication web : `lib.sh` autour de `action_publish`.
- Changer les tunnels locaux : `local/local.sh` et `local/dev-tunnel.sh`.
- Changer le workflow d'agent : `skills/` + `shipflow-spec-driven-workflow.md`.
- Changer les regles metadata : `skills/sf-docs/SKILL.md`, `tools/shipflow_metadata_lint.py`, `shipflow-metadata-migration-guide.md`, `templates/artifacts/`.
- Changer le positionnement, l'audience ou le scope produit : `BUSINESS.md`, `PRODUCT.md`, `GTM.md`, `BRANDING.md`.
- Changer la structure technique globale : `ARCHITECTURE.md`, `GUIDELINES.md`, puis `lib.sh` ou les scripts concernes.

## Read First By Task

- CLI principal : `CLAUDE.md`, `CONTEXT-FUNCTION-TREE.md`, `shipflow.sh`, `lib.sh`.
- Install / bootstrap : `install.sh`, `config.sh`, `README.md`.
- Skill / workflow : `README.md`, `shipflow-spec-driven-workflow.md`, puis la skill cible.
- Metadata docs : `shipflow-metadata-migration-guide.md`, `skills/sf-docs/SKILL.md`, `tools/shipflow_metadata_lint.py`.
- Tunnels / acces local : `local/README.md`, `local/local.sh`, `local/dev-tunnel.sh`.
- Produit / business / site : `BUSINESS.md`, `PRODUCT.md`, `BRANDING.md`, `GTM.md`.
- Architecture / conventions : `ARCHITECTURE.md`, `GUIDELINES.md`, `CLAUDE.md`.

## Linked Docs

- [AGENT.md](/home/claude/shipflow/AGENT.md)
- [CLAUDE.md](/home/claude/shipflow/CLAUDE.md)
- [README.md](/home/claude/shipflow/README.md)
- [CONTEXT-FUNCTION-TREE.md](/home/claude/shipflow/CONTEXT-FUNCTION-TREE.md)
- [shipflow-spec-driven-workflow.md](/home/claude/shipflow/shipflow-spec-driven-workflow.md)
- [shipflow-metadata-migration-guide.md](/home/claude/shipflow/shipflow-metadata-migration-guide.md)
- [BUSINESS.md](/home/claude/shipflow/BUSINESS.md)
- [PRODUCT.md](/home/claude/shipflow/PRODUCT.md)
- [BRANDING.md](/home/claude/shipflow/BRANDING.md)
- [GTM.md](/home/claude/shipflow/GTM.md)
- [ARCHITECTURE.md](/home/claude/shipflow/ARCHITECTURE.md)
- [GUIDELINES.md](/home/claude/shipflow/GUIDELINES.md)

## Maintenance Rule

Mettre a jour `CONTEXT.md` quand un changement modifie :

- les entry points reels
- un flux technique majeur
- les hotspots
- un invariant critique
- la destination officielle des docs de contexte
