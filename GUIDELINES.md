---
artifact: technical_guidelines
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: "shipflow"
created: "2026-04-26"
updated: "2026-04-26"
status: draft
source_skill: manual
scope: guidelines
owner: "unknown"
confidence: high
risk_level: medium
linked_systems:
  - "shipflow.sh"
  - "lib.sh"
  - "config.sh"
  - "local/"
  - "skills/"
  - "templates/artifacts/"
security_impact: yes
docs_impact: yes
evidence:
  - "CLAUDE.md and current repo structure define active shell, workflow, and metadata conventions"
depends_on: []
supersedes: []
next_review: "2026-05-26"
next_step: "/sf-docs audit GUIDELINES.md"
---

# Technical Guidelines

## Stack

- Bash-first orchestration for CLI and operational flows.
- Flox for runtime isolation.
- PM2 for managed process execution.
- Caddy plus DuckDNS for public exposure.
- Markdown artifacts plus skills for workflow governance.

## Critical Rules

- Invalidate PM2 cache after PM2 state changes.
- Validate project paths before using them.
- Prefer idempotent operations over check-then-act races.
- Do not treat generated runtime config as primary source of truth.
- Keep documentation contracts versioned when they guide implementation or audits.

## Preferred Patterns

- Use focused context docs instead of overloading one mega-doc.
- Use specs and verification for non-trivial work.
- Keep doc roles exclusive: route, context, business, product, GTM, architecture, brand, guidelines.
- Prefer explicit stop conditions over silent assumption repair.

## Anti-Patterns

- Silent success or silent failure in user-facing flows unless explicitly justified.
- Business or product claims without evidence.
- Metadata migration that rewrites content body unnecessarily.
- Using trackers as if they were decision contracts.

## Validation Expectations

- Technical checks are necessary but not sufficient.
- User-facing success and error behavior should be observable or explicitly justified.
- Docs that affect product understanding must be checked when behavior changes.

## Documentation Expectations

- `AGENT.md` routes to the right context.
- `CONTEXT.md` maps the repo operationally.
- Specialized context docs stay narrow.
- Business, product, GTM, brand, architecture, and guidelines docs should each keep an exclusive role.
