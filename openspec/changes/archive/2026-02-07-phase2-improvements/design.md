## Context

ShipFlow currently has two separate menu files serving the same purpose:
- `menu_simple_color.sh` (743 lines) — text-based with ANSI colors, used when gum is unavailable. This is the primary menu (Phase 1 features: dashboard, restart, smart start, logs, help). Uses `select_environment()` with plain numbered lists.
- `menu.sh` (568 lines) — gum-based with French labels, older design (pre-Phase 1). Uses `gum choose`/`gum filter` for selection. Has its own DuckDNS publish flow and web inspector toggle.

Both source `lib.sh` (2,304 lines) which contains all core logic. `config.sh` (185 lines) centralizes settings, already using `$HOME/.shipflow/` for session and log storage.

Key observations from code review:
- `menu_simple_color.sh` is the more complete, English-language menu with Phase 1 features
- `menu.sh` is older, French-language, and auto-installs gum if missing (lines 8-14) — this forced install should be removed
- `show_dashboard()` in lib.sh already has status icons (🟢🟡🔴⚪) but `select_environment()` in the menu file shows plain text lists
- `init_web_inspector()` exists in lib.sh:1729 but only handles injection — no toggle/removal logic
- DuckDNS credentials are prompted inline in both menu files with no persistence

## Goals / Non-Goals

**Goals:**
- Single menu entry point (`menu.sh`) that works with or without gum
- Status indicators visible in every environment selection prompt
- One-command batch operations with safety confirmations
- DuckDNS credentials cached securely and reusable across sessions
- Fix the `toggle_web_inspector()` runtime error

