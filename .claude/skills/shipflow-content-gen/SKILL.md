---
name: shipflow-content-gen
description: AI-generated SEO content — creates high-quality articles in 5 formats (Product Roundups, Reviews, Comparisons, Informational, How-to guides). 1200-2500 words, SEO-optimized, with structured data and affiliate integration.
disable-model-invocation: true
argument-hint: [roundup|review|comparison|informational|howto] [topic] (required)
---

## Context

- Current directory: !`pwd`
- Project CLAUDE.md: !`head -50 CLAUDE.md 2>/dev/null || echo "no CLAUDE.md"`
- Keywords data: !`ls -la seo/keywords-*.json 2>/dev/null | tail -5 || echo "no keyword files"`
- Product data: !`ls -la seo/products-*.json 2>/dev/null | tail -5 || echo "no product files"`
- Existing articles: !`find . -maxdepth 3 -type f \( -name "*.md" -o -name "*.mdx" -o -name "*.astro" \) 2>/dev/null | grep -vi changelog | grep -vi license | grep -v node_modules | grep -v .git | head -20 || echo "no content files"`
- Site framework: !`cat package.json 2>/dev/null | grep -E '"(astro|next|nuxt|gatsby|vite)"' || echo "unknown framework"`
- Content style: !`find . -maxdepth 3 -type f \( -name "*.md" -o -name "*.mdx" \) 2>/dev/null | grep -vi changelog | head -1 | xargs head -40 2>/dev/null || echo "no existing content to reference"`

## Pipeline position

```
/shipflow-keyword-research --> /shipflow-product-discovery[-digital] --> /shipflow-content-gen
                                                                         (you are here — articles)
                                                                         /shipflow-copywriter (conversion copy)
```

**Prerequisite check:** This skill checks for keyword data (`seo/keywords-*.json`) and product data (`seo/products-*.json`). If missing, it suggests running the upstream skills first. You can skip if you have your own topic and product list.

**For conversion copy** (landing pages, emails, CTAs, headlines): use `/shipflow-copywriter` instead.

## Mode detection

Parse `$ARGUMENTS` for article type and topic:

- **`roundup [topic]`** --> PRODUCT ROUNDUP: "Best [X] of [Year]" (1500-2500 words)
- **`review [product]`** --> PRODUCT REVIEW: In-depth single product review (1200-2000 words)
- **`comparison [A] vs [B]`** --> PRODUCT COMPARISON: Head-to-head comparison (1500-2000 words)
- **`informational [topic]`** --> INFORMATIONAL: Educational/explanatory article (1200-2000 words)
- **`howto [topic]`** --> HOW-TO GUIDE: Step-by-step tutorial (1500-2500 words)

If no type specified, analyze the topic and recommend the best format.

---

## Available Tools for Research & Quality

### Content Research (use before writing)

1. **Exa Web Search** (`mcp__exa__web_search_exa`) -- Research the topic:
   - Search top-ranking articles for structure inspiration
   - Find expert opinions, statistics, and quotes to cite
   - Discover unique angles competitors miss

2. **Perplexity Sonar API** (Tier 2) -- Deep research with citations:
   - Factual verification with real-time sources
   - Multi-step research for comprehensive coverage
   - Automatic citation generation

3. **WebFetch** -- Analyze competitor content:
   - Fetch top-ranking articles for structure/length benchmarks
   - Extract data points, statistics, expert quotes
   - Analyze heading structures and content depth

### Content Optimization

| Tool | What it does | Tier |
|------|-------------|------|
| **Surfer SEO API** | Score content against SERP competitors, get keyword density targets | Tier 2 ($79+/mo) |
| **Frase API** | Content briefs, SERP analysis, optimization scoring | Tier 2 ($40/mo) |
| **DataForSEO Content Analysis** | Sentiment, readability, content quality metrics | Tier 2 (pay-as-you-go) |

### Quality Assurance

| Tool | What it does | Tier |
|------|-------------|------|
| **Sapling AI API** | Grammar, spelling, style checking | Tier 2 (free tier: 50K chars/day) |
| **LanguageTool API** | Grammar/style, 30+ languages, self-hostable | Tier 2 (free tier available) |

### Publishing

