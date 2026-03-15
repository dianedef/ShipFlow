---
name: shipflow-product-discovery
description: Discover high-converting affiliate products from Amazon, Etsy, eBay, Booking.com, and 30+ networks. Matches products to keywords, evaluates conversion potential, and generates structured product data for content integration.
disable-model-invocation: true
argument-hint: [keyword/niche | "match" keywords-file] (required)
---

## Context

- Current directory: !`pwd`
- Project CLAUDE.md: !`head -50 CLAUDE.md 2>/dev/null || echo "no CLAUDE.md"`
- Keywords files: !`find . -path "*/seo/keywords*" -o -name "keywords*.json" 2>/dev/null | grep -v node_modules | head -10 || echo "no keyword files"`
- Existing product data: !`find . -path "*/products*" -name "*.json" 2>/dev/null | grep -v node_modules | head -10 || echo "no product files"`
- Affiliate config: !`cat affiliate.config.json 2>/dev/null || cat .env 2>/dev/null | grep -i "affiliate\|amazon\|awin\|cj\|rakuten" || echo "no affiliate config"`

## Pipeline position

```
/shipflow-keyword-research --> /shipflow-product-discovery --> /shipflow-content-gen
                               (you are here — physical)       /shipflow-copywriter
```

**Prerequisite check:** This skill checks for `seo/keywords-*.json` files. If none exist, it suggests running `/shipflow-keyword-research` first. You can skip this if you already know your topic.

**For digital products** (SaaS, courses, ebooks, templates): use `/shipflow-product-discovery-digital` instead.

## Mode detection

- **`$ARGUMENTS` is a keyword/niche** --> DISCOVERY MODE: find products for that keyword.
- **`$ARGUMENTS` starts with "match"** --> MATCH MODE: match products to an existing keywords file.

---

## Available Data Sources (priority order)

### Tier 1: MCP Tools (already available, no setup)

1. **Exa Web Search** (`mcp__exa__web_search_exa`) -- Primary product discovery tool:
   - Search "[keyword] best products [year]" for curated lists
   - Search "[keyword] amazon best seller" for top Amazon products
   - Search "[keyword] review" for reviewed products with ratings
   - Search "[product name] affiliate program" for affiliate availability
   - Search "site:amazon.com [keyword]" for Amazon-specific results

2. **WebSearch** -- Broader product research:
   - Find "best [keyword] products" roundup articles
   - Discover product comparison pages
   - Find affiliate program directories for a niche

3. **WebFetch** -- Deep product analysis:
   - Fetch Amazon product pages for pricing, ratings, review counts
   - Fetch competitor roundup articles to see what products they recommend
   - Fetch affiliate network product pages for commission rates

### Tier 2: Affiliate Network APIs (require setup)

| API | Products | Auth | Cost | Best For |
|-----|----------|------|------|----------|
| **Amazon Creators API** | 350M+ Amazon products | OAuth (Associates account, 10+ sales/mo) | Free | Physical products, electronics, books |
| **CJ Affiliate API** | 7,000+ advertisers via GraphQL | Personal Access Token | Free | Multi-merchant, major brands |
| **Datafeedr** | 950M+ products across 35+ networks | API key | $39-69/mo | One API for everything |
| **eBay Browse API** | eBay listings (new, used, auction) | OAuth 2.0 | Free | Used/refurbished, collectibles |
| **AliExpress Affiliate API** | 100M+ products | API key + secret | Free | Budget/dropship products |
| **Rakuten Advertising API** | Major retailer feeds (XML) | OAuth 2.0 Bearer | Free | Retail brands |
| **Awin API** | Etsy, HP, Alibaba + thousands more | Bearer token | Free | European merchants, Etsy |
| **ShareASale API** | ShareASale merchants | SHA-256 hash auth | Free | Niche merchants |
| **Impact API** | DTC brands, SaaS | Platform credentials | Free | DTC, software |
| **Booking.com Demand API** | Travel: hotels, cars, flights | Affiliate ID + token | Free | Travel niche |
| **SerpAPI Google Shopping** | Cross-retailer price comparison | API key | From $50/mo | Price comparison |

### Tier 3: MCP Servers (can be installed)

