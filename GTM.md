---
artifact: gtm_context
metadata_schema_version: "1.0"
artifact_version: "0.2.0"
project: "shipflow"
created: "2026-04-26"
updated: "2026-04-26"
status: draft
source_skill: manual
scope: gtm
owner: "unknown"
confidence: medium
risk_level: medium
target_segment: "solo founders and autonomous technical builders evaluating a clearer way to ship with AI agents"
offer: "a unified framework that combines server delivery operations, explicit task contracts, and verification-oriented agent workflows"
channels: "documentation-first discovery, technical content, demos, founder education, and autonomy-oriented positioning"
proof_points: "context routing docs, spec-first workflow, metadata contracts, linter, verification and audit skills, plus concrete server delivery tooling"
security_impact: unknown
docs_impact: yes
evidence:
  - "Current repo demonstrates the mechanics of the framework but not yet validated acquisition or conversion data"
linked_artifacts:
  - "BUSINESS.md"
  - "BRANDING.md"
  - "PRODUCT.md"
depends_on:
  - artifact: "BUSINESS.md"
    artifact_version: "0.2.0"
    required_status: "draft"
  - artifact: "BRANDING.md"
    artifact_version: "0.1.0"
    required_status: "draft"
supersedes: []
next_review: "2026-05-26"
next_step: "/sf-docs audit GTM.md"
---

# GTM Context

## Target Segment

- Solo founders who already feel the pain of weak AI execution loops.
- Autonomous technical users who want stronger delivery discipline rather than generic AI enthusiasm.

## Offer

- ShipFlow should be presented as a unified framework for reliable AI-assisted software delivery and simple server operations.
- The offer is stronger when framed around reduced ambiguity, explicit contracts, better verification, and stronger handoffs, not raw coding speed.

## Positioning

- Not “another coding assistant”.
- Not “just a server CLI with PM2 helpers”.
- Not “just a methodology or a bundle of prompts for agents”.
- Not a general-purpose PaaS or platform manager.
- Best current positioning: a unified framework between AI delivery and server environment management for solo founders.

## Channels

- Technical documentation and examples.
- Content explaining spec-first execution, observability of success/failure, and artifact-based workflow design.
- Demonstrations of fresh-thread onboarding and reduced context rebuild cost.
- Founder-facing content around autonomy, clarity, and shipping without fragile agent loops.

## Conversion Path

- First contact through docs, examples, or technical content.
- Interest through the concrete mechanics: `AGENT.md`, `CONTEXT.md`, specs, verification, lintable metadata.
- Conversion through confidence that the framework improves reliability of real work, not toy demos.
- The buying motion should stay simple and compatible with a solo-founder audience.

## Proof Points

- Dedicated context layer for fresh agents.
- Clear routing toward business, product, GTM, architecture, and guidelines.
- Spec, readiness, start, verify workflow.
- Observable success/error behavior discipline.
- Metadata-linted documentation contracts.
- Audit and verification skills built into the same framework.
- Real server operations tooling in the same operating model.

## Objections

- “This looks heavier than just prompting harder.”
- “Is this a methodology or an actual product?”
- “Is this just a server script plus a few helpers?”
- “Do I need all the docs before I get value?”
- “Is this only for Bash/server-heavy repos?”

## KPIs

- To be defined once there is an explicit site and funnel.
- Early candidate signals: activated repos, repeated use of spec/verify loop, reduction in context-restatement, docs adoption across projects.
- Business model is not defined yet; pricing and revenue KPIs remain open hypotheses.
