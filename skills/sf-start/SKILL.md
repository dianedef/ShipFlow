---
name: sf-start
description: Execute a task end-to-end from kickoff to implementation. Use spec-first guardrails when the scope is non-trivial.
argument-hint: <task description or TASKS.md item>
---

## Context

- Current directory: !`pwd`
- Current date: !`date '+%Y-%m-%d'`
- Project name: !`basename $(pwd)`
- Git branch: !`git branch --show-current 2>/dev/null || echo "unknown"`
- Git status: !`git status --short 2>/dev/null || echo "Not a git repo"`
- Master TASKS.md: !`cat /home/claude/shipflow_data/TASKS.md 2>/dev/null || echo "No master TASKS.md"`
- Local TASKS.md (if exists): !`cat TASKS.md 2>/dev/null || echo "No local TASKS.md"`
- Available specs: !`find docs specs -maxdepth 2 -type f -name "*.md" 2>/dev/null | sort | head -40`

## Your task

`sf-start` is an execution skill. It should implement, not only plan.

Goal: execute from an explicit contract in one pass, not rediscover intent while coding.

The contract starts from the user story. Implementation must preserve the promised user outcome, not only complete technical tasks.

Routing rule:
- **Small/local/clear** task: execute directly
- **Non-trivial or ambiguous** task: require a ready spec before implementation

### Step 1 — Identify the task

If `$ARGUMENTS` is provided, use it as the task description.

If `$ARGUMENTS` is empty, look at TASKS.md from context and use **AskUserQuestion**:
- Question: "Quelle tâche veux-tu commencer ?"
- `multiSelect: false`
- Options: top 5-7 uncompleted tasks from TASKS.md (highest priority first), each with its priority emoji as prefix
- Add a final option: "Autre — je décris ma tâche"

### Step 2 — Scope triage

Classify as `direct` or `spec-first`.

Signals for `spec-first`:
- multiple files or subsystems
- unclear expected behavior
- auth/data/migration/API contract implications
- likely edge cases or cross-domain impact

If any unresolved question could change permissions, data exposure, tenant boundaries, money movement, destructive behavior, external side effects, or workflow integrity, force `spec-first`.

If the triage is borderline (signals are mixed), use **AskUserQuestion**:
- Question: "Le scope est ambigu. Quelle stratégie ?"
- `multiSelect: false`
- Options:
  - **Exécuter directement (recommandé si local)** — "Tu avances maintenant avec scope limité"
  - **Passer par spec-first** — "Tu formalises avant d'implémenter"
  - **Clarifier d'abord** — "Tu fais un court détour d'exploration avant de coder"

If user picks **Clarifier d'abord**, route to `/sf-explore [task]` and stop execution.

If `spec-first` and no matching `Status: ready` spec exists:
- stop execution
- route to:
  1. `/sf-spec [task]`
  2. `/sf-ready [task/spec]`
  3. `/sf-start [task]`

### Step 3 — Load context, derive execution contract, and track task (silent)

- Si la tâche est `spec-first`, préférer une exécution sur contexte frais :
  - lancer un subagent sans historique si c'est possible
  - sinon demander explicitement à l'utilisateur d'ouvrir un nouveau thread avant de continuer
- If a `ready` spec exists, read it fully before touching code
- Derive an execution contract:
  - spec metadata: `metadata_schema_version`, `artifact_version`, `status`, `updated`
  - minimal behavior contract: what the feature accepts/triggers, what it produces/returns, what happens on failure, and the easiest edge case to miss
  - success behavior: observable success result, expected system effect, and proof to validate
  - error behavior: expected response for invalid input, missing permissions/resources, partial failure, retry/rollback/timeout, and forbidden bad states
  - dependency/version context from `depends_on`
  - user story and promised outcome
  - target files
  - read-first files / entry points
  - invariants and non-goals
  - linked systems / consequences to revalidate
  - documentation surfaces to update or explicitly leave unchanged
  - abuse cases / misuse cases and security constraints when present
  - validation commands and stop conditions
