---
name: shipflow-ship
description: Stage, commit, and push all changes to the remote repository
disable-model-invocation: true
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git add:*), Bash(git commit:*), Bash(git push:*)
argument-hint: [optional commit message]
---

## Context

- Current git status: !`git status`
- Current git diff (staged and unstaged): !`git diff HEAD`
- Current branch: !`git branch --show-current`
- Recent commits for style reference: !`git log --oneline -5`

## Your task

Ship all current changes: stage everything, commit, and push.

### Workspace root detection

If the current directory has no `.git` directory (not a git repo itself) BUT contains multiple project subdirectories — you are at the **workspace root**. Use **AskUserQuestion**:
- Question: "Which project should I ship?"
- `multiSelect: false`
- One option per project that has uncommitted changes (run `git -C [path] status --porcelain` for each)
- Only list projects with actual changes

Then `cd` into the selected project and continue with the steps below.

### Steps

1. **Review the changes** shown above. Identify all modified, added, and deleted files.
2. **Update TASKS.md first** — invoke `shipflow-tasks` to mark completed items and capture new tasks before committing, so the task state is included in the commit:
   ```
   Skill("shipflow-tasks")
   ```
3. **Stage all changes** using `git add -A`. If you spot untracked files that look like secrets (`.env`, credentials, tokens) and they are NOT in `.gitignore`, warn the user and stop — do not commit.
4. **Write a commit message** that:
   - Follows the style of recent commits shown above
   - Is concise (1-2 sentences) and focuses on the "why" not the "what"
   - If the user provided an argument (`$ARGUMENTS`), use it as the commit message or as guidance for the message
   - Ends with: `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>`
5. **Create the commit** using a HEREDOC for the message to preserve formatting.
6. **Push to the remote** using `git push`. If the branch has no upstream, use `git push -u origin <branch>`.
7. **Confirm success** by running `git status` after push.

### Also: update CHANGELOG

After a successful push, update the changelog automatically — no need to ask:

- **Update CHANGELOG.md** — invoke the `shipflow-changelog` skill to append an entry for the commit just pushed.

```
Skill("shipflow-changelog")
```

### Also: sync ShipFlow data

After all of the above, check if `/home/claude/ShipFlow` has uncommitted changes (TASKS.md or AUDIT_LOG.md may have been updated during this session). If yes, auto-commit and push ShipFlow too:

```bash
cd /home/claude/ShipFlow && git add -A && git diff --cached --quiet || git commit -m "sync" && git push
```

This is silent housekeeping — don't report it unless it fails.

### Final: delivery report

After everything is done (commit pushed, changelog updated, ShipFlow synced), output a delivery report in English using this exact format:

```
All pushed. Here's what was shipped in this commit:

  What's in [SHORT_SHA]
  - [bullet 1: one-line description of a change]
  - [bullet 2]
  - [bullet 3]
  - ... (one bullet per logical change, based on the diff)

  Next priorities (TASKS.md):
  1. [emoji] [top priority task]
  2. [emoji] [second priority task]
  3. [emoji] [third priority task]
```

- `[SHORT_SHA]` = the short commit hash (7 chars) from `git log --oneline -1`
- Bullets = derived from the actual diff — be specific and concrete, not vague
- Priorities = pulled from TASKS.md (top 3 non-completed items, with appropriate emoji: 🔴 urgent, 🟡 in progress, 🟢 ready, ⚪ backlog)

### Important

- Do all of the above in a single message using parallel tool calls where possible.
- If there are no changes to commit, inform the user and stop.
- Never force push. Never skip hooks.
- If the push fails, report the error clearly — do not retry automatically.
