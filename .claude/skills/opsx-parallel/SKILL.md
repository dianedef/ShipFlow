---
name: opsx-parallel
description: Coordinator agent — orchestrates parallel implementation of OpenSpec tasks using typed specialist agents in isolated git worktrees. The Intent-style upgrade to /opsx:apply.
disable-model-invocation: true
argument-hint: [change-name] (optional — auto-detects active change)
---

## Context

- Current directory: !`pwd`
- Active changes: !`ls openspec/changes/ 2>/dev/null || echo "no active changes"`
- Git status: !`git status --short 2>/dev/null | head -10`
- Current branch: !`git branch --show-current 2>/dev/null`

## What This Skill Does

This is the **Coordinator Agent** — the orchestrator that replaces serial `/opsx:apply` with parallel specialist agents running in isolated git worktrees.

Instead of one agent doing everything sequentially:
```
OLD: Task 1 → Task 2 → Task 3 → Task 4 → Verify (serial: ~120 min)
```

This skill launches typed agents in parallel:
```
NEW: ┌─ Investigator (worktree-1): analyze integration points
     ├─ Implementer (worktree-2): tasks 1, 3
     ├─ Implementer (worktree-3): tasks 2, 4
     ├─ Code Reviewer (worktree-4): reviews as implementations complete
     └─ Verifier: checks all results against spec
     Total: ~35-50 min
```

## Specialist Agent Types

| Agent Type | Role | When Used | Worktree? |
|-----------|------|-----------|-----------|
| **Investigator** | Analyze codebase, identify integration points, document risks | Before implementation | Yes |
| **Implementer** | Execute tasks, write code, update checklist | During implementation | Yes (one per task group) |
| **Verifier** | Validate implementation against spec | After each task group | Yes (read-only) |
| **Critic** | Review verifier findings, suggest spec updates, decide fix/accept | When verifier flags issues | No (orchestrator-level) |
| **Debugger** | Diagnose failures, try fixes, escalate if design change needed | When implementer fails | Yes (fresh worktree) |
| **Code Reviewer** | Review code quality, security, patterns during implementation | Async, parallel with impl | Yes (read-only) |

---

## How It Works

### Phase 0: Load the change

1. Find the active change (from `$ARGUMENTS` or scan `openspec/changes/`)
2. Read ALL artifacts: `proposal.md`, `specs.md`, `design.md`, `tasks.md`
3. Parse the task list — identify:
   - Total tasks and their status (pending/done/blocked)
   - Dependencies between tasks (which tasks must complete before others)
   - File overlap (which tasks touch the same files — these CANNOT be parallel)

### Phase 1: Investigate (optional, recommended for complex changes)

If the change touches 5+ files or has 4+ tasks, launch an **Investigator agent** in a worktree:

```
Agent: Investigator
Isolation: worktree
Purpose: Analyze the codebase before implementation begins

Instructions:
1. Read all artifacts from the change
2. For each task, identify:
   - Exact files that will be modified
   - Functions/components that will be affected
   - Integration points with other parts of the codebase
   - Potential risks or complications
3. Output a TASK DEPENDENCY MAP:
   - Which tasks are independent (can run in parallel)
   - Which tasks depend on others (must be sequential)
   - Which tasks touch the same files (CANNOT be parallel)
4. Output an INTEGRATION RISK REPORT:
   - High-risk integration points
   - Suggested implementation order
   - Files that need careful merge attention
```

If the change is simple (1-3 tasks, isolated files), skip this phase and go directly to Phase 2.

### Phase 2: Plan parallel execution

Based on the Investigator's output (or your own analysis), create the **execution plan**:

```
EXECUTION PLAN
═══════════════════════════════════════════════════

PARALLEL GROUP 1 (can run simultaneously)
  Worktree A: Tasks [1, 3] — touch src/auth/, src/utils/
  Worktree B: Tasks [2, 5] — touch src/components/, src/pages/

SEQUENTIAL (must run after Group 1)
  Tasks [4] — depends on Task 1 output, touches src/auth/

PARALLEL GROUP 2 (after sequential tasks)
  Worktree C: Task [6] — touch tests/
  Worktree D: Task [7] — touch docs/

CANNOT PARALLELIZE (same files)
  Tasks [1, 4] — both touch src/auth/middleware.ts

ESTIMATED TIME
  Serial:   ~90 min (7 tasks × ~13 min)
  Parallel: ~40 min (3 groups, longest group ~15 min + merge)
═══════════════════════════════════════════════════
```

Present this plan to the user. Ask for approval before launching agents.

### Phase 3: Launch parallel implementers

For each parallel group, launch agents in a SINGLE message (maximum parallelism):

Each **Implementer agent** gets:

```
Agent: Implementer
Isolation: worktree
subagent_type: general-purpose

Prompt:
You are an Implementer agent working on [change-name].
You are working in an ISOLATED GIT WORKTREE — your changes
won't affect the main branch until merged.

YOUR TASKS: [list of assigned tasks]

CONTEXT (from artifacts):
[Paste relevant sections of proposal.md, specs.md, design.md]

TASK DETAILS:
[Paste the specific task descriptions from tasks.md]

RULES:
1. Implement ONLY your assigned tasks — do not touch other files
2. After each task, update the checklist status in tasks.md
3. If you hit a blocker, document it and move to the next task
4. Log every decision with rationale (why you chose approach X)
5. Run any relevant tests if they exist
6. Do NOT commit — just make the changes. The coordinator will review.

OUTPUT:
When done, report:
- Tasks completed: [list]
- Tasks blocked: [list + reason]
- Files modified: [list]
- Decisions made: [list with rationale]
- Issues found: [list]
```

