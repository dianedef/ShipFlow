---
name: sf-illustrate
description: Generate SVG illustrations from markdown content — diagrams, charts, infographics. Reads source content, identifies visual opportunities, creates clean SVGs, and integrates them into articles.
argument-hint: <file-or-directory> [optional: "list" to only list opportunities]
---

## Context

- Current directory: !`pwd`
- Project name: !`basename $(pwd)`
- Existing visuals: !`find . -name "*.svg" -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null | head -20 || echo "none"`

## Your task

Generate professional SVG illustrations from markdown content. Read the source, identify what deserves a visual, create clean SVGs, and integrate them.

### Step 1 — Identify the scope

**If `$ARGUMENTS` is a file path** → single file mode. Read that file.

**If `$ARGUMENTS` is a directory** → batch mode. Scan all `.md` files in that directory.

**If `$ARGUMENTS` is empty** → scan current directory for `.md` files.

**If `$ARGUMENTS` contains "list"** → list-only mode. Identify opportunities but don't create anything.

### Step 2 — Scan for visual opportunities

Read the target markdown file(s) and identify content that would benefit from a visual:

| Pattern to detect | Visual type |
|---|---|
| ASCII art diagrams (`\`\`\`` blocks with boxes/arrows) | SVG replacement of the same diagram |
| Tables with scores/ratings | Radar chart, bar chart, or scorecard |
| Hierarchical lists (3+ levels) | Pyramid, tree, or nested diagram |
| Process/workflow (step 1 → step 2 → ...) | Flow diagram, cycle diagram |
| Spectrums/scales (A → B → C → D) | Gradient bar, spectrum visualization |
| Comparisons (vs, before/after) | Side-by-side, dual-column |
| Categorized lists (5+ categories) | Grid/card layout, mind map |
| Formulas or models (B = MAP, etc.) | Annotated diagram with axes |

For each opportunity found, note:
- Source file and line number
- What type of visual it would be
- Priority: 🔴 (replaces ugly ASCII art) / 🟠 (enhances comprehension) / 🟡 (nice to have)

**In list-only mode**: output the opportunities table and stop here.

### Step 3 — Create the visuals directory

```bash
mkdir -p [source-dir]/visuals
```

Use the same directory as the source files, with a `visuals/` subdirectory.

### Step 4 — Generate SVGs

For each visual opportunity (highest priority first), create an SVG file.

#### SVG design rules

**Layout & sizing:**
- ViewBox: use reasonable dimensions (700-900 width, proportional height)
- No fixed width/height attributes — use viewBox only for responsiveness
- Font: `system-ui, -apple-system, sans-serif` (no external fonts)

**Colors — branding first:**
- **Always check for a branding file first** : chercher `BRANDING.md`, `branding.md`, `BRAND.md`, `GUIDELINES.md`, `docs/branding*`, `docs/design*`, ou des variables CSS/tokens dans `tailwind.config.*`, `src/styles/`, `src/assets/`
- Si un fichier branding existe, **extraire la palette du projet** (couleurs primaires, secondaires, accent, sémantiques) et l'utiliser en priorité
- Si aucun branding n'est trouvé, utiliser la palette Tailwind par défaut :
  - Green for positive/good (`#22c55e`, `#16a34a`, `#dcfce7`)
  - Red for negative/bad (`#ef4444`, `#dc2626`, `#fef2f2`)
  - Yellow/orange for warning/medium (`#eab308`, `#f97316`)
  - Blue/indigo for primary/neutral (`#6366f1`, `#2563eb`, `#eef2ff`)
  - Purple for special/highlight (`#7c3aed`, `#8b5cf6`, `#f5f3ff`)
  - Gray for text and borders (`#1e293b`, `#64748b`, `#94a3b8`, `#e2e8f0`)
- Les couleurs sémantiques (vert=bon, rouge=mauvais) restent universelles même avec un branding custom

**Typography:**
- Title: 20-22px, font-weight 700, fill `#1e293b`
- Subtitle: 12-13px, fill `#64748b`
- Labels: 12-14px, font-weight 600-700
- Body text: 10-11px
- Source attribution: 10px, fill `#94a3b8`, at bottom

**Components:**
- Use `<defs>` for reusable filters (drop shadow), gradients, markers
- Round corners on rectangles (`rx="6"` to `rx="12"`)
- Subtle drop shadows for depth (`feDropShadow dx="0" dy="2" stdDeviation="3" flood-opacity="0.1"`)
- Clear visual hierarchy: title → diagram → annotations → source

**Content rules:**
- Every SVG must have a title and a source line referencing the article
- Text must be in the same language as the source article
- Preserve the meaning exactly — don't editorialize or add content not in the source
- Keep ASCII art blocks in the markdown as fallback — add the SVG reference ABOVE them

**Naming convention:** `kebab-case.svg` matching the concept (e.g., `spectre-ethique.svg`, `hook-model.svg`)

### Step 5 — Validate

Validate every SVG with Python XML parser:
```bash
python3 -c "import xml.etree.ElementTree as ET; ET.parse('file.svg')"
```

Fix any invalid SVG before proceeding.

### Step 6 — Integrate into articles

For each SVG created, add a markdown image reference in the source article **above** the ASCII art it replaces:

```markdown
![Description of the visual](./visuals/filename.svg)
```

Do NOT remove the ASCII art — it serves as text fallback for non-graphical contexts.

### Step 7 — Report

```
## Illustrations — [project/directory]

**Created:** X SVGs in [path]/visuals/

| # | File | Article | Type | Description |
|---|------|---------|------|-------------|
| 1 | name.svg | KB-XX | [type] | [one-line] |
| ... | | | | |

**Integrated into:** X articles
**Skipped:** X opportunities (🟡 low priority)

**Remaining opportunities:**
- [any 🟡 items not created]
```

### Rules

- Do NOT use external dependencies (no JS, no CSS files, no images, no fonts)
- Do NOT create raster images — SVG only
- Do NOT remove ASCII art from articles — add SVG as enhancement above
- Do NOT create visuals for content that doesn't need them (simple tables, short lists)
- SVGs must be self-contained and render correctly in any browser and GitHub markdown
- Validate XML before committing
- Commit visuals to the project repo, not to ShipFlow
- **Accents français obligatoires** sur tout contenu en français
