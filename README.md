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
- fast current-thread recap when a session becomes hard to follow
- spec-driven implementation flow
- verification and remediation loops
- audits across code, design, copy, SEO, GTM, deps, perf, and translation
- documentation and research workflows

## Core Docs

- [AGENT.md](./AGENT.md) — agent entrypoint: where to look first depending on the task
- [CONTEXT.md](./CONTEXT.md) — compact operational map of the project, hotspots, invariants, and edit routing
- [CONTEXT-FUNCTION-TREE.md](./CONTEXT-FUNCTION-TREE.md) — grouped function tree for the main shell scripts
- [CLAUDE.md](./CLAUDE.md) — repository constraints and coding guidance
- [shipflow-spec-driven-workflow.md](./shipflow-spec-driven-workflow.md) — ShipFlow V3 workflow for `sf-explore`, `sf-spec`, `sf-ready`, `sf-start`, `sf-verify`, and `sf-end`
- [shipflow-metadata-migration-guide.md](./shipflow-metadata-migration-guide.md) — how to adopt ShipFlow metadata and versioning in an existing project
- [ECOSYSTEM-AND-PORTS.md](./ECOSYSTEM-AND-PORTS.md) — persistent PM2 ecosystem files and port management
- [local/README.md](./local/README.md) — local tunnel setup
- [tools/codebase-mcp/README.md](./tools/codebase-mcp/README.md) — local MCP server for codebase context management
- [archive/README.md](./archive/README.md) — historical docs and old reports

## Installation

```bash
# Via the bootstrap dotfiles flow
curl -fsSL https://raw.githubusercontent.com/dianedef/dotfiles/main/bootstrap.sh | bash

# Or manually
cd ~/shipflow
sudo ./install.sh
```

## Codex TUI Defaults

`install.sh` configures Codex for each user (`root` + `/home/*`) by writing `~/.codex/config.toml` with:

```toml
tui.status_line = ["model-with-reasoning", "current-dir", "context-used"]
tui.terminal_title = ["spinner", "thread", "project"]
```

The install is idempotent and keeps user config outside the ShipFlow-managed block.

If your Codex version does not expose one of these items (for example `thread`), adjust interactively in Codex:

```text
/statusline
/title
```

Unlike Claude Code, Codex does not expose a custom shell-command status line renderer.

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

ShipFlow is now optimized for **one-pass execution**.

That means:
- the framing skill must carry the missing context before coding starts
- a `ready` spec must be executable by a fresh agent without reading the chat history
- agent prompts should already include linked systems, downstream consequences, and explicit validation targets
- if a fresh context is needed and cannot be created automatically, the skill must ask the user to open a new thread
- “prompt and correct” is a fallback for bounded drift, not the normal operating mode

Bug-first entrypoint:

```text
sf-fix -> (fix directly or spec-first path)
```

Fast thread recap:

```text
sf-resume -> 3-5 bullets, task statuses, close/keep-open verdict
```

Optional model-selection step:

```text
sf-model -> choose model / reasoning / fallbacks before execution
```

If the bug is local and clear, `sf-fix` fixes it directly, then verifies.
If the bug is ambiguous or non-trivial, `sf-fix` routes to `sf-spec -> sf-ready -> sf-start`.

For non-trivial coding work, the default workflow is:

```text
sf-explore -> sf-spec -> sf-ready -> sf-start -> sf-verify -> sf-end
```

Fast path for a small, explicit fix:

```text
sf-start -> sf-verify -> sf-end
```

Bug fast path (recommended mental model):

```text
sf-fix -> sf-verify -> sf-end
```

The key rule is simple:
- reduce ambiguity before coding
- verify against the contract before closing

## Context Layer

ShipFlow now uses a dedicated context layer for fast agent onboarding.

- `AGENT.md` is the routing file: it tells an agent where to look first.
- `CONTEXT.md` is the operational map: entry points, core flows, hotspots, invariants, and where to edit what.
- `CONTEXT-FUNCTION-TREE.md` is a specialized companion for large procedural files such as `lib.sh`.

