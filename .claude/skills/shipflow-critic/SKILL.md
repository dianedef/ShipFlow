---
name: shipflow-critic
description: Critic agent — reviews verify/review findings and makes decisions. Fix the code, update the spec, or accept as-is. Bridges the gap between finding issues and resolving them. The agent that decides what's worth fixing.
disable-model-invocation: true
argument-hint: [change-name | file-path | "auto"] (auto = review most recent verify output)
---

## Context

- Current directory: !`pwd`
- Active changes: !`ls openspec/changes/ 2>/dev/null || echo "no active changes"`
- Recent verify output: !`find . -name "VERIFY_REPORT.md" -o -name "verify-*.md" 2>/dev/null | head -5 || echo "no verify reports"`
- Recent audit output: !`find . -name "AUDIT_LOG.md" 2>/dev/null | head -3 || echo "no audit logs"`
- Git recent: !`git log --oneline -5 2>/dev/null`

## What This Skill Does

The Critic sits between **finding issues** and **fixing them**. It answers the question every team avoids: *"Is this actually worth fixing, or are we gold-plating?"*

```
/opsx:verify or /shipflow-audit-*
    │
    ▼ issues found
/shipflow-critic  ◄── you are here
    │
    ├── FIX CODE: issue is real, code is wrong → launch fix
    ├── UPDATE SPEC: code is right, spec was wrong → update artifacts
    ├── ACCEPT AS-IS: issue is theoretical, not practical → document decision
    └── ESCALATE: needs human judgment → present options with tradeoffs
```

## When to Use This

- After `/opsx:verify` flags WARNINGS or SUGGESTIONS
- After any `/shipflow-audit-*` finds issues
- After a code review (human or agent) raises concerns
- When you're unsure if something is a real problem or noise
- When implementation revealed that the original spec was incomplete

## How It Works

### Step 1: Gather findings

Load the issues to evaluate. Sources (check in order):

1. **OpenSpec verify output**: Read `openspec/changes/[name]/` artifacts + any verify report
2. **Audit log**: Read `AUDIT_LOG.md` for recent audit findings
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

**UPDATE SPEC (Living Spec):**
This is the critical capability Intent has that serial OpenSpec doesn't:
- Read the current artifact (specs.md, design.md, or proposal.md)
- Add the new insight/requirement discovered during implementation
- Mark the update with a `> [LIVING SPEC UPDATE — date]: ...` callout
- Log the decision: what changed, why, and what triggered it

Example living spec update:
```markdown
> [LIVING SPEC UPDATE — 2026-03-13]: Added error handling for
> rate-limited API responses. Discovered during implementation
> that the upstream API returns 429 with Retry-After header.
> Original spec didn't account for this. Added retry logic
> requirement to API integration section.
```

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
| `/opsx:verify` finds issues | Run `/shipflow-critic` to decide what to fix |
| `/shipflow-audit-*` finds issues | Run `/shipflow-critic` to triage findings |
| `/opsx:parallel` Phase 7 | Coordinator auto-triggers Critic for non-critical issues |
| `/shipflow-debug` fixes a bug | Critic reviews if the fix needs a spec update |
| Manual review raises concerns | Run `/shipflow-critic` with the file or issue |

---

## Important

- **The Critic never says "fix everything."** That's a junior reviewer. A senior reviewer knows what matters and what doesn't. The Critic prioritizes ruthlessly.
- **Living specs are the point.** The most valuable output of the Critic is updating specs to match reality. A spec that doesn't reflect the code is worse than no spec.
- **Document acceptance decisions.** "Accept as-is" without reasoning is just ignoring the problem. Always explain WHY it's acceptable.
- **Don't gold-plate.** A LOW severity + UNCERTAIN confidence issue that takes LARGE effort to fix? Accept it. Move on. Ship.
- **The Critic is opinionated.** It doesn't present every option neutrally — it makes a recommendation. The user can override, but the Critic takes a stance.
