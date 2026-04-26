---
name: sf-fix
description: Bug-first entrypoint. Triage a bug quickly, then either fix it directly or route to the spec-driven path.
argument-hint: <bug description, error message, or failing behavior>
---

## Context

- Current directory: !`pwd`
- Current date: !`date '+%Y-%m-%d'`
- Project name: !`basename $(pwd)`
- Git branch: !`git branch --show-current 2>/dev/null || echo "unknown"`
- Git status: !`git status --short 2>/dev/null || echo "Not a git repo"`
- Master TASKS.md: !`cat /home/claude/shipflow_data/TASKS.md 2>/dev/null || echo "No master TASKS.md"`
- Local TASKS.md (if exists): !`cat TASKS.md 2>/dev/null || echo "No local TASKS.md"`

## Your task

Use bug language, not session language.

`sf-fix` is the bug-oriented entrypoint that decides whether the issue should:
- be fixed directly now, or
- go through a spec-first path before implementation.

Goal: close small, clear bugs quickly without breaking the user promise, product coherence, or security posture.

### Routing rule

- **Direct fix path** (small/local/clear):
  - single area or small surface
  - expected behavior already obvious from the bug, product context, or existing code
  - low ambiguity on user-visible outcome
  - no migration/auth/data contract change
  - no material risk to permissions, visibility, workflow integrity, or external side effects
- **Spec-first path** (non-trivial/ambiguous):
  - multi-file or cross-system impact
  - unclear expected behavior
  - edge cases likely
  - migration/data/auth/perf implications
  - ambiguity that could materially change behavior, scope, or security

### Step 1 — Capture the bug

If `$ARGUMENTS` is provided, use it.
If empty, ask: "Quel bug veux-tu corriger ?"

Collect only what is needed:
- observed behavior
- expected behavior
- where it happens
- available repro steps or error message

Always reconstruct the bug as a tiny user story before triage:
- actor
- trigger
- broken behavior
- expected outcome / user value

If the user did not state it explicitly, infer a one-line story and confirm it briefly.

Ask targeted clarification prompts only when the missing answer would materially change:
- visible behavior or scope
- affected actor or permission boundary
- destructive side effects, retries, or failure handling
- data exposure, tenant isolation, or security posture

Prefer decision-forcing questions such as:
- "Quand ce cas arrive, on doit bloquer l'action, la rendre invisible, ou afficher une erreur explicite ?"
- "Le bug concerne tous les utilisateurs connectés, seulement les admins, ou seulement le owner ?"
- "En cas d'échec partiel, on retry, on rollback, ou on laisse l'état en erreur visible ?"

### Step 2 — Quick technical triage (silent)

Read only the 3-5 most relevant files and classify the bug as `direct` or `spec-first`.

Apply the shared Documentation Freshness Gate from `../references/documentation-freshness-gate.md` during triage when the bug may depend on current framework, SDK, service, API, auth/session, build, migration, cache, routing, or integration behavior. Local repo versions and patterns come first; Context7 official docs come next; official web docs are the fallback.

During triage, verify four things before choosing `direct`:
- **User story fit**: the expected fix is clearly tied to the promised user outcome
- **Product coherence**: the intended behavior matches adjacent flows, copy, permissions, and existing conventions
- **Documentation coherence**: the bug fix does not leave docs, FAQ, examples, onboarding, changelog, pricing or support copy describing the old behavior
- **Fresh external docs**: if the fix depends on external documented behavior, current official docs support the chosen path, or the task is rerouted/flagged as `fresh-docs gap` or `fresh-docs conflict`
- **Security impact**: the fix does not rely on UI-only protection or create a gap in auth, authz, validation, or data exposure
- **Blast radius**: linked systems and regressions are still local enough for a direct fix