| Tool | What it does | Tier |
|------|-------------|------|
| **WordPress REST API** | Publish directly as draft/scheduled post | Tier 2 (free) |

### MCP Servers for Content Optimization & Publishing

| MCP Server | Source | Adds |
|------------|--------|------|
| **DataForSEO MCP** (official) | `dataforseo/mcp-server-typescript` | Keyword density, content analysis, SERP data |
| **Frase MCP** | Via Frase API (50+ endpoints) | Content briefs, SERP analysis, optimization scoring |
| **SEO Review Tools MCP** | `SEO-Review-Tools/SEO-API-MCP` | Content SEO metrics |
| **kwrds.ai MCP** | `mkotsollaris/kwrds-ai-mcp` | SERP-informed content generation |
| **WordPress MCP** (official) | `WordPress/mcp-adapter` | Publish posts, manage media/taxonomies directly |
| **WordPress MCP** (docdyhr) | `docdyhr/mcp-wordpress` | 59 tools, full WordPress management |
| **Google Analytics 4 MCP** (official) | `developers.google.com/analytics/devguides/MCP` | Track content performance post-publish |
| **Google Search Console MCP** | `AminForou/mcp-gsc` | Monitor keyword rankings for published content |
| **Google Trends MCP** | `jmanek/google-news-trends-mcp` | Validate trending topics before writing |
| **Perplexity MCP** (official) | `ppl-ai/modelcontextprotocol` | Real-time research with AI-powered citations |
| **Firecrawl MCP** (official) | `firecrawl/firecrawl-mcp-server` | Competitor content scraping + structured extraction |
| **Jina AI MCP** (official) | `jina-ai/MCP` | URL-to-markdown, content embeddings, reranking |

---

## Pre-Writing Phase (ALL article types)

### Step 1: Load existing research

Check for keyword and product data:
- Read `seo/keywords-[topic-slug].json` if it exists
- Read `seo/products-[topic-slug].json` if it exists
- If neither exists, offer to run `/shipflow-keyword-research` and/or `/shipflow-product-discovery` first

### Step 2: SERP research (use Exa + WebSearch)

Even with existing keyword data, always research the SERP before writing:

1. **Search the primary keyword** -- analyze what's ranking
2. **Fetch top 2-3 results** (WebFetch) -- analyze:
   - Heading structure (H1/H2/H3)
   - Content length
   - Unique sections/angles
   - Questions answered
   - Internal/external links
3. **Identify content gaps** -- what are competitors NOT covering?
4. **Find data points** -- statistics, expert quotes, studies to cite

### Step 3: Build the content brief

```
CONTENT BRIEF: [Article Title]
─────────────────────────────────
Primary keyword:     [from research]
Supporting keywords: [3-5 from research]
Search intent:       [I/CI/T]
Target word count:   [range]
Content type:        [Roundup/Review/Comparison/Informational/How-to]
Target audience:     [specific segment]
Unique angle:        [what makes this different from competitors]
Key sections:        [H2 outline]
Data points needed:  [stats, quotes, studies to include]
Products to feature: [if applicable, from product research]
CTA:                 [what action should the reader take?]
```

Present the brief to the user before writing. Ask for approval or adjustments.

---

## Article Type 1: PRODUCT ROUNDUP

**Format**: "Best [X] of [Year]" -- 1500-2500 words
**Purpose**: Curated list of top products with affiliate links

### Structure

