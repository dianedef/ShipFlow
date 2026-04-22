# ShipFlow

ShipFlow is a server-first development environment manager built around Flox, PM2, Caddy, and SSH tunnels.

It has two layers:
- a CLI for managing project environments on a server
- a skill system for structured coding workflows, audits, documentation, and shipping

## What ShipFlow Does

### Server environment management

- deploy and run projects under isolated Flox environments
- manage long-running processes with PM2
- assign and persist project ports
- expose apps through Caddy and DuckDNS
- support local access through SSH tunnel tooling

### Structured AI workflows

- task tracking and session lifecycle
- spec-driven implementation flow
- verification and remediation loops
- audits across code, design, copy, SEO, GTM, deps, perf, and translation
- documentation and research workflows

## Core Docs

- [CLAUDE.md](./CLAUDE.md) — repository constraints and coding guidance
- [shipflow-spec-driven-workflow.md](./shipflow-spec-driven-workflow.md) — ShipFlow V3 workflow for `sf-explore`, `sf-spec`, `sf-ready`, `sf-start`, `sf-verify`, and `sf-end`
- [ECOSYSTEM-AND-PORTS.md](./ECOSYSTEM-AND-PORTS.md) — persistent PM2 ecosystem files and port management
- [local/README.md](./local/README.md) — local tunnel setup
- [tools/codebase-mcp/README.md](./tools/codebase-mcp/README.md) — local MCP server for codebase context management
- [archive/README.md](./archive/README.md) — historical docs and old reports

## Installation

```bash
# Via the bootstrap dotfiles flow
curl -fsSL https://raw.githubusercontent.com/dianedef/dotfiles/main/bootstrap.sh | bash

# Or manually
cd ~/ShipFlow
sudo ./install.sh
```

## Usage

```bash
sf
shipflow
```

Typical CLI actions:
- dashboard and PM2 status
- deploy, restart, stop, remove environments
- publish apps with public HTTPS URLs
- health checks and crash loop detection

## Skill Workflow

Bug-first entrypoint:

```text
sf-fix -> (direct fix path or spec-first path)
```

If the bug is local and clear, `sf-fix` routes to direct execution.
If the bug is ambiguous or non-trivial, `sf-fix` routes to `sf-spec -> sf-ready -> sf-start`.

For non-trivial coding work, the default workflow is:

```text
sf-explore -> sf-spec -> sf-ready -> sf-start -> implementation -> sf-verify -> sf-end
```

Fast path for a small, explicit fix:

```text
sf-start -> implementation -> sf-verify -> sf-end
```

Bug fast path (recommended mental model):

```text
sf-fix -> sf-start -> implementation -> sf-verify -> sf-end
```

The key rule is simple:
- reduce ambiguity before coding
- verify against the contract before closing

## Repository Layout

```text
ShipFlow/
├── shipflow.sh
├── lib.sh
├── config.sh
├── install.sh
├── README.md
├── CLAUDE.md
├── CHANGELOG.md
├── shipflow-spec-driven-workflow.md
├── ECOSYSTEM-AND-PORTS.md
├── archive/
├── skills/
├── local/
├── research/
├── tools/
└── injectors/
```

## Main Components

- `shipflow.sh` — interactive CLI entry point
- `lib.sh` — shared shell library for ports, PM2, Flox, Caddy, validation, and tracking
- `config.sh` — central configuration
- `install.sh` — installation and machine setup
- `skills/` — ShipFlow skill library
- `local/` — local machine tunnel scripts and setup docs
- `tools/codebase-mcp/` — optional MCP server for token-efficient codebase work
- `research/` — research notes and evaluations
- `archive/` — historical plans, reports, and obsolete documents kept for reference

## Key Features

- isolated per-project environments with Flox
- PM2-managed app lifecycle
- persistent `ecosystem.config.cjs` generation
- automatic port allocation and collision avoidance
- public HTTPS publishing through Caddy and DuckDNS
- local tunnel workflows
- spec-driven AI-assisted development workflows

## Tech Stack

- Flox
- PM2
- Caddy
- DuckDNS
- Bash
- SSH / autossh

## Status

The root of this repository is intentionally kept for living documentation.

Older plans, implementation summaries, and one-off reports have been moved into [`archive/`](./archive/).
