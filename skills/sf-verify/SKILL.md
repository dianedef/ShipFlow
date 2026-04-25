---
name: sf-verify
description: Vérifier que le travail est prêt à ship — user story tenue, complétude, correctitude, cohérence, dépendances et risques (SEC/PERF/DATA). Complémentaire à sf-check (purement technique).
argument-hint: [optional: tâche ou scope à vérifier]
---

## Context

- Current directory: !`pwd`
- Current date: !`date '+%Y-%m-%d'`
- Project name: !`basename $(pwd)`
- Git branch: !`git branch --show-current 2>/dev/null || echo "unknown"`
- Git diff stat: !`git diff HEAD --stat 2>/dev/null || echo "no changes"`
- Recent commits (session): !`git log --oneline -10 2>/dev/null || echo "no commits"`
- Master TASKS.md: !`cat /home/claude/shipflow_data/TASKS.md 2>/dev/null || echo "No master TASKS.md"`
- Local TASKS.md (if exists): !`cat TASKS.md 2>/dev/null || echo "No local TASKS.md"`
- CLAUDE.md (constraints): !`head -60 CLAUDE.md 2>/dev/null || echo "no CLAUDE.md"`

## Your task

Vérifier que le travail en cours est prêt à ship. Six dimensions : user story, complétude, correctitude, cohérence, dépendances, risques.

Tu dois aussi guider l'utilisateur vers la suite, pas seulement signaler les écarts.

Les snapshots de `TASKS.md` lus ici sont informatifs seulement.
Les fichiers de tracking partagés sont read-only dans `sf-verify`.
`sf-verify` peut corriger du code si le contrat est stable, mais ne doit pas modifier `TASKS.md`, `AUDIT_LOG.md` ou `PROJECTS.md`.
`TASKS.md`, `AUDIT_LOG.md` et `PROJECTS.md` sont des trackers/registries opérationnels : ne pas leur exiger de frontmatter metadata. Si un tracker contient une décision durable, signaler qu'elle devrait être extraite vers un artefact ShipFlow versionné, mais ne pas traiter l'absence de metadata sur le tracker comme un défaut.

### Step 1 — Identifier le scope

Si `$ARGUMENTS` est fourni, l'utiliser comme description de ce qu'on vérifie.

Sinon, déduire du contexte :
- Tâches marquées `🔄 in progress` dans TASKS.md
- Commits récents de la session
- Fichiers modifiés dans git diff

Si une spec `ready` existe pour ce scope, l'utiliser comme contrat principal. Sinon, utiliser la meilleure combinaison disponible : description de tâche + TASKS.md + diff courant.

Si une spec existe, extraire explicitement :
- Frontmatter metadata : `metadata_schema_version`, `artifact_version`, `status`, `updated`, `depends_on`
- `User Story`
- `Acceptance Criteria`
- `Invariants`
- `Links & Consequences`
- `Documentation Coherence`
- `Risks`

La vérification doit juger le résultat contre cette promesse, pas seulement contre la liste des tâches.

Si la spec est un artefact ShipFlow, son frontmatter fait partie du contrat. Une spec sans metadata versionnée peut être vérifiée pendant une migration, mais le rapport doit dégrader la confiance et signaler la dette metadata.

Si rien n'est clair, utiliser **AskUserQuestion** :
- Question: "Qu'est-ce que je vérifie ?"
- Options: tâches en cours depuis TASKS.md + "Tout le travail récent"

### Step 2 — Vérifier la user story

Déterminer si la promesse utilisateur est réellement livrée.

- Reformuler en une ligne : acteur, capacité, valeur
- Vérifier que le comportement observable a bien changé dans ce sens
- Refuser une implémentation qui coche les tâches mais ne livre qu'un proxy technique du besoin
- Si la spec mentionne plusieurs acteurs ou plusieurs branches de flow, vérifier que la branche principale est couverte et que les exclusions sont cohérentes avec `Scope Out`

Si la user story n'est pas explicitement vérifiable avec le code, les tests, ou un sanity check décrit, au minimum mettre `WARNING`, voire `CRITICAL` si le contrat central reste indémontrable.

Si le verdict dépend d'une question produit ou sécurité encore ouverte, ne pas masquer l'incertitude : nommer la question et dégrader le verdict en conséquence.

**Résultat** : promesse tenue / partiellement tenue / non démontrée avec preuves

### Step 3 — Vérifier les metadata et versions de contrat

Vérifier que les artefacts ShipFlow utilisés pour implémenter le travail sont synchronisés.

