---
name: shipflow-copywriter
description: Expert conversion copywriter — writes headlines, landing pages, email sequences, CTAs, value propositions, and A/B variants using proven frameworks (AIDA, PAS, BAB, 4Ps, StoryBrand). Multilingual (EN/FR). Not content-gen — this is persuasion engineering.
disable-model-invocation: true
argument-hint: [headline|landing|email|cta|value-prop|full-funnel] [product/topic] (required)
---

## Context

- Current directory: !`pwd`
- Project CLAUDE.md: !`head -50 CLAUDE.md 2>/dev/null || echo "no CLAUDE.md"`
- Product data: !`ls -la seo/products*.json 2>/dev/null | tail -5 || echo "no product files"`
- Existing copy: !`find . -maxdepth 3 -type f \( -name "*.md" -o -name "*.mdx" -o -name "*.astro" -o -name "*.html" \) 2>/dev/null | grep -iE "landing|sales|pricing|cta|hero|about" | head -10 || echo "no landing/sales pages"`
- Locale files: !`find . -path "*/locales/*" -o -path "*/i18n/*" 2>/dev/null | head -5 || echo "no i18n"`
- Brand guidelines: !`find . -maxdepth 2 -type f -name "*brand*" -o -name "*style*guide*" -o -name "*tone*" 2>/dev/null | head -5 || echo "no brand files"`

## Pipeline position

```
/shipflow-keyword-research --> /shipflow-product-discovery[-digital] --> /shipflow-content-gen (articles)
                                                                     └─> /shipflow-copywriter (conversion copy)
                                                                          (you are here)
```

**This skill is NOT for articles.** Use `/shipflow-content-gen` for blog posts, roundups, reviews, how-tos. This skill writes **conversion copy** — text whose sole purpose is to get someone to take action (click, sign up, buy, subscribe).

## Mode detection

Parse `$ARGUMENTS` for copy type and subject:

- **`headline [product/topic]`** --> HEADLINE MODE: 20+ headline variants using proven formulas
- **`landing [product/topic]`** --> LANDING PAGE MODE: full above-the-fold + below-the-fold copy
- **`email [product/topic]`** --> EMAIL SEQUENCE MODE: 3-7 email nurture/sales sequence
- **`cta [product/topic]`** --> CTA MODE: button text, microcopy, urgency variants
- **`value-prop [product/topic]`** --> VALUE PROP MODE: positioning statement + supporting pillars
- **`full-funnel [product/topic]`** --> FULL FUNNEL MODE: all of the above as a complete conversion system

Add `--fr` or `--lang:fr` anywhere in arguments to generate in French.

---

## Copywriting Frameworks (use the right one for the context)

### AIDA — Attention, Interest, Desire, Action
**Best for:** Landing pages, sales pages, product descriptions
```
Attention: Hook that stops the scroll
Interest: "Here's what makes this different..."
Desire: Paint the after-state, social proof, benefits
Action: Clear CTA with urgency
```

### PAS — Problem, Agitation, Solution
**Best for:** Email subject lines, ad copy, pain-point-driven products
```
Problem: Name the pain they feel
Agitate: Make the pain vivid — consequences of not solving it
Solution: Your product as the relief
```

### BAB — Before, After, Bridge
**Best for:** Case studies, testimonial-driven copy, SaaS landing pages
```
Before: Their current painful reality
After: Their life with the problem solved
Bridge: Your product is how they get there
```

### 4Ps — Promise, Picture, Proof, Push
**Best for:** Sales letters, high-ticket product pages
```
Promise: Bold claim about the outcome
Picture: Help them visualize the result
Proof: Testimonials, data, case studies
Push: Urgency + CTA
```

### StoryBrand — The Hero's Journey for Marketing
**Best for:** Brand messaging, about pages, mission statements
```
Character: The customer (not you) has a problem
Guide: You are the guide with empathy + authority
Plan: Give them a simple plan (3 steps)
CTA: Call them to action
Success: Show what success looks like
Failure: Show what failure looks like (stakes)
```

### Formule PAPA (French) — Problème, Agitation, Preuve, Action
**Best for:** French-market copy, same as PAS but with proof added
```
Problème: Nommer la douleur
Agitation: Amplifier les conséquences
Preuve: Témoignages, chiffres, résultats
Action: CTA clair avec urgence
```

---

## HEADLINE MODE

