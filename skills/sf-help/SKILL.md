---
name: sf-help
description: Cheatsheet for the full task tracking and audit system — skills, modes, prompts, workflows
disable-model-invocation: true
argument-hint: [optional: tasks, audit, workflows, prompts]
---

# Skill System Cheatsheet

Quick reference for the skill system, modes, and workflows.

---

## Skills at a Glance

### Task & Workflow

| Skill | Purpose | Arguments |
|-------|---------|-----------|
| `/sf-fix` | Bug-first intake and routing (direct fix vs spec-first) | `<bug description>` |
| `/sf-tasks` | Track work, check off items, suggest next | `[focus area]` |
| `/sf-priorities` | Re-rank by impact/effort matrix | `impact`, `effort`, `blockers`, `quick-wins` |
| `/sf-backlog` | Capture ideas, defer non-urgent | `add "idea"`, `defer`, `review`, `clean` |
| `/sf-review` | Session summary, update docs | `daily`, `weekly`, `sprint`, `release` |

### Audit (8 domains)

| Skill | Purpose | Arguments |
|-------|---------|-----------|
| `/sf-audit` | Master orchestrator (all 8 domains) | `@file`, `global`, or nothing |
| `/sf-audit-code` | Architecture, security, reliability, system fit (anti-duplication) | `@file`, `global`, or nothing |
| `/sf-audit-design` | UI/UX, a11y, responsiveness | `@file`, `global`, or nothing |
| `/sf-audit-copy` | Copywriting, tone, CTAs | `@file`, `global`, or nothing |
| `/sf-audit-seo` | Meta tags, structured data, links | `@file`, `global`, or nothing |
| `/sf-audit-gtm` | Go-to-market, conversion, trust | `@file`, `global`, or nothing |
| `/sf-audit-translate` | i18n completeness, consistency | `@file`, `global`, or nothing |
| `/sf-deps` | Dependencies: vulns, outdated, unused, licenses | `global`, or nothing |
| `/sf-perf` | Performance: bundle, CWV, rendering, data | `@file`, `global`, or nothing |

### DevOps & Shipping

| Skill | Purpose | Arguments |
|-------|---------|-----------|
| `/sf-ship` | Stage, commit, push | `"commit message"` |
| `/sf-check` | Typecheck + lint + build + test | `[check types]`, `fix`, `nofix` |
| `/sf-deploy` | Full deploy: check → ship → restart → verify | `skip-check` |
| `/sf-status` | Cross-project git dashboard | (none) |

### Scaffolding & Init

| Skill | Purpose | Arguments |
|-------|---------|-----------|
| `/sf-init` | Bootstrap new project for ShipFlow | `[project-path]` |
| `/sf-scaffold` | Generate files matching project patterns | `<type> <name>` |

### Research & Documentation

| Skill | Purpose | Arguments |
|-------|---------|-----------|
| `/sf-research` | Deep web research → saved report | `<topic>` |
| `/sf-docs` | Generate/update docs from code | `@file`, `readme`, `api`, `components` |
| `/sf-enrich` | Web research + content upgrade | `@file` or `folder/` |

### Upgrades

| Skill | Purpose | Arguments |
|-------|---------|-----------|
| `/sf-migrate` | Framework upgrade assistant | `[package@version]` |
| `/sf-changelog` | Auto-generate CHANGELOG from git | `[tag]`, `[date]`, `all` |

---

## Audit Modes (3 modes)

```bash
# PAGE MODE — audit a single file
/sf-audit-seo @src/pages/index.astro

# PROJECT MODE — audit current project (default)
/sf-audit-code

# GLOBAL MODE — audit ALL applicable projects
/sf-audit global
/sf-audit-seo global
```

**Domain applicability**: Not all audits apply to all projects. Global mode reads `~/shipflow_data/PROJECTS.md` and skips inapplicable domains (e.g., no SEO for `my-robots`, no Deps for `BuildFlowz`).

**8 domains**: Code, Design, Copy, SEO, GTM, Translate, Deps, Perf.

**Scoring**: Every audit scores categories A/B/C/D, fixes issues, logs to `AUDIT_LOG.md`, creates tasks in `TASKS.md`.

---

## Interactive Prompts

Skills auto-detect context and prompt when needed:

### Workspace root detection
Run any skill from `~/` (no project markers) and it asks **"Which project(s)?"** instead of failing.

### Scope selection
| Skill | Prompt | Options |
|-------|--------|---------|
| `/sf-review` | "What time scope?" | Daily, Weekly, Sprint, Release |
| `/sf-check` | "Which checks?" | Typecheck, Lint, Build, Test, Dependencies |
| `/sf-audit` | "Which domains?" | Code, Design, Copy, SEO, GTM, Translate, Deps, Perf |
| `/sf-audit global` | "Which projects?" + "Which domains?" | Checkboxes for both |
| `/sf-init` | "Confirm domain applicability?" | Checkboxes for 8 domains |