**Metadata de la spec**
- Vérifier que la spec contient `metadata_schema_version` et que la valeur est compatible avec la doctrine ShipFlow connue (`"1.0"` actuellement).
- Vérifier que la spec contient `artifact_version`.
- Vérifier que `status` est compatible avec l'exécution (`ready`, ou statut équivalent explicitement accepté par `sf-ready`).
- Vérifier que `updated` existe et n'est pas manifestement obsolète par rapport au travail en cours.
- Si un champ obligatoire manque : WARNING pendant migration, CRITICAL si l'absence empêche de savoir quel contrat a été implémenté.

**Dépendances documentaires versionnées**
- Lire `depends_on` dans le frontmatter de la spec.
- Pour chaque dépendance business ou technique (`BUSINESS.md`, `BRANDING.md`, `GUIDELINES.md`, docs API, architecture, pricing, personas, GTM docs, onboarding, support docs) :
  - vérifier que `artifact_version` est renseigné, ou explicitement `unknown` avec dette signalée
  - vérifier que `required_status` est renseigné quand la spec l'exige
  - ouvrir le fichier référencé si présent et lire son frontmatter ShipFlow quand il existe
  - comparer la version utilisée par la spec avec la version actuelle du document
  - vérifier que le document actuel n'est pas `status: stale`, `status: draft` non assumé, ou `confidence: low` sans mention explicite dans la spec
- Si la spec dépend d'une version ancienne de `BUSINESS.md`, `BRANDING.md`, `GUIDELINES.md`, docs API ou architecture : WARNING au minimum.
- Si la version ancienne peut changer permissions, pricing, promesse publique, onboarding, sécurité, données, API publique ou architecture : CRITICAL jusqu'à revalidation explicite.
- Si une dépendance référencée est introuvable : WARNING, ou CRITICAL si c'est le contrat principal du travail.
- Si le diff montre une dépendance implicite à une doc business/technique absente de `depends_on`, signaler un gap metadata.

**Implémentation contre contrat périmé**
- Déterminer si le code a été implémenté contre une spec dont les dépendances documentaires ont changé depuis la version référencée.
- Nommer explicitement les docs concernées : `BUSINESS.md`, `BRANDING.md`, `GUIDELINES.md`, docs API, architecture docs, pricing/persona/GTM docs.
- Le rapport doit dire : `implemented against current docs`, `implemented against outdated docs`, `dependency version unknown`, ou `not applicable`.

**Résultat** : metadata valides / dette metadata / contrat documentaire périmé avec preuves

### Step 4 — Vérifier la complétude

**Tâches cochées ?**
- Lire TASKS.md, trouver les tâches liées au scope
- Compter `📋 todo` / `🔄 in progress` / `✅ done` (ou `- [ ]` / `- [x]`)
- Si des tâches restent non cochées, vérifier si le code correspondant existe
- Si une spec existe : mapper `Implementation Tasks` et `Acceptance Criteria` au code/tests présents

**Fichiers attendus créés ?**
- Depuis la description des tâches, identifier les fichiers qui devraient exister
- Vérifier qu'ils existent et ne sont pas vides
- Si la spec liste des `Links & Consequences`, extraire les systèmes à revalider pour la suite

**Résultat** : liste des tâches complètes vs incomplètes avec preuves

### Step 5 — Vérifier la correctitude

**Le code fait-il ce qui est décrit ?**
- Pour chaque tâche complétée, lire le code modifié (git diff)
- Vérifier que l'implémentation correspond à la description de la tâche
- Chercher les cas limites non gérés
- Si une spec existe : vérifier aussi `Invariants`, `Links & Consequences` et `Execution Notes`
- Si une spec existe : vérifier aussi `Documentation Coherence` et les docs réellement modifiées ou explicitement non impactées
- Vérifier aussi que l'implémentation ne trahit pas la `User Story` en résolvant le mauvais problème ou en ne couvrant qu'un sous-cas commode

**Tests existants ?**
- Vérifier si des tests couvrent les changements
- Si des tests existent, les lancer (`npm test`, `pytest`, `./test_*.sh`)
- Si pas de tests et que le changement est significatif : WARNING

**Résultat** : mapping tâche → code avec évaluation

### Step 6 — Vérifier la cohérence

**CLAUDE.md respecté ?**
- Relire les règles critiques de CLAUDE.md
- Vérifier que le nouveau code les respecte
- Exemples : conventions de nommage, patterns obligatoires, interdictions

**Patterns du projet suivis ?**
- Comparer le style du nouveau code avec le code existant
- Vérifier : nommage des fichiers, structure des dossiers, style d'import, gestion d'erreur
- Si déviation significative : SUGGESTION

