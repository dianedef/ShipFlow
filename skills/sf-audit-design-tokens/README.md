# sf-audit-design-tokens

> Specialist profond sur les 4 systèmes de design tokens : **theme, typography, spacing, motion**. Appelée par `sf-audit-design` en deep mode ou utilisée en standalone.

## Le problème

Un design system ne tient pas à coup d'Figma. Il tient à coup de **tokens centralisés** : des variables partagées (couleur, taille de texte, espacement, durée d'animation) qui sont la seule source de vérité. Quand un développeur écrit `padding: 14px` ou `font-size: 1.2rem` directement dans un composant, le système fuit. Multiplié par 200 composants, c'est le chaos.

Cette skill audite les 4 systèmes de design tokens avec une rigueur que ne peut pas atteindre un audit généraliste : coverage matrix par thème, ratio modulaire, graphe de dépendances, drift historique, conformité DTCG.

## Les 4 systèmes audités

| Système | Ce qui est vérifié |
|---------|-------------------|
| **Theme Architecture** | 3 modes (light/dark/system), persistence, sync serveur si auth, FOUC prevention, préférence centralisée |
| **Typography Tokens** | Centralisation (0 literal), bundle (size+line-height+letter-spacing), ratio modulaire, `clamp()` fluide |
| **Spacing Tokens** | Centralisation, ratio cohérent (4px-base / 8px-base / modulaire), naming adaptatif |
| **Motion Tokens** | Tokens sémantiques (`duration-fast`), `prefers-reduced-motion`, compositor-only props |

## Les 7 phases

### Phase 1 — Inventory
Liste exhaustive des tokens présents dans chaque système. Métriques chiffrées : combien de tokens, combien de literal values en dehors du système, combien de références token.

### Phase 2 — Token coverage matrix per mode
Matrice token × mode (light / dark / custom). Un token `success` défini seulement en light = dark mode cassé. Détecte les trous systématiquement.

### Phase 3 — Modular ratio analysis
Calcule les ratios réels entre tokens consécutifs dans les scales typo + spacing. Si les ratios sont `1.1×`, `1.4×`, `1.2×` — c'est du chaos, pas une scale. **Recommande Utopia.fyi** pour régénérer une scale cohérente à partir d'un ratio (1.125 minor second, 1.2 minor third, 1.25 major third, 1.333 perfect fourth, 1.414 augmented fourth, 1.5 perfect fifth, 1.618 golden).

### Phase 4 — Dependency graph
Quel token référence quel autre token (ex: `--color-danger-bg: color-mix(in oklch, var(--color-danger) 15%, var(--surface-base))`). Détecte les cycles, les orphelins, les références vers des tokens qui n'existent plus.

### Phase 5 — Historical drift
`git log` sur les fichiers de tokens. Détecte les ajouts non-canoniques (un token ajouté hors de la scale), les renommages incohérents, la dette accumulée.

### Phase 6 — DTCG compliance
Si `tokens.json` ou équivalent présent, vérifie la conformité au format W3C Design Tokens Community Group (`$value`, `$type`, `$description`). La première version stable du DTCG a été publiée en octobre 2025.

### Phase 7 — Theme system architecture (deep)
Reprend les checks de l'audit light avec plus de rigueur : mesure effective du FOUC via inspection du HTML initial, sync serveur testé par requête, préférence normalisée (un ancien cookie corrompu ne doit pas crasher l'app).

## Naming adaptatif à la taille du projet

| Taille | Naming recommandé | Exemple |
|--------|-------------------|---------|
| Small (< 30 composants, site de contenu) | **T-shirt** | `xs`, `sm`, `base`, `lg`, `xl`, `2xl` |
| Large (SaaS, multi-produit, design system partagé) | **Sémantique** | `body`, `caption`, `heading-1`, `display` |

Naming mixte dans le même projet = violation. Pick one and stick to it.

## Sévérité adaptative

- **Small project** (< 10 composants) → violations cappées à 🟡 medium
- **Mid project** (10-30 composants) → violations cappées à 🟠 high
- **Large project** (> 30 composants) → violations → 🔴 critical

La logique : à petite échelle, le drift n'a pas de coût réel. À grande échelle, il compound. L'audit calibre sa rigueur en conséquence.

## Format du sub-report

```
DESIGN TOKEN AUDIT: [project name]
─────────────────────────────────────
Theme Architecture     [A/B/C/D]
  Modes:           [light + dark + system / ...]
  Preference:      [centralized + normalized / scattered / missing]
  Persistence:     [present / missing]
  Server sync:     [yes / N/A / MISSING — auth present but no sync]
  FOUC prevention: [yes / no]
  Settings UI:     [present / missing]
Typography Tokens      [A/B/C/D]
  Centralization:  X literal font-sizes outside tokens
  Naming:          [t-shirt / semantic / MIXED]
  Bundle:          [size+lh+ls bundled / font-size only]
  Scale ratio:     [coherent (1.X×) / chaotic — recommend Utopia.fyi]
  Fluid clamp():   [adopted / partial / absent / vw-dominant — WCAG risk]
Spacing Tokens         [A/B/C/D]
Motion Tokens          [A/B/C/D]
Universal Palette Socle [A/B/C/D]
─────────────────────────────────────
OVERALL                [A/B/C/D]

QUICK WINS
  ⚡ [file:line] description — Why: [principle]
```

## Cross-platform

- **Web** : CSS custom properties (`--fs-base`), Tailwind config, `theme()` helpers
- **Flutter** : `ThemeData`, `TextTheme`, `ColorScheme`, extensions via `ThemeExtension`
- **Design files** : `tokens.json` DTCG

## Dépendances

- **Appelée par** : `sf-audit-design` en deep mode (Agent tool, en parallèle avec `sf-audit-components` et `sf-audit-a11y`).
- **Recommande** : `sf-design-playground` en quick-win si aucune page de preview des design tokens n'est détectée.

## Exemple

```bash
# Standalone (hors orchestrateur)
/sf-audit-design-tokens

# Cross-projet
/sf-audit-design-tokens global
```
