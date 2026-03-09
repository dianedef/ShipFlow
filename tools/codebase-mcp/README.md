# Codebase MCP Server

A local MCP server for Claude Code that reduces token usage through smart context management, file retrieval, and session memory. No cloud, no tracking, no license key.

## Install

```bash
pip3 install mcp --break-system-packages
```

Configure per project in `.claude/settings.json`:

```json
{
  "mcpServers": {
    "codebase": {
      "command": "python3",
      "args": ["/home/claude/tools/codebase-mcp/server.py", "/home/claude/YOUR_PROJECT"]
    }
  }
}
```

Then restart Claude Code. The server starts automatically.

## How it works

The server exposes **22 MCP tools** in 3 groups. Claude calls them based on rules injected into each project's `CLAUDE.md`. The core loop:

```
Every turn:
  1. context_continue      ← what Claude already knows (avoids re-reads)
  2. context_retrieve      ← find relevant files by keyword
  3. context_read          ← read with excerpting + budget tracking
  4. [do work]
  5. context_register_edit ← invalidate cache after edits
  6. session_wrap          ← save state when done
```

---

## Tools Reference

### Context Tools — token savings

#### `context_continue`
**Call this first every turn.** Returns files already in memory, recent decisions, and remaining read budget. Prevents re-reading files Claude already processed. Also recovers context automatically after `/compact`.

```
→ Files in memory (3):
    [read] src/components/Header.astro  (2,400 chars)
    [EDITED] src/pages/index.astro      (1,800 chars)
  Decisions:
    - using Vue for interactive islands
  Turn budget: 16,200 / 18,000 chars remaining
```

---

#### `context_retrieve(query, limit?)`
Rank project files by keyword relevance **before** using Grep or Glob. Builds an inverted index on first call (indexes filenames, imports, headings, frontmatter).

```
context_retrieve("authentication clerk webhook")
→ [100%] src/lib/auth.ts
   [75%] convex/users.ts
   [50%] src/middleware.ts
```

---

#### `context_read(file, query?, max_chars?)`
Read a file with smart excerpting and budget tracking. Much cheaper than the native Read tool.

- Returns only the portions matching your query (not the full file)
- Deduplicates reads within the same turn
- Serves cached content for repeated queries across turns
- Hard cap: 4,000 chars per read, 18,000 chars per turn total

**Symbol notation** — read just one function:
```
context_read("src/utils/api.ts::fetchUser")
→ reads only lines 12-45 instead of the whole 300-line file
```

---

#### `list_symbols(file_path)`
List all functions and classes in a file with their line ranges. Use before `context_read` on large files to find the exact symbol you need.

```
list_symbols("src/utils/static-responses.ts")
→ Symbols in src/utils/static-responses.ts:
    L1-28    normalizeString
    L30-55   groupTagsByParent
    L57-120  getFilteredPosts
    L122-180 getTagPosts

Use context_read with 'src/utils/static-responses.ts::getFilteredPosts'
```

---

#### `context_register_edit(files, summary?)`
Register files you edited. **Call after every edit.**
- Invalidates cached content for those files
- Stores the summary as a cross-session decision
- Prevents Claude from serving stale cached content

```
context_register_edit(["src/components/Nav.astro"], "fixed z-index on mobile dropdown")
```

---

#### `context_decide(decision, files?)`
Store an architectural decision that persists across sessions.

```
context_decide("using Astro islands for all interactive components", ["astro.config.mjs"])
```

---

#### `context_invalidate(files)`
Clear cached context for specific files when assumptions change (e.g., you refactored something outside Claude's view).

---

#### `session_wrap(task, decisions?, next_steps?)`
Save a session summary to `.codebase-mcp/session-summary.md`. Call when the user says "done", "bye", or "wrap up". On the next session, `context_continue` reads this file and recovers context instantly after `/compact`.

```
session_wrap(
  task="adding dark mode toggle to header",
  decisions=["using CSS variables for theme", "toggle state in localStorage"],
  next_steps=["test on Safari", "add to mobile nav"]
)
```

---

### Token Tools — cost tracking

#### `count_tokens(text)`
Estimate token count and USD cost **before** reading a file. Use on any file over 200 lines to decide if it's worth the budget.

```
count_tokens("<paste first 50 lines of large file>")
→ {
    "chars": 2400,
    "tokens_est": 600,
    "cost_if_input": {
      "opus":   "$0.00900",
      "sonnet": "$0.00180",
      "haiku":  "$0.00048"
    }
  }
```

---

#### `log_usage(input_tokens, output_tokens, model, description)`
Log actual token usage after completing a task. Builds a persistent cost history in `.codebase-mcp/token_log.json`.

```
log_usage(2400, 800, "sonnet", "refactored auth middleware")
→ { "cost_usd": "$0.01920", "session_total_usd": "$0.0842" }
```

---

#### `get_session_stats()`
Show running cost for the current session and all-time breakdown by model.

```
→ Session: $0.0842  (8,200 in / 2,100 out tokens)
  Today:   $0.2341
  All-time: $4.8820  (143 tasks logged)

  By model:
    sonnet: $3.9200
    opus:   $0.9620

  This session:
    $0.0192  [sonnet]  refactored auth middleware
    $0.0310  [sonnet]  added dark mode toggle
```

---

### Project Tools — codebase knowledge

#### `get_structure()`
High-level overview: framework detection (Astro/Next.js/generic), file counts by type, key directories with file counts.

#### `find_file(name)`
Find files by partial name, case-insensitive. Faster than Glob for known filenames.

#### `find_usages(component)`
Find all files that import or reference a component, function, or symbol. Shows matching lines with context.

#### `get_imports(file_path)`
List all import statements in a file — useful for understanding dependencies before editing.

#### `list_pages()`
List all pages/routes. Framework-aware:
- **Astro**: scans `src/pages/` for `.astro`, `.md`, `.mdx`
- **Next.js**: scans `app/` or `pages/` for `page.tsx`, `index.tsx`

#### `list_components()`
List all components in `src/components/`, `src/ui/`, `src/layouts/`. Covers `.astro`, `.vue`, `.tsx`, `.jsx`.

#### `list_content()`
List Astro content collections with file counts. Essential for large content sites (GoCharbon has ~290 posts across multiple collections).

#### `search_content(query)`
Search for text across `.md`, `.mdx`, `.astro` content files. Returns file path + line number + matching line preview.

---

## Session data

All data is stored in `.codebase-mcp/` inside your project (add to `.gitignore`):

| File | Contents |
|------|----------|
| `action_graph.json` | Files read/edited, decisions, action history |
| `session-summary.md` | Last session summary for auto-compact recovery |
| `token_log.json` | Persistent cost log (last 500 tasks) |

---

## Token budgets

| Limit | Value |
|-------|-------|
| Max chars per file read | 4,000 |
| Max chars per turn (all reads) | 18,000 |
| Approx tokens per turn max | ~4,500 |
| Cache TTL | process lifetime (in-memory) |

---

## Pricing reference (input tokens)

| Model | Per 1M tokens |
|-------|--------------|
| Claude Opus | $15.00 |
| Claude Sonnet | $3.00 |
| Claude Haiku | $0.80 |

Update `MODEL_COSTS` in `server.py` if Anthropic changes pricing.

---

## Related

- `TIPS.md` — prompting rules and token-saving habits
- `/context-prime` skill — session kickoff: calls context_continue + context_retrieve before starting work
- Inspired by [GrapeRoot Dual-Graph](https://grape-root.vercel.app/) — we reverse-engineered their approach and rebuilt it without the license key, cloud dependency, or tracking