**Résultat** : liste des écarts de cohérence

### Step 6.5 — Vérifier les liens et conséquences

Quand une spec ou le diff révèle des systèmes liés, vérifier explicitement qu'ils ont bien été pris en compte :
- routes/pages/consommateurs qui dépendent du code touché
- contrats de données, auth, permissions, migrations
- analytics, SEO, i18n, accessibilité, design system
- jobs, scripts, webhooks, ops, déploiement si concernés
- docs, README, guides, exemples, FAQ, onboarding, pricing, changelog, support, screenshots si la feature change

Si une conséquence attendue n'a pas été vérifiée ou si un système lié a dérivé, le signaler au minimum en WARNING, voire CRITICAL si cela casse le contrat.

**Résultat** : liste des conséquences vérifiées vs oubliées avec preuves

### Step 6.6 — Vérifier la cohérence documentaire

Quand le travail change un comportement utilisateur, une API, un workflow, un pricing, une permission, une intégration ou une limite produit :
- vérifier que les docs actives restent alignées
- vérifier que les docs ShipFlow concernées portent des metadata versionnées quand elles servent de contrat de décision
- chercher les références probablement impactées dans README, docs, content, FAQ, onboarding, support, examples, changelog, public pages
- signaler en WARNING toute doc stale qui peut tromper un utilisateur ou un opérateur
- signaler en CRITICAL si la doc stale concerne sécurité, paiement, conformité, données sensibles, migration, API publique ou usage destructif
- signaler explicitement quand la spec a été implémentée contre une version périmée ou inconnue d'une doc business/technique

Si aucune doc n'est impactée, exiger une justification courte : `not impacted because ...`.

**Résultat** : docs alignées / non impactées / stale avec preuves

### Step 7 — Vérifier les dépendances

**Nouvelles dépendances ajoutées ?**
- Vérifier git diff sur `package.json`, `requirements.txt`, `Cargo.toml`, etc.
- Si de nouvelles dépendances ont été ajoutées :
  - Sont-elles justifiées par le scope du travail ?
  - Y a-t-il un doublon avec une dépendance existante ?
  - Si injustifiée : WARNING "Nouvelle dépendance ajoutée sans lien avec la tâche"

**Vulnérabilités évidentes ?**
- Si package.json modifié : lancer `npm audit --audit-level=high` (ou pnpm/yarn)
- Si requirements.txt modifié : lancer `pip-audit` si disponible
- Si vulnérabilités high/critical trouvées : CRITICAL

**Résultat** : liste des dépendances ajoutées avec justification + vulnérabilités

### Step 8 — Scan de risques rapide

Passer en revue le diff pour détecter les risques évidents. Ne pas chercher l'exhaustivité — seulement les signaux forts.

