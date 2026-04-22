---
name: sf-verify
description: Vérifier que le travail est prêt à ship — complétude, correctitude, cohérence, dépendances, risques (SEC/PERF/DATA). Complémentaire à sf-check (purement technique).
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

Vérifier que le travail en cours est prêt à ship. Cinq dimensions : complétude, correctitude, cohérence, dépendances, risques.

Tu dois aussi guider l'utilisateur vers la suite, pas seulement signaler les écarts.

### Step 1 — Identifier le scope

Si `$ARGUMENTS` est fourni, l'utiliser comme description de ce qu'on vérifie.

Sinon, déduire du contexte :
- Tâches marquées `🔄 in progress` dans TASKS.md
- Commits récents de la session
- Fichiers modifiés dans git diff

Si rien n'est clair, utiliser **AskUserQuestion** :
- Question: "Qu'est-ce que je vérifie ?"
- Options: tâches en cours depuis TASKS.md + "Tout le travail récent"

### Step 2 — Vérifier la complétude

**Tâches cochées ?**
- Lire TASKS.md, trouver les tâches liées au scope
- Compter `📋 todo` / `🔄 in progress` / `✅ done` (ou `- [ ]` / `- [x]`)
- Si des tâches restent non cochées, vérifier si le code correspondant existe

**Fichiers attendus créés ?**
- Depuis la description des tâches, identifier les fichiers qui devraient exister
- Vérifier qu'ils existent et ne sont pas vides

**Résultat** : liste des tâches complètes vs incomplètes avec preuves

### Step 3 — Vérifier la correctitude

**Le code fait-il ce qui est décrit ?**
- Pour chaque tâche complétée, lire le code modifié (git diff)
- Vérifier que l'implémentation correspond à la description de la tâche
- Chercher les cas limites non gérés

**Tests existants ?**
- Vérifier si des tests couvrent les changements
- Si des tests existent, les lancer (`npm test`, `pytest`, `./test_*.sh`)
- Si pas de tests et que le changement est significatif : WARNING

**Résultat** : mapping tâche → code avec évaluation

### Step 4 — Vérifier la cohérence

**CLAUDE.md respecté ?**
- Relire les règles critiques de CLAUDE.md
- Vérifier que le nouveau code les respecte
- Exemples : conventions de nommage, patterns obligatoires, interdictions

**Patterns du projet suivis ?**
- Comparer le style du nouveau code avec le code existant
- Vérifier : nommage des fichiers, structure des dossiers, style d'import, gestion d'erreur
- Si déviation significative : SUGGESTION

**Résultat** : liste des écarts de cohérence

### Step 5 — Vérifier les dépendances

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

### Step 6 — Scan de risques rapide

Passer en revue le diff pour détecter les risques évidents. Ne pas chercher l'exhaustivité — seulement les signaux forts.

**Sécurité (SEC)**
- Secrets ou credentials en dur dans le code ? (clés API, mots de passe, tokens)
- Inputs utilisateur non validés ? (injection SQL, XSS, command injection)
- Endpoints sans authentification/autorisation ?
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

### Step 7 — Checks techniques (rapide)

Lancer les vérifications techniques de base si un package.json ou des scripts de test existent :
- Typecheck (s'il existe)
- Lint (s'il existe)
- Tests (s'ils existent)

**NE PAS lancer le build.** Le build tourne en CI / Vercel au push — le refaire ici perd du temps et pollue l'environnement. Utiliser `/sf-check` explicitement si un build local est vraiment nécessaire.

Ne pas dupliquer sf-check — juste un run rapide pour confirmer que rien n'est cassé. Si les checks échouent : CRITICAL.

### Step 8 — Rapport

Générer UN rapport structuré :

```
## Vérification : [scope]

### Résumé
| Dimension    | Résultat                    |
|--------------|-----------------------------|
| Complétude   | X/Y tâches, Z fichiers      |
| Correctitude | M/N points vérifiés         |
| Cohérence    | Conforme / N écarts         |
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

Ajouter ensuite un bloc workflow explicite :

```text
### Workflow
Primary cause: [specified but not implemented / spec incomplete or ambiguous / technical failure / mixed]
Next step (recommended): [commande exacte]
Reason: [phrase courte]
```

### Step 9 — Prompt guidé de suite

Si le verdict est `⚠` ou `✗`, proposer un choix guidé avec **AskUserQuestion** :

- Question: "On fait quoi maintenant ?"
- `multiSelect: false`
- Options (ordre recommandé) :
  1. **Corriger maintenant (recommandé)** — "Tu appliques les fixes suggérés puis tu relances sf-verify"
  2. **Repasser par spec** — "Tu clarifies/complètes la spec avant de continuer"
  3. **Stop et reprendre plus tard** — "Tu conserves le diagnostic et t'arrêtes ici"

Puis agir selon le choix :
- Si **Corriger maintenant** :
  - corriger les points CRITICAL/WARNING liés à la cause principale
  - relancer checks ciblés
  - relancer `sf-verify` sur le même scope
- Si **Repasser par spec** :
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
- Préférer SUGGESTION à WARNING, WARNING à CRITICAL en cas de doute
- Ne pas inventer de problèmes — vérifier avec des preuves (code lu, tests lancés)
- Ne jamais laisser un verdict `⚠/✗` sans recommandation de suite explicite
- Prioriser un guidage actionnable pour les utilisateurs non techniques
- Ne pas être pointilleux sur le style — se concentrer sur les vrais écarts
