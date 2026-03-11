# 🎨 ShipFlow UX Improvement Proposal

**Date:** 2026-01-24
**Current State:** 2 menus with 10-11 options each, significant redundancy
**Goal:** Streamline UX, reduce redundancy, improve workflow efficiency

---

## 📊 Current UX Issues

### 1. **Redundant Commands**

| Current Problem | Impact |
|----------------|--------|
| Two "Start Environment" options (#7 & #8) | Confusing - users don't know which to use |
| "List Environments" AND "Show URLs" (separate in menu.sh) | Extra step - should be combined |
| "Navigate /root" AND "Open code directory" | Similar purpose, unclear distinction |
| No "Restart" option | Forces users to Stop → Start (2 steps) |

### 2. **Poor Command Organization**

**Current menu** (10 options, no grouping):
```
1. 📁 Naviguer dans /root
2. 📋 Lister les environnements et URLs
3. 🛑 Stopper un environnement
4. 📝 Ouvrir le répertoire de code
5. 🚀 Déployer un repo GitHub
6. 🗑️ Supprimer un environnement
7. ▶️ Démarrer un environnement (détecté)
8. ▶️ Démarrer un environnement (chemin personnalisé)
9. 🌐 Publier sur le web
10. ❌ Quitter
```

**Issues:**
- No logical flow (stop/start/deploy mixed)
- Common tasks not prioritized
- No visual grouping

### 3. **Missing Common Operations**

- ❌ Restart environment (stop + start in one)
- ❌ View logs for debugging
- ❌ Check environment health/status
- ❌ Batch operations (stop all, restart all)
- ❌ Quick status dashboard

---

## ✨ Proposed Improvements

### **Option A: Streamlined Menu (Recommended)**

Reduce from **10 options to 7 core actions** with smart defaults:

```
╔══════════════════════════════════════════════════╗
║               ShipFlow DevServer               ║
╚══════════════════════════════════════════════════╝

📊 OVERVIEW
  1) Dashboard - View all environments at a glance

🚀 ENVIRONMENT MANAGEMENT
  2) Start/Deploy - Quick start (detects projects automatically)
  3) Restart - Restart an environment
  4) Stop - Stop an environment
  5) Remove - Delete an environment

🌐 PUBLISHING
  6) Publish to Web - Configure HTTPS (Caddy + DuckDNS)

⚙️  ADVANCED
  7) More Options ⟶
     ├─ View Logs
     ├─ Open Code Directory
     ├─ Navigate Projects
     ├─ Toggle Web Inspector
     ├─ Batch Operations
     └─ Settings

0) Exit
```

**Key Changes:**
- ✅ Merged "List" + "Show URLs" into **Dashboard** (one screen, all info)
- ✅ Combined two "Start" options into **one smart Start** (auto-detects or asks for path)
- ✅ Added **Restart** (most common operation)
- ✅ Moved less common tasks to **"Advanced"** submenu
- ✅ Clear categorization with section headers
- ✅ 7 main options instead of 10 (30% reduction)

---

### **Option B: Grouped Menu (More Detailed)**

Group commands by purpose:

```
╔══════════════════════════════════════════════════╗
║               ShipFlow DevServer               ║
╚══════════════════════════════════════════════════╝

[VIEW]
  1) 📊 Dashboard - All environments, URLs, ports, status

[MANAGE]
  2) ▶️  Start   - Launch an environment
  3) 🔄 Restart - Restart an environment
  4) ⏸️  Stop    - Stop an environment
  5) 🗑️  Remove  - Delete an environment

[CREATE]
  6) 🚀 Deploy - GitHub repo deployment
  7) 🌐 Publish - Configure web access (HTTPS)

[TOOLS]
  8) 📝 Logs    - View application logs
  9) ⚙️  More   - Advanced options

0) Exit
```

**Benefits:**
- Clear mental model (View → Manage → Create → Tools)
- Grouped by user intent
- Still only 9 main options

---

### **Option C: Context-Aware Menu (Most Advanced)**

Show different options based on current state:

```
╔══════════════════════════════════════════════════╗
║               ShipFlow DevServer               ║
║             3 environments running               ║
╚══════════════════════════════════════════════════╝

Quick Actions:
  ⚡ [s] Start new    [r] Restart    [l] Logs    [d] Dashboard

Environments:
  🟢 my-app          :3001   https://myapp.duckdns.org
  🟢 api-server      :3002   http://localhost:3002
  🟡 test-env        :3003   (stopped)

Actions:
  1) Manage environments ⟶
  2) Deploy new project
  3) Publish to web
  4) Advanced options
  0) Exit

Choose [1-4/0] or quick action [s/r/l/d]:
```

**Benefits:**
- Status visible immediately (no need to "list")
- Quick actions for power users
- Context-aware (shows running environments)
- Most information on one screen

---

## 🎯 Specific Improvements to Implement

### **Priority 1: Quick Wins** (1-2 hours)

#### 1.1 Merge List + URLs → Dashboard
**Before:**
- Option 2: "Lister les environnements"
- Option 3: "Afficher les URLs" (separate)

**After:**
```bash
Option 1: "📊 Dashboard - Overview"

Output:
╔══════════════════════════════════════════════════╗
║               Active Environments                ║
╚══════════════════════════════════════════════════╝

🟢 my-app             Port: 3001    http://localhost:3001
🟢 api-server         Port: 3002    http://localhost:3002
🟡 test-env           Port: 3003    (stopped)

Web URLs:
  https://myapp.duckdns.org/my-app
  https://myapp.duckdns.org/api-server
```

**Code Location:** Create new function `show_dashboard()` in lib.sh

---

#### 1.2 Add Restart Option
**Current:** Stop (#3) → Start (#7) = 2 steps

**Proposed:**
```bash
Option 3: "🔄 Restart Environment"

Behavior:
1. List running environments
2. User selects one
3. Auto: pm2 restart <env_name>
4. Invalidate cache + show success
```

**Code Location:** Add `env_restart()` function in lib.sh

---

#### 1.3 Combine Two "Start" Options
**Current:**
- Option 7: "Démarrer un environnement (détecté)"
- Option 8: "Démarrer un environnement (chemin personnalisé)"

**Proposed:**
```bash
Option 2: "▶️ Start/Deploy Environment"

Smart behavior:
1. Show: "Choose a project to start:"
2. List detected projects in /root (find -maxdepth 2)
3. Option at end: "⊕ Custom path / GitHub repo"
4. If custom selected → ask "Local path or GitHub URL?"
   - If path → validate + start
   - If GitHub → deploy workflow
```

**Benefits:**
- Single menu option
- Progressive disclosure (simple → advanced)
- Covers all use cases

---

#### 1.4 Add Quick Log Viewer
```bash
Option 8: "📝 View Logs"

Behavior:
1. List all environments
2. User selects one
3. Run: pm2 logs <env_name> --lines 50
4. Press any key to return to menu
```

**Code Location:** Add `view_environment_logs()` in lib.sh

---

### **Priority 2: Medium Improvements** (4-6 hours)

#### 2.1 Consolidate Menus into One
**Problem:** Maintain 2 nearly-identical menu files

**Solution:** Single menu with fallback

```bash
# menu.sh (new unified version)
if command -v gum >/dev/null 2>&1; then
    use_gum_menu  # Pretty UI
else
    use_simple_menu  # Text fallback
fi
```

**Benefits:**
- Single source of truth
- Automatic feature parity
- Easier maintenance

---

#### 2.2 Add Status Indicators in Environment Lists
**Current:**
```
my-app
api-server
test-env
```

**Proposed:**
```
🟢 my-app          :3001   Online   [↻ Restart | ⏹ Stop | 📝 Logs]
🟢 api-server      :3002   Online   [↻ Restart | ⏹ Stop | 📝 Logs]
🟡 test-env        :3003   Stopped  [▶️ Start | 🗑️ Remove]
🔴 broken-app      :3004   Error    [📝 Logs | 🗑️ Remove]
```

**Implementation:** Enhance `list_all_environments()` to include inline actions

---

#### 2.3 Batch Operations Submenu
```bash
Advanced → Batch Operations

1) ⏹ Stop All Environments
2) ▶️ Start All Environments
3) 🔄 Restart All Environments
4) 🗑️ Remove All Stopped Environments
5) ← Back
```

---

#### 2.4 Cache DuckDNS Credentials
**Current:** Ask for subdomain + token every time

**Proposed:**
```bash
First time:
  Enter DuckDNS subdomain: myapp
  Enter DuckDNS token: ********
  [✓] Save credentials? (stored in ~/.shipflow/secrets) [y/N]

Next time:
  Using saved credentials: myapp.duckdns.org
  [Change credentials?]
```

**Security:** Store in `~/.shipflow/secrets` with chmod 600

---

### **Priority 3: Advanced Features** (8+ hours)

#### 3.1 Interactive Dashboard (Top Priority)
Full-screen TUI with live updates:

```
╔══════════════════════════════════════════════════╗
║ ShipFlow Dashboard                      ⟳ Auto║
╚══════════════════════════════════════════════════╝

┌─ Running Environments (3) ──────────────────────┐
│ 🟢 my-app         :3001  CPU: 2%   Mem: 45MB    │
│ 🟢 api-server     :3002  CPU: 1%   Mem: 38MB    │
│ 🟢 frontend       :3000  CPU: 5%   Mem: 120MB   │
└──────────────────────────────────────────────────┘

┌─ Stopped Environments (1) ──────────────────────┐
│ 🟡 test-env       :3003  (stopped 2h ago)       │
└──────────────────────────────────────────────────┘

┌─ Web URLs ───────────────────────────────────────┐
│ https://myapp.duckdns.org/my-app                 │
│ https://myapp.duckdns.org/api-server             │
└──────────────────────────────────────────────────┘

[r] Refresh  [s] Start  [q] Quit  [?] Help
```

**Tech:** Could use `dialog`, `whiptail`, or build custom with ANSI

---

#### 3.2 Environment Templates
```bash
Option 6: "🚀 Deploy New Project"

Choose a template:
  1) 📦 Node.js Express API
  2) ⚛️  React + Vite
  3) 🐍 Python FastAPI
  4) 🎨 Astro Static Site
  5) 📘 Next.js Fullstack
  6) 🔧 Custom (empty project)
  7) 📁 From GitHub

> User selects template
> Auto-generate boilerplate
> Initialize Flox with correct dependencies
> Start development server
```

---

#### 3.3 Health Checks
```bash
Option: "🏥 Health Check"

Scanning environments...

✓ my-app
  ├─ Process: Running (PM2)
  ├─ Port 3001: Responding
  ├─ HTTP: 200 OK
  └─ Flox: Active

✗ broken-app
  ├─ Process: Crashed (exit code 1)
  ├─ Port 3004: Not responding
  ├─ Last error: "MODULE_NOT_FOUND"
  └─ Logs: pm2 logs broken-app
```

---

## 📋 Recommended Implementation Plan

### **Phase 1: Foundation** (Week 1)
1. ✅ Create `UX_IMPROVEMENT_PROPOSAL.md` (this document)
2. ⬜ Implement Dashboard (merge list + URLs)
3. ⬜ Add Restart option
4. ⬜ Combine two Start options into one smart option
5. ⬜ Add View Logs option

**Deliverable:** 7-option menu with core improvements

---

### **Phase 2: Consolidation** (Week 2)
6. ⬜ Merge menu.sh + menu_simple_color.sh into one file
7. ⬜ Add status indicators (🟢/🟡/🔴) to environment lists
8. ⬜ Implement batch operations submenu
9. ⬜ Add DuckDNS credential caching

**Deliverable:** Single unified menu with advanced features

---

### **Phase 3: Polish** (Week 3)
10. ⬜ Build interactive dashboard
11. ⬜ Add environment templates
12. ⬜ Implement health checks
13. ⬜ Add fuzzy search for environment selection

**Deliverable:** Production-ready TUI with professional UX

---

## 🎨 Visual Mockup Comparison

### **Before: Current Menu**
```
📁 Naviguer dans /root
📋 Lister les environnements et URLs
🛑 Stopper un environnement
📝 Ouvrir le répertoire de code
🚀 Déployer un repo GitHub
🗑️ Supprimer un environnement
▶️ Démarrer un environnement (détecté)
▶️ Démarrer un environnement (chemin personnalisé)
🌐 Publier sur le web
❌ Quitter
```
**Issues:** 10 options, unclear grouping, redundancy

---

### **After: Streamlined Menu (Option A)**
```
╔══════════════════════════════════════════════════╗
║               ShipFlow DevServer               ║
╚══════════════════════════════════════════════════╝

📊 OVERVIEW
  1) Dashboard

🚀 MANAGE
  2) Start/Deploy
  3) Restart
  4) Stop
  5) Remove

🌐 PUBLISHING
  6) Publish to Web

⚙️ ADVANCED
  7) More Options ⟶

0) Exit
```
**Benefits:** 7 options, clear groups, no redundancy

---

## 💡 Quick Decision Matrix

Not sure which option to choose? Use this:

| If you want... | Choose |
|---------------|--------|
| **Fastest improvement** | Priority 1 tasks (Dashboard, Restart, combine Start) |
| **Best long-term UX** | Option A (Streamlined Menu) |
| **Most professional** | Phase 3 (Interactive Dashboard) |
| **Easiest maintenance** | Consolidate menus (Priority 2.1) |

---

## 📊 Expected Impact

| Metric | Before | After (Phase 1) | After (Phase 3) |
|--------|--------|-----------------|-----------------|
| Menu options | 10 | 7 | 7 |
| Avg. clicks to start | 2-3 | 1-2 | 1 |
| Avg. clicks to view status | 2 | 1 | 0 (always visible) |
| Time to restart | ~10s (2 steps) | ~5s (1 step) | ~3s (quick action) |
| Code duplication | HIGH | MEDIUM | LOW |
| User satisfaction | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

---

## 🚀 Next Steps

**To proceed:**

1. **Review this proposal** - Which option do you prefer?
   - Option A: Streamlined (7 options, simple)
   - Option B: Grouped (9 options, detailed)
   - Option C: Context-aware (most advanced)

2. **Choose implementation phase:**
   - Phase 1 only (quick wins)
   - Phases 1-2 (consolidation)
   - Full implementation (all 3 phases)

3. **Approve changes** - I'll implement the selected improvements

---

## 📝 Questions for You

Before implementing, please clarify:

1. **Menu preference:** Option A, B, or C?
2. **DuckDNS credentials:** Should we cache them? (security vs convenience)
3. **Gum dependency:** Keep menu.sh with gum, or consolidate to simple menu only?
4. **Breaking changes:** OK to renumber menu options? (will affect user muscle memory)
5. **Advanced features:** Priority 3 features desired, or focus on Phase 1-2 only?

Let me know your preferences and I'll start implementing! 🎯