```markdown
# Best [Product Category] of [Year]: [Qualifier]

[Hook — 2-3 sentences addressing the reader's pain point]
[Brief context — why this roundup exists, what criteria were used]
[Quick picks summary — table with top 3 for skimmers]

## How We Chose These [Products]
[Selection criteria — what factors were evaluated]
[Methodology transparency — builds trust]

## Quick Comparison
| Product | Best For | Price | Rating | Our Verdict |
|---------|----------|-------|--------|-------------|
| [#1] | [segment] | $XX | 4.X/5 | [1-line] |
| ... | | | | |

## 1. [Product Name] — Best Overall
[Product image placeholder]
**Price:** $XX | **Rating:** 4.X/5 (X,XXX reviews) | **Best for:** [segment]

[2-3 paragraph review covering:]
- What makes it stand out
- Key features (top 3-5)
- Who it's best for
- Potential drawbacks (honesty builds trust)

**Pros:**
- [Pro 1]
- [Pro 2]
- [Pro 3]

**Cons:**
- [Con 1]
- [Con 2]

[CTA button placeholder: "Check Price on Amazon"]

## 2. [Product Name] — Best Value
[Same structure as #1]

## 3-7. [Continue for 5-10 products]

## Buying Guide: How to Choose the Right [Product]
### [Factor 1 — e.g., Size/Capacity]
[Explanation of why this matters and how to evaluate]

### [Factor 2 — e.g., Material/Build Quality]
[Explanation]

### [Factor 3 — e.g., Price vs. Features]
[Explanation]

## Frequently Asked Questions
### [Question 1 from PAA/keyword research]
[Answer — 2-4 sentences, direct and helpful]

### [Question 2]
[Answer]

### [Question 3]
[Answer]

## Our Verdict
[2-3 sentences summarizing the top pick and runner-up with clear reasoning]
```

### SEO Requirements for Roundups
- Primary keyword in H1, first paragraph, and at least 2 H2s
- Each product section = potential featured snippet (structured with bold labels)
- FAQ section targets PAA keywords
- Buying guide section targets informational long-tails
- Comparison table = rich snippet opportunity

---

## Article Type 2: PRODUCT REVIEW

**Format**: "[Product Name] Review [Year]" -- 1200-2000 words
**Purpose**: In-depth single product analysis

### Structure

```markdown
# [Product Name] Review [Year]: [Verdict in 5 Words]

[Hook — the reader's problem and how this product addresses it]
[One-sentence verdict for skimmers]

## Quick Summary
| | |
|---|---|
| **Product** | [Name] |
| **Price** | $XX |
| **Rating** | X/10 |
| **Best For** | [segment] |
| **Avoid If** | [anti-segment] |

## What is [Product Name]?
[Brief intro — what it is, who makes it, what category it fits]

## Key Features
### [Feature 1]
[2-3 sentences — what it does + why it matters to the user]

### [Feature 2]
[Same format]

### [Feature 3]
[Same format]

## [Using/Testing] the [Product]
[First-hand experience narrative OR synthesized user experience]
[Setup/getting started]
[Day-to-day usage]
[Edge cases and limitations discovered]

## What I Like (Pros)
- **[Pro 1]:** [Brief explanation]
- **[Pro 2]:** [Brief explanation]
- **[Pro 3]:** [Brief explanation]

## What Could Be Better (Cons)
- **[Con 1]:** [Brief explanation]
- **[Con 2]:** [Brief explanation]

## [Product] vs. Alternatives
| Feature | [Product] | [Alt 1] | [Alt 2] |
|---------|-----------|---------|---------|
| Price | $XX | $XX | $XX |
| [Key diff 1] | [value] | [value] | [value] |
| [Key diff 2] | [value] | [value] | [value] |
| Best for | [segment] | [segment] | [segment] |

## Who Should Buy [Product]?
[2-3 paragraphs mapping product to specific user segments]
- **Buy if:** [conditions]
- **Skip if:** [conditions]

## FAQ
[3-5 questions from keyword research]

## Final Verdict: X/10
[3-4 sentence summary — clear recommendation with reasoning]
[CTA button placeholder]
```

---

## Article Type 3: PRODUCT COMPARISON

**Format**: "[Product A] vs [Product B]: [Year]" -- 1500-2000 words
**Purpose**: Head-to-head comparison helping the reader choose

### Structure

