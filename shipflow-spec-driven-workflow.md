# ShipFlow V3: Spec-Driven Workflow

## Summary

ShipFlow V3 shifts iteration upstream.

Bug intake entrypoint:

```text
sf-fix -> route to direct path or spec-first path
```

For non-trivial work, the default flow is:

```text
sf-explore -> sf-spec -> sf-ready -> sf-start -> implementation -> sf-verify -> sf-end
```

For small, explicit, local fixes, the fast path remains:

```text
sf-start -> implementation -> sf-verify -> sf-end
```

The goal is not to remove iteration. The goal is to move ambiguity reduction before coding, then let verification close the loop when implementation or spec drift appears.

## Core Principles

- `sf-explore` is for ambiguity reduction, not implementation.
- `sf-spec` produces an implementation contract, not loose notes.
- `sf-ready` enforces a real Definition of Ready before non-trivial execution.
- `sf-start` begins execution from a ready contract instead of rediscovering intent.
- `sf-verify` checks against the spec first, then quality and risks, and can now remediate limited gaps.
- `sf-end` closes the task against the delivered scope, not only against the diff.

## Workflow by Stage

### 0. `sf-fix` (bug intake)

Use `sf-fix` when your intent is "fix a bug" rather than "start a session."

It performs a short triage and routes the bug:
- local and clear -> direct fix path
- ambiguous or non-trivial -> spec-first path

Typical routed outcomes:
- direct: `sf-start -> implementation -> sf-verify -> sf-end`
- spec-first: `sf-spec -> sf-ready -> sf-start -> implementation -> sf-verify -> sf-end`

### 1. `sf-explore`

Use `sf-explore` when the problem is still fuzzy:
- feature idea not fully shaped
- risky refactor
- bug with unclear root cause
- cross-cutting behavior change

Expected outcome:
- clearer problem framing
- surfaced constraints
- identified unknowns
- decision to either stop, keep exploring, or move to `sf-spec`

### 2. `sf-spec`

Use `sf-spec` to create the implementation contract for non-trivial work.

The spec is expected to be autonomous and structured. It must include:
- `Title`
- `Status`
- `Problem`
- `Solution`
- `Scope In`
- `Scope Out`
- `Constraints`
- `Invariants`
- `Edge Cases`
- `Implementation Tasks`
- `Acceptance Criteria`
- `Test Strategy`
- `Risks`
- `Open Questions`

Status lifecycle:
- `draft`
- `reviewed`
- `ready`
- `implemented`
- `closed`

Rules:
- no `TBD`
- no blocking open questions
- every implementation task must name a file and an action
- tasks must be ordered by dependency

`sf-spec` is the canonical entry point for initial framing. It should be the default for medium+ work.

### 3. `sf-ready`

Use `sf-ready` as the guardrail before first implementation on non-trivial work.

It verifies that the spec is actually executable:
- structure is complete
- ambiguity is low enough
- task ordering is coherent
- acceptance criteria are testable
- open questions are resolved

If the spec passes, `sf-ready` promotes it to `Status: ready`.

If not, it returns a concrete `not ready` verdict and pushes the work back toward spec refinement.

### 4. `sf-start`

`sf-start` is the execution kickoff, not a discovery phase.

Behavior:
- accepts direct execution for small, explicit, local fixes
- requires a `ready` spec for non-trivial work
- blocks if the spec is missing, incomplete, or contradictory
- loads only the execution-relevant files and produces a short ordered plan

The key rule:
- if the work is ambiguous or multi-file, `sf-start` should not invent the missing intent

### 5. Implementation

Once execution begins, the implementation should follow the spec contract:
- same scope
- same ordering assumptions
- same acceptance criteria
- same constraints and invariants

If the implementation reveals a small missing delta, the loop does not automatically restart from scratch.

### 6. `sf-verify`

`sf-verify` is now both a verifier and a controlled remediation orchestrator.

It verifies in this order:
1. spec compliance
2. traceability from spec to code/tests
3. code quality, dependencies, and risks
4. workflow next step