**Sécurité (SEC)**
- Secrets ou credentials en dur dans le code ? (clés API, mots de passe, tokens)
- Inputs utilisateur non validés ? (injection SQL, XSS, command injection)
- Endpoints sans authentification/autorisation ?
- Contrôle uniquement côté UI alors que la sécurité devrait être portée par backend/API ?
- Bypass métier possible (saut d'étape, replay, double soumission, IDOR, accès cross-tenant) ?
- Hypothèse de confiance non prouvée sur webhook, fichier entrant, contenu généré, service tiers ou identité appelante ?
- Si trouvé : CRITICAL

**Performance (PERF)**
- Requêtes N+1 évidentes ? (boucle avec appels DB/API)
- Fichiers volumineux chargés en mémoire sans streaming ?
- Boucles infinies potentielles ?
- Si trouvé : WARNING

**Données (DATA)**
- Migrations destructives sans rollback ?
- Données utilisateur supprimées sans confirmation ?
- Si trouvé : WARNING

Ne pas transformer ce step en audit complet. 2-3 minutes max. Seulement ce qui saute aux yeux dans le diff.

**Résultat** : risques identifiés avec sévérité et fichier:ligne

### Step 9 — Checks techniques (rapide)

Lancer les vérifications techniques de base si un package.json ou des scripts de test existent :
- Typecheck (s'il existe)
- Lint (s'il existe)
- Tests (s'ils existent)

**NE PAS lancer le build.** Le build tourne en CI / Vercel au push — le refaire ici perd du temps et pollue l'environnement. Utiliser `/sf-check` explicitement si un build local est vraiment nécessaire.

Ne pas dupliquer sf-check — juste un run rapide pour confirmer que rien n'est cassé. Si les checks échouent : CRITICAL.

### Step 10 — Rapport

Générer UN rapport structuré :

```
## Vérification : [scope]

### Résumé
| Dimension    | Résultat                    |
|--------------|-----------------------------|
| User story   | Promise tenue / partielle   |
| Complétude   | X/Y tâches, Z fichiers      |
| Correctitude | M/N points vérifiés         |
| Cohérence    | Conforme / N écarts         |
| Metadata     | Versions OK / gaps          |
| Docs         | Alignées / gaps             |
| Dépendances  | N ajoutées, vulnérabilités  |
| Risques      | N SEC / N PERF / N DATA     |
| Technique    | ✓ OK / ✗ N erreurs          |

### CRITICAL (à corriger avant de ship)
- [ ] [description + fichier:ligne + recommandation]

### WARNING (à considérer)
- [ ] [description + recommandation]

### SUGGESTION (améliorations)
- [ ] [description]

### Verdict
[✓ Prêt à ship / ⚠ N points à revoir / ✗ Pas prêt]
```

Inclure explicitement :

```text
### User Story Verdict
- Story: [one-line story]
- Outcome delivered: [yes / partial / no]
- Evidence: [tests, diff, manual path, missing proof]
```

Ajouter ensuite un bloc workflow explicite :

```text
### Metadata / Contract Versions
- Spec metadata: [metadata_schema_version / artifact_version / status]
- Dependency status: [current / outdated / unknown / not applicable]
- Outdated contracts: [BUSINESS.md, BRANDING.md, GUIDELINES.md, API docs, architecture docs, ...]
- Impact: [none / revalidation required / blocks ship]
```

```text
### Workflow
Primary cause: [specified but not implemented / spec incomplete or ambiguous / technical failure / mixed]
Next step (recommended): [commande exacte]
Reason: [phrase courte]
```

### Step 11 — Prompt guidé de suite

Si le verdict est `⚠` ou `✗`, proposer un choix guidé avec **AskUserQuestion** :

- Question: "On fait quoi maintenant ?"
- `multiSelect: false`
- Options (ordre recommandé) :
  1. **Corriger maintenant (recommandé)** — "Tu appliques les fixes suggérés puis tu relances sf-verify"
  2. **Repasser par spec** — "Tu clarifies/complètes la spec avant de continuer"
  3. **Stop et reprendre plus tard** — "Tu conserves le diagnostic et t'arrêtes ici"

Puis agir selon le choix :
- Si **Corriger maintenant** :
  - seulement si le contrat est stable (implémentation incomplète ou panne technique locale)
  - corriger les points CRITICAL/WARNING liés à la cause principale
  - relancer checks ciblés
  - relancer `sf-verify` sur le même scope
- Si **Repasser par spec** :
  - si le contrat est incomplet, ambigu, ou si les liens/conséquences n'étaient pas explicités
  - router vers `/sf-spec [scope]`, puis `/sf-ready`, puis `/sf-start`
- Si **Stop et reprendre plus tard** :
  - fournir la commande exacte pour reprendre (`/sf-verify [scope]`)

Si le verdict est `✓`, ne pas poser cette question et proposer `/sf-end`.

### Dégradation gracieuse

- Si pas de TASKS.md : vérifier uniquement git diff + checks techniques
- Si pas de CLAUDE.md : sauter la vérification de cohérence documentée
- Si pas de tests : noter en WARNING, ne pas bloquer
- Si pas de package.json/requirements.txt : sauter le check dépendances
- Si pas de diff (rien à vérifier) : le signaler et arrêter
- Le scan de risques s'applique toujours (il lit le diff)
- Toujours indiquer quelles vérifications ont été sautées et pourquoi

### Rules

- Chaque issue doit avoir une recommandation actionnable avec référence fichier:ligne
- Prioriser les écarts qui cassent la promesse utilisateur ou ouvrent un bypass de sécurité/workflow
- Prioriser aussi les docs stale qui peuvent faire utiliser la feature de travers ou masquer une limite importante
- Si une question manquante empêche une conclusion fiable, la faire remonter explicitement au lieu de conclure "ça a l'air bon"
- Préférer SUGGESTION à WARNING, WARNING à CRITICAL en cas de doute
- Ne pas inventer de problèmes — vérifier avec des preuves (code lu, tests lancés)
- Ne jamais laisser un verdict `⚠/✗` sans recommandation de suite explicite
- Ne corriger directement que si le contrat est suffisamment stable pour éviter un nouveau cycle de clarification
- Prioriser un guidage actionnable pour les utilisateurs non techniques
- Ne pas être pointilleux sur le style — se concentrer sur les vrais écarts