```markdown
# [Product A] vs [Product B] ([Year]): Which Is Right for You?

[Hook — the decision the reader is facing]
[One-sentence spoiler: "If you [need X], go with [A]. If you [need Y], go with [B]."]

## Quick Verdict
| | [Product A] | [Product B] |
|---|---|---|
| **Best For** | [segment] | [segment] |
| **Price** | $XX | $XX |
| **Rating** | X/5 | X/5 |
| **Winner** | [category] | [category] |

## Overview
### [Product A]
[3-4 sentence overview]

### [Product B]
[3-4 sentence overview]

## Head-to-Head Comparison

### [Category 1 — e.g., Design & Build]
**[Product A]:** [Assessment]
**[Product B]:** [Assessment]
**Winner:** [Product X] — [why in one sentence]

### [Category 2 — e.g., Performance]
[Same format]

### [Category 3 — e.g., Price & Value]
[Same format]

### [Category 4-6]
[Continue for all relevant categories]

## Comparison Summary
| Category | [Product A] | [Product B] | Winner |
|----------|-------------|-------------|--------|
| [Cat 1] | [score/note] | [score/note] | [A/B/Tie] |
| [Cat 2] | [score/note] | [score/note] | [A/B/Tie] |
| ... | | | |
| **Overall** | | | **[Winner]** |

## Who Should Choose [Product A]?
[Bullet points — specific user profiles]

## Who Should Choose [Product B]?
[Bullet points — specific user profiles]

## FAQ
[3-5 comparison-specific questions]

## Final Verdict
[3-4 sentences — clear winner with nuance for different use cases]
```

---

## Article Type 4: INFORMATIONAL ARTICLE

**Format**: "[Topic]: [Explanatory subtitle]" -- 1200-2000 words
**Purpose**: Educational content targeting informational keywords

### Structure

```markdown
# [Topic]: [What You Need to Know in Year]

[Hook — why the reader should care about this topic]
[Scope — what this article covers]

## Key Takeaways
- [Takeaway 1 — one sentence]
- [Takeaway 2]
- [Takeaway 3]

## What Is [Topic]?
[Clear definition in plain language]
[Context — why it matters, who it affects]

## [Aspect 1 — e.g., How It Works]
[Detailed explanation with examples]
[Data points or expert quotes where relevant]

## [Aspect 2 — e.g., Types/Categories]
[Breakdown of different types with explanations]

## [Aspect 3 — e.g., Benefits/Advantages]
[Evidence-backed benefits]

## [Aspect 4 — e.g., Common Mistakes/Misconceptions]
[Address myths or pitfalls — builds authority]

## [Aspect 5 — e.g., Getting Started / What to Look For]
[Actionable advice — transition to commercial intent if natural]
[Product recommendations if relevant — light touch, helpful not salesy]

## FAQ
[5-7 questions from PAA and keyword research]

## Summary
[3-4 sentences recapping key points with clear next-step CTA]
```

---

## Article Type 5: HOW-TO GUIDE

**Format**: "How to [Action]: [Step-by-Step Guide]" -- 1500-2500 words
**Purpose**: Step-by-step tutorial targeting "how to" keywords

### Structure

```markdown
# How to [Action]: [Qualifier] ([Year] Guide)

[Hook — the outcome the reader wants to achieve]
[What they'll learn — scope of the guide]
[Time/difficulty estimate if applicable]

## What You'll Need
- [Prerequisite/tool 1] — [brief note on why]
- [Prerequisite/tool 2]
- [Optional: product recommendation with affiliate link]

## Quick Overview
1. [Step 1 summary]
2. [Step 2 summary]
3. [Step 3 summary]
...

## Step 1: [Action Verb] [What]
[Detailed explanation — 150-300 words]
[Image/screenshot placeholder if applicable]
[Pro tip or common mistake callout]

> **Pro tip:** [Insider knowledge that saves time or improves results]

## Step 2: [Action Verb] [What]
[Same format]

## Step 3-N: [Continue for all steps]

## Common Mistakes to Avoid
### Mistake 1: [What people do wrong]
[Why it's wrong + what to do instead]

### Mistake 2: [What people do wrong]
[Why it's wrong + what to do instead]

## Advanced Tips
[2-3 tips for readers who want to go further]
[Product recommendations for advanced usage if relevant]

## FAQ
[3-5 how-to specific questions]

## Wrapping Up
[Recap the key steps]
[Encouragement + next-step CTA]
```

---

## Post-Writing Phase (ALL article types)

### Step 1: SEO optimization check

Verify before delivering:

- [ ] Primary keyword in: H1, first 100 words, at least 2 H2s, meta description
- [ ] Supporting keywords appear naturally (not stuffed)
- [ ] All H2/H3 headings are descriptive (not generic like "Conclusion")
- [ ] Internal link opportunities noted (link to related content on the site)
- [ ] External links to authoritative sources (stats, studies, official docs)
- [ ] Images noted with ALT text suggestions containing keywords
- [ ] Meta title: under 60 chars, keyword-first, compelling
- [ ] Meta description: under 160 chars, includes keyword + CTA
- [ ] URL slug suggestion: short, keyword-rich, no stop words

