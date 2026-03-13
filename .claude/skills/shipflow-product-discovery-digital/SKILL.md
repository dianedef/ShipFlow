---
name: shipflow-product-discovery-digital
description: Discover high-converting digital products — SaaS, online courses, ebooks, templates, WordPress plugins, design assets. Covers French-market platforms (SystemeIO, 1TPE) and global platforms (AppSumo, Envato, Gumroad, Udemy, ClickBank). Higher commissions, recurring revenue focus.
disable-model-invocation: true
argument-hint: [keyword/niche | "match" keywords-file | "fr" keyword] (required)
---

## Context

- Current directory: !`pwd`
- Project CLAUDE.md: !`head -50 CLAUDE.md 2>/dev/null || echo "no CLAUDE.md"`
- Keywords files: !`find . -path "*/seo/keywords*" -o -name "keywords*.json" 2>/dev/null | grep -v node_modules | head -10 || echo "no keyword files"`
- Existing product data: !`find . -path "*/products*" -name "*.json" 2>/dev/null | grep -v node_modules | head -10 || echo "no product files"`
- Language/locale files: !`find . -path "*/locales/*" -o -path "*/i18n/*" -o -name "*.fr.*" 2>/dev/null | head -5 || echo "no locale files"`
- Affiliate config: !`cat affiliate.config.json 2>/dev/null || cat .env 2>/dev/null | grep -i "affiliate\|appsumo\|envato\|gumroad\|systeme" || echo "no affiliate config"`

## Pipeline position

```
/shipflow-keyword-research --> /shipflow-product-discovery-digital --> /shipflow-content-gen
                               (you are here)                         or /shipflow-copywriter
```

**Prerequisite check:** This skill checks for `seo/keywords-*.json` files. If none exist, it suggests running `/shipflow-keyword-research` first. You can skip this if you already know your topic.

## Mode detection

- **`$ARGUMENTS` starts with "fr"** --> FRENCH MODE: prioritize French-market platforms (1TPE, SystemeIO, Digi-Shop, French Udemy/Skillshare).
- **`$ARGUMENTS` is a keyword/niche** --> DISCOVERY MODE: find digital products globally (English default).
- **`$ARGUMENTS` starts with "match"** --> MATCH MODE: match digital products to an existing keywords file.

---

## Why Digital Products Need a Separate Skill

| Factor | Physical Products | Digital Products |
|--------|------------------|-----------------|
| Commission | 1-10% (Amazon: 1-4%) | 20-75% (often 50%+) |
| Cookie duration | 24h (Amazon) | 30-365 days |
| Recurring revenue | Rare | Common (SaaS subscriptions) |
| Refund risk | Low | Higher (30-day guarantees) |
| Earning per click | $0.10-$2.00 | $2.00-$50.00+ |
| Platforms | Amazon, eBay, retail | AppSumo, Gumroad, Envato, SaaS direct |
| Evaluation criteria | Rating, reviews, price | Trial quality, onboarding, support, updates |

---

## Digital Product Platforms

### Global Platforms

| Platform | Product Types | Commission | Cookie | Auth/API |
|----------|-------------|-----------|--------|----------|
| **AppSumo** | SaaS lifetime deals | 100% first month (new), then varies | 30 days | Partner program, no public API |
| **Envato / ThemeForest / CodeCanyon** | WordPress themes, plugins, templates, code | 30% first purchase | 90 days | Envato API (OAuth) |
| **Creative Market** | Design assets, fonts, templates | 15% | 30 days | Affiliate program |
| **Gumroad** | Ebooks, courses, digital downloads | Custom (creator sets) | 30 days | Gumroad API (OAuth) |
| **LemonSqueezy** | SaaS, digital products | Custom per creator | 30 days | LemonSqueezy API |
| **Udemy** | Online courses | 15-20% | 7 days | Udemy Affiliate API |
| **Skillshare** | Online courses (subscription) | $7/free trial referral | 30 days | Impact affiliate |
| **Coursera** | University courses, certificates | 15-45% | 30 days | Impact affiliate |
| **Teachable** | Creator courses | 30% recurring | 90 days | Direct program |
| **Podia** | Courses, memberships, downloads | 30% recurring | 30 days | Direct program |
| **ClickBank** | Digital products, courses, ebooks | 50-75% | 60 days | ClickBank API |
| **JVZoo** | Digital marketing tools, courses | 50-100% | Cookie-less (IP tracking) | JVZoo API |
| **WarriorPlus** | Internet marketing products | 50-100% | Session-based | Direct program |
| **Payhip** | Ebooks, courses, memberships | 50% | 30 days | Direct program |
| **Paddle** | SaaS products | Varies by vendor | Varies | Paddle API |
| **Hotmart** | Digital products (strong in LatAm) | Up to 80% | 180 days | Hotmart API |
| **Partnerize** | Premium brands (SaaS, retail) | Varies | Varies | Partnerize API |