**Non-Goals:**
- Interactive TUI dashboard with real-time refresh (that's Phase 3, item 9)
- Project templates (Phase 3, item 10)
- Health checks (Phase 3, item 11)
- Translating the menu to French or supporting i18n
- Changing the existing lib.sh function signatures

## Decisions

### 1. Menu merge strategy: rewrite `menu.sh` based on `menu_simple_color.sh`

**Decision:** Take `menu_simple_color.sh` as the canonical source (it has all Phase 1 features) and rewrite `menu.sh` to use a gum-detection wrapper pattern. Delete `menu_simple_color.sh` afterward.

**Rationale:** `menu_simple_color.sh` is the actively maintained menu with English labels, proper structure (header, show_menu, show_advanced_menu, main loop), and all Phase 1 features. `menu.sh` is older French-only code missing Phase 1 features. Starting from the better base avoids re-implementing features.

**Alternatives considered:**
- *Merge both files line by line* — Too complex, menus have diverged significantly in structure and feature set
- *Keep both files and add a launcher* — Defeats the purpose of reducing maintenance burden

**Approach:** Create a `HAS_GUM` flag at script start. For each UI interaction, use helper functions:
```bash
HAS_GUM=$(command -v gum >/dev/null 2>&1 && echo true || echo false)

# Wrappers in lib.sh
ui_choose()   # gum choose || numbered list with read
ui_input()    # gum input || echo + read
ui_confirm()  # gum confirm || yes/no read
ui_header()   # gum style || echo with ANSI colors
ui_spinner()  # gum spin || simple "Working..." message
```

These `ui_*` wrappers go into `lib.sh` so both the menu and any future scripts can use them. The menu itself stays as procedural case/switch logic.

### 2. Status indicators: extract `get_status_icon()` into lib.sh

**Decision:** Extract the status icon logic currently in `show_dashboard()` (lib.sh:1957-1972) into a standalone `get_status_icon()` function. Use it in `select_environment()` and everywhere environments are listed.

**Approach:**
```bash
# Returns: icon color_var (e.g., "🟢 GREEN")
get_status_icon() {
    local status=$1
    case "$status" in
        online)  echo "🟢";;
        stopped) echo "🟡";;
        errored|error) echo "🔴";;
        *) echo "⚪";;
    esac
}
```

Update `select_environment()` (moving it from menu into lib.sh) to call `get_pm2_status()` + `get_status_icon()` for each environment in the list. The dashboard's inline icon logic gets replaced with `get_status_icon()` calls too.

### 3. Batch operations: new functions in lib.sh + menu entries

**Decision:** Add `batch_stop_all()`, `batch_start_all()`, `batch_restart_all()` to lib.sh. Expose them as a submenu item under the main menu (new option or under "More Options").

**Approach:**
- Each function iterates `list_all_environments`, shows a count, requires confirmation
- Uses existing `env_stop`/`env_start`/`env_restart` per environment — no shortcuts that skip cache invalidation
- Shows per-environment progress: `[1/5] Stopping webinde... ✅`
- Single `invalidate_pm2_cache` call at the end (each env_* already invalidates, but one final call ensures consistency)
- Add as main menu option 7 (shift current "More Options" to 8, "Help" to 9)

**Alternatives considered:**
- *`pm2 stop all` shortcut* — Skips our cache invalidation and logging; doesn't match our env_stop behavior
- *Put under "More Options" submenu* — Batch ops are common enough to deserve top-level placement

### 4. Credential cache: `~/.shipflow/secrets`

**Decision:** Store DuckDNS subdomain and token in `~/.shipflow/secrets` as a simple key=value file with chmod 600. Provide `load_secrets()` and `save_secret()` helpers in lib.sh.

**Approach:**
```bash
SHIPFLOW_SECRETS_FILE="${SHIPFLOW_SECRETS_DIR:-$HOME/.shipflow}/secrets"

save_secret() {  # key, value → append/update in secrets file
    # Create dir with 700, file with 600
    # Use sed to update existing key or append new one
}

load_secret() {  # key → stdout
    # Read from secrets file, grep for key
}
```

The "Publish to Web" flow changes to:
1. Try `load_secret DUCKDNS_SUBDOMAIN` and `load_secret DUCKDNS_TOKEN`
2. If found, show cached value and ask "Use cached credentials? (Y/n)"
3. If not found or user says no, prompt as before and save afterward
4. Never log or echo the token value

**Config addition:**
```bash
export SHIPFLOW_SECRETS_DIR="${SHIPFLOW_SECRETS_DIR:-$HOME/.shipflow}"
```

### 5. Fix toggle_web_inspector(): implement in lib.sh

**Decision:** Implement `toggle_web_inspector()` in lib.sh that checks if the inspector is already injected and either removes it or calls `init_web_inspector()`.

**Approach:**
```bash
toggle_web_inspector() {
    local project_dir=$1
    cd "$project_dir" || return 1

    # Check if inspector is present
    if [ -f "public/shipflow-inspector.js" ]; then
        # Remove: delete the JS file and strip script tags from HTML/Astro/Next layouts
        rm -f "public/shipflow-inspector.js"
        # Remove injected lines (marker + script tag) from index.html, layouts, etc.
        # Use sed to remove lines containing "shipflow-inspector"
        echo "Web inspector disabled"
    else
        # Enable: call existing init_web_inspector
        init_web_inspector
        echo "Web inspector enabled"
    fi
}
```

Place it right after `init_web_inspector()` in lib.sh (after line ~1865). The function uses the presence of the JS file as the toggle state — simple and reliable.

## Risks / Trade-offs

**[BREAKING: menu_simple_color.sh removal]** → Anyone with scripts or docs pointing to `./menu_simple_color.sh` will break. *Mitigation:* Leave a one-line stub that sources menu.sh with a deprecation warning for one release cycle. Update CLAUDE.md and all documentation references.

**[Gum auto-detection reliability]** → Edge case where gum is in PATH but broken. *Mitigation:* Test with `gum --version` not just `command -v gum`. Fall back gracefully on any error.

**[Batch operations on large environments]** → Stopping 20+ environments sequentially could be slow. *Mitigation:* Show progress per environment so user sees it's working. Don't parallelize — sequential is safer for PM2 state consistency.

**[Secrets file security]** → Plain-text credentials on disk. *Mitigation:* chmod 600 on file, chmod 700 on directory. This matches how SSH keys, `.netrc`, and Docker credentials are stored. Document that this is not suitable for multi-user servers. Token is read with `-s` flag (no echo) when prompted.

**[select_environment() move to lib.sh]** → Currently defined in menu_simple_color.sh. Moving it to lib.sh changes where it lives. *Mitigation:* It's a clean function with no menu-specific dependencies. Tests don't test it directly (it's interactive). The move is straightforward.
