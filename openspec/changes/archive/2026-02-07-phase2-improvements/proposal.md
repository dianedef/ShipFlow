## Why

ShipFlow Phase 1 delivered a working CLI with dashboard, restart, smart start, and log viewing. However, the menu system is duplicated across two files (743-line `menu_simple_color.sh` + 568-line `menu.sh`) creating maintenance burden, environment selection lists lack the status indicators that the dashboard already has, there are no batch operations for managing all environments at once, DuckDNS credentials must be re-entered every time, and the menu references `toggle_web_inspector()` which doesn't exist — causing a runtime error.

## What Changes

- **Fix `toggle_web_inspector()` bug** — The "More Options > Toggle Web Inspector" menu item (menu_simple_color.sh:348) calls `toggle_web_inspector()` which is not defined anywhere. `init_web_inspector()` exists in lib.sh but only handles injection, not toggling. Need to implement the toggle function or replace the menu call.
- **Merge two menu files into one** — Combine `menu_simple_color.sh` (text-based, 743 lines) and `menu.sh` (gum-based, 568 lines) into a single `menu.sh` that auto-detects gum availability and falls back to text-based UI. **BREAKING**: `menu_simple_color.sh` will be removed.
- **Status indicators everywhere** — The dashboard (`show_dashboard()` in lib.sh:1930) already uses 🟢/🟡/🔴/⚪ status dots. Extend this to `select_environment()` (menu_simple_color.sh:222) and all other environment selection/listing contexts so users always see which environments are online, stopped, or errored.
- **Batch operations** — Add "Stop All", "Restart All", "Start All" options to the main menu for managing all PM2 environments in one action, with confirmation prompts and proper cache invalidation.
- **Cache DuckDNS credentials** — Store DuckDNS subdomain and token in `~/.shipflow/secrets` (chmod 600) so the "Publish to Web" flow can reuse them without re-prompting. Support overriding cached values when needed.

## Capabilities

### New Capabilities
- `batch-operations`: Stop All, Restart All, and Start All commands that iterate over all PM2 environments with confirmation, progress output, and cache invalidation.
- `credential-cache`: Secure storage of DuckDNS subdomain and token in `~/.shipflow/secrets` with chmod 600 permissions, read/write helpers, and override support.

### Modified Capabilities
- `menu-system`: Merge two menu files into a single unified menu with gum auto-detection and text fallback. Move `select_environment()` and shared UI functions into lib.sh. Remove `menu_simple_color.sh`.
- `status-indicators`: Extract the status icon logic from `show_dashboard()` into a reusable `get_status_icon()` function in lib.sh, and apply it to `select_environment()` and all environment listing contexts.
- `web-inspector`: Fix missing `toggle_web_inspector()` function — implement it in lib.sh to enable/disable the web inspector script injection for a given project (check if injected, add or remove).

## Impact

- **Files modified**: `lib.sh` (new functions: `toggle_web_inspector`, `get_status_icon`, batch ops, credential cache helpers), `menu.sh` (rewritten as unified menu)
- **Files removed**: `menu_simple_color.sh` (merged into `menu.sh`) — **BREAKING** for anyone invoking it directly
- **Files created**: `~/.shipflow/secrets` at runtime (credential cache)
- **Dependencies**: No new dependencies. Gum remains optional (auto-detected).
- **Config**: New settings in `config.sh` for credential cache path (`SHIPFLOW_SECRETS_DIR`)
- **Tests**: Existing test suites (`test_validation.sh`, `test_priority2.sh`, `test_priority3.sh`) unaffected — new tests needed for batch ops and credential cache
