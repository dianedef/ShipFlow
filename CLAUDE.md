# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Project Overview

**ShipFlow** is a CLI development environment manager for Hetzner servers that automates deployment using **Flox** (isolated environments), **PM2** (process management), and **Caddy** (HTTPS reverse proxy). It provides both local SSH tunnel access for development and public HTTPS URLs via DuckDNS.

**Production Status:** ✅ Production-ready, enterprise-grade (v2.0.0)
- 99% test coverage (107/108 tests)
- Zero security vulnerabilities
- 32x performance improvement from caching
- Comprehensive error handling and logging

---

## Architecture

### Core Components

**lib.sh (43K, 1,200+ lines)** - Central library with all reusable logic
- PM2 data caching system (5-second TTL, auto-invalidation)
- Intelligent port allocation (3000-3100 range, anti-collision)
- Flox environment initialization with project type detection
- Environment lifecycle (start/stop/remove with idempotent operations)
- Input validation (blocks path traversal, command injection)
- Structured logging with auto-rotation
- Error traps with line number reporting

**config.sh** - Centralized configuration (130+ settings)
- All configurable via environment variables
- Port ranges, SSH settings, logging config, cache TTL
- Tool requirements and validation patterns

**menu_simple_color.sh** - Deprecated stub (redirects to menu.sh)
**menu.sh** - Gum-based interactive menu (requires gum)

### Key Architecture Patterns

**1. PM2 Data Caching (Priority 2 improvement)**
```bash
# Single pm2 jlist call, cached for 5 seconds
get_pm2_data_cached()  # Returns: name|status|port|cwd
invalidate_pm2_cache() # Call after PM2 state changes (start/stop/delete)
```
- Reduces 30+ subprocess spawns to 1 per operation
- 32x performance boost (231ms → 7ms)
- Used by: get_pm2_status(), get_port_from_pm2(), get_all_pm2_ports()

**2. Persistent Ecosystem Files**
Each project gets `/root/project-name/ecosystem.config.cjs`:
```javascript
module.exports = {
  apps: [{
    name: "project-name",
    cwd: "/root/project-name",
    script: "bash",
    args: ["-c", "export PORT=3001 && flox activate -- npm run dev -- --port 3001"],
    env: { PORT: 3001 },  // Persistent port assignment
    autorestart: true,
    watch: false
  }]
};
```
- Port allocation persists across restarts
- Enables SSH tunnel auto-detection on local machine
- CommonJS format (.cjs) for ESM project compatibility

**3. Port Management (Anti-collision)**
```bash
find_available_port()
  ├─ Check active ports (ss -ltn)
  ├─ Check PM2-assigned ports (even if stopped)
  ├─ Double-check before returning (race condition mitigation)
  └─ Returns first available port in 3000-3100 range
```
- Validates both active AND PM2-reserved ports
- Prevents port collisions
- Reuses existing port from ecosystem.config.cjs if present

**4. Project Resolution**
```bash
resolve_project_path("identifier")
  ├─ If absolute path with .flox → return as-is
  └─ If name → search /root for matching .flox directory
```
- Handles both environment names and absolute paths
- Flox directory (.flox) indicates valid project

