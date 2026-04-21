# sf-audit-a11y

> Specialist accessibilité de niveau pro : WCAG 2.2 complet (A/AA/AAA) + patterns ARIA du W3C ARIA Authoring Practices (APG) pour composants custom. Niveau Radix UI / React Aria. Cross-platform (web ARIA + Flutter `Semantics`).

## Le problème

L'accessibilité dans un audit design généraliste se résume souvent à : "les images ont un alt, les liens ont un focus visible, le contraste est OK". C'est le minimum syndical, pas un niveau pro.

Un vrai audit a11y de 2026 doit couvrir :
- **WCAG 2.2 complet** (9 nouveaux success criteria par rapport à 2.1)
- **W3C ARIA Authoring Practices (APG)** — les patterns exacts pour combobox, menu, tabs, dialog, grid, tree
- **Focus management** avancé — trap, roving tabindex, virtual focus
- **Screen reader announcements** — ce que Voice Over / NVDA / JAWS disent réellement
- **Focus appearance 2.4.11** — 2px solid minimum, contraste 3:1
- **Target size 2.5.8** — 24×24px minimum, 44×44px recommandé touch

Cette skill fait ce travail, au niveau de rigueur qu'on trouve dans les composants Radix UI ou React Aria d'Adobe.

## Les 10 phases

### Phase 1 — WCAG 2.2 complet
Tous les success criteria A / AA / AAA :
- **Perceivable** : contrast (1.4.3), non-text content (1.1.1), resize text (1.4.4), reflow (1.4.10), text spacing (1.4.12)
- **Operable** : keyboard (2.1.1), no keyboard trap (2.1.2), timing (2.2), seizures (2.3), navigable (2.4)
- **Understandable** : readable, predictable, input assistance (3.1-3.3)
- **Robust** : parsing, name/role/value (4.1)

Les 9 nouveaux SC de WCAG 2.2 sont audités en détail dans les phases suivantes.

### Phase 2 — Keyboard navigation patterns (APG)
Vérifie la conformité aux patterns du W3C ARIA Authoring Practices pour chaque composant interactif :

| Composant | Tab | Arrow keys | Home/End | Enter/Space | Escape | Typeahead |
|-----------|-----|------------|----------|-------------|--------|-----------|
| Menu | entry | ↑↓ navigate | first/last | activate | close | focus match |
| Combobox | entry | ↑↓ options | first/last | select | close popup | filter |
| Tabs | entry | ←→ tabs | first/last | activate | — | — |
| Dialog | trap | — | — | — | close | — |
| Tree | entry | ↑↓ nav, ←→ expand | first/last | activate | — | focus match |
| Slider | entry | ↑↓/←→ step | min/max | — | — | — |

### Phase 3 — Focus management
Trois patterns distincts, chacun avec ses règles :

- **Focus trap** (dialogs, modals) : le focus ne sort pas du container. Tab en dernier élément → revient au premier. Shift+Tab en premier → va au dernier.
- **Roving tabindex** (menus, tabs, toolbars) : un seul élément dans le tab order (`tabindex="0"`), les autres à `tabindex="-1"`. Les arrow keys déplacent le focus ET le tabindex.
- **Virtual focus** (comboboxes) : le focus DOM reste sur l'input, `aria-activedescendant` pointe vers l'option "active". Le SR lit l'option active sans que le focus physique bouge.
- **Focus restoration** : après fermeture d'un dialog ou d'un menu, le focus revient sur l'élément déclencheur (le bouton qui a ouvert le dialog).

### Phase 4 — ARIA patterns par composant
Vérification composant par composant contre le W3C APG :
- `combobox` (role, aria-expanded, aria-controls, aria-activedescendant, aria-autocomplete)
- `menu` / `menubar` (role, aria-haspopup, aria-expanded)
- `dialog` / `alertdialog` (role, aria-modal, aria-labelledby)
- `tabs` (role=tablist/tab/tabpanel, aria-selected, aria-controls)
- `listbox` (role, aria-multiselectable, aria-selected)
- `grid` (role=grid/row/gridcell, aria-rowcount, aria-colindex)
- `tree` / `treegrid` (role, aria-expanded, aria-level, aria-posinset)
- `slider` / `spinbutton` (role, aria-valuenow, aria-valuemin, aria-valuemax)
- `toolbar` (role, aria-orientation)
- `tooltip` (role, aria-describedby)
- `disclosure` / `accordion` (aria-expanded, aria-controls)
- `carousel` (role=region, aria-roledescription=carousel)
- `feed` (role, aria-busy, aria-labelledby)

