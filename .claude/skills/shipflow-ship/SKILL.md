---
name: shipflow-ship
description: Ship the session — commit, push, update tasks + changelog, save memory, wrap context. One report. Use this at end of session when ready to push.
argument-hint: [optional commit message or notes]
---

## Context

- Current directory: !`pwd`
- Current date: !`date '+%Y-%m-%d'`
- Git status: !`git status --short 2>/dev/null || echo "Not a git repo"`
- Git diff stat: !`git diff HEAD --stat 2>/dev/null || echo ""`
- Current branch: !`git branch --show-current 2>/dev/null || echo "unknown"`
- Recent commits (style reference): !`git log --oneline -5 2>/dev/null || echo "no commits"`
- Master TASKS.md: !`cat /home/claude/shipflow_data/TASKS.md 2>/dev/null || cat TASKS.md 2>/dev/null || echo "No TASKS.md"`
- Existing CHANGELOG: !`head -20 CHANGELOG.md 2>/dev/null || echo "no CHANGELOG.md"`

## Your task

Close the session and ship — all steps inline, no sub-skills. ONE report at the end. Do NOT invoke shipflow-end, shipflow-tasks, or shipflow-changelog.

### Step 1 — Workspace root detection

If the current directory has no `.git` directory BUT contains project subdirectories with changes, use **AskUserQuestion**:
- "Which project should I ship?"
- One option per project with uncommitted changes
- `multiSelect: false`

Then work inside that project for all remaining steps.

### Step 2 — Pre-ship verification (internal, may output warnings)

Before shipping, run these checks silently. Only surface issues that need attention.

**2a. TASKS.md completeness check**
Read TASKS.md (master or local). Compare uncompleted tasks (`📋 todo` / `🔄 in progress` / `- [ ]`) against the conversation — did any get done but not checked off? Flag:
- Tasks marked in-progress that the conversation shows are done → will fix in Step 3
- Tasks that were the stated goal of the session but show no evidence of completion → warn user

**2b. Git diff vs intent check**
Run `git diff HEAD --name-only` and compare modified files against the session's stated goals:
- If the session goal was "add feature X" but no files related to X were modified → warn: "Goal was X but no related files changed — still ship?"
- If files were modified that seem unrelated to any discussed task → note in report (not a blocker)

**2c. Stale docs check**
For each modified file in the diff, quick-check:
- If `CLAUDE.md` references a function/file that was renamed or deleted → flag for update
- If `README.md` describes behavior that the diff changed → flag for update
- Do NOT exhaustively audit docs — just catch obvious staleness from THIS session's changes

**2d. TODO scan**
Run a quick search for `TODO`, `FIXME`, `HACK`, `XXX` in files modified this session:
```bash
git diff HEAD --name-only | xargs grep -n 'TODO\|FIXME\|HACK\|XXX' 2>/dev/null || true
```
- If any were ADDED this session (not pre-existing) → list them in the report as "TODOs left behind"
- Pre-existing TODOs are not your problem — ignore them

**2e. Verdict**
- If all checks pass → proceed silently
- If warnings found → present a short checklist before committing:
  ```
  ⚠️  Pre-ship check:
  - [ ] [warning 1]
  - [ ] [warning 2]
  Ship anyway? (y/n)
  ```
  Use **AskUserQuestion** with options: "Ship anyway", "Let me fix first"
- If no blockers but has notes → include them in the final report (Step 11) under a "Notes" section

### Step 3 — Summarize session (internal, no output)

From the conversation, silently identify:
- What was completed this session
- What was started but not finished
- Any decisions worth saving to memory

### Step 4 — Update TASKS.md (silent, no sub-skill)

Using the master TASKS.md from context:
- Mark completed items: `📋 todo` → `✅ done` (or `- [ ]` → `- [x]`)
- Add new tasks discovered this session under the right section
- Update master `/home/claude/shipflow_data/TASKS.md` — always, even from a sub-project
- If a local `TASKS.md` also exists, update both
- Use Edit or Write tool. No output at this step.

### Step 5 — Update CHANGELOG.md (silent, no sub-skill)

Using the recent commits from context:
- Group commits into Keep a Changelog categories: Added / Changed / Fixed / Security / Removed
- Consolidate related commits into single human-readable entries
- Skip CI, formatting, merge, and changelog-update commits
- Prepend a new `## [Unreleased] — [date]` entry to CHANGELOG.md (or create it)
- No tagging question — just write the entry
- No output at this step.

### Step 6 — Save decisions to memory (silent MCP)

For each significant decision or discovery from Step 3, call `context_decide` with a one-sentence summary.

Skip if no meaningful decisions were made. No output at this step.

### Step 7 — Stage and commit

Check for secrets before staging:
- If untracked `.env`, credential, or token files are NOT in `.gitignore`, warn the user and stop

Stage and commit:
```bash
git add -A
git commit -m "[message from $ARGUMENTS or derived from session summary]
Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

Use a HEREDOC for the commit message. Follow the style of recent commits.

### Step 8 — Push

```bash
git push
# If no upstream: git push -u origin <branch>
```

### Step 9 — Wrap session context (silent MCP)

Call `session_wrap` to persist the context store for the next session. Skip gracefully if unavailable.

### Step 10 — Sync ShipFlow (silent housekeeping)

If `/home/claude/ShipFlow` has uncommitted changes, auto-commit and push:
```bash
cd /home/claude/ShipFlow && git add -A && git diff --cached --quiet || git commit -m "sync" && git push
```

Only report this if it fails.

### Step 11 — ONE combined report

```
## Shipped — [date]

**[SHORT_SHA]** — "[commit message]" → [branch]

**What changed:**
- [bullet per logical change from diff — specific, not vague]

**Session closed:**
- Completed: [item], [item]
- In progress: [item — where it stands]
- Decisions saved: [decision or "none"]

**Pre-ship check:** [✓ All clear] or [list of notes/warnings from Step 2]

**TODOs left behind:** [list from Step 2d, or "none"]

**Up next:**
1. [emoji] [top TASKS.md priority]
2. [emoji] [second priority]
3. [emoji] [third priority]

[✓ Pushed] or [⚠️  Push failed: reason]
```

### Rules

- Do NOT call shipflow-end, shipflow-tasks, or shipflow-changelog — all steps are inline
- Do NOT output anything before Step 11 — one report only (except Step 2 warnings)
- Do NOT force push to main/master
- Do NOT commit secrets or credentials
- If nothing to commit, say so in the report and still do Steps 2–6 and 9
- Keep the final report under 30 lines