It classifies the primary cause into one of these buckets:
- `specified but not implemented`
- `spec incomplete or ambiguous`
- `implemented but not specified`
- `technical failure only`
- `missing contract`
- `complete and ready`

Then it decides what to do.

#### When `sf-verify` remediates directly

If the spec is sound and the gap is only implementation:
- it can complete the missing work
- rerun the relevant checks
- mark traceability entries as `fixed during verify`

If the delta becomes too large, it should stop and route back to `sf-start`.

#### When `sf-verify` updates the spec

If the implementation exposed a small framing hole:
- it can ask the minimum required clarification questions
- translate the answers into a mini spec delta
- update the existing spec first
- then resume implementation and re-verify

This is not a replacement for `sf-spec`.
It is a local repair path for late-discovered, bounded ambiguity.

#### When `sf-verify` reroutes

Typical routing outcomes:
- `specified but not implemented` -> remediate now, or `/sf-start` if the delta is too large
- `spec incomplete or ambiguous` -> mini-spec correction, then continue; if global drift, return to `/sf-spec`
- `implemented but not specified` -> clarify whether to keep or remove the extra behavior, then update spec or code
- `technical failure only` -> fix technical breakage and rerun verify
- `complete and ready` -> `/sf-end`

Every `sf-verify` report should end with:
- `Primary cause`
- `Action taken`
- `Next step`
- `Reason`

### 7. `sf-end`

`sf-end` closes the task against the spec and the delivered behavior.

It should:
- mark completed tasks as done
- keep partial work explicit
- record drift from the spec when it happened
- move the spec to `implemented` or `closed`
- prepare the next priorities cleanly

## Decision Rules

Use this rule of thumb:

- bug intake -> `sf-fix`
- unclear problem -> `sf-explore`
- non-trivial scoped work -> `sf-spec`
- spec candidate before first implementation -> `sf-ready`
- ready execution kickoff -> `sf-start`
- verify and possibly close the loop -> `sf-verify`
- wrap up delivered work -> `sf-end`

Shortcut rules:

- if the issue is already specified and simply unfinished, do not rewrite the whole spec
- if the issue reveals real contract ambiguity, update the spec before more code
- if the missing delta is local and obvious, `sf-verify` may absorb it
- if the missing delta changes architecture or scope, go back to `sf-spec`

## Example Flows

### Small local bug fix

```text
sf-fix -> sf-start -> implementation -> sf-verify -> sf-end
```

### New feature with ambiguity

```text
sf-explore -> sf-spec -> sf-ready -> sf-start -> implementation -> sf-verify -> sf-end
```

### Feature mostly implemented but incomplete

```text
sf-spec -> sf-ready -> sf-start -> implementation -> sf-verify
                                           |
                                           v
                          remediate missing specified work
                                           |
                                           v
                                        sf-end
```

### Feature reveals missing edge case late

```text
sf-spec -> sf-ready -> sf-start -> implementation -> sf-verify
                                           |
                                           v
                              mini spec delta + remediation
                                           |
                                           v
                                        sf-end
```

## What Changed from Earlier Flow

Earlier, the workflow tended to rediscover intent during `sf-start` or after failed implementation.

ShipFlow V3 changes that:
- `sf-start` is no longer the place where the problem gets clarified
- `sf-spec` is stricter and contract-oriented
- `sf-ready` is a real gate, not a nice-to-have
- `sf-verify` no longer stops at diagnosis; it can classify, clarify, remediate, and reroute
- the system now has an explicit path for incomplete implementation without automatically restarting the full cycle

## Practical Guidance

If a feature is reported as incomplete:
- use `sf-start` again only when the spec is still valid and the missing work is already specified
- use `sf-spec` again when the contract itself is insufficient
- let `sf-verify` absorb the delta when the missing work is local and safe to repair in-place

The important distinction is not "is the feature incomplete?"

The real distinction is:
- incomplete implementation
- incomplete contract
- implementation/spec drift

That distinction now drives the workflow.
