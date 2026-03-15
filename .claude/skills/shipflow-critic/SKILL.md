---
name: shipflow-critic
description: Critic agent — reviews audit/review findings and makes decisions. Fix the code, update docs, or accept as-is. Bridges the gap between finding issues and resolving them. The agent that decides what's worth fixing.
disable-model-invocation: true
argument-hint: [file-path | "auto"] (auto = review most recent audit or git diff)
---

## Context

- Current directory: !`pwd`
- Tasks: !`cat TASKS.md 2>/dev/null | head -30 || echo "no TASKS.md"`
- Recent audit output: !`find . -name "AUDIT_LOG.md" 2>/dev/null | head -3 || echo "no audit logs"`
- Git recent: !`git log --oneline -5 2>/dev/null`
- Recent changes: !`git diff --stat HEAD~3 2>/dev/null | tail -10 || echo "no recent changes"`

## What This Skill Does

The Critic sits between **finding issues** and **fixing them**. It answers the question every team avoids: *"Is this actually worth fixing, or are we gold-plating?"*

```
/shipflow-audit-* or code review or error report
    │
    ▼ issues found
/shipflow-critic  ◄── you are here
    │
    ├── FIX CODE: issue is real, code is wrong → fix it or delegate to /shipflow-debug
    ├── UPDATE DOCS: code is right, docs were wrong → update README/CLAUDE.md/TASKS.md
    ├── ACCEPT AS-IS: issue is theoretical, not practical → document decision
    └── ESCALATE: needs human judgment → present options with tradeoffs
```

## When to Use This

- After any `/shipflow-audit-*` finds issues
- After a code review (human or agent) raises concerns
- When you're unsure if something is a real problem or noise
- When you want to triage a long list of findings before acting
- After `/shipflow-debug` identifies multiple issues to prioritize

## How It Works

### Step 1: Gather findings

Load the issues to evaluate. Sources (check in order):

1. **Audit log**: Read `AUDIT_LOG.md` for recent audit findings
2. **TASKS.md**: Check for audit findings or flagged issues
3. **Specific file**: If `$ARGUMENTS` is a file path, review that file's issues
4. **Git diff**: Check recent changes for review context

### Step 2: Classify each issue

For every finding, the Critic evaluates on 3 axes:

| Axis | Question | Scale |
|------|----------|-------|
| **Severity** | How bad is this if left unfixed? | CRITICAL / HIGH / MEDIUM / LOW |
| **Confidence** | How sure are we this is actually a problem? | CERTAIN / LIKELY / UNCERTAIN / SPECULATIVE |
| **Effort** | How much work to fix? | TRIVIAL / SMALL / MEDIUM / LARGE |

### Step 3: Decision matrix

Based on the classification, decide:

```
                        HIGH CONFIDENCE          LOW CONFIDENCE
                   ┌─────────────────────┬──────────────────────┐
  HIGH SEVERITY    │ FIX CODE (now)       │ INVESTIGATE (then    │
                   │                      │ decide)              │
                   ├─────────────────────┼──────────────────────┤
  LOW SEVERITY     │ FIX if TRIVIAL,     │ ACCEPT AS-IS         │
                   │ else BACKLOG        │ (document why)       │
                   └─────────────────────┴──────────────────────┘

  SPEC WRONG:     If code is correct but spec didn't anticipate
                  this case → UPDATE SPEC (living spec!)

  NEEDS JUDGMENT: If reasonable people could disagree →
                  ESCALATE with options and tradeoffs
```

### Step 4: For each decision, act

**FIX CODE:**
- If trivial (< 5 lines): fix it directly
- If small: describe the fix, ask user to approve, then apply
- If large: create a task in TASKS.md, suggest running `/opsx:apply` or `/shipflow-debug`

**UPDATE DOCS:**
When the code is right but documentation is outdated or incomplete:
- Update `CLAUDE.md` if architectural understanding changed
- Update `README.md` if user-facing behavior changed
- Update `TASKS.md` if priorities shifted based on findings
- Add a note in the relevant file: `> [UPDATE — date]: [what changed and why]`

**ACCEPT AS-IS:**
- Document WHY the issue is acceptable
- Add a `> [CRITIC DECISION — date]: Accepted — [reasoning]` note
- This prevents the same issue from being re-flagged in future audits

**ESCALATE:**
- Present the options to the user with tradeoffs:
  ```
  ISSUE: [description]

  OPTION A: [fix approach]
    Pros: [list]
    Cons: [list]
    Effort: [estimate]

  OPTION B: [accept approach]
    Pros: [list]
    Cons: [list]
    Risk: [what could go wrong]

  OPTION C: [alternative approach]
    Pros: [list]
    Cons: [list]

  MY RECOMMENDATION: [option] because [reasoning]
  ```

### Step 5: Report

```
══════════════════════════════════════════════════════
CRITIC REVIEW: [change-name or context]
══════════════════════════════════════════════════════

FINDINGS REVIEWED: [X total]

DECISIONS
  ✅ FIX CODE:      [X] issues
  📝 UPDATE SPEC:   [X] artifacts modified (living spec)
  ☑️  ACCEPT AS-IS:  [X] issues (documented)
  ⚠️  ESCALATE:      [X] need your input

──────────────────────────────────────────────────────
FIXES APPLIED
──────────────────────────────────────────────────────
  1. [file:line] — [what was fixed] — [why]
  2. ...

──────────────────────────────────────────────────────
SPEC UPDATES (Living Spec)
──────────────────────────────────────────────────────
  1. [artifact] — [what was added/changed] — [triggered by]
  2. ...

──────────────────────────────────────────────────────
ACCEPTED AS-IS
──────────────────────────────────────────────────────
  1. [issue] — [why it's acceptable]
  2. ...

──────────────────────────────────────────────────────
NEEDS YOUR INPUT
──────────────────────────────────────────────────────
  [escalation details with options]

══════════════════════════════════════════════════════
```

---

## Integration with Other Skills

| Trigger | What happens |
|---------|-------------|
| `/shipflow-audit-*` finds issues | Run `/shipflow-critic` to triage findings |
| `/shipflow-debug` fixes a bug | Critic reviews if docs need updating |
| Manual review raises concerns | Run `/shipflow-critic` with the file or issue |
| Large TASKS.md backlog | Critic prioritizes what's worth doing vs accepting |

---

## Important

- **The Critic never says "fix everything."** That's a junior reviewer. A senior reviewer knows what matters and what doesn't. The Critic prioritizes ruthlessly.
- **Keep docs honest.** If the code diverged from what CLAUDE.md or README says, update the docs. Outdated docs are worse than no docs.
- **Document acceptance decisions.** "Accept as-is" without reasoning is just ignoring the problem. Always explain WHY it's acceptable.
- **Don't gold-plate.** A LOW severity + UNCERTAIN confidence issue that takes LARGE effort to fix? Accept it. Move on. Ship.
- **The Critic is opinionated.** It doesn't present every option neutrally — it makes a recommendation. The user can override, but the Critic takes a stance.
