---
name: shipflow-keyword-research
description: AI-powered keyword research — discovers SEO-optimized keywords for articles using SERP analysis, competitor mining, search intent classification, and search volume estimation. Supports single topic, bulk topics, or full content calendar generation.
disable-model-invocation: true
argument-hint: [topic/niche | "bulk" | "calendar"] (required)
---

## Context

- Current directory: !`pwd`
- Project CLAUDE.md: !`head -50 CLAUDE.md 2>/dev/null || echo "no CLAUDE.md"`
- Existing content: !`find . -maxdepth 3 -type f \( -name "*.md" -o -name "*.mdx" -o -name "*.astro" -o -name "*.html" \) 2>/dev/null | grep -vi changelog | grep -vi license | grep -v node_modules | grep -v .git | head -30 || echo "no content files"`
- Existing keywords file: !`cat keywords.json 2>/dev/null | head -40 || cat seo/keywords.json 2>/dev/null | head -40 || echo "no keywords file"`
- Site config: !`cat astro.config.* next.config.* nuxt.config.* 2>/dev/null | head -30 || echo "no site config"`
- Package.json: !`cat package.json 2>/dev/null | head -20 || echo "no package.json"`

## Pipeline position

```
/shipflow-keyword-research --> /shipflow-product-discovery         --> /shipflow-content-gen
(you are here)                 /shipflow-product-discovery-digital      /shipflow-copywriter
```

**You are at the START of the pipeline.** This skill's output (`seo/keywords-*.json`) feeds into product discovery and content generation. No prerequisites needed.

## Mode detection

- **`$ARGUMENTS` starts with a topic/niche** --> TOPIC MODE: deep keyword research for one topic.
- **`$ARGUMENTS` is "bulk"** --> BULK MODE: research keywords for multiple topics at once.
- **`$ARGUMENTS` is "calendar"** --> CALENDAR MODE: generate a full content calendar with keyword clusters.

---

## Available Data Sources (use in priority order)

### Tier 1: MCP Tools (already available, no setup)

These tools are available in the current environment. Use them FIRST before any external APIs.

1. **Exa Web Search** (`mcp__exa__web_search_exa`) -- Search the web for any topic. Use for:
   - SERP analysis: search the exact keyword, analyze what ranks
   - Competitor content analysis: find top-ranking articles
   - Related keyword discovery: search variations and long-tails
   - Search intent classification: analyze what type of content ranks

2. **Exa Code Context** (`mcp__exa__get_code_context_exa`) -- Find technical documentation. Use for:
   - Technical keyword research (API docs, library docs)
   - Developer-focused content keywords

3. **WebSearch** -- General web search. Use for:
   - Validating keyword ideas against real SERPs
   - Finding "People Also Ask" style questions
   - Discovering trending topics in a niche

4. **WebFetch** -- Fetch and analyze any URL. Use for:
   - Scraping competitor articles for keyword extraction
   - Analyzing top-ranking pages for content structure
   - Extracting meta titles/descriptions for keyword patterns

5. **Context7** (`mcp__context7__resolve-library-id` + `mcp__context7__query-docs`) -- Library docs. Use for:
   - Technical content keyword validation
   - Framework-specific terminology research

### Tier 2: External APIs (require setup)

Reference these in your output so the user knows what's available for deeper research:

| API | Best For | Auth | Cost |
|-----|----------|------|------|
| **DataForSEO API** | Search volume, keyword difficulty, CPC, SERP features | HTTP Basic Auth | Pay-as-you-go, $0.0006/req, $50 min deposit |
| **Serper.dev** | Fastest SERP scraping, PAA, related searches | API key | 2,500 free/month, then $1/1K queries |
| **SerpAPI** | Multi-engine SERP + Google Trends + Keyword Planner | API key | 100 free/month, then $75/mo |
| **Google Search Console API** | Existing keyword performance, impressions, CTR | OAuth 2.0 | Free |
| **Google Trends API (Alpha)** | Trending topics, seasonal patterns, rising queries | API key (Google Cloud) | Free (alpha, rate-limited) |
| **SEMrush API** | 25B keyword database, competitive analysis | API key (subscription) | $449.95/mo + API units |
| **Ahrefs API v3** | Keyword difficulty, clickstream data, backlinks | API key (enterprise) | From $500/mo |
| **Keywords Everywhere** | Bulk search volumes, related keywords, CPC | API key | Credits-based ($10/year entry) |
| **Serpstat API** | Keyword research, competitor analysis, rank tracking | API token | From $69/mo (7-day trial) |
| **Mangools / KWFinder** | Keyword difficulty scoring, SERP analysis | Private API (contact) | From $29/mo |
| **ValueSERP** | Budget SERP scraping | API key | 100 free, then $2.59/1K |
| **SearchCans** | Cheapest SERP API | API key | $0.56/1K, credits last 6 months |

