---
name: sf-ready
description: Gate de readiness pour une spec avant implémentation. Vérifie qu'elle est complète, alignée sur la user story, résistante en revue adverse, exécutable sans ambiguïté et suffisamment solide en cyber sécurité.
argument-hint: <spec path or task name>
---

## Context

- Current directory: !`pwd`
- Current date: !`date '+%Y-%m-%d'`
- Project name: !`basename $(pwd)`
- Git branch: !`git branch --show-current 2>/dev/null || echo "unknown"`
- CLAUDE.md (constraints): !`head -60 CLAUDE.md 2>/dev/null || echo "no CLAUDE.md"`
- Available specs: !`find docs specs -maxdepth 2 -type f -name "*.md" 2>/dev/null | sort | head -60`

## Your task

Valider qu'une spec est réellement prête avant `/sf-start`.

Cette gate s'applique surtout au cadrage initial. Si `sf-verify` découvre plus tard un petit delta de cadrage, il peut jouer localement le rôle d'une mini gate de readiness après mise à jour de la spec.

Cette skill applique la `Definition of Ready` du flow spec-driven :
- zéro ambiguïté bloquante
- alignement explicite avec la user story et le résultat métier attendu
- forme comportementale minimale explicite : entrée/déclencheur, sortie/résultat, échec, edge case principal
- tâches ordonnées
- fichiers cibles identifiés
- systèmes liés et conséquences explicités
- cohérence documentaire explicitée pour les changements de feature
- critères d'acceptation vérifiables
- revue adversariale suffisante pour empêcher une implémentation naïve ou contournable
- sécurité proportionnée au scope, pensée dès la spec
- notes d'exécution suffisantes pour un agent frais
- aucun `TBD`

### Step 1 — Trouver la spec

Si `$ARGUMENTS` est un path de spec, l'utiliser.

Sinon :
- chercher la spec la plus probable dans `docs/` puis `specs/`
- si plusieurs candidates existent, choisir la plus pertinente et expliquer pourquoi

Si aucune spec n'est trouvée, arrêter et renvoyer vers `/sf-spec`.

### Step 2 — Vérifier la structure

La spec doit contenir :
- `Title`
- `Status`
- `User Story`
- `Minimal Behavior Contract`
- `Success Behavior`
- `Error Behavior`
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

Si une section obligatoire manque, verdict `not ready`.

### Step 3 — Vérifier l'alignement user story -> solution

Avant de regarder le détail technique, vérifier que la spec relie clairement :
- le problème utilisateur
- l'acteur concerné
- le déclencheur
- le comportement attendu
- la valeur métier ou opérationnelle obtenue
- les limites explicites du scope

Refuser la spec si un lecteur frais ne peut pas répondre sans hésitation à :
- qui veut quoi, et pourquoi ?
- qu'est-ce que la feature accepte ou déclenche ?
- qu'est-ce qu'elle produit ou rend observable ?
- que se passe-t-il quand ça échoue ?
- à quoi ressemble une réussite observable et vérifiable ?
- à quoi ressemble une erreur correctement gérée ?
- quel edge case majeur doit être couvert ?
- qu'est-ce qui change concrètement pour l'utilisateur ou l'opérateur ?
- qu'est-ce qui ne change pas ?
- comment saura-t-on que la user story est satisfaite ?

Exiger que `Solution`, `Implementation Tasks` et `Acceptance Criteria` soient traçables jusqu'à la user story. Une tâche purement technique sans lien explicable avec le résultat attendu doit être signalée.

### Step 4 — Vérifier la readiness réelle

Contrôler :
- le frontmatter existe ou une convention metadata équivalente est présente
- `artifact: spec`, `metadata_schema_version`, `artifact_version`, `source_skill`, `created`, `updated`, `status`, `scope`, `risk_level`, `security_impact`, `docs_impact` sont renseignés
- `depends_on` liste les versions des docs business/techniques utilisées par la spec, ou explicite `unknown` pendant migration
- aucune dépendance business/technique utilisée par la spec n'est connue comme `stale` sans revue explicite
- `Status` est `draft` ou `reviewed`, pas déjà `ready` sans vérification
- aucun `TBD`, `TODO`, placeholder ou formulation vague critique
- `Open Questions` est `None`
- aucune dépendance cachée à l'historique de conversation
- la spec nomme les préconditions, postconditions et invariants métier importants
- `Minimal Behavior Contract` tient en un paragraphe comportemental non technique et couvre entrée/déclencheur, sortie/résultat, échec, et edge case principal
- `Success Behavior` explicite les préconditions, l'action, le résultat utilisateur/opérateur, l'effet système attendu et la preuve de succès
- `Error Behavior` explicite les entrées invalides ou états d'échec pertinents, le retour utilisateur/opérateur, l'effet système attendu, et ce qui ne doit jamais arriver
- toute action réussie produit un changement d'état observable, ou la spec justifie explicitement pourquoi le succès peut rester silencieux et comment il reste vérifiable
- toute erreur produit une explication observable ou un état récupérable, ou la spec justifie explicitement pourquoi l'échec peut rester silencieux et comment il reste récupérable
- `Execution Notes` expose une approche d'implémentation en étapes avant code, ainsi que les contraintes explicites : packages à utiliser/éviter, patterns existants, flux de données, abstractions à éviter, limites de scope
- chaque tâche a :
  - un fichier cible
  - une action explicite
  - un ordre de dépendance cohérent
  - un check de validation identifiable