- For every business or technical contract listed in `depends_on` (`BUSINESS.md`, `BRANDING.md`, `GUIDELINES.md`, docs API, architecture, pricing, personas, GTM docs, onboarding/support docs):
  - preserve the referenced `artifact_version` and `required_status` in the execution context
  - read the current file when it is present and its version/status may affect the implementation
  - stop and route back to `/sf-ready` if the current document is `stale`, has a newer incompatible `artifact_version`, or contradicts the spec
  - ask the user or reroute if a missing version would change product promise, permissions, pricing, data behavior, API contract, architecture, security posture, or documentation obligations
- If a direct task has no spec but clearly depends on business or technical docs, record a mini-contract with the document names and current versions/status when available.
- If a direct task has no spec, still form a lightweight mini-contract before editing:
  - one behavioral paragraph: accepted input/trigger, output/result, failure behavior, likely missed edge case
  - success behavior: what must be observable when the change works
  - error behavior: what must happen when expected failure modes occur
  - one short adversarial pass: what is missing, what assumption could break, what edge case is not covered
  - one implementation plan: files/areas to touch and validation to run
  - explicit constraints: packages to use or avoid, existing patterns to follow, data flow, abstractions to avoid, scope limits
  - keep this silent unless it reveals ambiguity that changes product behavior, security, data handling, destructive behavior, or external side effects
- If a `ready` spec exists, also identify the likely execution topology:
  - implementation groups
  - files owned by each group
  - shared files that must stay with the main agent
  - groups that can run in parallel vs groups that must wait
- Read `/home/claude/shipflow/skills/sf-model/references/model-routing.md` before choosing execution model(s)
- If the spec is missing any of the above, stop and route back to `/sf-ready` or `/sf-spec`
- If a non-trivial spec lacks `Minimal Behavior Contract`, `Success Behavior`, `Error Behavior`, implementation approach, adversarial gaps, or explicit constraints, stop and route back to `/sf-ready` or `/sf-spec`
- If the spec is missing required metadata/version context, treat it as a contract gap. Continue only for trivial/local work where the missing metadata cannot change product or security semantics; otherwise route back to `/sf-ready`.
- If the implementation path would satisfy the listed tasks but miss the user story outcome, stop and reroute instead of coding the wrong thing efficiently
- If the remaining ambiguity is product-meaningful or security-meaningful, ask the user instead of "picking a sensible default"
- Read only the files needed to implement plus the linked systems that must be sanity-checked
- Include associated tests or entry points
- Update task tracking to `🔄 in progress` in master TASKS.md
- Update local TASKS.md too when present
- Treat the TASKS content loaded in Context as informational only.
- Immediately before editing either TASKS file, re-read it from disk and use that version as authoritative.
- Apply a minimal targeted edit (status row / task line only), never a whole-file rewrite from stale context.
- If the expected row or section moved, re-read once and recompute; if it is still ambiguous, stop and ask the user.

### Step 4 — Model routing

Choose the execution model before coding.

Use `/home/claude/shipflow/skills/sf-model/references/model-routing.md` as the shared source of truth.

Pick:
- `Primary execution model`
- `Reasoning effort`
- optional `Per-group model overrides`

Prefer simple defaults:
- `gpt-5.4-mini` for small, clear, local work
- `gpt-5.3-codex` for long agentic implementation and multi-file coding work
- `gpt-5.4` for ambiguity, architecture, or high error cost
- `gpt-5.3-codex-spark` for highly local fast-iteration work, especially UI-focused deltas

Only use per-group overrides when:
- the task is materially non-trivial
- groups have clearly different profiles
- the gain in speed, cost, or reliability is obvious

If the task is simple, keep one model and continue.

### Step 5 — Choose execution topology

Decide whether to run in `single-agent` or `multi-agent`.

Prefer `single-agent` when:
- the task is small or medium
- most changes converge on the same 1-3 files
- the work is tightly coupled and sequencing matters more than parallelism
- the integration overhead would outweigh the gain

Prefer `multi-agent` when:
- the spec is `ready` and materially non-trivial
- there are multiple implementation groups with mostly disjoint write sets
- backend, frontend, tests, docs, ops, or migrations can be separated cleanly
- the main agent can keep ownership of integration and final validation

Guardrails for `multi-agent`:
- create at most 2-4 groups
- each group must have explicit file ownership
- do not assign the same writable file to multiple subagents
- keep cross-cutting files, final wiring, and conflict resolution with the main agent
- if boundaries are fuzzy, fall back to `single-agent`

