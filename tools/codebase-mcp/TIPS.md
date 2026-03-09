# Token-Saving Guide for Claude Code

## What drains tokens most

| Source | Cost | Fix |
|--------|------|-----|
| Broad file exploration (Glob/Grep all) | High | Use `context_retrieve` first |
| Re-reading files Claude already has | High | `context_continue` shows what's cached |
| Vague prompts → multiple search rounds | High | Give exact file paths when you know them |
| Long conversations without /clear | Medium | `/clear` between unrelated tasks |
| Root CLAUDE.md loaded every turn | Medium | Keep it slim (routing only) |
| Using Opus for simple tasks | High | Switch to Sonnet for edits/content |

---

## Prompting rules (biggest ROI)

### Give file paths directly
```
BAD:  "fix the header bug"
GOOD: "fix the z-index in src/components/Header.astro:42"
```

### One task per prompt
```
BAD:  "refactor the auth system, then update the docs, then add tests"
GOOD: one message per task, /clear between unrelated ones
```

### Say what NOT to do
```
"don't explore, just edit src/pages/index.astro"
"don't read other files, the fix is in this function"
```

### Reference existing code explicitly
```
"same pattern as src/components/Card.astro"
"follow the existing error handling in src/lib/api.ts"
```

---

## Model selection

| Task | Model |
|------|-------|
| Architecture decisions, complex bugs, multi-file refactors | Opus |
| Standard edits, content writing, adding features | Sonnet (default) |
| Simple questions, formatting, one-liners | Haiku (`/model haiku`) |

Switch with `/model sonnet` or `/model haiku`. Sonnet is ~5x cheaper than Opus.

---

## Conversation hygiene

- `/clear` — wipe context between unrelated tasks (biggest single saving)
- `/compact` — summarize context when conversation gets long
- Don't repeat context the AI already has — it's in the conversation history
- Don't paste large files into chat — use `context_read` or file paths instead

---

## New tools (v2)

| Tool | Usage |
|------|-------|
| `count_tokens(text)` | Estimate cost BEFORE reading a large file |
| `log_usage(input, output, model, desc)` | Track actual task cost |
| `get_session_stats()` | See running USD cost for session + all-time |
| `list_symbols(file)` | List all functions/classes in a file |
| `context_read("file.ts::functionName")` | Read just one function, not the whole file |
| `session_wrap(task, decisions, next_steps)` | Save session state before `/compact` |

**Symbol reading example:**
```
list_symbols("src/utils/api.ts")
→ shows: fetchUser (L12-45), handleError (L47-60), validateInput (L62-80)

context_read("src/utils/api.ts::fetchUser")
→ reads only lines 12-45 instead of the whole file
→ saves ~80% of tokens for large files
```

## MCP context tools (what they save)

| Tool | Saves |
|------|-------|
| `context_continue` | Avoids re-reading files already in memory |
| `context_retrieve` | Reads only relevant files, not the whole codebase |
| `context_read` | Excerpts only matching portions (4K cap vs full file) |
| `context_register_edit` | Invalidates stale cache so Claude doesn't re-derive decisions |
| `context_decide` | Stores architectural choices cross-session (no re-discovery) |

Turn budget: **18,000 chars/turn** for file reading via `context_read`.
At ~4 chars/token, that's ~4,500 tokens of file content max per turn.

---

## CLAUDE.md hygiene

Every line in CLAUDE.md costs tokens on **every turn**. Keep them lean:
- Root `~/CLAUDE.md`: routing only (project table + tracking rules)
- Project CLAUDE.md: architecture + commands for that project only
- No duplicate info between root and project files