- `Links & Consequences` nomme les systèmes amont/aval, les consommateurs et les validations transverses à faire
- `Documentation Coherence` nomme les docs, README, guides, FAQ, onboarding, pricing, changelog, exemples ou support à aligner, ou explique `None, because ...`
- `Execution Notes` donne les fichiers à lire d'abord, les commandes de validation et les stop conditions
- les acceptance criteria couvrent :
  - `Success Behavior`
  - `Error Behavior`
  - cas limites
- les prérequis de données, auth, permissions, feature flags, migrations ou config sont explicités si pertinents
- les non-goals de `Scope Out` bornent bien le travail

Si un point change matériellement le comportement, le scope ou la sécurité et n'est ni prouvé par le code existant ni tranché par la spec, verdict `not ready`. Ne pas combler ce vide par inférence généreuse.

### Step 5 — Revue adversariale

Faire une vraie revue adverse, pas une passe cosmétique.

Critiquer la spec comme si tu voulais :
- provoquer une implémentation incorrecte mais "plausible"
- contourner le flow métier
- forcer un état incohérent
- exploiter une hypothèse implicite
- casser un système adjacent sans être détecté

- un agent frais pourrait-il mal interpréter une exigence ?
- le contrat comportemental minimal cache-t-il une hypothèse sur l'entrée, la sortie, l'échec ou un edge case ?
- `Success Behavior` peut-il être validé par un test, un sanity check, un log ou un état final observable ?
- `Error Behavior` laisse-t-il une erreur partielle, un retry, un rollback, un timeout ou un doublon sans comportement défini ?
- un succès peut-il sembler ne rien faire pour l'utilisateur ou l'opérateur ?
- une erreur peut-elle disparaître sans message, état récupérable, log utile ou action possible ?
- l'approche prévue choisirait-elle le mauvais package, la mauvaise abstraction ou le mauvais flux de données ?
- un edge case important manque-t-il ?
- une tâche dépend-elle d'une autre mais apparaît trop tôt ?
- une action est-elle trop vague pour être implémentée sans décision supplémentaire ?
- un système lié pourrait-il casser sans être revalidé ?
- une conséquence hors des fichiers principaux est-elle oubliée ?
- une page de doc, FAQ, onboarding, pricing, screenshot, exemple ou support devient-elle fausse après la feature ?
- le test plan permet-il vraiment à `sf-verify` de juger la conformité ?
- le flow peut-il être bypassé par saut d'étape, replay, double soumission, ordre invalide, état périmé ou entrée concurrente ?
- une hypothèse "UI = sécurité" existe-t-elle alors qu'un contrôle serveur ou backend devrait être requis ?
- la spec suppose-t-elle qu'un acteur restera honnête, qu'un identifiant sera valide, qu'une donnée externe sera propre, ou qu'un ordre d'événements sera respecté ?
- une erreur partielle peut-elle laisser des données, permissions, statuts ou side effects dans un état incohérent ?
- un rollback, retry, timeout, refresh, duplicate request ou reprise après échec est-il couvert ?
- les acteurs non nominaux sont-ils couverts : utilisateur sans droit, utilisateur malveillant, intégration tierce défaillante, administrateur, job asynchrone, système legacy ?

Si oui, la spec n'est pas ready.

### Step 6 — Solidité cyber sécurité

Faire une revue sécurité proportionnée au scope, en s'inspirant au minimum des familles de risques OWASP ASVS / OWASP Top 10 et des pratiques SSDF NIST.

