# CLAUDE.md

Guidance for Claude Code when working in this repository.

---

## Project Overview

**ShipFlow** — CLI dev environment manager for servers. Automates deployment with **Flox** (isolation), **PM2** (processes), **Caddy** (HTTPS reverse proxy). Provides SSH tunnel access + public HTTPS URLs via DuckDNS.

---

## Architecture

### Core Files

- **shipflow.sh** — Main entry point (interactive menu)
- **lib.sh** — Central library (ports, PM2 cache, Flox, Caddy, validation, logging)
- **config.sh** — All settings via env vars (ports, SSH, logging, cache TTL)
- **install.sh** — Server setup (Node.js, PM2, Flox, Caddy, gh, skills symlinks)

### Key Patterns

**PM2 Data Caching** — Single `pm2 jlist` call, cached 5 seconds:
```bash
get_pm2_data_cached()  # Returns: name|status|port|cwd
invalidate_pm2_cache() # MUST call after pm2 start/stop/delete
```

**Port Allocation** — Anti-collision in 3000-3100 range:
```bash
find_available_port()  # Checks active ports + PM2-reserved ports
```

**Idempotent Operations** — No check-then-act races:
```bash
pm2 delete "app" 2>/dev/null || true  # Safe to retry
```

**Input Validation** — `validate_project_path()` blocks `..`, `;`, `&`, `|`, `$`, backticks.

**JSON Parsing** — Prefers jq (2-5x faster), falls back to python3.

---

## Common Tasks

```bash
# Launch menu
sf                    # or: shipflow, or: ./shipflow.sh

# Install dependencies (run as root)
sudo ./install.sh

# Run tests
./test_validation.sh  # Input validation
./test_priority2.sh   # Caching, logging, config
./test_priority3.sh   # jq, error handling

# Source library functions
source lib.sh
env_start "myapp"     # Start environment
env_stop "myapp"      # Stop (idempotent)
env_remove "myapp"    # Remove (destructive)
get_pm2_status "myapp"
get_port_from_pm2 "myapp"
```

---

## Critical Rules

1. **Always invalidate cache** after PM2 state changes (`invalidate_pm2_cache`)
2. **Don't parse JS with grep** — use `node -e "require(...)"`
3. **Don't use relative paths** — validation requires absolute paths
4. **Don't manually edit ecosystem.config.cjs** — regenerated on each start
5. **Use idempotent operations** — `pm2 delete || true`, not check-then-act

---

## Framework Auto-Configuration

| Framework | Detection | Port Config |
|-----------|-----------|-------------|
| Astro | package.json | `server.port = PORT` in config |
| Vite | package.json | `--port $PORT --host` |
| Next.js | package.json | `-p $PORT` (automatic) |
| Nuxt | package.json | `--port $PORT` |
| Expo | package.json | Tunnel mode, no fixed port |

---

## File Structure

```
ShipFlow/
├── shipflow.sh                 # Main menu
├── lib.sh                      # Core library
├── config.sh                   # Configuration
├── install.sh                  # Server installation
├── .claude/skills/             # 39 Claude Code skills
├── .claude/statusline-starship.sh  # Status bar
├── local/                      # SSH tunnel scripts
│   ├── dev-tunnel.sh
│   ├── local.sh
│   └── install.sh
├── injectors/web-inspector.js  # Browser inspector
└── test_*.sh                   # Test suites
```
