---
name: sf-fix
description: Bug-first entrypoint. Triage a bug quickly, decide fix path (direct vs spec-driven), then start the right workflow.
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

`sf-fix` is the bug-oriented alias that decides whether the issue should:
- go through a direct local fix path, or
- go through spec-first path before implementation.

### Routing rule

- **Direct fix path** (small/local/clear):
  - single area or small surface
  - expected behavior already obvious
  - low ambiguity
  - no migration/auth/data contract change
- **Spec-first path** (non-trivial/ambiguous):
  - multi-file or cross-system impact
  - unclear expected behavior
  - edge cases likely
  - migration/data/auth/perf implications

### Step 1 — Capture the bug

If `$ARGUMENTS` is provided, use it.
If empty, ask: "Quel bug veux-tu corriger ?"

Collect only what is needed:
- observed behavior
- expected behavior
- where it happens
- available repro steps or error message

### Step 2 — Quick technical triage (silent)

Read only the 3-5 most relevant files and classify the bug as `direct` or `spec-first`.

### Step 3 — Choose the path

If `direct`:
- run the same startup behavior as `sf-start` for this bug task
- mark task `in progress` in TASKS tracking
- produce a short execution plan

If `spec-first`:
- do not start coding
- explicitly route to:
  1. `/sf-spec [bug title]`
  2. `/sf-ready [bug title or spec path]`
  3. `/sf-start [bug title]`

### Step 4 — Report

Output:

```text
## Bug Intake: [title]

Classification: [direct / spec-first]
Reason: [short rationale]

Next step:
- [exact command to run]

Scope estimate: [small / medium / large]
```

### Rules

- Prefer direct path for truly small and clear bugs
- Prefer spec-first when ambiguity could create rework
- Never hide uncertainty; route early instead
- Keep triage short and actionable