### Phase 4: Launch parallel reviewers (async)

While implementers work (or immediately after), launch:

**Code Reviewer agent** (one per parallel group):
```
Agent: Code Reviewer
Isolation: worktree (same as implementer, read-only review)
subagent_type: general-purpose

Prompt:
You are a Code Review agent. Review the changes made by
the Implementer in this worktree.

ARTIFACTS FOR REFERENCE:
[specs.md, design.md sections]

CHECK:
1. Does the code match the spec requirements?
2. Security issues (OWASP top 10)
3. Performance concerns
4. Error handling completeness
5. Code style consistency with existing codebase
6. Any "clever" code that should be simplified

OUTPUT:
- APPROVE: no issues found
- REQUEST_CHANGES: [list of issues with file:line and suggested fix]
- BLOCK: [critical issue that must be fixed before merge]
```

### Phase 5: Merge and reconcile

After all agents complete:

1. **Collect all worktree results** — check which tasks succeeded, which blocked
2. **Review code review findings** — BLOCK issues must be fixed before proceeding
3. **Merge worktrees** — for non-conflicting changes, merge automatically
4. **Handle conflicts** — if two worktrees touched the same file (shouldn't happen if Phase 2 was correct), present the conflict to the user
5. **Update living spec** — if implementation revealed new insights, suggest artifact updates

### Phase 6: Verify

Launch the **Verifier agent** against the merged result:

```
Agent: Verifier
subagent_type: general-purpose

Prompt:
You are the Verifier agent. Check the MERGED implementation
against the original spec.

ARTIFACTS: [all artifacts]
IMPLEMENTATION: [diff of all changes from worktrees]

CHECK:
1. Completeness — all tasks marked done? All requirements met?
2. Correctness — does the code do what the spec says?
3. Coherence — does the implementation follow the design?
4. Integration — do the parallel pieces work together?

OUTPUT:
- PASS: ready for human review
- ISSUES: [list with severity CRITICAL/WARNING/SUGGESTION]
```

### Phase 7: Handle failures (Critic + Debugger)

If Verifier or Code Reviewer flagged issues:

**For SUGGESTION/WARNING:**
Launch **Critic agent** (see `/shipflow-critic`):
- Decides: fix code, update spec, or accept as-is
- If spec update needed: modifies artifacts (living spec!)

**For CRITICAL / implementation failure:**
Launch **Debugger agent** (see `/shipflow-debug`):
- Diagnoses root cause in a fresh worktree
- Tries fix
- Escalates to user only if fix requires design change

### Phase 8: Report

```
══════════════════════════════════════════════════════
PARALLEL EXECUTION REPORT: [change-name]
══════════════════════════════════════════════════════

EXECUTION STATS
  Total tasks:         [X]
  Completed:           [X] ✅
  Blocked:             [X] 🔴 (with reasons)
  Parallel groups:     [X]
  Worktrees used:      [X]
  Time saved (est.):   [X min vs serial]

AGENT ACTIVITY
  Investigator:    [ran/skipped] — [summary]
  Implementer A:   Tasks [1,3] — ✅ complete
  Implementer B:   Tasks [2,5] — ✅ complete
  Code Reviewer:   [X issues found] — [X fixed, X accepted]
  Verifier:        [PASS/ISSUES]
  Critic:          [ran/not needed] — [decisions]
  Debugger:        [ran/not needed] — [fixes]

LIVING SPEC UPDATES
  [List any artifacts that were updated based on implementation insights]

MERGE STATUS
  [X/X worktrees merged successfully]
  [Conflicts: none / list]

NEXT STEPS
  → Review diffs: git diff main..HEAD
  → If satisfied: /opsx:verify (full verification)
  → Then: /opsx:archive [change-name]
══════════════════════════════════════════════════════
```

---

## When to Use This vs /opsx:apply

| Scenario | Use |
|----------|-----|
| 1-2 simple tasks, same file area | `/opsx:apply` (serial is fine) |
| 3+ tasks, different file areas | **`/opsx:parallel`** (this skill) |
| Complex change, many integration points | **`/opsx:parallel`** with Investigator phase |
| Quick fix, already know what to do | `/opsx:apply` (skip the ceremony) |
| Risky change, need isolation | **`/opsx:parallel`** (worktree safety) |

---

## Important

- **File overlap kills parallelism.** If two tasks touch the same file, they MUST be in the same group or sequential. The Investigator phase catches this.
- **Worktrees are cheap.** Claude Code creates and cleans them automatically. Don't hesitate to use them.
- **Living specs are a feature, not a bug.** When implementation reveals that the spec was wrong, UPDATE THE SPEC. Don't force-fit code to a broken spec.
- **The Coordinator doesn't implement.** This skill orchestrates. It launches agents, collects results, handles failures, and reports. It does NOT write code itself.
- **Always present the plan first.** Show the user the execution plan (Phase 2) before launching parallel agents. Let them adjust task grouping.
- **Merge conflicts are the exception.** If the plan is correct, worktrees should never conflict. A conflict means the Investigator missed a file overlap.