### Tier 3: MCP Servers (can be installed)

Recommend these for users who want deeper integration:

| MCP Server | GitHub / Source | What it adds |
|------------|----------------|-------------|
| **DataForSEO MCP** (official) | `dataforseo/mcp-server-typescript` | Keyword volume, ideas, SERP, backlinks |
| **rpark Keyword Research MCP** | `rpark/keyword-research-tool-mcp` | Combines Firecrawl + Perplexity + DataForSEO |
| **Keywords Everywhere MCP** | `hithereiamaliff/mcp-keywords-everywhere` | Bulk volumes, CPC, related keywords |
| **SEMrush MCP** | `mrkooblu/semrush-mcp` | Domain analytics, keyword research |
| **Ahrefs MCP** (official) | `ahrefs/ahrefs-mcp-server` | Rank tracking, keyword research, backlinks |
| **SE Ranking MCP** (official) | `seranking/seo-data-api-mcp-server` | Lost keywords, competitor keywords, suggestions |
| **kwrds.ai MCP** | `mkotsollaris/kwrds-ai-mcp` | Keyword query, SERP analysis, content gen |
| **FetchSERP MCP** | npm: `fetchserp-mcp-server` | SEO analysis, SERP querying, keyword research |
| **KeywordsPeopleUse MCP** | `keywordspeopleuse.com/mcp-server` | PAA-focused keyword suggestions |
| **App SEO AI MCP** | Smithery: `@FreeMarketamilitia/app-seo-ai` | Google Ads Keyword Planner integration |
| **Google Search Console MCP** | `AminForou/mcp-gsc` | Real keyword performance data |
| **Google Trends MCP** | `jmanek/google-news-trends-mcp` | Trending keywords by location |
| **SerpAPI MCP** (official) | `serpapi/serpapi-mcp` | Multi-engine SERP (Google, Bing, YouTube, etc.) |
| **SEO Review Tools MCP** | `SEO-Review-Tools/SEO-API-MCP` | Advanced SEO metrics |
| **Serpstat MCP** | `SerpstatGlobal/serpstat-mcp-server-js` | Comprehensive SEO data |
| **Frase MCP** | Via Frase API | Content briefs + keyword data |
| **Screaming Frog MCP** | `bzsasson/screaming-frog-mcp` | Site crawling, SEO audit data |
| **SEO-MCP (free Ahrefs)** | `cnych/seo-mcp` | Free backlinks, keyword ideas via Ahrefs |

### Tier 4: Open-Source Self-Hosted Tools

| Tool | GitHub | What it does |
|------|--------|-------------|
| **SerpBear** | `towfiqi/serpbear` | Open-source rank tracking, free on Fly.io |
| **OpenSEO** | `every-app/open-seo` | Open-source keyword + competitor research |
| **ContentSwift** | `hilmanski/contentswift` | Free content research/optimization (Surfer alternative) |

---

## TOPIC MODE

Deep keyword research for a single topic/niche.

### Step 1: Understand the topic

Parse `$ARGUMENTS` to identify:
- **Seed keyword** -- the core topic (e.g., "mechanical keyboards", "home espresso")
- **Niche context** -- any qualifiers (e.g., "for beginners", "budget", "2026")
- **Content type signal** -- does the topic suggest a specific format? (review, how-to, comparison)
- **Language/locale** -- default to English/US unless specified

### Step 2: SERP analysis (use Exa + WebSearch)

Run 3-5 parallel searches using different angles on the seed keyword:

1. **Exact match search**: Search the seed keyword exactly
2. **Question variant**: "how to [keyword]" or "what is [keyword]"
3. **Comparison variant**: "best [keyword]" or "[keyword] vs"
4. **Long-tail variant**: "[keyword] for [qualifier]"
5. **Commercial variant**: "[keyword] review" or "buy [keyword]"

For each search, extract:
- **Top 10 titles** -- what exact phrases are ranking?
- **Content types** -- listicles, guides, reviews, comparisons?
- **Title patterns** -- numbers, years, power words used?
- **URL slugs** -- what keywords do competitors target in URLs?

### Step 3: Competitor content mining (use WebFetch on top 3 results)