If `multi-agent` is chosen:
- define each group with:
  - goal
  - owned files
  - model
  - reasoning effort
  - read-only context files
  - validations to run
  - dependency order if not parallel-safe
- launch subagents only for groups that materially advance the task without overlapping writes
- keep working locally on integration-critical or shared-file work while subagents run
- integrate returned changes, then run focused validation across the combined result

### Step 6 — Implement

Execute the changes directly.

Implementation constraints:
- implement the user story outcome, not a narrow proxy metric
- make successful actions observable to the user/operator unless the contract explicitly justifies silent success and provides another verification path
- make failures observable or recoverable unless the contract explicitly justifies silent failure and provides a recovery/observation path
- follow existing project conventions
- keep the change inside the declared task scope
- preserve the invariants and linked systems named in the execution contract
- preserve the spec's dependency/version context while coding; do not silently implement against a newer or stale `BUSINESS.md`, `BRANDING.md`, `GUIDELINES.md`, API doc, or architecture doc than the spec names
- keep documentation coherent with feature behavior: update docs, README, guides, examples, FAQ, onboarding, pricing or support copy when the contract names them
- preserve abuse-case and security constraints named in the spec
- avoid speculative refactors unrelated to the task
- if a new side effect appears outside the contract, stop and reroute instead of improvising
- if scope expands materially, stop and reroute to spec-first
- if a missing answer changes authorization, failure handling, visibility, retention, tenant isolation, or retry behavior, stop and ask

### Step 7 — Quick validation

Run focused validation relevant to the modified area:
- include at least one validation that the main user story outcome is actually delivered
- validate `Success Behavior` and `Error Behavior` when the contract names them; if an error path cannot be exercised, state the gap explicitly
- include a sanity check that success is not silent and failure is not silent unless explicitly justified by the contract
- targeted tests if available
- quick lint/type check for touched modules when practical
- syntax check for touched shell scripts if relevant
- run the validation commands named in the spec when present
- include at least one sanity check on each linked system / consumer impacted by the change
- include a documentation coherence check when the user-visible feature behavior changed
- include abuse-case / security sanity checks when the contract names them

If checks fail, report clearly and include next repair action.

### Step 8 — Report

Output one concise execution report:

```text
## Started and Implemented: [task name]

Mode: [direct / spec-first]
Primary execution model: [model]
Reasoning effort: [low / medium / high / xhigh]
Execution topology: [single-agent / multi-agent]
Contract: [ready spec path / direct mini-contract]
Fresh context: [used fresh subagent / user asked to open new thread / not necessary]
User story: [one-line promise]

Agent groups:
- [group] — [model] — [owned files or scope]

Files changed:
- [file] — [what changed]

Validation:
- [check] -> [pass/fail]

Linked checks:
- [area] -> [pass/fail]

Documentation coherence:
- [docs updated / not impacted because ... / gap]

Metadata / version context:
- Spec: [metadata_schema_version / artifact_version / status]
- Depends on: [artifact@version status, ...]
- Drift: [none / outdated dependency / unknown version / rerouted]

User story validation:
- [main promised outcome] -> [pass/fail]

Success / error behavior:
- Success behavior -> [pass/fail/not checked]
- Error behavior -> [pass/fail/not checked]
- Observability -> [success visible / error visible / justified silent / gap]

Security / abuse checks:
- [check] -> [pass/fail]

Next step:
- /sf-verify [task]
```

### Rules

- Implement by default (do not stop at planning)
- Do NOT commit or push
- Do NOT update CHANGELOG.md (handled by end/ship flow)
- For non-trivial tasks, block without a `ready` spec
- If request and spec conflict, surface the conflict before coding
- Do not silently compensate for a weak spec during implementation; reroute instead
- Do not silently drop or reinterpret `depends_on` metadata from the spec; version context must survive from read -> implementation -> report -> sf-verify
- Do not reduce a user story to UI behavior only when the contract implies workflow, permission, data, or system guarantees
- Do not ship a feature behavior change while leaving known docs, examples, onboarding, pricing, FAQ or support copy stale
- When ambiguity affects security or product semantics, ask the user before proceeding
- If a fresh context is required and cannot be created inside the current environment, ask the user to create it before proceeding
- Use subagents only when write ownership is clear and the coordination overhead is justified
- Reuse the `sf-model` routing reference rather than inventing ad hoc model choices