Generate 20+ headline variants organized by framework.

### Step 1: Research the product/topic

Use Exa/WebSearch to:
- Find existing headlines for competing products
- Identify the #1 pain point and #1 desired outcome
- Find specific numbers/results for credibility

### Step 2: Generate headline variants

#### Power Headlines (proven formulas)

**Number + Outcome:**
- "7 [Things] That [Desirable Outcome] (Without [Pain Point])"
- "[X] [People] Have Already [Achieved Outcome]. Here's How."

**How-To:**
- "How to [Achieve Outcome] in [Timeframe] (Even If [Objection])"
- "Comment [Résultat] en [Délai] (Même Si [Objection])" (FR)
- "Comment tu peux [Résultat] en [Délai] (Même Si [Objection])" (FR, tutoiement)

**Question:**
- "Still [Doing Painful Thing]? There's a Better Way."
- "What If You Could [Desired Outcome] Without [Pain]?"

**Social Proof:**
- "Why [X,000] [Audience] Switched to [Product]"
- "The [Tool/Method] [Authority Figure] Uses to [Outcome]"

**Curiosity Gap:**
- "The [Adjective] [Thing] Most [Audience] Don't Know About [Topic]"
- "I [Did Thing] for [Time Period]. Here's What Happened."

**Urgency:**
- "[Outcome] Before [Deadline/Event]. Here's Your Plan."
- "Stop [Pain] Today. Start [Benefit] Tonight."

**Contrarian:**
- "Why [Common Advice] Is Actually Killing Your [Metric]"
- "[Controversial Opinion]: The Real Reason [Problem Exists]"

**French-Specific (tutoiement):**
- "Arrête de [Douleur]. Commence à [Bénéfice]."
- "La Méthode [X] Pour [Résultat] (Prouvée par [Nombre] Utilisateurs)"
- "Pourquoi [X] [Audience] Ont Choisi [Produit] en [Année]"
- "Tu [Douleur] encore ? Il y a mieux."

### Step 3: Deliver with scoring

```
══════════════════════════════════════════════════════
HEADLINES: [product/topic]
══════════════════════════════════════════════════════

TOP 5 RECOMMENDED (by estimated conversion potential)

1. [headline] — Framework: [X] — Why: [one-line reasoning]
2. ...

FULL LIST BY FRAMEWORK

### AIDA Headlines
  1. [headline]
  2. ...

### PAS Headlines
  1. [headline]
  2. ...

### Number/Outcome Headlines
  1. [headline]
  2. ...

### Question Headlines
  1. [headline]
  2. ...

### French Variants (🇫🇷)
  1. [headline]
  2. ...

A/B TEST RECOMMENDATION
  Control: [headline A]
  Variant: [headline B]
  Why: [what's being tested — emotional vs rational, long vs short, etc.]
══════════════════════════════════════════════════════
```

---

## LANDING PAGE MODE

Write complete landing page copy: hero section through final CTA.

### Step 1: Research

- Read product data from `seo/products*.json` if available
- Search for the product's existing landing page (analyze strengths/weaknesses)
- Search for competitor landing pages
- Identify the #1 objection and how to overcome it

### Step 2: Write the landing page

```markdown
## HERO SECTION (Above the fold)

### Headline
[Main headline — outcome-focused, specific]

### Subheadline
[1-2 sentences expanding the headline — addresses "how" or "for whom"]

### CTA Button
[Action verb + outcome] — e.g., "Start Your Free Trial" not "Submit"

### Supporting proof
[One-line social proof — "Trusted by 10,000+ teams" or "4.8/5 on G2"]

---

## PROBLEM SECTION

### Section headline
[Name the pain — "Tired of [painful thing]?"]

[2-3 pain points the audience experiences]
- Pain 1: [Specific, vivid, relatable]
- Pain 2: [Specific, vivid, relatable]
- Pain 3: [Specific, vivid, relatable]

---

## SOLUTION SECTION

### Section headline
[Position your product as the answer — "Meet [Product]"]

[Brief product description — what it does in one sentence]

### Key Benefits (not features)
1. **[Benefit headline]** — [One sentence explaining the outcome, not the mechanism]
2. **[Benefit headline]** — [One sentence]
3. **[Benefit headline]** — [One sentence]

---

## SOCIAL PROOF SECTION

### Testimonials
[3 testimonials — each with: quote, name, role, company, result achieved]

### Logos / Numbers
[Client logos or metrics: "10,000+ users", "99.9% uptime", "$2M saved"]

---

## HOW IT WORKS

### Section headline
["Get Started in 3 Steps" or "How It Works"]

1. **[Step 1]** — [What the user does + what happens]
2. **[Step 2]** — [What the user does + what happens]
3. **[Step 3]** — [What the user does + what happens (the outcome)]

---

## OBJECTION HANDLING (FAQ)

### [Objection as question]
[Answer that dissolves the objection]

### [Objection as question]
[Answer]

### [Objection as question]
[Answer]

---

## FINAL CTA SECTION

### Headline
[Restate the transformation — "Ready to [outcome]?"]

### Subheadline
[Risk reversal — "Start free. No credit card. Cancel anytime."]

### CTA Button
[Same as hero CTA for consistency]

### Microcopy below button
["Join 10,000+ [audience] who already [outcome]"]
```