For the top 3 ranking pages, fetch and analyze:
- **H1/H2/H3 headings** -- these reveal subtopic keywords
- **Meta title & description** -- optimized keyword phrases
- **Word count** -- content depth expectations
- **Internal links** -- related topic clusters
- **Schema markup** -- content type (Article, HowTo, FAQ, Product)

### Step 4: Keyword expansion

From Steps 2-3, build keyword clusters:

#### 4a. Search Intent Classification

Classify every keyword into one of 4 intents:
- **Informational** (I) -- "what is...", "how to...", "why does..."
- **Commercial Investigation** (CI) -- "best...", "top...", "review", "vs"
- **Transactional** (T) -- "buy...", "price", "discount", "coupon"
- **Navigational** (N) -- brand names, specific product names

#### 4b. Keyword Types

Generate keywords in each category:
- **Head terms** (1-2 words, high volume, high competition)
- **Body terms** (2-3 words, medium volume, medium competition)
- **Long-tail** (4+ words, lower volume, lower competition, higher conversion)
- **Questions** (who/what/where/when/why/how)
- **LSI/Semantic** (related terms, synonyms, co-occurring phrases)
- **Modifier keywords** (best, top, cheap, free, vs, alternative, review, 2026)

#### 4c. Search Volume Estimation

Without API access, estimate relative search volume using signals:
- **High volume**: topic appears in Google autocomplete, has Wikipedia page, multiple major publications cover it
- **Medium volume**: appears in niche publications, has dedicated subreddits/forums
- **Low volume**: few results, niche-specific, long-tail
- **Trending**: appears in recent news, social media buzz

Mark estimates clearly: `[EST: High/Med/Low]` -- recommend DataForSEO or Keywords Everywhere MCP for exact numbers.

### Step 5: Keyword scoring & prioritization

Score each keyword on 3 axes (1-10):

| Factor | How to Assess |
|--------|---------------|
| **Relevance** | How closely does this match the user's topic/niche? |
| **Opportunity** | Can we realistically rank? (fewer strong competitors = higher) |
| **Value** | Does this keyword drive the right traffic? (commercial intent = higher value) |

**Priority Score** = (Relevance x 0.4) + (Opportunity x 0.35) + (Value x 0.25)

### Step 6: Report

```
══════════════════════════════════════════════════════
KEYWORD RESEARCH: [seed keyword]
══════════════════════════════════════════════════════

SERP LANDSCAPE
  Content types ranking:    [listicle, guide, review, etc.]
  Avg content length:       [word count estimate]
  Dominant intent:          [I/CI/T/N]
  Competition level:        [Low/Medium/High/Very High]
  Featured snippets:        [Yes/No — type if yes]

──────────────────────────────────────────────────────
TOP 20 KEYWORDS (ranked by priority score)
──────────────────────────────────────────────────────

| # | Keyword | Intent | Volume Est | Competition | Priority | Content Type |
|---|---------|--------|-----------|-------------|----------|-------------|
| 1 | [keyword] | CI | [EST: High] | Medium | 9.2 | Product Roundup |
| 2 | [keyword] | I | [EST: Med] | Low | 8.7 | How-to Guide |
| ... | | | | | | |

──────────────────────────────────────────────────────
KEYWORD CLUSTERS
──────────────────────────────────────────────────────

### Cluster 1: [Theme]
  Primary: [main keyword]
  Supporting: [related keywords]
  Content format: [recommended article type]

### Cluster 2: [Theme]
  ...

──────────────────────────────────────────────────────
QUESTION KEYWORDS (FAQ/PAA opportunities)
──────────────────────────────────────────────────────
  1. [question keyword] — [intent] — [volume est]
  2. ...

──────────────────────────────────────────────────────
LONG-TAIL OPPORTUNITIES (low competition, high conversion)
──────────────────────────────────────────────────────
  1. [long-tail keyword] — [intent] — [why this is an opportunity]
  2. ...

──────────────────────────────────────────────────────
COMPETITOR CONTENT GAP
──────────────────────────────────────────────────────
  Keywords/topics NOT well-covered by top results:
  1. [gap topic] — [why this is an opportunity]
  2. ...

══════════════════════════════════════════════════════
RECOMMENDED ARTICLES (prioritized)
══════════════════════════════════════════════════════

| Priority | Article Title | Primary Keyword | Supporting Keywords | Type | Est. Words |
|----------|--------------|----------------|-------------------|------|-----------|
| 1 | [title] | [keyword] | [2-3 supporting] | [type] | [range] |
| 2 | [title] | [keyword] | [2-3 supporting] | [type] | [range] |
| ... | | | | | |

══════════════════════════════════════════════════════
DATA ACCURACY NOTE
══════════════════════════════════════════════════════
Search volumes are estimated from SERP signals. For exact data, install:
  - DataForSEO MCP: github.com/dataforseo/mcp-server-typescript
  - Keywords Everywhere MCP: github.com/hithereiamaliff/mcp-keywords-everywhere
  - Or use DataForSEO API directly ($0.0006/request)
══════════════════════════════════════════════════════
```