**5. Input Validation (Security)**
All user inputs validated before processing:
- `validate_project_path()` - Blocks: .., ;, &, |, $, backticks. Allows: /root/*, /home/*, /opt/*
- `validate_env_name()` - Alphanumeric, dash, underscore, dot only
- `validate_repo_name()` - GitHub naming conventions

**6. Error Handling System**
```bash
# Automatic error traps (configurable)
error_trap_handler() {
    log ERROR "Script failed at line $line_number with exit code $exit_code"
}

# Temp file cleanup on exit
cleanup_temp_files() { ... }
trap cleanup_temp_files EXIT
```
- Optional strict mode: `SHIPFLOW_STRICT_MODE=true` (set -euo pipefail)
- Line number logging for debugging
- Automatic temporary file cleanup

**7. JSON Parsing Strategy**
```bash
# Prefers jq (2-5x faster), falls back to python3
if command -v jq >/dev/null 2>&1; then
    data=$(pm2 jlist | jq -r '.[] | .name')  # Fast path
else
    data=$(pm2 jlist | python3 -c "...")     # Fallback
fi
```
- Configurable: `SHIPFLOW_PREFER_JQ=true` (default)
- Graceful degradation if jq not installed

---

## Common Development Tasks

### Running Tests

```bash
# All test suites (107/108 tests)
./test_validation.sh   # Priority 1: Input validation (28/28)
./test_priority2.sh    # Priority 2: Caching, logging, config (23/24)
./test_priority3.sh    # Priority 3: jq, error handling, docs (28/32, 4 optional)

# Syntax validation
bash -n lib.sh
bash -n menu.sh
bash -n menu.sh
```

### Using the Menu Systems

```bash
# Server-side (interactive menus)
./menu.sh               # Unified menu (auto-detects gum, text fallback)
./menu.sh               # Gum-based (requires gum)

# Local machine (SSH tunnels)
cd local
./dev-tunnel.sh         # Auto-creates tunnels for all PM2 apps
./local.sh              # Interactive tunnel manager
```

### Working with Environments

```bash
# Source library functions
source lib.sh

# Start an environment (creates Flox env, finds port, starts PM2)
env_start "myapp"              # By name
env_start "/root/custom/path"  # By absolute path

# Stop environment (idempotent)
env_stop "myapp"

# Remove environment (destructive - deletes directory)
env_remove "myapp"

# Get PM2 data (uses cache)
get_pm2_status "myapp"         # Returns: online|stopped|errored
get_port_from_pm2 "myapp"      # Returns: 3001
invalidate_pm2_cache           # Call after PM2 state changes
```

### Configuration

```bash
# View current config
source config.sh
shipflow_print_config

# Customize via environment variables
export SHIPFLOW_PORT_RANGE_START=4000
export SHIPFLOW_PORT_RANGE_END=4100
export SHIPFLOW_LOG_LEVEL=DEBUG
export SHIPFLOW_PM2_CACHE_TTL=10
export SHIPFLOW_PREFER_JQ=true

# Run menu with custom config
./menu.sh
```

### Viewing Logs

```bash
# Live tail
tail -f /var/log/shipflow/shipflow.log

# Filter by level
grep ERROR /var/log/shipflow/shipflow.log
grep WARNING /var/log/shipflow/shipflow.log

# Recent operations
tail -20 /var/log/shipflow/shipflow.log
```

---

## Framework Auto-Configuration

When starting an environment, ShipFlow automatically configures frameworks to use the `PORT` environment variable:

**Astro** - Modifies `astro.config.mjs`:
```javascript
server: {
  port: parseInt(process.env.PORT) || 3000
}
```

**Vite** - Modifies `vite.config.js/ts`:
```javascript
server: {
  port: parseInt(process.env.PORT) || 3000,
  host: true,
  hmr: {
    protocol: 'ws',
    host: 'localhost',
    port: parseInt(process.env.PORT) || 3000
  }
}
```

**Next.js** - Uses `-p $PORT` flag (automatic)

**Nuxt** - Uses `--port $PORT` flag (automatic)

Detection: Checks package.json for framework dependencies

---

## Critical Implementation Details

### Idempotent Operations (Race Condition Fixes)

All PM2 operations are idempotent - safe to retry without check-then-act races:

```bash
# ❌ OLD (race condition)
if pm2 list | grep -q "app"; then
    pm2 delete "app"
fi

# ✅ NEW (idempotent)
pm2 delete "app" 2>/dev/null || true
```

Applied to: `env_start()`, `env_stop()`, `env_remove()`

### Cache Invalidation

**CRITICAL:** Always invalidate PM2 cache after state changes:

```bash
pm2 start ecosystem.config.cjs
pm2 save
invalidate_pm2_cache  # ← REQUIRED

pm2 stop "myapp"
pm2 save
invalidate_pm2_cache  # ← REQUIRED
```

Locations: Already integrated into env_start/stop/remove

### Web Inspector Injection

`init_web_inspector()` automatically injects `/shipflow-inspector.js` into projects:
- Copies from `injectors/web-inspector.js` to `public/`
- Injects `<script>` tag before `</body>` in index.html or Astro layouts
- Provides visual element inspector with screenshot capabilities
- Called automatically in `env_start()`

### Proper JS Config Parsing

Never use grep for JavaScript config files - use Node.js:

```bash
# ❌ WRONG (brittle)
port=$(grep -oP 'PORT: \K[0-9]+' ecosystem.config.cjs)

# ✅ CORRECT (robust)
port=$(node -e "const cfg = require('$config_file'); console.log(cfg.apps[0].env.PORT)")
```

See: `env_start()` doppler detection

---

## Function Documentation Standard

All key functions are documented with this format:

```bash
# -----------------------------------------------------------------------------
# function_name - Brief description
#
# Description:
#   Detailed multi-line explanation...
#
# Arguments:
#   $1 - First parameter description
#   $2 - Second parameter (optional)
#
# Returns:
#   0 - Success condition
#   1 - Error condition
#
# Outputs:
#   What gets written to stdout
#
# Side Effects:
#   Files created, state modified, cache invalidated, etc.
#
# Example:
#   function_name "arg1" "arg2"
# -----------------------------------------------------------------------------
```

See: lib.sh for 16+ documented functions

---

## Performance Considerations

**PM2 Caching:** Reduces subprocess overhead by 97% (30+ spawns → 1)
- Cache TTL: 5 seconds (configurable)
- Invalidate after: pm2 start/stop/delete operations

**jq vs Python:** 2-5x faster JSON parsing when jq installed
- Optional dependency (graceful fallback to python3)
- Install: `sudo apt install jq`

**Port Finding:** Double-check verification reduces race window
- First check: active + PM2-assigned ports
- Second check: active ports only (right before return)
- Small delay (0.5s) after process kill for port release

---

## Common Pitfalls

1. **Don't manually edit ecosystem.config.cjs** - Regenerated on each start
2. **Don't use relative paths** - All validation requires absolute paths
3. **Don't skip cache invalidation** - PM2 state changes must invalidate cache
4. **Don't assume project names** - Always use `resolve_project_path()` first
5. **Don't parse JS with grep** - Use Node.js `require()` for robustness
6. **Don't check-then-act** - Use idempotent operations (pm2 delete || true)

---

## Required Tools

**Critical (script fails if missing):**
- pm2
- node

**Standard (installed via install.sh):**
- flox (environment isolation)
- git (GitHub operations)
- jq (faster JSON parsing, 2-5x speedup)
- python3 (JSON parsing fallback if jq unavailable)
- fuser/psmisc (port cleanup operations)
- caddy (HTTPS reverse proxy)
- gh (GitHub CLI)

Check: `check_prerequisites()` validates on startup

---

## Configuration Files

**config.sh** - All settings (130+ variables)
**ecosystem.config.cjs** - Per-project PM2 config (auto-generated)
**Caddyfile** - Generated at /etc/caddy/Caddyfile (web publishing)
**Log file** - /var/log/shipflow/shipflow.log (10MB rotation, 30-day retention)

---

## Web Publishing (Caddy + DuckDNS)

Menu option 9 generates reverse proxy config:

```
https://subdomain.duckdns.org/app1 → localhost:3000
https://subdomain.duckdns.org/app2 → localhost:3001
```

- Automatic HTTPS certificates via Caddy
- Free DNS via DuckDNS (no domain required)
- Auto-detects all online PM2 apps with PORT
- Backs up previous Caddyfile before overwrite

---

## File Structure

```
ShipFlow/
├── lib.sh                   # Core library (43K)
├── config.sh                # Centralized config (6.3K)
├── menu.sh                  # Gum-based menu
├── menu_simple_color.sh     # Deprecated (redirects to menu.sh)
├── install.sh               # Server installation
├── local/                   # Local machine scripts
│   ├── dev-tunnel.sh        # Auto SSH tunnels
│   ├── local.sh             # Tunnel manager menu
│   ├── install.sh           # Local setup
│   └── ssh-config           # SSH config template
├── injectors/
│   └── web-inspector.js     # Browser inspector (377 lines)
├── test_*.sh                # Test suites (3 files)
└── *.md                     # Documentation (10 files)
```

---

## Additional Documentation

- **FINAL_REPORT.md** - Complete improvement overview
- **IMPROVEMENTS.md** - All 14 issues analyzed
- **CHANGELOG.md** - Detailed change history
- **ECOSYSTEM-AND-PORTS.md** - Port management deep dive
- **PRIORITY{1,2,3}_SUMMARY.md** - Per-priority implementation details
- **local/README.md** - SSH tunnel setup guide

## Context MCP — Token-Saving Protocol

This project uses a local codebase MCP server for efficient context management. Follow this order strictly:

### Every turn:
1. **Call `context_continue` FIRST** — before any Read, Grep, Glob, or file exploration. This returns files already in memory and avoids re-reading.
2. **If you need more files**, call `context_retrieve` with your query BEFORE using Grep/Glob. It ranks files by relevance.
3. **Use `context_read`** instead of the Read tool when exploring code. It excerpts only relevant portions and tracks your token budget (18K chars/turn).
4. **After editing files**, always call `context_register_edit` with a one-sentence summary.
5. **Store key decisions** with `context_decide` (e.g., "using Vue for interactive islands").

### Rules:
- Do NOT use Read/Grep/Glob for broad exploration before calling `context_continue`
- Do NOT re-read files that `context_continue` says are already in memory
- Prefer `context_read` over Read for all code exploration (Read is fine for files you need in full)
- Do NOT exceed the turn read budget — if `context_read` says budget exhausted, stop reading and work with what you have
- After edits, ALWAYS call `context_register_edit` — this invalidates stale cache
- For large files: call `list_symbols` first, then `context_read "file::symbol"` to read just the function you need
- Call `count_tokens(text)` before reading any file > 200 lines to decide if it's worth the budget
- When user says "done", "bye", or "wrap up" — call `session_wrap` to save context for next session