### When prompts are skipped
Provide explicit arguments and prompts don't appear:
```bash
/sf-review weekly          # No scope prompt
/sf-audit-seo global      # No domain prompt (SEO only)
/sf-check typecheck        # No check selection prompt
```

---

## Multi-Project Tracking

### Architecture
```
~/TASKS.md              # Master tracker (symlink to ShipFlow)
~/AUDIT_LOG.md          # Audit history (symlink to ShipFlow)
~/ShipFlow/
├── TASKS.md            # Source of truth (12 projects)
├── AUDIT_LOG.md        # Cross-project audit scores
└── PROJECTS.md         # Project registry + domain matrix (8 domains)
```

### Rules
1. **Master file first**: `/sf-tasks`, `/sf-priorities`, `/sf-backlog` always update `~/TASKS.md`
2. **Local files too**: If a project has its own `TASKS.md`, update both
3. **Dashboard sync**: Update the Dashboard table when project phases change
4. **Prefix items**: Backlog entries include project name (e.g., `- tubeflow: Add dark mode`)

---

## Workflow Cycle

```
/sf-backlog  →  /sf-priorities  →  /sf-tasks  →  (work)  →  /sf-review
 capture               rank                    track               code        reflect
```

### Daily (5 min)
```bash
/sf-tasks                    # Morning: see what's next
# ... work ...
/sf-tasks                    # Evening: check off done items
```

### Weekly (15 min)
```bash
/sf-review weekly            # What happened this week
/sf-priorities               # Re-rank for next week
/sf-backlog review           # Promote ready items
/sf-backlog defer            # Clear non-urgent from active
```

### Sprint (30 min)
```bash
/sf-review sprint            # Comprehensive review
/sf-backlog clean            # Remove stale items
/sf-priorities impact        # Plan high-value work
```

### New project
```bash
/sf-init /path/to/project    # Bootstrap tracking
/sf-audit                    # Initial baseline audit
/sf-tasks                    # Start tracking work
```

### Ship something
```bash
/sf-check                    # Verify everything passes
/sf-ship "Feature description"  # Commit + push
/sf-tasks                    # Mark completed, get next
```

### Fix a bug
```bash
/sf-fix "short bug description"    # Triage and route
# If local and clear -> direct fix flow
# If ambiguous/non-trivial -> /sf-spec -> /sf-ready -> /sf-start
```

### Full deploy
```bash
/sf-deploy                   # Check → ship → restart → verify
# or
/sf-deploy skip-check        # Skip checks (use with caution)
```

### Framework upgrade
```bash
/sf-migrate astro@5          # Research + plan + apply
/sf-check                    # Verify build
/sf-changelog                # Document the upgrade
/sf-ship                     # Commit and push
```

### Full audit
```bash
/sf-audit                    # All 8 domains, current project
/sf-audit global             # All 8 domains, all projects
/sf-audit-code               # Code only, current project
/sf-deps global              # Dependencies across all projects
/sf-perf @src/pages/index.astro  # Performance for one file
```

### Cross-project overview
```bash
/sf-status                   # Git status dashboard for all projects
```

---

## Priority Levels

| Level | Label | When to use |
|-------|-------|-------------|
| P0 | Critical | Blockers, security, high-ROI + low-effort |
| P1 | High | Important features, medium effort |
| P2 | Medium | Standard work, nice improvements |
| P3 | Low | Nice-to-have, can wait |

---

## Audit Scoring

| Grade | Meaning |
|-------|---------|
| A | Excellent — no action needed |
| B | Good — minor improvements |
| C | Needs work — issues found and fixed |
| D | Poor — significant problems |

---

## File Reference

| File | Location | Purpose |
|------|----------|---------|
| `TASKS.md` | `~/` (master) + project dirs | Task tracking |
| `BACKLOG.md` | Project dirs | Deferred ideas |
| `AUDIT_LOG.md` | `~/` (master) + project dirs | Audit score history |
| `CHANGELOG.md` | Project dirs | Release notes |
| `REVIEW-*.md` | Project dirs | Review reports |
| `PROJECTS.md` | `~/ShipFlow/` | Project registry + domain matrix |

---

## Quick Answers

**Too many tasks?** → `/sf-priorities effort` then `/sf-backlog defer`

**Don't know what's next?** → `/sf-priorities blockers`

**New idea mid-work?** → `/sf-backlog add "description"`

**End of day?** → `/sf-tasks` then `/sf-review daily`

**Before deploy?** → `/sf-deploy` (runs check + ship + verify automatically)

**Audit everything?** → `/sf-audit global` (all 8 domains)

**Which projects need SEO?** → `/sf-audit-seo global` (auto-filters)

**New project?** → `/sf-init` (bootstrap tracking)

**Outdated dependencies?** → `/sf-deps` (full audit) or `/sf-check` (quick scan)

**Need to upgrade a framework?** → `/sf-migrate package@version`

**Generate docs?** → `/sf-docs readme` or `/sf-docs api`

**Research a topic?** → `/sf-research "topic"`

---

*Run `/sf-help` anytime for this reference.*