| MCP Server | Source | What it adds |
|------------|--------|-------------|
| **SnapLinker MCP** | `mcp.snaplinker.com` | AI affiliate link generation, product search (AvantLink) |
| **Amazon MCP** (Fewsats) | `Fewsats/amazon-mcp` | Search + buy Amazon products with budget controls |
| **Amazon Scraper MCP** (Apify) | `apify.com/junglee/amazon-crawler/api/mcp` | Product data: prices, ratings, ASINs, reviews |
| **Shopify Catalog MCP** (official) | `shopify.dev/docs/agents/catalog/mcp` | Cross-merchant product search across Shopify ecosystem |
| **Shopify Storefront MCP** (official) | `shopify.dev/docs/apps/build/storefront-mcp` | Single store product browsing + cart |
| **Affise MCP** | `affise.com` | Campaign analysis, performance optimization |
| **Tapfiliate MCP** | `mcp.pipedream.com/app/tapfiliate` | Affiliate tracking + referral program management |
| **PostAffiliatePro MCP** | `flowhunt.io` | Affiliate analytics: clicks, transactions, conversion |
| **SerpAPI MCP** (official) | `serpapi/serpapi-mcp` | Google Shopping, eBay, Walmart product search |
| **Firecrawl MCP** (official) | `firecrawl/firecrawl-mcp-server` | Deep product page scraping + structured extraction |
| **Apify MCP** (official) | `apify/apify-mcp-server` | 2,000+ actors: Amazon, eBay, Google Shopping scrapers |
| **Bright Data MCP** | `brightdata/brightdata-mcp` | SERP API + stealth scraping + CAPTCHA solving |
| **E-Commerce Scraper MCP** (Apify) | `apify.com/iglu/e-commerce-scraper/api/mcp` | Generic e-commerce product extraction |

---

## DISCOVERY MODE

Find high-converting products for a keyword/niche.

### Step 1: Parse the request

From `$ARGUMENTS`, identify:
- **Product keyword** -- what the user wants to find products for
- **Niche qualifiers** -- budget, premium, beginner, professional, etc.
- **Product type signals** -- physical, digital, SaaS, service, travel
- **Platform preferences** -- if any specific marketplace mentioned

### Step 2: Product research (use Exa + WebSearch)

Run 4-6 parallel searches:

1. **"best [keyword] [year]"** -- Find curated product roundups
2. **"[keyword] amazon best seller"** -- Amazon top sellers
3. **"[keyword] review comparison"** -- Comparative reviews
4. **"[keyword] affiliate program"** -- Affiliate availability
5. **"top rated [keyword] products"** -- High-rated products
6. **"[keyword] alternatives"** -- Product alternatives and competitors

### Step 3: Extract product data

For each product found, gather:

```
Product Data Schema:
- name: Product name
- brand: Manufacturer/brand
- category: Product category
- price_range: Estimated price range
- rating: Average rating (if found)
- review_count: Number of reviews (if found)
- key_features: Top 3-5 features
- pros: Strengths mentioned in reviews
- cons: Weaknesses mentioned in reviews
- best_for: Ideal user segment
- affiliate_platforms: Where this product has affiliate programs
- conversion_signals: Why this product converts well
```

### Step 4: Conversion potential scoring

Score each product on conversion potential (1-10):

| Factor | Weight | How to Assess |
|--------|--------|---------------|
| **Rating quality** | 25% | 4.5+ stars with 1000+ reviews = high |
| **Price point** | 20% | Sweet spot: $20-200 for impulse, >$200 needs strong intent match |
| **Review sentiment** | 20% | Consistent positive mentions of key features |
| **Affiliate availability** | 15% | Available on Amazon + at least one other network = high |
| **Market demand** | 10% | Appears in multiple "best of" lists = high demand |
| **Commission potential** | 10% | Higher commission rate or higher price = more earnings per click |

**Conversion Score** = weighted average across all factors

### Step 5: Affiliate program mapping

For each product, identify available affiliate programs:

```
Product: [Name]
├── Amazon Associates: [Yes/No] — Commission: [X%] — Cookie: 24h
├── Direct affiliate: [Yes/No] — Commission: [X%] — Cookie: [days]
├── CJ Affiliate: [Yes/No] — Commission: [X%]
├── ShareASale/Awin: [Yes/No] — Commission: [X%]
└── Other networks: [list]

Recommended: [Best program for this product and why]
```

### Step 6: Content integration recommendations

For each product, suggest how to integrate into content:

- **Product Roundup**: Include as item #X in "Best [Keyword] of [Year]"
- **Product Review**: Standalone in-depth review (1500-2500 words)
- **Product Comparison**: Compare with [competitor product] — "[Product A] vs [Product B]"
- **How-to Guide**: Feature as recommended tool in "[How to Do X]"
- **Informational**: Mention as solution in "[What is X / Why You Need X]"

### Step 7: Report

