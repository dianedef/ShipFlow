---
artifact: product_context
metadata_schema_version: "1.0"
artifact_version: "0.2.0"
project: "shipflow"
created: "2026-04-26"
updated: "2026-04-26"
status: draft
source_skill: manual
scope: product
owner: "unknown"
confidence: medium
risk_level: medium
target_user: "solo founders and autonomous technical builders using AI agents on real product work"
user_problem: "lost context, weak agent handoffs, repeated re-explanation, silent ambiguity, and incomplete verification across delivery work"
desired_outcomes: "faster orientation, stronger handoffs, explicit task contracts, cleaner verification, and simpler launch/publish/maintain loops"
non_goals: "mass-market beginner education, generic project management, general-purpose PaaS positioning, or replacing engineering judgment with autonomous automation"
security_impact: yes
docs_impact: yes
evidence:
  - "Repo artifacts strongly emphasize context routing, specs, readiness, verification, audits, and environment operations"
linked_artifacts:
  - "BUSINESS.md"
  - "ARCHITECTURE.md"
  - "GUIDELINES.md"
depends_on:
  - artifact: "BUSINESS.md"
    artifact_version: "0.2.0"
    required_status: "draft"
supersedes: []
next_review: "2026-05-26"
next_step: "/sf-docs audit PRODUCT.md"
---

# Product Context

## Target User

- A solo founder who already ships code and feels the pain of context loss, unreliable prompts, and weak handoffs.
- An autonomous builder who wants AI help without downgrading execution standards.

## Problem

- Fresh agent threads repeatedly pay a context reconstruction tax.
- The main pain is not only slow coding. It is lost context and weak handoffs between the founder and the agents.
- Product intent, business assumptions, docs, and code changes drift apart easily.
- Technical checks alone do not prove that user-facing behavior or workflow integrity still holds.

## Desired Outcomes

- A fresh agent can find the right context quickly.
- A founder can hand work to an agent with less ambiguity and less re-explanation.
- Non-trivial work is shaped before coding through explicit contracts.
- Success and failure behavior are made observable and testable.
- Verification catches contract drift instead of just syntax or lint errors.

## Core Workflows

- Explore -> Spec -> Ready -> Start -> Verify -> End.
- Fix-first path for bounded bugs.
- Docs and metadata path for keeping context and decision artifacts consistent.
- Server environment lifecycle path for deploy, restart, publish, and health management.

## Scope In

- Workflow governance for AI-assisted engineering work.
- Context routing and artifact-based execution.
- Server-hosted environment management for developer workflows.
- A unified operating model between AI delivery and server environment management.

## Scope Out

- General-purpose product management suite.
- Beginner no-code workflow tooling.
- Broad cloud hosting abstraction for every deployment model.
- Generic platform-manager positioning without a strong agent-workflow angle.

## Success Signals

- Reduced need to re-explain the same repo facts in fresh threads.
- Less context loss and fewer failed handoffs in real agent-assisted delivery work.
- Specs and docs become usable contracts rather than passive notes.
- Workflow-critical changes are less likely to ship with silent success, silent failure, or stale docs.

## Risks

- The product can become too broad if the CLI and workflow framework are not presented as one coherent operating model.
- The tool can be mistaken for “just a PM2 server script with helpers” if the AI framing layer is underexplained.
- The tool can be mistaken for “just a prompting method” if the environment-delivery layer is underexplained.
- Documentation volume can grow faster than its clarity if doc roles are not kept exclusive.
