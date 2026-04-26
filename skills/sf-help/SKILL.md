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
| `/sf-auth-debug` | Browser-auth diagnosis for Clerk, OAuth, Google/YouTube, Convex, sessions, callbacks | `<bug/URL/flow>` |
| `/sf-model` | Choose model, reasoning level, and fast/cheap fallback before execution | `<task description>` or `<spec path>` |
| `/sf-tasks` | Track work, check off items, suggest next | `[focus area]` |
| `/sf-priorities` | Re-rank by impact/effort matrix | `impact`, `effort`, `blockers`, `quick-wins` |
| `/sf-backlog` | Capture ideas, defer non-urgent | `add "idea"`, `defer`, `review`, `clean` |
| `/sf-review` | Session summary, update docs | `daily`, `weekly`, `sprint`, `release` |
| `/sf-resume` | Ultra-fast current-thread recap and close/keep-open verdict | `court`, `ultra-court` |

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
| `/sf-ship` | Quick ship by default; full close+ship with explicit keyword | `"commit message"`, `end la tache`, `skip-check` |
| `/sf-check` | Typecheck + lint + build + test | `[check types]`, `fix`, `nofix` |
| `/sf-deploy` | Full deploy: check → ship → restart → verify | `skip-check` |
| `/sf-status` | Cross-project git dashboard | (none) |

Note: `/sf-verify` now includes guided next-step prompting when verdict is not ready (`corriger maintenant`, `repasser par spec`, `stop/reprendre`).
Note: `/sf-auth-debug` is the required diagnostic path for auth bugs that need browser evidence before implementation.
Note: `/sf-start` now reuses the `sf-model` routing matrix and can choose `single-agent` vs `multi-agent` execution with explicit file ownership and per-group model overrides.
Note: `/sf-spec` → `/sf-ready` → `/sf-start` → `/sf-verify` now share a `User Story` contract and should ask targeted user questions whenever behavior, scope, or security is still ambiguous.

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

### Guided decision prompts (new)
| Skill | When it prompts | Choices |
|-------|------------------|---------|
| `/sf-fix` | Bug scope is borderline | Direct fix / Spec-first / Diagnostic only |
| `/sf-start` | Scope triage is ambiguous | Execute direct / Spec-first / Clarify first (`/sf-explore`) |
| `/sf-end` | Completion is unclear | Full close / Partial close / Summary only |
| `/sf-status` | No view mode argument | Issues only / Dirty only / All projects |
| `/sf-context` | Context priming completed | Proceed now / Add 1 key file / Refine target |
| `/sf-spec` | Small/local change | Spec light / Spec full / Auto by risk |
| `/sf-verify` | Verdict is not ready | Fix now / Return to spec / Stop and resume later |

### Clarification prompts (important)
- A skill should ask the user when the answer materially changes behavior, scope, permissions, data exposure, tenant isolation, retry/rollback policy, or external side effects.
- Do not ask broad "anything else?" questions. Ask short, decision-forcing questions anchored in the code or spec.
- Good examples:
  - "Cette action doit-elle être réservée aux admins côté serveur, ou un membre connecté suffit-il ?"
  - "En cas d'échec partiel, on retry, on garde l'état pending, ou on annule tout ?"
  - "Cette donnée peut-elle être visible entre organisations, même en lecture seule ?"

### Security-by-default
- Public or high-value products must assume hostile inputs, bypass attempts, and cross-system fallout.
- `sf-spec` must capture trust assumptions, allowed/forbidden actors, and key abuse cases when relevant.
- `sf-ready` must block specs with unresolved security-significant questions.
- `sf-start` must not pick silent defaults when ambiguity affects auth, data, money, tenant boundaries, or workflow integrity.
- `sf-verify` must explicitly call out security assumptions it cannot prove.
- `sf-fix` must reroute instead of applying a "small fix" when the bug may actually hide a contract or security decision.
- `sf-scaffold` must preserve existing product/system coherence and avoid generating unsafe public-by-default artifacts.
- `sf-check` and `sf-prod` must surface risky unknowns clearly instead of treating green checks as proof of product safety.
- `sf-audit-code` must review business-flow abuse and product coherence, not just code style and raw security smells.

### Product coherence
- A technically valid change is not enough if it weakens the product promise, creates a confusing flow, or diverges from established project patterns.
- Skills should verify coherence across user story, UI behavior, permissions, data lifecycle, failure handling, and linked systems.
- If a requested change conflicts with the existing product model, the skill should surface the conflict explicitly instead of normalizing it silently.

### Documentation coherence
- When a feature behavior changes, active docs must stay aligned: README, docs, guides, examples, FAQ, onboarding, pricing, changelog, support copy, screenshots, and public pages when relevant.
- Specs should name impacted docs or state `None, because ...`.
- Implementation and verification skills should update or flag stale docs instead of treating documentation as optional cleanup.
- Stale docs are a product risk when they affect setup, security, payments, permissions, API usage, migration, destructive actions, or support expectations.