```
══════════════════════════════════════════════════════
PRODUCT DISCOVERY: [keyword/niche]
══════════════════════════════════════════════════════

MARKET OVERVIEW
  Product category:        [category]
  Price range:             [low] — [high]
  Dominant platforms:      [Amazon, direct, etc.]
  Commission range:        [X% — Y%]
  Content opportunity:     [Roundup / Review / Comparison]

──────────────────────────────────────────────────────
TOP PRODUCTS (ranked by conversion potential)
──────────────────────────────────────────────────────

### 1. [Product Name] — [Brand]
  Price:         $XXX
  Rating:        4.X/5 (X,XXX reviews)
  Best for:      [user segment]
  Key features:  [top 3]
  Affiliate:     [best program] — [commission %]
  Conv. score:   [X/10]
  Content fit:   [Roundup #1, Standalone Review]

### 2. [Product Name] — [Brand]
  ...

### 3-10. [Continue for top 10 products]
  ...

──────────────────────────────────────────────────────
COMMISSION COMPARISON
──────────────────────────────────────────────────────

| Product | Amazon | Direct | CJ | Awin | Best Option |
|---------|--------|--------|-----|------|-------------|
| [name] | 4% | 10% | — | — | Direct (10%) |
| [name] | 3% | — | 8% | — | CJ (8%) |
| ... | | | | | |

──────────────────────────────────────────────────────
CONTENT PLAN
──────────────────────────────────────────────────────

| Article | Type | Products Featured | Est. Commission/Click |
|---------|------|-------------------|----------------------|
| "Best [X] of [Year]" | Roundup | #1, #2, #3, #5, #7 | $X.XX avg |
| "[Product 1] Review" | Review | #1 | $X.XX |
| "[Product 1] vs [Product 2]" | Comparison | #1, #2 | $X.XX avg |
| "How to [Use Case]" | How-to | #1, #4 | $X.XX avg |

──────────────────────────────────────────────────────
DATA ACCURACY NOTE
══════════════════════════════════════════════════════
Prices, ratings, and commissions are point-in-time estimates from
web research. For real-time data, configure:
  - Amazon Creators API (free, requires 10+ sales/month)
  - Datafeedr ($39/mo — searches 35+ networks, 950M products)
  - CJ Affiliate API (free — 7,000+ advertisers)
  - SnapLinker MCP (mcp.snaplinker.com — AI affiliate links)
══════════════════════════════════════════════════════
```

### Step 8: Save & offer next steps

Save product data to `seo/products-[keyword-slug].json`:

```json
{
  "keyword": "[keyword]",
  "researched_at": "[ISO date]",
  "market_overview": { ... },
  "products": [
    {
      "name": "...",
      "brand": "...",
      "price_range": "$XX-$XX",
      "rating": 4.7,
      "review_count": 2345,
      "conversion_score": 9.1,
      "key_features": ["...", "..."],
      "pros": ["...", "..."],
      "cons": ["...", "..."],
      "best_for": "...",
      "affiliate_programs": [
        { "network": "Amazon", "commission": "4%", "cookie_days": 1 },
        { "network": "Direct", "commission": "10%", "cookie_days": 30 }
      ],
      "content_fit": ["Roundup", "Standalone Review"]
    }
  ],
  "content_plan": [ ... ]
}
```

Then ask:

> **Product discovery complete. What next?**
> 1. Generate a product roundup article (`/shipflow-content-gen roundup`)
> 2. Generate a product review (`/shipflow-content-gen review [product]`)
> 3. Research more products for a different keyword
> 4. Match these products to existing keyword research (`/shipflow-product-discovery match`)

---

## MATCH MODE

When `$ARGUMENTS` starts with "match", match products to an existing keyword file.

### Step 1: Load keyword data

Read the keywords file specified (or the most recent `seo/keywords-*.json`).

### Step 2: Categorize keywords by product relevance

- **High product fit**: Commercial intent (CI) and transactional (T) keywords
- **Medium product fit**: Informational keywords that could include product recommendations
- **Low product fit**: Pure informational keywords (define, explain, history)

### Step 3: Run product discovery for each high-fit keyword

Launch parallel agents (one per keyword cluster), each running DISCOVERY MODE Steps 2-6.

### Step 4: Product-keyword mapping

```
══════════════════════════════════════════════════════
PRODUCT-KEYWORD MATCH: [niche]
══════════════════════════════════════════════════════

| Keyword Cluster | Intent | Top Products | Best Article Type |
|----------------|--------|-------------|------------------|
| [cluster 1] | CI | [Product A, B, C] | Roundup |
| [cluster 2] | T | [Product D] | Review |
| [cluster 3] | I | [Product A mention] | How-to |
| ... | | | |

MONETIZATION PRIORITY (by estimated revenue per article)
  1. [keyword] → [article type] → [products] → Est. $XX/mo
  2. ...
══════════════════════════════════════════════════════
```

### Step 5: Save to `seo/product-keyword-match-[date].json`

---

## Important (all modes)

- **Conversion potential > product count.** 5 high-converting products beat 50 random ones. Be selective.
- **Always verify affiliate availability.** Don't recommend a product if there's no affiliate program for it.
- **Price point awareness.** Match product price to keyword intent. "Budget [X]" should feature products under $50, not $500 items.
- **Freshness matters.** Flag products with outdated models or discontinued items. Only recommend currently available products.
- **Commission stacking.** Always check if a product is available on multiple affiliate networks — recommend the highest-paying one.
- **Review authenticity signals.** Favor products with high review counts AND high ratings. A 5.0 rating with 3 reviews is suspicious.
- **The deliverable is a content plan.** Raw product data is useless without article recommendations. Every product set should map to specific content.
- **Content Egg reference.** The Content Egg WordPress plugin integrates 30+ affiliate networks (Amazon, AliExpress, eBay, CJ, Rakuten, Awin, etc.). If the user is on WordPress, recommend it as an all-in-one product display solution after research is done.
