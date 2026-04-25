---
name: sf-spec
description: Créer une spécification technique prête à implémenter — par conversation, investigation du code, et documentation structurée. Ancre la solution dans une user story claire avant de coder.
argument-hint: [optional: description de ce qu'on veut construire]
---

## Context

- Current directory: !`pwd`
- Current date: !`date '+%Y-%m-%d'`
- Project name: !`basename $(pwd)`
- Git branch: !`git branch --show-current 2>/dev/null || echo "unknown"`
- CLAUDE.md (constraints): !`head -60 CLAUDE.md 2>/dev/null || echo "no CLAUDE.md"`
- Master TASKS.md: !`cat /home/claude/shipflow_data/TASKS.md 2>/dev/null | head -40 || echo "No master TASKS.md"`
- Local TASKS.md (if exists): !`cat TASKS.md 2>/dev/null | head -30 || echo "No local TASKS.md"`
- Project structure: !`find . -maxdepth 3 -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.astro" -o -name "*.vue" -o -name "*.py" -o -name "*.sh" \) 2>/dev/null | grep -v node_modules | grep -v .git | grep -v dist | sort | head -30`

## Your task

Créer une spec technique complète et prête à implémenter par conversation. Quatre étapes : comprendre, investiguer, spécifier, valider.

### Step 0 — Choisir la profondeur de spec

Si le changement semble petit/local (ex: bug mono-fichier, ajustement mineur), utiliser **AskUserQuestion**:
- Question: "Quel niveau de spec veux-tu ?"
- `multiSelect: false`
- Options:
  - **Spec light (recommandé)** — "Structure minimale mais exécutable"
  - **Spec full** — "Spec complète avec couverture élargie"
  - **Je ne sais pas** — "Tu choisis selon le risque"

Règle de choix automatique si "Je ne sais pas":
- petit scope clair -> light
- ambigu/multi-domaines/non-trivial -> full

### Standard "Prêt à coder"

Une spec est prête UNIQUEMENT si :
- **Ancrée dans la user story** : l'acteur, le besoin, le déclencheur et le résultat attendu sont explicites
- **Réduite à sa forme comportementale minimale** : un paragraphe dit ce que le système accepte, retourne/produit, fait quand ça échoue, et quel edge case est facile à rater
- **Actionnable** : chaque tâche a un fichier cible et une action claire
- **Ordonnée** : les tâches sont triées par dépendance (fondations d'abord)
- **Testable** : les critères d'acceptation couvrent le happy path et les cas limites
- **Complète** : aucun "TBD" ou placeholder — tout le contexte est dans la spec
- **Liée** : les systèmes amont/aval, consommateurs impactés et points de régression sont explicités
- **Conséquences** : les effets de bord (data, auth, SEO, analytics, perf, accessibilité, déploiement, ops) sont nommés quand ils existent
- **Documentée** : les docs, README, guides, FAQ, changelog, exemples et contenus support impactés sont identifiés
- **Autonome** : un agent frais peut implémenter sans lire l'historique de conversation

Les snapshots de `TASKS.md` lus ici sont informatifs seulement.
`sf-spec` n'édite jamais `TASKS.md`, `AUDIT_LOG.md` ou `PROJECTS.md` ; la skill produit une spec, pas du tracking.

---

### Step 1 — Comprendre le besoin

**Si `$ARGUMENTS` est fourni**, l'utiliser comme point de départ.
**Sinon**, demander : "Qu'est-ce qu'on construit ?"

**Scan rapide d'orientation (< 30 secondes) :**
- Chercher des docs existantes (CLAUDE.md, README, docs/)
- Si l'utilisateur mentionne du code spécifique, scanner les fichiers concernés
- Repérer le stack technique, les patterns, la structure du projet

**Poser des questions informées** — pas des questions génériques, mais des questions ancrées dans ce qu'on a trouvé :
- "Le `AuthService` valide dans le controller — on suit ce pattern ou on crée un validateur dédié ?"
- "Je vois que les composants utilisent du state local — on reste là-dessus ou on passe au store global ?"

Déclencher des prompts utilisateur ciblés dès qu'un point ci-dessous reste flou et change matériellement la spec :
- acteur principal ou secondaire ambigu
- déclencheur du flow incertain
- résultat observable ou métrique de succès imprécis
- frontière de scope incertaine
- hypothèse sécurité implicite sur auth, permissions, données, tenant, intégration externe ou contenu non fiable

Quand tu poses une question, préférer une formulation qui force une décision exploitable, par exemple :
- "Le bouton est visible par tous, mais l'action doit-elle être exécutable seulement par les admins ou par tout membre connecté ?"
- "Sur échec partiel du webhook, on doit retry automatiquement, laisser en état pending, ou annuler toute l'opération ?"
- "Un utilisateur d'une autre organisation peut-il jamais voir cette ressource, même en lecture seule ?"

**Capturer et confirmer :**
- **Titre** : nom clair et concis
- **User story** : "En tant que [acteur], je veux [capacité], afin de [valeur]"
- **Problème** : qu'est-ce qu'on résout ?
- **Solution** : approche en 1-2 phrases
- **Scope in** : ce qui est inclus
- **Scope out** : ce qui est explicitement exclu

Si l'utilisateur ne formule pas naturellement une user story, la reconstruire à partir de l'échange et la lui proposer explicitement.

Vérifier avant de continuer :
- qui agit ?
- quel déclencheur démarre le flow ?
- quel résultat observable doit changer ?
- qu'est-ce qui resterait hors scope même si ce serait "nice to have" ?

Demander confirmation avant de continuer.

---

### Step 2 — Investiguer le code

Explorer le codebase en profondeur pour ancrer la spec dans la réalité technique.

**Pour chaque fichier/zone pertinente :**
- Lire le code complet
- Identifier les patterns, conventions, style
- Noter les dépendances et imports
- Trouver les fichiers de test associés

**Capturer le contexte technique :**
- **Stack** : langages, frameworks, librairies
- **Patterns** : architecture, nommage, structure de fichiers
- **Fichiers à modifier/créer** : liste concrète
- **Entrypoints & dépendants** : qui appelle la zone, quelles routes/pages/jobs/tests/consommateurs seront touchés
- **Liens & conséquences** : contrats, side effects, invariants, migrations, analytics/SEO/auth/perf à préserver
- **Cohérence documentaire** : docs, README, guides, FAQ, changelog, exemples, screenshots, onboarding ou support à mettre à jour si la feature change
- **Patterns de test** : comment les tests sont structurés

**Si aucun code existant** (clean slate) :
- Identifier le dossier cible
- Scanner les dossiers parents pour le contexte architectural
- Documenter "Clean Slate confirmé" — pas de contraintes legacy

Résumer les trouvailles à l'utilisateur avant de continuer.

---

### Step 3 — Générer la spec

Produire la spécification complète.

Adapter la profondeur au mode choisi:
- **light**: moins de tâches, focus sur le chemin critique + cas limites principaux
- **full**: couverture complète, risques et cas limites étendus

Commencer la spec par un frontmatter YAML traçable :

```yaml
---
artifact: spec
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: "[project name]"
created: "[YYYY-MM-DD]"
updated: "[YYYY-MM-DD]"
status: draft
source_skill: sf-spec
scope: "[feature / bug / migration / audit-fix]"
owner: "[user or team if known]"
user_story: "[En tant que..., je veux..., afin de...]"
risk_level: "[low|medium|high]"
security_impact: "[none|yes|unknown]"
docs_impact: "[none|yes|unknown]"
linked_systems: []
depends_on:
  - artifact: "BUSINESS.md"
    artifact_version: "[version or unknown]"
    required_status: "[reviewed|active|unknown]"
  - artifact: "BRANDING.md"
    artifact_version: "[version or unknown]"
    required_status: "[reviewed|active|unknown]"
supersedes: []
evidence: []
next_step: "/sf-ready [title]"
---
```

Les specs sont des artefacts internes ShipFlow : ce frontmatter est obligatoire. Ne pas appliquer les schémas de contenu applicatif (`src/content`, blog, MDX runtime) aux specs ShipFlow.

Règle de dépendance documentaire :
- si la spec utilise `BUSINESS.md`, `BRANDING.md`, `GUIDELINES.md`, docs API, architecture, pricing, persona, ou tout autre contrat ShipFlow, renseigner la version dans `depends_on`
- si la version est absente pendant une migration, utiliser `artifact_version: unknown` et `required_status: unknown`, puis signaler le manque comme dette metadata/docs
- si une dépendance business/technique est `stale`, la spec ne peut pas passer `ready` sans revue explicite

Utiliser ces titres de sections exacts pour que `/sf-ready` et `/sf-verify` puissent relire la spec mécaniquement :
- `Title`
- `Status`
- `User Story`
- `Minimal Behavior Contract`
- `Problem`
- `Solution`
- `Scope In`
- `Scope Out`
- `Constraints`
- `Dependencies`
- `Invariants`
- `Links & Consequences`
- `Documentation Coherence`
- `Edge Cases`
- `Implementation Tasks`
- `Acceptance Criteria`
- `Test Strategy`
- `Risks`
- `Execution Notes`
- `Open Questions`

**Tâches d'implémentation :**
```markdown
- [ ] Tâche N : Description claire de l'action
  - Fichier : `chemin/vers/fichier.ext`
  - Action : Modification spécifique à faire
  - User story link : [quelle partie de la promesse utilisateur cette tâche sert]
  - Depends on : [fondation ou tâche précédente]
  - Validate with : [test/check/sanity check exact]
  - Notes : Détails d'implémentation si nécessaire
```

Ordonnées par dépendance (fondations d'abord).

**Minimal Behavior Contract :**
Écrire un seul paragraphe non technique qui couvre :
- ce que la feature accepte ou déclenche
- ce qu'elle retourne, produit ou rend observable
- ce qui se passe en cas d'échec
- l'edge case le plus facile à oublier

Ce paragraphe doit être assez précis pour qu'un agent frais puisse dire si l'implémentation tient la promesse, sans encore parler de fichiers, packages ou architecture.

**Critères d'acceptation (Given/When/Then) :**
```markdown
- [ ] CA N : Given [précondition], when [action], then [résultat attendu]
```

Couvrir : promesse principale de la user story, happy path, erreurs, cas limites, intégrations, abus ou contournements probables si le flow est non trivial.

**Sections complémentaires :**
- **Dépendances** : librairies, services, APIs nécessaires
- **Links & Consequences** : systèmes/fichiers impactés, invariants, effets de bord attendus, validations transverses
- **Documentation coherence** : docs/support/onboarding/pricing/changelog impacted, or `None, because ...`
- **Stratégie de test** : unit, intégration, tests manuels
- **Risques** : points sensibles identifiés (sécurité, perf, données)
- **Documentation Coherence** : docs, README, guides, FAQ, onboarding, pricing, changelog, exemples ou support à aligner, ou `None, because ...`
- **Execution Notes** : 3-5 fichiers à lire d'abord, approche d'implémentation en étapes avant code, contraintes explicites (packages à utiliser/éviter, patterns existants, flux de données, abstractions à éviter, limites de scope), ordre d'exécution, commandes de validation, stop conditions / cas de reroute

Quand le scope touche auth, permissions, données, intégrations, paiement, admin, contenu riche, prompts, fichiers, ou automatisations, exiger dans la spec :
- hypothèses de confiance
- acteurs autorisés / non autorisés
- misuse cases ou abuse cases principaux
- impact sécurité explicite (`none` ou `mitigated by ...`)

Si l'un de ces éléments n'est pas déductible du code ou du brief, arrêter la génération finale et poser les questions nécessaires à l'utilisateur au lieu d'inventer.

---

### Step 4 — Valider avec l'utilisateur

Présenter la spec complète et demander une revue.

**Déclencheurs de revue adversariale (règle simple) :**
- Si **au moins un** signal ci-dessous est vrai, faire une revue adversariale avant validation finale :
  - plus d'un fichier à modifier
  - plus d'un domaine impacté (ex: UI + API, backend + data, auth + routing)
  - comportement métier non trivial
  - impact sécurité, données, auth, perf, migration, ou contrat API
  - cas limites probables ou déjà observés
  - au moins une phrase vague dans la spec ("optimiser", "gérer proprement", "adapter") sans critère testable

**Quand la revue adversariale peut rester légère :**
- bug local, comportement attendu évident, un seul fichier, pas d'impact transverse

**Afficher un résumé rapide :**
```
Spec : [titre]
─────────────────────────
Tâches : N à implémenter
Critères : M à vérifier
Fichiers : P à modifier
─────────────────────────
```

Puis afficher la spec complète.

**Utiliser AskUserQuestion :**
- Question : "La spec est prête ?"
- Options :
  - **C'est bon** — "Enregistrer et passer à l'implémentation"
  - **À modifier** — "J'ai des retours à intégrer"
  - **Revue adversariale** — "Critique la spec toi-même avant de valider" (recommandé)

**Si "À modifier"** : intégrer les retours, re-présenter, boucler.

**Si "Revue adversariale"** : prendre du recul et critiquer sa propre spec :
- la `User Story` est-elle assez précise pour juger le succès ?
- Le `Minimal Behavior Contract` couvre-t-il entrée, sortie, échec et edge case principal ?
- Quelles hypothèses implicites pourraient casser dans un environnement réel ?
- Les tâches sont-elles vraiment ordonnées par dépendance ?
- Y a-t-il des cas limites non couverts dans les CA ?
- Un agent frais pourrait-il implémenter sans contexte supplémentaire ?
- Manque-t-il des fichiers à modifier ?
- Les consommateurs/entrypoints impactés sont-ils nommés ?
- Les docs, README, guides, FAQ, onboarding, pricing ou support doivent-ils changer avec la feature ?
- Un agent frais sait-il quoi revalider hors du happy path ?
- Les stop conditions et cas de reroute sont-ils explicites ?
- Y a-t-il des formulations vagues sans test associé ?
- Un acteur malveillant, non autorisé ou simplement hors-chemin pourrait-il contourner le flow prévu ?
- Présenter les trouvailles, corriger, re-présenter.

Avant de finaliser après revue adversariale, expliciter aussi :
- l'approche d'implémentation prévue, en étapes courtes, sans écrire de code
- les contraintes à respecter : packages autorisés/interdits, patterns existants à suivre, flux de données attendu, abstractions à éviter, limites de scope

**Si "C'est bon"** : enregistrer la spec.

---

### Step 5 — Enregistrer

Sauvegarder la spec dans le projet :
- Écrire dans `specs/[slug].md` (créer le dossier `specs/` si nécessaire)
- Si un dossier `docs/` existe, écrire là-bas à la place

**Rapport final :**
```
Spec enregistrée : specs/[slug].md

Prochaine étape :
- Lancer /sf-start [titre] pour commencer l'implémentation
- Ou continuer à explorer avec /sf-explore
```

---

### Rules

- **Ne pas implémenter** — cette skill produit une spec, pas du code
- **Questions informées** — toujours scanner le code AVANT de poser des questions
- **Pas de TBD** — si quelque chose n'est pas clair, poser la question plutôt que laisser un placeholder
- **User story d'abord** — ne jamais partir directement en solution sans expliciter la promesse utilisateur
- **Questions décisives** — si une réponse change le comportement, le scope ou la sécurité, demander avant d'écrire la spec finale
- **Docs dans le scope** — toute feature qui change un comportement utilisateur doit expliciter les docs à aligner ou justifier pourquoi il n'y en a pas
- **Autonome** — la spec doit contenir TOUT le contexte nécessaire pour implémenter
- **Pragmatique** — adapter la profondeur au scope (pas de spec de 50 tâches pour un bug fix)
- **Conversationnel** — c'est un dialogue, pas un formulaire. Suivre les fils intéressants.