### Artifact metadata
- ShipFlow internal artifacts must start with YAML frontmatter using the ShipFlow schema. This includes specs, reviews, research reports, audit reports, verification reports, architecture notes, decision records, and project documentation generated by ShipFlow.
- Operational trackers/registries are excluded: do not add metadata frontmatter to `TASKS.md`, `AUDIT_LOG.md`, or `PROJECTS.md`. Extract durable decisions from them into separate artifacts instead.
- Required common fields for reusable ShipFlow artifacts: `artifact`, `metadata_schema_version`, `artifact_version`, `project`, `created`, `updated`, `status`, `scope`, `owner`, `source_skill`.
- Use structured fields when relevant: `user_story`, `confidence`, `risk_level`, `security_impact`, `docs_impact`, `linked_systems`, `depends_on`, `supersedes`, `evidence`, `next_step`.
- `metadata_schema_version` versions the ShipFlow metadata format. `artifact_version` versions the document's decision content.
- Specs and implementation artifacts should record which business, brand, technical, API, or architecture artifact versions they depend on through `depends_on`.
- Version bump rules for `artifact_version`: patch = clarification/no decision change; minor = changed assumption/scope/audience/API/pricing/docs impact; major = incompatible product promise/business model/security posture/architecture direction.
- Draft or migrated artifacts start at `0.x.y`; first reviewed active contract should become `1.0.0`.
- If a dependency in `depends_on` is stale, missing, or newer than the version used by the spec, route through `/sf-docs audit` or `/sf-ready` before implementation/closure.
- Do not hide uncertainty. If proof is partial, metadata should say `confidence: medium|low`, `status: draft|partial|reviewed`, or `risk_level: medium|high`.
- Application content keeps its project schema. This includes `src/content/**`, blog posts, SEO pages, framework docs, MDX content, and any file parsed by the app runtime.
- Existing ShipFlow artifacts without metadata should be migrated to the standard schema during adoption or the next time the relevant skill touches them.
- `shipflow_data` is the control plane for trackers and registry files. Per-project business, brand, guideline, spec, research, and decision docs should live in the project repo, not in `shipflow_data`.

### Honest closure and shipping
- `sf-end`, `sf-review`, and `sf-ship` must distinguish "work tracked and summarized" from "product actually validated".
- A commit, push, changelog entry, or green lightweight check is not proof that the main user flow, security posture, or production behavior is correct.
- When closure or shipping status is ambiguous, the skill should ask a targeted question or explicitly report the remaining proof/doc gap.

### Audit and dependency posture
- `sf-audit` should orchestrate domain audits around linked systems, user outcomes, and downstream consequences, not just isolated file quality.
- `sf-deps` should treat dependency changes as product and security changes: supply chain, trust, runtime blast radius, and commercial license risk all matter.
- Business-facing audits should treat public promises as contracts: if GTM, copy, SEO, or design promises something the app/docs do not prove, the issue is material.

### One-pass rule
- A `ready` spec must let a fresh agent implement without reading the chat history.
- A `ready` spec must also make the user outcome and the security posture understandable without hidden assumptions.
- Specs now need explicit dependencies, linked systems / consequences, and execution notes.
- `sf-start` should choose a primary execution model before coding, using the shared `sf-model` routing reference.
- For non-trivial work, `sf-start` may choose `single-agent` or `multi-agent`; if `multi-agent` is chosen, write ownership and integration responsibility must be explicit.
- When a skill launches agents, the prompt should already include relevant context files and a no-follow-up rule.
- If the next step should run on fresh context and the environment cannot spawn it cleanly, the skill must ask the user to open a new thread.
- If that context cannot be made explicit, route back to `/sf-spec` or `/sf-ready` instead of coding.

### Shared tracking file protocol
- Shared files such as `~/shipflow_data/TASKS.md`, `~/shipflow_data/AUDIT_LOG.md`, `~/shipflow_data/PROJECTS.md`, and persistent workspace notes must never be edited from stale context.
- A read at skill start is informative only.
- Right before each write, the skill must re-read the target file from disk and use that version as authoritative.
- The write must be minimal and targeted to the intended row or subsection, never a whole-file rewrite.
- If the expected anchor moved, re-read once and recompute.
- If it is still ambiguous after the second read, stop and ask the user instead of forcing the write.
- Skills that only inspect these files must say they are read-only in that context.

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
~/TASKS.md              # Master tracker (symlink to shipflow_data)
~/AUDIT_LOG.md          # Audit history (symlink to shipflow_data)
~/shipflow_data/
├── TASKS.md            # Source of truth (12 projects)
├── AUDIT_LOG.md        # Cross-project audit scores
└── PROJECTS.md         # Project registry + domain matrix (8 domains)
```

### Rules
1. **Master file first**: `/sf-tasks`, `/sf-priorities`, `/sf-backlog` always update `~/TASKS.md`
2. **Local files too**: If a project has its own `TASKS.md`, update both
3. **Dashboard sync**: Update the Dashboard table when project phases change
4. **Prefix items**: Backlog entries include project name (e.g., `- tubeflow: Add dark mode`)

### TASKS vs BACKLOG convention
- `TASKS.md` = active, prioritized, executable work
- `BACKLOG.md` = deferred ideas and parking lot
- Promote from `BACKLOG.md` to `TASKS.md` only when the item is ready to be executed now

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
/sf-ship "Feature description"  # Quick mode (default): commit + push
/sf-ship "end la tache"         # Full mode: updates tasks/changelog + commit + push
/sf-tasks                    # Mark completed, get next
```

### Choose execution model
```bash
/sf-model specs/my-spec.md      # Recommend model + reasoning + fallbacks
/sf-start specs/my-spec.md      # Reuses the same routing logic internally
```

### Fix a bug
```bash
/sf-fix "short bug description"    # Triage + direct fix or route
/sf-auth-debug "Google login returns to sign-in" # Reproduce auth flow and isolate the failure point
# If local and clear -> fix now, then verify
# If ambiguous/non-trivial -> /sf-spec -> /sf-ready -> /sf-start
```

### Prepare context only
```bash
/sf-context "task description"      # Primes context, then asks what to do next
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