### Step 2: Generate structured data (JSON-LD)

Generate appropriate Schema.org markup based on article type:

| Article Type | Schema Types |
|-------------|-------------|
| Product Roundup | `Article` + `ItemList` + `Product` per item + `FAQPage` |
| Product Review | `Article` + `Review` + `Product` + `FAQPage` |
| Comparison | `Article` + `Product` (x2) + `FAQPage` |
| Informational | `Article` + `FAQPage` |
| How-to | `Article` + `HowTo` + `FAQPage` |

Output the JSON-LD as a code block the user can paste into their page.

### Step 3: Content quality checklist

Before delivering, verify:

- [ ] Word count within target range (1200-2500 depending on type)
- [ ] No fluff paragraphs (every paragraph adds value)
- [ ] Tone matches site's existing content (if reference available)
- [ ] Claims are backed by data, sources, or reasoning
- [ ] Affiliate disclosures included where required (FTC compliance)
- [ ] No AI-sounding phrases ("in today's fast-paced world", "it's important to note", "delve into")
- [ ] Transitions between sections are natural
- [ ] CTA is clear and matches search intent
- [ ] Pros/cons are balanced and honest (not all positive)

### Step 4: Deliver the article

Output the full article in markdown, followed by:

```
══════════════════════════════════════════════════════
ARTICLE METADATA
══════════════════════════════════════════════════════
Title:            [title]
Meta Title:       [SEO title, <60 chars]
Meta Description: [<160 chars, keyword + CTA]
URL Slug:         [suggested-slug]
Primary Keyword:  [keyword]
Supporting KWs:   [list]
Word Count:       [count]
Article Type:     [type]
Schema Markup:    [included below]
══════════════════════════════════════════════════════

[JSON-LD structured data block]

══════════════════════════════════════════════════════
OPTIMIZATION NOTES
══════════════════════════════════════════════════════
For higher SEO scores, consider:
  - Surfer SEO API: Score this article against SERP competitors
  - Frase API: Get content brief + optimization suggestions
  - DataForSEO MCP: Keyword density analysis
══════════════════════════════════════════════════════
```

### Step 5: Save & offer next steps

Save article to appropriate location:
- If site uses Astro/Next/Nuxt: suggest proper content directory
- If no framework detected: save to `content/[slug].md`

Ask:

> **Article generated. What next?**
> 1. Edit/refine the article (tell me what to change)
> 2. Generate another article type for the same topic
> 3. Publish to WordPress (`wp-json/wp/v2/posts` endpoint)
> 4. Run SEO optimization score (requires Surfer/Frase API)
> 5. Generate more keyword research (`/shipflow-keyword-research`)

---

## Important (all types)

- **Research BEFORE writing.** Never generate content without SERP analysis first. The research phase is what separates mediocre content from ranking content.
- **Honesty over hype.** Affiliate content that's genuinely helpful converts better than salesy content. Always include real cons, not just pros.
- **FTC compliance.** Every article with affiliate links MUST include a disclosure: "This article contains affiliate links. We may earn a commission at no extra cost to you."
- **No AI slop.** Avoid: "In today's world", "It's worth noting", "Let's delve into", "Whether you're a beginner or expert", "In conclusion". Write like a knowledgeable human.
- **Data beats opinions.** Every claim should be backed by a data point, user review, expert quote, or logical reasoning. "This keyboard is good" loses to "This keyboard scored 4.8/5 across 12,000 reviews on Amazon."
- **Structured data is not optional.** Every article gets JSON-LD. This is how you win rich snippets.
- **Match the intent.** A "how to" searcher wants steps, not a product pitch. A "best X" searcher wants a curated list, not a 2000-word essay. Respect the intent.
- **The user's voice matters.** If existing content exists on the site, match its tone, reading level, and style. Don't impose a generic "content mill" voice.
- **Word count is a range, not a target.** 1200 words of substance beats 2500 words of padding. Hit the minimum, but don't pad.
