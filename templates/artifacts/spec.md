---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: "[project name]"
created: "YYYY-MM-DD"
updated: "YYYY-MM-DD"
status: draft
source_skill: sf-spec
scope: feature
owner: "[owner]"
user_story: "En tant que..., je veux..., afin de..."
confidence: medium
risk_level: medium
security_impact: unknown
docs_impact: yes
linked_systems: []
depends_on:
  - artifact: "[BUSINESS.md|BRANDING.md|GUIDELINES.md|docs/path.md]"
    artifact_version: "unknown"
    required_status: "unknown"
supersedes: []
evidence:
  - "[code path, doc, user decision, or investigation note]"
next_step: "/sf-ready [title]"
---

# Spec: [title]

## Title

[Clear, concise feature or fix title.]

## Status

draft

## User Story

En tant que [actor], je veux [capability], afin de [value].

## Minimal Behavior Contract

[One non-technical paragraph: what the feature accepts or triggers, what it produces or returns, what happens on failure, and the easiest edge case to miss.]

## Success Behavior

- Preconditions: [state or inputs required for success.]
- Trigger: [user/system action.]
- User/operator result: [observable result.]
- System effect: [data persisted, status updated, event sent, file created, job launched, or `None, because ...`]
- Success proof: [test, sanity check, log, final state, or `None, because ...`]
- Silent success: [not allowed / justified because ... and verifiable by ...]

## Error Behavior

- Expected failures: [invalid input, missing permission, absent resource, external dependency error, timeout, duplicate, concurrency, stale state, or `None, because ...`]
- User/operator response: [message, status, fallback, or `None, because ...`]
- System effect: [no mutation, rollback, pending state, retry, compensation, log, alert, or `None, because ...`]
- Must never happen: [partial inconsistent data, expanded permission, unconfirmed deletion, logged secret, repeated side effect, or `None, because ...`]
- Silent failure: [not allowed / justified because ... and recoverable by ...]

## Problem

[What user, operator, or business problem is being solved.]

## Solution

[1-2 sentences describing the chosen approach.]

## Scope In

- [Included behavior, file area, or workflow.]

## Scope Out

- [Explicit non-goal or excluded follow-up.]

## Constraints

- [Technical, product, security, timing, or compatibility constraint.]

## Dependencies

- Runtime: [library, service, API, config, data prerequisite, or `None, because ...`]
- Document contracts: [versioned docs from `depends_on`, or `None, because ...`]
- Metadata gaps: [unknown versions, stale contracts, missing frontmatter, or `None`]

## Invariants

- [Business, data, permission, or UX invariant that must remain true.]

## Links & Consequences

- Upstream systems: [callers, producers, docs, config, or `None, because ...`]
- Downstream systems: [consumers, routes, jobs, analytics, support, or `None, because ...`]
- Cross-cutting checks: [auth, data, i18n, a11y, SEO, perf, deploy, ops, or `None, because ...`]

## Documentation Coherence

- [Docs, README, guides, FAQ, onboarding, pricing, changelog, examples, support surfaces to align, or `None, because ...`.]

## Edge Cases

- [Happy-path boundary, error state, invalid state, retry, concurrency, stale data, or abuse case.]

## Implementation Tasks

- [ ] Task 1: [Clear action]
  - File: `[path/to/file.ext]`
  - Action: [Specific change to make]
  - User story link: [Which part of the user promise this serves]
  - Depends on: [Task number, foundation, or `None`]
  - Validate with: `[exact command, test, or sanity check]`
  - Notes: [Implementation detail or `None`]

## Acceptance Criteria

- [ ] AC 1: Given [precondition], when [action], then [observable result].

## Test Strategy

- Unit: [tests or `None, because ...`]
- Integration: [tests or `None, because ...`]
- Manual: [sanity checks or `None, because ...`]

## Risks

- Security impact: [none, because ... / yes, mitigated by ... / unknown, because ...]
- Product/data/performance risk: [risk and mitigation, or `None, because ...`]

## Execution Notes

- Read first: `[files/docs to read before implementation]`
- Validate with: `[commands/checks]`
- Stop conditions: [ambiguity, failing invariant, stale dependency, security concern, or `None`]

## Open Questions

None