This split is intentional. `CLAUDE.md` should hold constraints and critical rules, not the full project map. The context files exist to reduce repetitive discovery work at the start of a fresh thread without pretending to replace the code.

## ShipFlow as a Professional Work Framework

ShipFlow is not just a collection of prompts or isolated skills. It is a work framework built around explicit decision contracts.

The core idea is that serious product work depends on more than code. A feature is shaped by user stories, business positioning, brand promises, security assumptions, documentation, pricing, onboarding, support, and operational constraints. ShipFlow treats these as first-class project artifacts rather than informal chat context.

### Decision contracts

ShipFlow artifacts are contracts that later skills can verify against:

- A spec is an implementation contract: it defines scope, invariants, linked systems, risks, acceptance criteria, and documentation impact.
- A business document is a product-decision contract: it defines the audience, value proposition, market, promise, pricing assumptions, and proof level.
- A brand document is a communication contract: it defines tone, trust posture, vocabulary, visual consistency, and claims that must not drift.
- An audit report is an evidence contract: it records what was checked, what remains uncertain, and what should happen next.
- A review or verification report is a closure contract: it distinguishes implemented, verified, assumed, partial, and unsafe-to-close work.

This is what makes ShipFlow different from ad hoc AI assistance: every stage produces or consumes structured artifacts that can be reviewed, updated, and challenged.

### Metadata and traceability

ShipFlow internal artifacts use YAML frontmatter metadata. The goal is not bureaucracy; the goal is traceability.

Common metadata fields include:

```yaml
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: "[project name]"
created: "2026-04-25"
updated: "2026-04-25"
status: draft
source_skill: sf-spec
scope: feature
owner: "[user/team]"
user_story: "En tant que..., je veux..., afin de..."
confidence: medium
risk_level: medium
security_impact: unknown
docs_impact: yes
linked_systems: []
depends_on:
  - artifact: BUSINESS.md
    artifact_version: "1.0.0"
    required_status: reviewed
evidence: []
next_step: "/sf-ready [title]"
```

ShipFlow provides skill-aligned artifact templates in `templates/artifacts/` and a dependency-free linter:

```bash
tools/shipflow_metadata_lint.py
```

For legacy projects, use the migration playbook in [`shipflow-metadata-migration-guide.md`](./shipflow-metadata-migration-guide.md) before normalizing old docs.

By default it checks `specs/`, `docs/`, `AGENT.md`, `CONTEXT.md`, `CONTEXT-FUNCTION-TREE.md`, `BUSINESS.md`, `BRANDING.md`, and `GUIDELINES.md`. Pass explicit files or folders to validate a narrower scope.

For internal ShipFlow files, this schema is mandatory for the active official artifact set. That set now includes `AGENT.md`, `CONTEXT.md`, and promoted specialized context docs such as `CONTEXT-FUNCTION-TREE.md`. For legacy project adoption, the default migration scope is intentionally narrower: active context docs when they exist, `BUSINESS.md`, `BRANDING.md`, `GUIDELINES.md`, and `specs/*.md`. Historical ad hoc docs can stay out of scope until they are promoted into the active ShipFlow workflow.

Operational tracking files are intentionally excluded from the mandatory artifact schema: `TASKS.md`, `AUDIT_LOG.md`, and `PROJECTS.md` are trackers/registries, not decision contracts. Keep them fast to edit. If a task entry contains a durable decision, spec, or business rule, extract that durable content into a dedicated artifact with metadata instead of adding frontmatter to the tracker itself.

Location rule:
- `shipflow_data` is the control plane for shared tracking and registry files.
- Each project repository is the canonical home for its own `BUSINESS.md`, `BRANDING.md`, `GUIDELINES.md`, specs, research, and decision records.
- Do not duplicate or symlink project decision-contract documents into `shipflow_data` by default. `shipflow_data` may reference that the contracts exist, but should not host the canonical copy of per-project business or technical documentation.