If the bug touches browser authentication, protected routes, OAuth redirects, Clerk session state, callback handling, or "works in code but fails in browser" behavior:
- prefer using `sf-auth-debug` as the diagnostic layer before or during the fix
- use it to locate the exact failure step instead of inferring the auth break only from static code
- keep `sf-fix` as the router and execution owner; `sf-auth-debug` provides evidence, not a separate workflow

Force `spec-first` if any unresolved point could change:
- who can see/do the action
- what data becomes visible, editable, deletable, or triggerable
- whether the workflow can be bypassed, replayed, or left inconsistent
- whether external systems, billing, notifications, jobs, or automations behave differently

If classification confidence is low (mixed signals), use **AskUserQuestion**:
- Question: "Le scope du bug est borderline. Quelle voie prends-tu ?"
- `multiSelect: false`
- Options:
  - **Corriger directement** — "Tu tentes un fix local immédiat et tu vérifies ensuite"
  - **Passer par spec-first** — "Tu clarifies le contrat avant de coder"
  - **Diagnostic seulement** — "Tu veux un diagnostic + plan sans exécution"

### Step 3 — Choose the path and execute

If `direct`:
- implement the fix directly
- keep scope local to the classified delta
- preserve the user story outcome, not only the failing technical symptom
- preserve product coherence with nearby flows and conventions
- update or flag documentation that describes the fixed behavior when user-facing behavior changes
- preserve security-by-default:
  - do not assume UI visibility is a security control
  - validate untrusted inputs where relevant
  - preserve auth/authz checks and tenant/resource boundaries
  - prevent obvious replay, double-submit, stale-state, or invalid-order issues when relevant
- mark task `in progress` in TASKS tracking
- treat the TASKS snapshots loaded at skill start as informational only
- right before editing any TASKS file, re-read it from disk and use that version as authoritative
- apply a minimal targeted edit to the relevant row only; never rewrite the whole file from stale context
- if the expected row or section moved, re-read once and recompute; if it is still ambiguous, stop and ask the user
- run relevant checks for the changed area
- run at least one user-story sanity check
- include the Documentation Freshness Gate verdict when it was triggered, especially the dependency/version and Context7 or official docs source that influenced the fix
- if the bug involves auth, redirects, protected pages, or session behavior in the browser, run or emulate `sf-auth-debug` logic to reproduce and re-check the broken flow
- run a documentation coherence check when the bug changes visible behavior, API behavior, permissions, pricing, integration behavior, or support expectations
- run at least one quick coherence/security sanity check when the bug touches auth, data, workflow, external effects, or non-trivial state
- run `sf-verify` logic after the fix to confirm closure

If `spec-first`:
- do not code yet
- explicitly route to:
  1. `/sf-spec [bug title]`
  2. `/sf-ready [bug title or spec path]`
  3. `/sf-start [bug title]`

If `diagnostic only`:
- do not code
- if the bug is auth/browser-flow related, prefer `/sf-auth-debug [bug title]`
- otherwise report the suspected root cause and concrete next step command

### Step 4 — Report

Output:

```text
## Bug Intake: [title]

Classification: [direct / spec-first]
Reason: [short rationale]
User story: [actor + expected outcome]
Clarifications asked: [none / short list]
Product coherence: [ok / risk]
Documentation coherence: [ok / risk / not impacted]
Fresh external docs: [checked / not needed / gap / conflict]
Security posture: [ok / risk]
Action taken: [fixed directly / routed]

Next step:
- [exact command to run]

Scope estimate: [small / medium / large]
```

### Rules

- Prefer direct path for truly small and clear bugs
- Prefer spec-first when ambiguity could create rework
- Never hide uncertainty; route early instead
- Keep triage short and actionable
- Ask the user instead of guessing when ambiguity changes product meaning or security posture
- A direct fix must still defend product coherence, not only pass the local repro
- A direct fix that changes feature behavior must align docs or explicitly report the doc gap
- A direct fix must keep or improve security posture; never weaken controls for speed
- If direct-fix verification fails or reveals broader ambiguity, reroute to spec-first
- If the user chooses `diagnostic only`, do not implement
