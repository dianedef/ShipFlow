# sf-design-playground

> Générateur (pas auditeur) qui scaffold une page `/design-system` versionnée avec preview live des design tokens, édition temps réel, et 3 modes d'export. Auth adaptative 3 niveaux.

## Le problème

Itérer sur un design system sans outil visuel, c'est travailler à l'aveugle. Tu changes un token, tu dois ouvrir 30 fichiers pour voir l'impact. Tu veux tester une nouvelle couleur de `danger`, tu dois modifier le code, recompiler, attendre.

La solution : une **page de preview centralisée** où tous les design tokens sont affichés en direct, éditables via sliders et color pickers, et exportables. Tous les design systems pro en ont une (Chakra, Material, Carbon, Tailwind UI). Cette skill la génère automatiquement pour ton projet.

## Ce que la skill génère

Une page `/design-system` versionnée qui contient :

### Preview des 4 systèmes de design tokens
- **Couleurs** : toute la palette (primitives + semantic socle + surfaces) avec contraste WCAG calculé en live
- **Typographie** : chaque token (size + line-height + letter-spacing) rendu sur un texte d'exemple, preview des ratios modulaires
- **Spacing** : visualisation des tokens d'espacement (barres proportionnelles)
- **Motion** : preview des durées + easings avec animation déclenchable

### Édition temps réel
- **Sliders** pour les valeurs numériques (font-size, spacing, duration)
- **Color pickers** pour les couleurs (avec support oklch)
- **Dropdowns** pour les easings et les ratios
- Les changements se répercutent **instantanément** sur la page (CSS variables mises à jour)

### 3 modes d'export

| Mode | Comportement | Usage |
|------|--------------|-------|
| **Copy** | Copie le token édité dans le clipboard (format `--fs-base: 1.125rem;`) | Test rapide, dev dans une autre fenêtre |
| **Save** | POST vers un endpoint dev-only qui patche le fichier de tokens | Iteration rapide sur design system, dev local |
| **Export** | Génère un fichier téléchargeable : `.css` (custom properties), `.json` (DTCG), `.ts` (TypeScript const) | Partage avec l'équipe, commit manuel |

Le mode **Save** est bloqué en production (`NODE_ENV !== 'development'`) pour éviter tout risque.

## Les 3 tiers d'authentification adaptatifs

La skill détecte automatiquement le contexte du projet et applique le tier approprié :

### Tier 1 — Dev : open
```
NODE_ENV === 'development' → accès libre
```
Tu hackes en local, pas de friction.

### Tier 2 — Prod + auth détectée : admin role
```
NODE_ENV === 'production' && auth library detected (next-auth, Clerk, Supabase, Better Auth, Lucia...) → admin role required
```
Si le projet a déjà une auth, la skill la réutilise et gate la page derrière un role `admin`.

### Tier 3 — Prod sans auth : password env var
```
NODE_ENV === 'production' && no auth library → password middleware
```
Middleware qui check un env var `DESIGN_PLAYGROUND_PASSWORD`. Pas besoin d'infrastructure auth complète juste pour gater une page interne.

## Frameworks supportés

| Framework | Route | Layout |
|-----------|-------|--------|
| Next.js (App Router) | `app/design-system/page.tsx` | `app/design-system/layout.tsx` |
| Next.js (Pages Router) | `pages/design-system.tsx` | `_app.tsx` middleware |
| Astro | `src/pages/design-system.astro` | `src/layouts/` |
| SvelteKit | `src/routes/design-system/+page.svelte` | `+layout.svelte` |
| Nuxt 3 | `pages/design-system.vue` | `layouts/` |
| Remix | `app/routes/design-system.tsx` | `app/root.tsx` |
| Vite SPA | route configurée dans router | lazy loadée |

Pour chaque framework, la skill génère la route + le middleware auth + les composants de preview.

## Versioning

La page est **versionnée** (`/design-system/v1`, `/design-system/v2`...) pour pouvoir tester un nouveau design system en parallèle de l'ancien sans casser la production.

## Garde-fous

La skill applique plusieurs protections pour éviter tout bricolage dangereux :

- **Path-locked** : le endpoint `Save` ne peut patcher QUE le fichier de tokens (`tokens.css`, `tokens.json`, `theme.ts`). Toute tentative d'écriture hors de ce path = rejet 403.
- **Format-validated** : avant d'écrire, le serveur valide que le contenu est du CSS / JSON / TS valide. Token malformé = rejet.
- **Backup-first** : avant chaque write, copie du fichier original dans `.backup-{timestamp}`. Recovery facile.
- **NODE_ENV check** : l'endpoint `Save` retourne 404 en production, quelles que soient les autres conditions. Défense en profondeur.
- **Rate limit** : max 10 writes par minute par session pour éviter les boucles.

## Pourquoi pas un Storybook ?

Storybook audite des **composants** (un `Button` dans tous ses états). `sf-design-playground` audite les **design tokens** (tous les tokens du système sur une page).

Complémentaires, pas redondants :
- Storybook → developer tool pour documenter les composants
- `/design-system` → design tool pour itérer sur les design tokens (utilisable par designer non-dev)

## Output

La skill génère :
- 1 route versionnée (`/design-system/v1`)
- 1 layout avec middleware auth adapté au tier détecté
- 4 composants de preview (Colors, Typography, Spacing, Motion)
- 1 composant d'édition (sliders, pickers, dropdowns)
- 1 endpoint API pour le mode Save (dev-only)
- Format exporters (CSS / JSON / TS)
- README local expliquant comment utiliser la page

## Dépendances

- **Associée à** : `sf-audit-design-tokens` — l'audit recommande cette skill en quick-win si aucune page de preview n'est détectée dans le projet.
- **Indépendante** : scaffold-and-forget. Une fois générée, la page vit sa vie dans le projet.

## Exemple

```bash
# Génère la page dans le framework détecté
/sf-design-playground

# Re-génère avec une nouvelle version (bump v1 → v2)
/sf-design-playground v2
```