### Step 7: Save & offer next steps

Save keywords to `seo/keywords-[topic-slug].json`:

```json
{
  "topic": "[seed keyword]",
  "researched_at": "[ISO date]",
  "serp_landscape": { ... },
  "keywords": [
    {
      "keyword": "...",
      "intent": "CI",
      "volume_estimate": "High",
      "competition": "Medium",
      "priority_score": 9.2,
      "content_type": "Product Roundup",
      "cluster": "Cluster 1 name"
    }
  ],
  "clusters": [ ... ],
  "recommended_articles": [ ... ]
}
```

Then ask:

> **Keyword research complete. What next?**
> 1. Generate content for the top-priority article (`/shipflow-content-gen`)
> 2. Find affiliate products for these keywords (`/shipflow-product-discovery`)
> 3. Research another topic
> 4. Build a full content calendar (`/shipflow-keyword-research calendar`)

---

## BULK MODE

When `$ARGUMENTS` is "bulk", ask the user for a list of topics, then run TOPIC MODE Step 2-5 for each in parallel using the **Agent tool** (one agent per topic). Consolidate all results into a single prioritized keyword database.

### Step 1: Gather topics

Use **AskUserQuestion**:
- Question: "Enter your topics (one per line, or comma-separated):"
- Free text input

### Step 2: Launch parallel research

One agent per topic, all in a single message. Each agent runs Steps 2-5 from TOPIC MODE.

### Step 3: Consolidate & cross-reference

After all agents return:
- Merge all keyword lists
- Remove duplicates (keep highest priority score)
- Identify cross-topic keyword opportunities
- Rank all keywords in a unified priority list

### Step 4: Unified report + save to `seo/keywords-bulk-[date].json`

---

## CALENDAR MODE

When `$ARGUMENTS` is "calendar", generate a full content calendar.

### Step 1: Gather inputs

Use **AskUserQuestion** with multiple questions:
- Q1: "What's your niche/topic area?"
- Q2: "How many articles per week/month?"
- Q3: "What content types? (roundups, reviews, comparisons, how-tos, informational)"
- Q4: "Any seasonal events or product launches to plan around?"

### Step 2: Run keyword research for the niche

Execute TOPIC MODE for the main niche + 3-5 sub-niches identified from SERP analysis.

### Step 3: Build the calendar

Map keywords to a publishing schedule:

```
══════════════════════════════════════════════════════
CONTENT CALENDAR: [niche] — [month range]
══════════════════════════════════════════════════════

WEEK 1 (Mar 10-16)
  Mon: [Article Title] — [Primary KW] — [Type] — [Est. Words]
  Thu: [Article Title] — [Primary KW] — [Type] — [Est. Words]

WEEK 2 (Mar 17-23)
  Mon: [Article Title] — [Primary KW] — [Type] — [Est. Words]
  Thu: [Article Title] — [Primary KW] — [Type] — [Est. Words]

...

CONTENT MIX
  Roundups:      X articles (X%)
  Reviews:       X articles (X%)
  How-tos:       X articles (X%)
  Comparisons:   X articles (X%)
  Informational: X articles (X%)

SEASONAL NOTES
  [Any timing considerations — product launches, holidays, trends]
══════════════════════════════════════════════════════
```

### Step 4: Save to `seo/content-calendar-[date].json`

---

## Important (all modes)

- **Always use MCP tools first.** Exa + WebSearch give real SERP data without API keys. Only recommend external APIs for exact volume numbers.
- **Search intent is king.** A keyword without intent classification is useless. Always classify.
- **Be honest about estimates.** Mark all volume estimates clearly. Never present guesses as data.
- **Prioritize opportunity over volume.** A low-volume keyword with no competition beats a high-volume keyword dominated by Wikipedia and Amazon.
- **Think in clusters, not individual keywords.** One article should target a cluster of related keywords, not just one.
- **Content type matters.** Match the keyword to the right article format — don't suggest a "how-to" for a transactional keyword.
- **The deliverable is actionable.** Every keyword should map to a specific article recommendation with title, type, and word count.