### Step 3: Deliver

Output the full landing page copy in markdown, plus:
- French variant if requested
- A/B suggestions for the hero section
- Recommended Schema.org markup (`Product`, `SoftwareApplication`, `FAQPage`)

---

## EMAIL SEQUENCE MODE

Write a 3-7 email nurture/sales sequence.

### Email Sequence Structure

**Sequence A: Welcome + Nurture (SaaS/Course)**
1. **Welcome** — Deliver the lead magnet, set expectations (Day 0)
2. **Value** — Teach something useful, build authority (Day 2)
3. **Story** — Case study or personal story, BAB framework (Day 4)
4. **Objection** — Address the #1 objection head-on (Day 6)
5. **Soft sell** — Present the product as a natural next step (Day 8)
6. **Urgency** — Limited offer, deadline, scarcity (Day 10)
7. **Last chance** — Final email, direct ask (Day 12)

**Sequence B: Cart Abandonment (E-commerce/SaaS)**
1. **Reminder** — "You left something behind" (1 hour)
2. **Objection** — Address why they hesitated (24 hours)
3. **Social proof** — Testimonials + urgency (48 hours)

**Sequence C: Product Launch (French market)**
1. **Teaser** — "Quelque chose arrive..." (J-7)
2. **Valeur** — Contenu gratuit qui démontre l'expertise (J-5)
3. **Annonce** — Présentation du produit (J-0)
4. **Preuve** — Témoignages + résultats (J+2)
5. **FAQ** — Réponses aux objections (J+5)
6. **Dernière chance** — Urgence + FOMO (J+7)

### Email Template Format

```
SUBJECT LINE: [subject] (+ 2 A/B variants)
PREVIEW TEXT: [preview — the text shown after subject in inbox]

---

[Opening — 1-2 sentences, personal, hooks attention]

[Body — 3-5 paragraphs maximum]
[Framework used: AIDA/PAS/BAB]

[CTA — one clear action, linked]

[P.S. — optional, for urgency or bonus mention]

---
METRICS TO TRACK:
  Open rate target: [X%]
  Click rate target: [X%]
  Conversion target: [X%]
```

---

## CTA MODE

Generate button text, microcopy, and urgency variants.

### CTA Categories

**Action-Oriented (Primary):**
- "Start Your Free Trial"
- "Get [Product] Now"
- "Commence Gratuitement" (FR)

**Outcome-Oriented:**
- "Start [Achieving Outcome]"
- "Get My [Deliverable]"
- "Découvre Comment [Résultat]" (FR)

**Risk-Reducing:**
- "Try Free for 14 Days — No Credit Card"
- "Start Free. Upgrade When Ready."
- "Essaie Sans Engagement" (FR)

**Urgency:**
- "Claim Your Spot (XX Left)"
- "Get [X%] Off — Ends [Date]"
- "Offre Limitée — Plus Que [X] Places" (FR)

### Microcopy (below-button text)

- "No credit card required. Cancel anytime."
- "Join [X,000]+ [audience] who trust [product]"
- "30-day money-back guarantee"
- "Sans carte bancaire. Annule quand tu veux." (FR)

Output: 10+ CTA variants with microcopy, scored by likely conversion impact.

---

## VALUE PROP MODE

Create the core positioning statement and supporting pillars.

### Value Proposition Canvas