Application runtime content keeps the schema required by the application. Blog posts, Astro content collections, MDX pages, and app-rendered docs must keep their framework-compatible frontmatter. ShipFlow can enrich compatible fields, but it must not break the app parser.

### Business documentation is technical documentation

ShipFlow treats `BUSINESS.md`, `BRANDING.md`, `GUIDELINES.md`, personas, pricing notes, positioning, and GTM documents as technical artifacts because they drive technical decisions.

If `BUSINESS.md` says the product serves solo founders, then copy, onboarding, pricing, feature scope, support, and prioritization should be evaluated against that audience. If `BRANDING.md` says trust and clarity are core values, then UI copy, error messages, claims, screenshots, and documentation must preserve that trust. If a pricing or positioning document is stale, a technically correct feature can still be strategically wrong.

Business documentation therefore needs the same discipline as code documentation:

- clear status: `draft`, `reviewed`, `stale`, `active`
- confidence level: `high`, `medium`, `low`
- evidence: interviews, user statements, analytics, market research, source URLs, or explicit assumptions
- review date and next review date
- linked artifacts: specs, audits, pages, onboarding, pricing, support docs
- artifact version and dependency references, so a spec can say which version of the business contract it was built against
- risk level when the document influences public promises, pricing, security, compliance, or user expectations

The practical rule is simple: if a document influences what the agent will build, audit, ship, or claim publicly, it must be traceable.

ShipFlow uses two version fields:

- `metadata_schema_version` tracks the shape of the ShipFlow metadata itself.
- `artifact_version` tracks the decision content of the document.

This matters when business or technical documentation changes. If a spec was written against `BUSINESS.md` version `1.0.0`, and the business document later moves to `1.1.0` because the target persona or pricing changed, the spec should be rechecked before implementation. Versioning makes drift visible instead of relying on memory.

### Proof over optimism

ShipFlow avoids treating green checks, commits, pushes, or polished copy as proof that work is done.

Skills should distinguish:

- `implemented`: code or content was changed
- `verified`: the intended outcome was checked
- `assumed`: the outcome is plausible but not proven
- `partial`: part of the promise is delivered
- `stale`: an artifact no longer matches the product

This matters for public and expensive products. Security, pricing, data handling, onboarding, docs, and support expectations can fail even when the code builds. ShipFlow makes those gaps visible before they become production risk.

### Documentation coherence

When a feature changes, ShipFlow treats documentation as part of the feature surface.

Relevant docs may include:

- README
- product docs
- API docs
- guides and examples
- FAQ
- onboarding
- pricing
- changelog
- support copy
- screenshots
- public marketing pages

Stale documentation is a product bug when it causes users or operators to misunderstand setup, security, pricing, permissions, API behavior, migration steps, destructive actions, or support expectations.

For medium and large changes, the contract is explicit:
- `sf-spec` defines scope, dependencies, invariants, links, consequences, and execution notes
- `sf-ready` rejects a spec that still depends on hidden assumptions
- `sf-start` executes from that contract instead of rediscovering intent
- `sf-start` now also selects a primary execution model and chooses `single-agent` vs `multi-agent` topology before coding
- `sf-verify` checks the implementation and the linked systems that could regress around it

Success criterion:
- a fresh agent should be able to pick up the task in one pass

Operational rule:
- for non-trivial work, `sf-ready` and `sf-start` are the places where a fresh context may be enforced
- if multiple agents are used, write ownership and final integration responsibility must be explicit

## TASKS vs BACKLOG

Use both files on purpose:

- `TASKS.md` = active, prioritized, executable work
- `BACKLOG.md` = deferred ideas, parking lot, non-committed items

Promotion rule:
- move an item from `BACKLOG.md` to `TASKS.md` only when it is ready to be worked on now (clear enough, prioritized enough, and scoped enough)

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