### Phase 5 — aria-live regions
- **polite** : annonces non-urgentes (notification de sauvegarde), attend une pause dans la parole du SR
- **assertive** : urgentes (erreur critique, session expire), interrompt le SR
- **off** : aucune annonce
- Règles : jamais double-announce (ne pas changer l'aria-live + changer le contenu au même render), `aria-atomic="true"` si tout le container doit être relu, tenir compte que certains SR ne supportent pas `aria-relevant`.

### Phase 6 — Screen reader announcements
Vérifier ce que le SR **dit réellement** pour chaque composant : nom + rôle + état + position. Outils : Voice Over sur macOS, NVDA sur Windows, TalkBack sur Android. Utilisation correcte de `aria-label`, `aria-labelledby`, `aria-describedby`.

### Phase 7 — Focus Appearance (WCAG 2.4.11, nouveau en 2.2)
- 2px solid minimum
- Contraste 3:1 contre les couleurs adjacentes
- Jamais `outline: none` sans remplacement
- `:focus-visible` préféré à `:focus` (pas de outline sur clic souris)

### Phase 8 — Target Size Minimum (WCAG 2.5.8, nouveau en 2.2)
- 24×24px minimum en CSS
- ≥ 8px de spacing entre targets adjacents (ou 24px offset aux voisins)
- 44×44px recommandé sur touch
- Exemptions : liens inline dans du texte, controls qui sont de facto obligatoires (widget natifs du user agent)
- Icon buttons : padding (pas width fixe) pour atteindre 24×24 — ex: icône 16px + 4px de padding de chaque côté

### Phase 9 — Dragging Movements (WCAG 2.5.7, nouveau en 2.2)
Toute interaction drag doit avoir une **alternative non-drag** : boutons, click-to-place, menu contextuel. Exemple : un kanban drag-and-drop doit aussi permettre de déplacer une carte via un menu "Move to column...".

### Phase 10 — Consistent Help (WCAG 3.2.6, nouveau en 2.2)
Les mécanismes d'aide (contact, FAQ, chat, tél) doivent apparaître au **même endroit relatif** sur toutes les pages qui les exposent. Pas de "chat en bas à droite sur /pricing, en haut à gauche sur /contact".

## Format du sub-report

```
ACCESSIBILITY AUDIT: [project name]
─────────────────────────────────────
WCAG 2.2 (A/AA)           [A/B/C/D]
  X critical violations | Y high | Z medium
Keyboard Navigation        [A/B/C/D]
  X components non-conformant to APG patterns
Focus Management           [A/B/C/D]
  X missing focus traps | Y missing roving tabindex | Z missing restoration
ARIA Patterns              [A/B/C/D]
  X components with incorrect ARIA (role / state / property)
aria-live Regions          [A/B/C/D]
  X missing announcements for status updates
Screen Reader Announcements [A/B/C/D]
  X components with unclear/missing accessible name
Focus Appearance (2.4.11)  [A/B/C/D]
  X elements with insufficient focus indicator
Target Size (2.5.8)        [A/B/C/D]
  X interactive targets < 24×24px
Dragging Alternatives (2.5.7) [A/B/C/D]
  X drag surfaces without non-drag alternative
Consistent Help (3.2.6)    [A/B/C/D]
─────────────────────────────────────
OVERALL                    [A/B/C/D]

QUICK WINS
  ⚡ [file:line] description — Why: [WCAG SC / APG pattern]
```

## Cross-platform

- **Web** : ARIA, `role`, `aria-*`, `tabindex`, `:focus-visible`, HTML native (`<dialog>`, `<details>`, `popover`)
- **Flutter** : `Semantics` widget, `FocusScope`, `Shortcuts`, `Actions`, `ExcludeSemantics`, `MergeSemantics`, `Focus`, `FocusNode`
- **Mobile natif** : `accessibilityLabel`/`accessibilityRole` (iOS via RN), `contentDescription` (Android)

Mapping conceptuel Flutter :
- `role="dialog"` → `Semantics(container: true, label: "Dialog", ...)`
- Focus trap → `FocusScope` avec `FocusTraversalGroup`
- Roving tabindex → `FocusNode` custom + `Shortcuts(shortcuts: { ... })`
- `aria-live` → `SemanticsService.announce()`

## Pourquoi niveau Radix / React Aria ?

La règle : **tu peux reproduire custom le niveau d'a11y de shadcn** (qui utilise Radix sous le capot) à partir du moment où tu as une skill bien composée qui te force à respecter les patterns APG. Cette skill fait ce travail.

Si un projet écrit ses propres composants interactifs (sans headless lib), l'a11y doit atteindre le même niveau qu'une lib mature. Cette skill mesure l'écart.

## Dépendances

- **Appelée par** : `sf-audit-design` en deep mode (parallèle avec `sf-audit-design-tokens` et `sf-audit-components`).
- **Complémentaire à** : `sf-audit-components` — celle-ci audite l'architecture des composants, cette skill audite leur accessibilité. Les deux ensemble donnent une vision complète.

## Exemple

```bash
# Standalone
/sf-audit-a11y

# Cross-projet
/sf-audit-a11y global
```