### French-Market Platforms

| Platform | Product Types | Commission | Cookie | Notes |
|----------|-------------|-----------|--------|-------|
| **1TPE** | Ebooks, formations, logiciels (French affiliate #1) | 20-70% | 365 days | Largest French-language affiliate marketplace |
| **SystemeIO** | All-in-one marketing platform | 40% recurring lifetime | 180 days | Created by Aurelien Amacker, huge French community |
| **Digi-Shop** | Formations, ebooks numériques | Varies | 30 days | French digital product marketplace |
| **Learnybox** | Formations en ligne | 30% recurring | 60 days | French LMS/course platform |
| **Kooneo** | Produits numériques, formations | Varies | 30 days | French e-commerce for digital products |
| **Thinkific** (FR content) | Courses (supports French) | 30% recurring | 90 days | Global but many French creators |
| **Affilae** | French affiliate network | Varies by merchant | Varies | Major French affiliate network (CPA/CPL/CPS) |
| **Effinity** | French affiliate network | Varies | Varies | Specialist French performance marketing |
| **Awin France** | French merchants on Awin | Varies | Varies | Awin's French division |
| **CJ France** | French merchants on CJ | Varies | Varies | CJ's French programs |

### SaaS Direct Affiliate Programs (High-Value)

Many SaaS companies run direct affiliate programs with 20-40% recurring commissions:

| SaaS Category | Examples | Typical Commission |
|--------------|----------|-------------------|
| **Email marketing** | ConvertKit (30%), Mailchimp (varies), Brevo/Sendinblue (€5/referral), ActiveCampaign (30%) | 20-30% recurring |
| **Website builders** | Wix (100% first), Squarespace ($100-200 flat), Webflow (50%) | High one-time or recurring |
| **SEO tools** | SEMrush (40% recurring), Ahrefs ($170/sale), Surfer SEO (25%) | 25-40% recurring |
| **Project management** | Monday.com (varies), Notion (50%), ClickUp (20%) | 20-50% |
| **Design tools** | Canva (varies), Figma (none), Adobe CC (85% first month) | Varies |
| **Hosting** | Cloudways (varies), SiteGround ($50-100/sale), Kinsta ($50-500) | High one-time |
| **Marketing automation** | HubSpot (30% recurring), Kartra (40%), GetResponse (33%) | 30-40% recurring |
| **AI tools** | Jasper AI (30%), Copy.ai (varies), Writesonic (30%) | 20-30% recurring |

---

## Available Data Sources

### Tier 1: MCP Tools (already available, no setup)

1. **Exa Web Search** (`mcp__exa__web_search_exa`) -- Primary digital product discovery:
   - Search "[keyword] best tools [year]" for SaaS roundups
   - Search "[keyword] course review" for course discovery
   - Search "[keyword] template" for design/code assets
   - Search "site:appsumo.com [keyword]" for lifetime deals
   - Search "meilleur [keyword] formation" for French market
   - Search "site:1tpe.com [keyword]" for French digital products

2. **WebSearch** -- Broader research:
   - Find "[keyword] affiliate program" for direct programs
   - Discover "alternative to [product]" for competitor mapping
   - Search "[produit] avis" for French product reviews

3. **WebFetch** -- Deep product analysis:
   - Fetch product landing pages for feature/pricing extraction
   - Fetch G2/Capterra/Trustpilot pages for ratings
   - Fetch affiliate program pages for commission details

### Tier 2: External APIs

| API | Best For | Auth | Cost |
|-----|----------|------|------|
| **ClickBank API** | Digital product marketplace | Account + API key | Free |
| **Envato API** | Themes, plugins, templates | OAuth token | Free |
| **Gumroad API** | Creator digital products | OAuth | Free |
| **Udemy Affiliate API** | Online courses | Affiliate account | Free |
| **Hotmart API** | Digital products (LatAm + global) | API key | Free |
| **LemonSqueezy API** | SaaS + digital products | API key | Free |
| **G2 API** | SaaS reviews + ratings | API key | Paid |
| **Capterra API** | Software reviews | Contact | Paid |
| **Product Hunt API** | Trending SaaS/tools | OAuth | Free |

### Tier 3: MCP Servers

| MCP Server | Source | What it adds |
|------------|--------|-------------|
| **Shopify Catalog MCP** | Official | Cross-merchant digital product search |
| **Apify MCP** | `apify/apify-mcp-server` | Scrapers for G2, Capterra, Product Hunt, AppSumo |
| **Firecrawl MCP** | `firecrawl/firecrawl-mcp-server` | Deep landing page scraping + structured data |
| **SnapLinker MCP** | `mcp.snaplinker.com` | Affiliate link generation |

---

## DISCOVERY MODE

### Step 1: Parse the request

From `$ARGUMENTS`, identify:
- **Product keyword** -- the topic/niche
- **Product type signals** -- SaaS, course, template, ebook, plugin
- **Language** -- if "fr" prefix or French terms detected, activate French mode
- **Audience** -- B2B, B2C, creator, developer, marketer, student

### Step 2: Digital product research

Run 5-7 parallel searches tailored to digital product types:

1. **SaaS tools**: "best [keyword] software [year]" / "meilleur logiciel [keyword] [year]"
2. **Online courses**: "best [keyword] course online" / "meilleure formation [keyword]"
3. **Templates/assets**: "[keyword] template" or "[keyword] plugin wordpress"
4. **Ebooks/guides**: "[keyword] ebook guide" / "[keyword] guide pdf"
5. **Deals**: "site:appsumo.com [keyword]" or "[keyword] lifetime deal"
6. **Affiliate programs**: "[keyword] tool affiliate program" or "programme affiliation [keyword]"
7. **Reviews**: "[keyword] tool review G2" or "[keyword] avis utilisateurs"

### Step 3: Extract digital product data

For each product found:

```
Digital Product Schema:
- name: Product name
- type: SaaS | Course | Ebook | Template | Plugin | Design Asset | Membership
- creator: Company or individual creator
- price_model: One-time | Subscription | Freemium | Lifetime Deal
- price: Price or price range
- free_trial: Yes/No + duration
- rating: G2/Capterra/Trustpilot score (if SaaS) or platform rating (if course)
- review_count: Number of reviews
- key_features: Top 3-5 features
- target_audience: Who this is for
- language: Languages available (flag French availability)
- affiliate_program: Details (commission %, cookie, recurring?)
- recurring_revenue: Yes/No — monthly commission potential
- lifetime_value: Estimated LTV of a referred customer
- conversion_signals: Why this product converts well
- alternatives: 2-3 competing products
```

### Step 4: Revenue potential scoring

Digital products use a different scoring model than physical:

| Factor | Weight | How to Assess |
|--------|--------|---------------|
| **Commission rate** | 25% | 50%+ = excellent, 30-49% = good, <20% = weak |
| **Recurring revenue** | 25% | Monthly recurring commissions compound over time |
| **Conversion rate signals** | 20% | Free trial available, strong landing page, good reviews |
| **Cookie duration** | 15% | 90+ days = excellent, 30 days = standard, 7 days = weak |
| **Product-market fit** | 15% | Active user base, growing market, solves real pain |

**Revenue Score** = weighted average (1-10)

**Monthly Revenue Estimate per 1,000 clicks:**
```
Est. Revenue = (Click-to-trial rate × Trial-to-paid rate × Avg commission) × 1000
  SaaS example: (10% × 20% × $15/mo) = $300/mo per 1,000 clicks (recurring!)
  Course example: (5% × 100% × $20) = $1,000 one-time per 1,000 clicks
```

### Step 5: Commission structure analysis

For digital products, commission structure matters more than for physical:

```
Product: [Name]
├── Direct affiliate: [Yes/No] — [X%] recurring — Cookie: [X days]
├── ClickBank: [Yes/No] — [X%] — Cookie: 60 days
├── 1TPE (French): [Yes/No] — [X%] — Cookie: 365 days
├── AppSumo: [Yes/No] — [X%] first month
├── Impact/CJ/Awin: [Yes/No] — [X%]
└── Recommended: [Best program and why]

Monthly Recurring Revenue potential: $[X]/referred customer/month
Lifetime Value estimate: $[X] over [Y] months
```

### Step 6: French market analysis (when applicable)

If French mode is active or French products found:

- **French audience sizing** -- Is there enough French-speaking search volume?
- **Localization quality** -- Is the product properly translated or just auto-translated?
- **French payment methods** -- Does it support Carte Bancaire, PayPal FR, virement?
- **French support** -- Is customer support available in French?
- **RGPD/GDPR compliance** -- Is the product compliant for EU/FR?
- **French competitors** -- Are there French-native alternatives to consider?
- **1TPE availability** -- Is the product on 1TPE (longest cookie in the market: 365 days)?

### Step 7: Report

```
══════════════════════════════════════════════════════
DIGITAL PRODUCT DISCOVERY: [keyword/niche]
[Language: EN/FR/Both]
══════════════════════════════════════════════════════

MARKET OVERVIEW
  Product types found:      [SaaS, Courses, Templates, ...]
  Price range:              [free-$XXX/mo or one-time]
  Commission range:         [X% — Y%] (avg: Z%)
  Recurring revenue:        [X of Y products offer recurring]
  Best platform:            [where most products are found]
  French market:            [Available / Limited / Strong]

──────────────────────────────────────────────────────
TOP DIGITAL PRODUCTS (ranked by revenue potential)
──────────────────────────────────────────────────────

### 1. [Product Name] — [Type: SaaS/Course/etc.]
  Price:            $XX/mo or $XX one-time
  Free trial:       [Yes — 14 days / No]
  Rating:           X/5 on [G2/Capterra/platform] (X reviews)
  French:           [Available / Not available]
  Affiliate:        [program] — [X%] [recurring/one-time] — [X-day cookie]
  Revenue est:      $XX/mo per 1,000 clicks
  Revenue score:    [X/10]
  Best content:     [Review, Comparison, Tutorial]

### 2. [Product Name] — [Type]
  ...

──────────────────────────────────────────────────────
🇫🇷 FRENCH MARKET PRODUCTS (if applicable)
──────────────────────────────────────────────────────

### [Produit] — [Type]
  Prix:             XX€/mois or XX€
  Plateforme:       [1TPE / SystemeIO / Direct]
  Commission:       [X%] — Cookie: [X jours]
  Avis:             [X/5 sur Y avis]
  Potentiel:        [X/10]

──────────────────────────────────────────────────────
RECURRING REVENUE OPPORTUNITIES
──────────────────────────────────────────────────────

| Product | Commission | Recurring | Monthly/Referred | 12-Month LTV |
|---------|-----------|-----------|-----------------|-------------|
| [SaaS 1] | 30% | Monthly | $15/mo | $180 |
| [SaaS 2] | 40% | Monthly | $20/mo | $240 |
| [Course platform] | 30% | Monthly | $10/mo | $120 |

Best recurring play: [product] — $XX/mo per referral

──────────────────────────────────────────────────────
CONTENT PLAN
──────────────────────────────────────────────────────

| Article | Type | Products | Est. Monthly Revenue |
|---------|------|----------|---------------------|
| "Best [X] Tools [Year]" | Roundup | #1, #2, #3 | $XXX/mo |
| "[Product 1] Review" | Review | #1 | $XX/mo |
| "[Product 1] vs [Product 2]" | Comparison | #1, #2 | $XX/mo |
| "Comment [faire X]" (FR) | How-to | #1 FR | $XX/mo |

══════════════════════════════════════════════════════
NEXT STEPS
══════════════════════════════════════════════════════
→ Generate content: /shipflow-content-gen [type] [topic]
→ Write conversion copy: /shipflow-copywriter [type] [product]
→ For physical products: /shipflow-product-discovery [keyword]
══════════════════════════════════════════════════════
```

### Step 8: Save & offer next steps

Save to `seo/products-digital-[keyword-slug].json` with all product data.

> **Digital product discovery complete. What next?**
> 1. Generate an article featuring these products (`/shipflow-content-gen`)
> 2. Write landing page / email copy for top product (`/shipflow-copywriter`)
> 3. Discover physical products for the same niche (`/shipflow-product-discovery`)
> 4. French-market deep dive (`/shipflow-product-discovery-digital fr [keyword]`)

---

## FRENCH MODE

When `$ARGUMENTS` starts with "fr", run DISCOVERY MODE with these adjustments:

1. **Search in French first**: "meilleur [keyword] [year]", "formation [keyword]", "outil [keyword] avis"
2. **Prioritize French platforms**: 1TPE, SystemeIO, Affilae, Learnybox
3. **Check French localization** for global products: UI, support, docs, payment
4. **French SEO keywords**: research French equivalents of English keywords
5. **Report bilingual**: product names in original, descriptions in French
6. **Flag RGPD/GDPR** compliance for each product
7. **French content suggestions**: article titles in French, targeting `.fr` SERPs

---

## MATCH MODE

Same as `/shipflow-product-discovery` match mode, but searches digital product platforms instead of physical product platforms. Loads keyword file, categorizes by digital product fit, launches parallel discovery agents.

---

## Important (all modes)

- **Recurring > one-time.** A $15/mo recurring commission from SaaS beats a $50 one-time commission from a course after 4 months. Always highlight recurring opportunities.
- **Free trials convert.** Products with free trials or freemium tiers convert 3-5x better than products requiring upfront payment. Prioritize them.
- **French market is underserved.** Less competition for French-language content means easier rankings. Flag this advantage when applicable.
- **1TPE has 365-day cookies.** This is the longest cookie in any affiliate marketplace. A referral that buys 11 months later still earns commission.
- **SaaS lifetime deals are time-sensitive.** AppSumo deals expire. Note the deal status and whether the product is still available.
- **Don't recommend vaporware.** Check that the product has real users, real reviews, and is actively maintained. A dead SaaS with a great affiliate program is a refund waiting to happen.
- **Commission stacking.** Some products are on multiple platforms (ClickBank + direct + 1TPE). Always recommend the highest-paying channel.
- **Creator reputation matters.** For courses and ebooks, the creator's reputation is the product. Check their track record, social following, and course completion rates.