```
TARGET CUSTOMER: [Specific segment]
PAIN POINT: [#1 problem they face]
CURRENT ALTERNATIVES: [What they use now / do without]

VALUE PROPOSITION:
"[Product] helps [audience] [achieve outcome] by [mechanism],
unlike [alternative] which [limitation]."

FRENCH:
"[Produit] aide [audience] à [résultat] grâce à [mécanisme],
contrairement à [alternative] qui [limite]."

SUPPORTING PILLARS:
1. [Pillar 1 — key differentiator] — proof: [data/testimonial]
2. [Pillar 2 — key differentiator] — proof: [data/testimonial]
3. [Pillar 3 — key differentiator] — proof: [data/testimonial]

ELEVATOR PITCH (10 seconds):
"[One sentence that makes someone say 'tell me more']"

POSITIONING STATEMENT (internal):
"For [target], [product] is the [category] that [key benefit],
because [reason to believe]."
```

---

## FULL FUNNEL MODE

When `$ARGUMENTS` starts with "full-funnel", generate the complete conversion system:

1. **Value Proposition** (value-prop mode)
2. **Landing Page** (landing mode)
3. **Headlines** for ads/social (headline mode — top 5 only)
4. **Email Sequence** (email mode — 5-email welcome sequence)
5. **CTA Set** (cta mode — 5 variants)

All pieces should be tonally consistent and reference each other (landing page CTA matches email CTA, etc.).

---

## Language Handling

### French Copy Rules

French copywriting has specific conventions:

- **Typographic spaces** -- Use non-breaking space before `:`, `;`, `!`, `?`
- **Tutoiement par défaut** -- Utiliser "tu" (informel, direct, proche). Le vouvoiement sonne corporate et distant — on veut créer une connexion.
- **French punctuation** -- Guillemets « » not " " for quotes
- **Avoid anglicisms** -- "Télécharger" not "Downloader", "Courriel" not "Email" (though "email" is widely accepted)
- **French urgency words** -- "Offre limitée", "Plus que X places", "Dernière chance", "Ne rate pas ça"
- **French trust signals** -- "Satisfait ou remboursé", "Sans engagement", "Garanti X jours", "Teste gratuitement"
- **Cultural tone** -- French audiences respond better to sophistication and logic than aggressive American-style hype. Less exclamation marks, more elegant persuasion.

When generating French copy, apply these rules automatically. When generating bilingual, output EN first, then FR variant with a `🇫🇷` header.

---

## Quality Checklist (all modes)

Before delivering any copy:

- [ ] **One CTA per section** -- Never give two competing actions
- [ ] **Benefits over features** -- "Save 3 hours/week" > "Automated scheduling"
- [ ] **Specific over vague** -- "10,847 users" > "thousands of users"
- [ ] **Active voice** -- "Start your trial" > "Your trial can be started"
- [ ] **Second person** -- "You" (or "Vous"/"Tu") not "Users" or "Customers"
- [ ] **No jargon** -- Write for the buyer, not the builder
- [ ] **Power words present** -- Free, New, Proven, Guaranteed, Instant, Secret, You
- [ ] **Objection handled** -- At least one objection addressed per section
- [ ] **Social proof present** -- Numbers, names, logos, testimonials
- [ ] **Urgency is real** -- Never fabricate false scarcity
- [ ] **Mobile-scannable** -- Short paragraphs, bold keywords, bullet points
- [ ] **No AI tells** -- No "leverage", "streamline", "cutting-edge", "in today's landscape"

---

## Important

- **Copy is not content.** Content informs. Copy persuades. Every word in copy must earn its place by moving the reader toward action. If a sentence doesn't advance the sale, cut it.
- **Research before writing.** Never write copy without understanding the audience's pain, current alternatives, and objections. Use Exa/WebSearch to find real customer language (reviews, forum posts, support tickets).
- **One reader, one action.** Write as if talking to one specific person. Ask for one specific action. Multiple CTAs kill conversion.
- **French copy is not translated English.** French copy must be written natively, not translated. The rhythm, cultural references, and persuasion patterns are different. "Découvrez comment..." is better than a literal translation of "Find out how...".
- **A/B testing is mandatory.** Always provide at least 2 variants for headlines and CTAs. The best copywriter in the world doesn't know what converts until it's tested.
- **Steal from reviews.** The best copy comes from customer language. Search product reviews for the exact words people use to describe their pain and desired outcome. Use those words.
