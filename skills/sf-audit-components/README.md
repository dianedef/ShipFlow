# sf-audit-components

> Specialist sur l'architecture des composants : inventaire atomic design, détection de duplication, god components, qualité des abstractions, adoption des variant systems et des headless primitives. Cross-platform (React/Vue/Svelte/Astro + Flutter).

## Le problème

Les composants, c'est la partie du design system où tout fout le camp en silence. Trois devs, trois semaines, et tu te retrouves avec 4 variantes de `Button` qui font presque la même chose, un `Card` à 23 props, et un composant `SuperModal` qui gère à la fois confirmation, alerte, formulaire et notification parce que "c'était plus simple".

Cette skill audite l'architecture des composants contre les bonnes pratiques modernes : Atomic Design (Brad Frost), Rule of Three (Fowler), AHA rule (Avoid Hasty Abstractions — Kent C. Dodds), headless primitives (Radix, React Aria), variant systems (CVA, tailwind-variants).

## Les 9 phases

### Phase 1 — Atomic Design Inventory
Classifie chaque composant en **atoms** (Button, Input, Icon), **molecules** (FormField, SearchBar), **organisms** (Header, ProductCard), **templates** (page layouts), **pages**. Repère les composants mal placés dans la hiérarchie.

### Phase 2 — Duplication Detection
Détecte les copy-paste patterns par similarité de nom + props + structure JSX. Applique la **Rule of Three** (Fowler) : avant la 3e occurrence, on ne factorise pas. Après, on abstrait.

### Phase 3 — God Components
Flag les composants avec :
- **> 15 props** (prop explosion anti-pattern)
- **> 300 lignes** (responsabilités multiples)
- **Plusieurs concerns non liés** (loading + error + empty + form + navigation dans un seul composant)

### Phase 4 — Unused Components
Composants importés nulle part dans le codebase (`grep -r "import.*ComponentName"` → 0 résultat). Candidats à la suppression.

### Phase 5 — Abstraction Quality (AHA rule)
**Avoid Hasty Abstractions** — Kent C. Dodds. Détecte les mauvaises abstractions : composants flexibles qui couvrent 3 cas avec des props escape-hatch partout, là où 3 composants distincts seraient plus clairs et plus maintenables.

> Règle : duplication est moins chère qu'une mauvaise abstraction. Une abstraction prématurée crée une dépendance à laquelle on devra tordre le code pour s'adapter.

### Phase 6 — Variant Systems Adoption
Si le projet utilise Tailwind + React/Vue + > 20 composants sans système de variants → recommande l'adoption de **CVA** (class-variance-authority) ou **tailwind-variants**. Bénéfice : variants typés, defaults, compound variants, pas de concaténation de strings à la main.

```ts
// Sans variant system (fragile)
<button className={`px-4 py-2 ${size === 'lg' ? 'text-lg' : 'text-sm'}`}>

// Avec CVA (typé, maintenable)
<button className={buttonVariants({ size: 'lg', intent: 'primary' })}>
```

### Phase 7 — Headless Primitives Adoption
Composants interactifs écrits from scratch → flag pour migration vers **headless libs** :
- **Radix UI** (React — stable, large catalog)
- **React Aria** (Adobe — le plus rigoureux en a11y)
- **Ark UI** (cross-framework via Zag state machines)
- **Base UI** (MUI — successeur de MUI Unstyled)
- **Headless UI** (Tailwind team — léger)

Cible : menu, dialog, combobox, tabs, toolbar, slider, listbox, tree, disclosure. Ces composants sont un cauchemar à implémenter correctement en a11y — utiliser une headless lib économise des semaines et évite les bugs ARIA subtils.

**Note importante** : la skill reste **neutre côté techno** (pas de bias shadcn). Si l'utilisateur n'utilise pas shadcn, elle recommande la lib headless qui correspond au framework + ne pousse jamais un stack particulier. Le principe : tu peux recréer le niveau d'a11y de shadcn à partir de n'importe quelle headless lib.

### Phase 8 — Composition vs Configuration
Détecte les composants qui surchargent de props booléens (`isLoading && isError && isEmpty && hasHeader && hasFooter`) là où le pattern **composition** serait plus clair :

```tsx
// Configuration (props-heavy)
<Card title="..." subtitle="..." image="..." ctaLabel="..." isLoading={...} />

// Composition (sous-composants)
<Card>
  <Card.Image src="..." />
  <Card.Title>...</Card.Title>
  <Card.CTA>...</Card.CTA>
</Card>
```

Le seuil : si > 3 props booléens ou > 8 props totales, la composition est probablement préférable.

### Phase 9 — Component API Hygiene
- Naming des props (cohérence : `onClose` partout, pas `onDismiss` ici et `onClose` là)
- Defaults raisonnables
- Required vs optional bien distingués
- Typage strict (pas de `any`, pas de `props: any extends object`)
- Controlled vs uncontrolled clarifié

## Format du sub-report

```
COMPONENT AUDIT: [project name]
─────────────────────────────────────
Atomic Design Inventory    [A/B/C/D]
  Atoms: X | Molecules: Y | Organisms: Z | Templates: N | Pages: M
Duplication                [A/B/C/D]
  X copy-paste patterns detected (> Rule of Three threshold)
God Components             [A/B/C/D]
  X components > 15 props | Y components > 300 lines
Unused Components          [A/B/C/D]
  X components with zero imports
Abstraction Quality (AHA)  [A/B/C/D]
  X premature abstractions flagged
Variant Systems Adoption   [A/B/C/D]
  [CVA / tailwind-variants / none — recommend CVA]
Headless Primitives        [A/B/C/D]
  X interactive components written from scratch (should migrate)
Composition vs Configuration [A/B/C/D]
  X components with > 3 boolean props (candidates for composition)
API Hygiene                [A/B/C/D]
─────────────────────────────────────
OVERALL                    [A/B/C/D]

QUICK WINS
  ⚡ [file:line] description — Why: [principle]
```

## Cross-platform

- **React** : functional components, hooks, `forwardRef`, `use client` boundaries
- **Vue** : SFC, `defineProps`, `defineEmits`, composables
- **Svelte** : `.svelte` components, runes (Svelte 5), slots
- **Astro** : `.astro` components (server-rendered), islands
- **Flutter** : `StatelessWidget` vs `StatefulWidget`, composition via `child`/`children`, `Widget`-as-function patterns

Pour Flutter, les équivalences :
- Atomic design → Widgets atomics/molecules/organisms
- Headless primitives → packages community (`flutter_hooks`, `go_router`, `riverpod` pour state)
- Variant systems → pattern `copyWith` + `ThemeExtension`

## Dépendances

- **Appelée par** : `sf-audit-design` en deep mode (parallèle avec `sf-audit-design-tokens` et `sf-audit-a11y`).
- **Associée** : l'accessibilité des composants (focus management, ARIA patterns, keyboard nav) est couverte par `sf-audit-a11y` séparément — cette skill se concentre sur l'architecture.

## Exemple

```bash
# Standalone
/sf-audit-components

# Cross-projet
/sf-audit-components global
```