Pour toute spec touchant auth, permissions, données sensibles, upload, rendu HTML/Markdown, API, webhooks, paiements, admin, secrets, intégrations externes, exécution d'actions, fichiers, recherche, prompts, ou automatisations, vérifier explicitement :
- Authentification : qui peut initier l'action ? comment l'identité est-elle établie ?
- Autorisation : qui peut lire, créer, modifier, supprimer, approuver, relancer ? les contrôles sont-ils côté serveur si nécessaire ?
- Validation d'entrée : quelles entrées sont non fiables ? quelles bornes, formats, allowlists ou sanitizations s'appliquent ?
- Intégrité du workflow : peut-on contourner les étapes métier, approuver sans droit, rejouer une action, injecter un état interdit ?
- Exposition de données : quelles données sensibles existent, où transitent-elles, où sont-elles stockées, loggées, cacheées, exportées ?
- Secrets et configuration : y a-t-il des tokens, clés, webhooks, variables d'env, permissions machine ou accès tiers à protéger ?
- Intégrations externes : quelles hypothèses de confiance sont faites sur APIs, webhooks, fichiers entrants, contenu généré, retrievers ou services tiers ?
- Journalisation et erreurs : que faut-il tracer pour audit et incident response, et que faut-il ne jamais logguer ?
- Disponibilité et abus : rate limiting, quotas, tailles max, protections contre spam, brute force, boucle, coût excessif, fan-out incontrôlé
- Multi-tenant / périmètre : un tenant, user, org ou projet peut-il voir ou agir sur les ressources d'un autre ?

Refuser la spec si elle contient un angle mort sécurité matériel et non traité. Ne pas exiger une analyse disproportionnée pour un micro-changement purement local, mais exiger au minimum une phrase explicite du type :
- `Security impact: none, because ...`
ou
- `Security impact: yes, mitigated by ...`

Si la sécurité dépend d'une décision produit encore non prise, exiger que la spec nomme explicitement la question à poser à l'utilisateur, puis rester en `not ready`.

### Step 7 — Verdict et statut

Si tout passe :
- mettre à jour la spec en `Status: ready`
- mettre aussi à jour le frontmatter : `status: ready`, `updated: [today]`, `next_step: "/sf-start [title]"`
- rapporter un verdict `ready`
- si la suite doit idéalement partir sur un contexte frais :
  - lancer un subagent sans historique si c'est possible dans l'environnement courant
  - sinon demander explicitement à l'utilisateur d'ouvrir un nouveau thread avant `/sf-start`

Sinon :
- laisser le statut inchangé ou le remettre à `reviewed`
- garder le frontmatter cohérent avec le verdict : `status: reviewed` ou `status: draft`, `next_step: "/sf-spec [title]"`
- rapporter `not ready` avec corrections concrètes

### Rapport attendu

```text
## Readiness: [spec title]

Spec: [path]
Current status: [draft/reviewed]

Checklist:
- Structure: [ok / fail]
- Metadata: [ok / fail]
- User story alignment: [ok / fail]
- Ambiguity: [ok / fail]
- Task ordering: [ok / fail]
- Links & consequences: [ok / fail]
- Acceptance criteria: [ok / fail]
- Success behavior: [ok / fail]
- Error behavior: [ok / fail]
- Documentation coherence: [ok / fail]
- Execution notes: [ok / fail]
- Minimal behavior contract: [ok / fail]
- Adversarial review: [ok / fail]
- Security review: [ok / fail]
- Open questions: [ok / fail]

Not ready because:
- [issue]

Adversarial gaps:
- [missing abuse case / bypass / bad state / cross-system consequence]

Security gaps:
- [missing auth/authz/input validation/data protection/logging/abuse control]

Verdict:
- ready
- not ready

Next step:
- /sf-start [title] if ready
- /sf-spec [title] if not ready
Fresh context:
- [subagent launched / ask user to open a new thread / not necessary]
```

### Rules

- Ne pas implémenter
- Être strict sur les ambiguïtés bloquantes
- Préférer `not ready` à une validation molle
- Toujours raisonner contre la user story avant de raisonner sur la solution
- Toujours faire une passe "comment est-ce que ça casse ?" avant de conclure `ready`
- Toujours expliciter le niveau de risque cyber sécurité, même si l'impact est nul ou faible
- Toujours vérifier que les docs actives restent alignées quand une feature change
- Si une question manquante change le contrat ou la sécurité, bloquer au lieu de supposer
- Donner des corrections actionnables, pas des critiques vagues
- Refuser une spec qui dépend de clarifications futures pour être implémentée proprement
- Si un contexte frais est nécessaire pour la suite et que la skill ne peut pas le créer elle-même, demander à l'utilisateur de le faire
- Rester la gate canonique avant la première implémentation d'un travail non trivial
