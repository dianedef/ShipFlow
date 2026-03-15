---
name: linking
description: Audit and optimize internal links across a content site — with SEO best practices, project-aware context, and structured workflow. Use when adding new links, fixing broken links, or auditing orphan pages.
license: MIT
compatibility: Works with any static content site (Astro, Next.js, Hugo, etc.)
metadata:
  author: claiire
  version: "1.0"
---

Internal linking skill — SEO-aware, project-aware, structured.

**Input**: The user's request may specify a scope (a section, a set of pages, a broken link migration) or be open-ended ("audit my links", "fix the navigation after restructuring").

---

## Step 1 — Load project context

Before doing anything else, read the project documentation files that exist. **Do not skip this step.** These files contain the site's architecture, editorial voice, and linking strategy — all of which affect how links should be built.

Read in this order (skip gracefully if a file doesn't exist):

1. `CLAUDE.md` — project architecture, content structure, technical conventions
2. `GUIDELINES.md` — editorial tone, content rules, what to avoid
3. `BUSINESS.md` — business goals, target audience, conversion priorities
4. `BRANDING.md` — brand voice, terminology, naming conventions
5. `LINKING-STRATEGY.md` — **project-specific** linking logic: clusters, pillar pages, priorities, internal link rules

After reading, summarize in 2-3 lines what you now know about this project's content architecture and linking priorities. This anchors all subsequent decisions.

---

## Step 2 — Identify the scope

If the user specified a precise scope (e.g., "fix links pointing to /old-path/", "audit the violence/ section", "add links to the new module"), go directly to that scope.

If the scope is open-ended, ask:
- Is this an **audit** (find problems: broken links, orphan pages, missing cross-links)?
- Is this a **migration** (update links after restructuring)?
- Is this an **enrichment** (add new relevant links to existing pages)?

You can handle multiple types in one session, but be explicit about which you're doing at each step.

---

## Step 3 — Apply SEO best practices for internal links

Regardless of project, these rules always apply:

### Anchor text
- **Descriptive, not generic** — never "cliquez ici", "en savoir plus", "this page". Always describe what the linked page is about.
- **Include the target keyword naturally** — if the linked page targets "gestion du stress", the anchor should contain those words, not a synonym.
- **Vary anchor text** for the same destination across multiple pages — exact-match repetition looks manipulative to search engines.
- **Match user intent** — the anchor should set accurate expectations for what's on the other side.

### Link placement
- **In-body links > navigation links** for SEO — contextual links in content carry more weight than repeated nav links.
- **Earlier is better** — links placed earlier in the body tend to carry more weight.
- **Don't over-link** — 3-5 contextual links per page is typically ideal. More dilutes authority. Less misses opportunities.
- **Bidirectional when relevant** — if Page A links to Page B, consider whether Page B should link back to Page A.

### Link architecture
- **Pillar pages attract links from sub-pages** — every article in a cluster should link up to its pillar page.
- **Pillar pages link to their sub-pages** — not necessarily all of them, but the most important ones.
- **Avoid orphan pages** — every page should have at least one internal link pointing to it (check with grep or glob).
- **Avoid link chains** — A → B → C when A should just link directly to C.
- **Canonical depth** — important pages should be reachable in 3 clicks or fewer from the homepage.

### What to avoid
- Linking to pages that don't exist yet (check before adding)
- Linking to redirect pages when you can link directly to the destination
- Identical anchor text for different destinations
- Over-optimized anchor text (exact keyword repetition across many pages)

---

## Step 4 — Execute

### For a broken link migration:
1. Use Grep to find all occurrences of the old path pattern
2. List all affected files
3. For each file: read it, update the link(s), verify the new target exists
4. Report: X files updated, Y links corrected

### For an orphan page audit:
1. Glob all content files in the relevant section
2. For each file, grep the entire codebase for its path
3. Flag any page with zero inbound links
4. Suggest where a link could naturally be added (which related pages already discuss this topic?)

### For a cross-linking enrichment:
1. Read the target pages (the ones you want to get more links)
2. Identify the key topic/keyword of each
3. Grep for pages that discuss that topic but don't link to the target
4. For each candidate: read it, find the natural insertion point, add the link with good anchor text
5. Update the file

### For a full section audit:
1. Map the section structure (glob all files)
2. Check each pillar page: does it link to its sub-pages?
3. Check each sub-page: does it link up to the pillar? To adjacent pages?
4. Identify missing links, add them
5. Report findings and changes made

---

## Step 5 — Report

After completing the work, produce a concise report:

```
## Linking audit — [section or scope]

### Changes made
- X files updated
- Y links added / Z links corrected

### Patterns found
- [Any structural issues noticed: missing pillar links, orphaned pages, etc.]

### Still to do (if any)
- [Anything not handled in this session]
```

Do not pad the report. If there's nothing to flag, say so in one line.

---

## SEO principles to keep in mind throughout

**Internal links distribute "link equity"** — they signal to search engines which pages on your site are important. Pillar pages should accumulate more links than sub-pages.

**Topical clusters boost authority** — a tightly interlinked cluster of pages on a topic signals to search engines that your site is authoritative on that topic. Missing links within a cluster weaken this signal.

**User experience and SEO are aligned here** — a link that helps the reader find relevant content also helps search engines understand your site's structure. If a link feels forced, it probably is.

**Don't add links just to add links** — each link should serve a clear purpose: help the reader go deeper on a topic, discover a related concept, or take a practical action. Low-relevance links dilute the experience and the SEO value.
