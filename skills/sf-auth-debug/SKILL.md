---
name: sf-auth-debug
description: Diagnostiquer un bug d'authentification dans un navigateur réel avec Playwright MCP — Clerk, Supabase Auth, OAuth, Google login, cookies, callbacks, middleware, redirects, sessions.
argument-hint: <bug auth, URL, provider, ou flow à diagnostiquer>
---

## Context

- Current directory: !`pwd`
- Current date: !`date '+%Y-%m-%d'`
- Project name: !`basename $(pwd)`
- Git branch: !`git branch --show-current 2>/dev/null || echo "unknown"`
- Git status: !`git status --short 2>/dev/null || echo "Not a git repo"`
- CLAUDE.md (constraints / URLs): !`grep -i "auth\\|clerk\\|supabase\\|google\\|oauth\\|domain\\|url\\|vercel\\|netlify" CLAUDE.md 2>/dev/null | head -20 || echo "no CLAUDE.md"`
- Local TASKS.md (if exists): !`cat TASKS.md 2>/dev/null | head -40 || echo "No local TASKS.md"`

## Your task

Diagnostiquer un flux d'authentification cassé avec un vrai navigateur, sans supposer que le login complet sera automatisable.

`sf-auth-debug` est une skill de diagnostic spécialisée. Elle ne remplace pas `sf-spec`, `sf-fix`, `sf-start` ou `sf-verify`.
Elle intervient quand le sujet touche à l'auth réelle côté navigateur:
- Clerk
- Supabase Auth
- OAuth / Google login
- redirects et callbacks
- cookies / session
- middleware / guards
- retour inattendu vers login
- boucle d'auth

Le but n'est pas de "faire passer Playwright à tout prix".
Le but est de localiser précisément le point de rupture et de produire un diagnostic exploitable par la suite du workflow.

Références locales à charger selon le contexte:
- `references/clerk-tooling.md` pour choisir entre Clerk MCP, Clerk CLI et Playwright selon le type de bug
- `references/clerk-testing.md` pour savoir comment tester Clerk avec Playwright, Testing Tokens, comptes de test, OTP de test, et limites dev/prod
- `references/clerk.md` pour Clerk, Next.js, middleware, redirects, sessions, Google social connection via Clerk
- `references/supabase-testing.md` pour savoir comment tester Supabase avec stack locale, Mailpit, SSR cookies, RLS, et limites d'automatisation
- `references/supabase-tooling.md` pour choisir entre Supabase MCP, Supabase CLI et Playwright selon le type de bug
- `references/vercel-tooling.md` pour choisir entre Vercel MCP et Vercel CLI sur les sujets de déploiement, logs et runtime
- `references/google-oauth.md` pour les règles OAuth Google, redirect URI, state, consent screen, limites d'automatisation
- `references/convex-tooling.md` pour choisir entre Convex MCP, Convex CLI et sync de config d'auth
- `references/convex-clerk.md` pour les apps qui propagent l'identité Clerk vers Convex
- `references/playwright-auth.md` pour la méthode de preuve navigateur, les stratégies de session et les règles de secret hygiene
- `references/astro-clerk.md` pour les sites Astro avec `@clerk/astro`, SSR, middleware et Account Portal
- `references/flutter-clerk-convex.md` pour les apps Flutter avec Clerk beta et accès Convex
- `references/python-convex.md` pour scripts Python, jobs, imports et clients Convex
- `references/sdk-policy.md` pour choisir stable/beta/non-officiel dans le stack ShipFlow
- `references/flutter-web-clerkjs-bridge.md` pour le pattern ContentFlow: Flutter web + routes HTML ClerkJS + bridge Dart
- `/home/claude/shipflow/skills/references/supabase-auth.md` pour Supabase Auth, `@supabase/ssr`, cookies, redirects, callbacks et limites `getUser()` / `getSession()`
- `/home/claude/shipflow/skills/references/flutter-web-clerkjs-auth-pattern.md` comme documentation technique transverse à réutiliser dans les autres repos Flutter
- `/home/claude/shipflow/skills/references/tubeflow-youtube-oauth-nextjs-convex-pattern.md` comme documentation technique transverse pour YouTube OAuth via Next.js + Convex

Ne charger que les références utiles au bug courant. Si une info de référence est critique et peut avoir changé récemment, vérifier ponctuellement la documentation officielle, puis mettre à jour la référence locale si nécessaire.

Les snapshots de `TASKS.md` lus ici sont informatifs seulement.
`sf-auth-debug` ne doit jamais modifier `TASKS.md`, `AUDIT_LOG.md` ou `PROJECTS.md`.

---

### Step 1 — Consommer le contexte existant

Ne pas repartir de zéro si le problème est déjà cadré.

Priorité des sources:
1. spec existante
2. bug report ou demande utilisateur
3. diff courant / fichiers récents
4. exploration du code

Si `$ARGUMENTS` est fourni, l'utiliser comme point de départ.

Extraire ou reformuler explicitement:
- acteur concerné
- environnement visé (`local`, `staging`, `prod`)
- URL ou flow à tester
- provider d'auth (`Clerk`, `Supabase`, `Google`, autre)
- comportement observé
- comportement attendu

Si une info manque et change matériellement le diagnostic, poser une question courte et ciblée.

Toujours reformuler le problème comme une mini user story:
- acteur
- déclencheur
- rupture
- résultat attendu

---

### Step 2 — Identifier la stratégie de repro

Choisir l'approche la plus réaliste avant de lancer Playwright.

Cas autorisés:
- flow public jusqu'au bouton de login
- flow auth simple par formulaire
- flow OAuth partiellement automatisé pour observer où ça casse
- flow assisté par l'utilisateur si une étape humaine est nécessaire
- session déjà ouverte si le contexte la fournit

Ne pas promettre une automatisation complète si le flow passe par:
- MFA forte
- captcha
- device approval
- magic link non accessible
- WebAuthn / passkeys
- garde-fous anti-bot externes

Si l'auth complète n'est pas automatisable, continuer quand même le diagnostic jusqu'au point utile:
- bouton cliquable ou non
- redirect correcte ou non
- domaine de callback correct ou non
- retour vers l'app réussi ou non
- message d'erreur visible ou non

---

### Step 3 — Explorer le code minimum utile

Lire seulement les fichiers les plus pertinents avant d'agir:
- config Clerk / auth provider
- routes login / callback / middleware
- guards serveur ou client
- variables d'environnement liées à auth
- pages ou composants du flow cassé

Charger les références locales pertinentes avant de conclure:
- Clerk ou `@clerk/*` détecté -> lire `references/clerk-tooling.md`, puis `references/clerk-testing.md` si l'agent doit réellement tester, puis `references/clerk.md`
- Supabase Auth, `@supabase/ssr`, `@supabase/supabase-js`, `supabase.auth`, `auth/v1`, callback email/OAuth Supabase, ou dossier `supabase/` détecté -> lire `references/supabase-tooling.md`, puis `references/supabase-testing.md` si l'agent doit réellement tester, puis `/home/claude/shipflow/skills/references/supabase-auth.md`
- Vercel ou problème de runtime/deploy/logs détecté -> lire `references/vercel-tooling.md`
- Google OAuth direct ou social login Google -> lire `references/google-oauth.md`
- Convex détecté -> lire `references/convex-tooling.md`
- Convex avec Clerk ou session backend Convex -> lire `references/convex-clerk.md`
- Diagnostic Playwright, session persistée, preuve navigateur ou auth automatisée -> lire `references/playwright-auth.md`
- Astro ou `@clerk/astro` détecté -> lire `references/astro-clerk.md`
- Flutter, Dart, `clerk_flutter`, `clerk_auth`, ou `convex_dart` détecté -> lire `references/flutter-clerk-convex.md`
- Flutter web avec ClerkJS, `web_auth/`, `clerk-runtime.js`, `/sign-in`, `/sso-callback`, ou bridge JS/Dart -> lire `references/flutter-web-clerkjs-bridge.md`
- Implémentation ou correction d'auth Flutter web dans un autre repo -> lire aussi `/home/claude/shipflow/skills/references/flutter-web-clerkjs-auth-pattern.md`
- YouTube OAuth, Google API scopes, `refresh_token`, `/api/auth/youtube`, ou connexion YouTube depuis Flutter -> lire aussi `/home/claude/shipflow/skills/references/tubeflow-youtube-oauth-nextjs-convex-pattern.md`
- Python script/job qui appelle Convex -> lire `references/python-convex.md`
- Choix de SDK, dépendance beta, ou package non-officiel -> lire `references/sdk-policy.md`

Chercher notamment:
- URL de callback attendue
- domaines autorisés
- `SITE_URL`, redirect allow list, et `redirectTo` attendu
- clés d'environnement manquantes
- middleware trop large ou mal ordonné
- mauvaise distinction `public` / `protected`
- lecture/écriture de session ou cookie
- redirect post-login

Le but ici est de guider l'observation Playwright, pas de faire une revue exhaustive.

---

### Step 4 — Reproduire avec Playwright MCP

Utiliser Playwright pour observer le comportement réel.

Minimum à capturer:
- URL de départ
- action jouée
- URL après redirect
- page finale affichée
- message visible si erreur
- console browser si utile
- requêtes réseau auth si utile

Ordre recommandé:
1. ouvrir l'URL pertinente
2. capturer un snapshot initial
3. cliquer le CTA de login ou l'action qui déclenche l'auth
4. attendre la navigation ou le changement d'état
5. capturer la page d'arrivée
6. si besoin, inspecter console et réseau

Si une étape humaine est nécessaire:
- amener l'utilisateur jusqu'à l'écran utile
- noter exactement à quel moment l'automatisation s'arrête
- reprendre l'observation dès que possible

Ne pas conclure "Google bloque" sans preuve plus précise.
Nommer l'étape exacte:
- bouton absent
- popup refusée
- redirect externe incorrecte
- callback app en erreur
- retour à `/sign-in`
- session non persistée

---

### Step 5 — Isoler la cause probable

Classifier le bug dans une catégorie principale:
- `UI trigger`
  - bouton inactif, mauvais lien, popup, JS cassé
- `OAuth redirect`
  - mauvais domaine, mauvais callback, state invalide, mismatch d'environnement
- `Clerk configuration`
  - publishable key, domain, allowed redirect, provider config
- `Supabase SSR / token refresh`
  - middleware/proxy absent, cookies non rafraichis, `getSession()` utilisé comme preuve serveur, callback ou redirectTo incohérent
- `Session / cookies`
  - cookie absent, non persisté, domaine incohérent, secure/sameSite problématique
- `Middleware / protection`
  - route protégée trop tôt, boucle login, redirect incorrecte
- `Auth-to-DB boundary`
  - session OK mais requêtes Supabase refusées par RLS, client serveur/admin mal choisi, identité non propagée
- `App post-login flow`
  - callback ok mais app ne consomme pas la session correctement

Pour chaque hypothèse, chercher au moins une preuve observable:
- URL
- message d'erreur
- statut réseau
- contenu DOM
- config ou code lu dans le repo

Éviter les diagnostics vagues du type "Clerk ne marche pas".

---

### Step 6 — Produire un diagnostic exploitable

Le résultat doit être actionnable par `sf-fix`, `sf-start` ou `sf-verify`.

Sortie attendue:

```text
## Auth Debug: [titre]

User story:
- [acteur] veut [action] afin de [valeur]

Environment:
- [local / staging / prod]

Flow tested:
- [URL de départ]
- [action déclenchée]

Observed result:
- [ce qui se passe réellement]

Expected result:
- [ce qui devrait se passer]

Failure point:
- [étape exacte où ça casse]

Primary diagnosis:
- [catégorie + hypothèse principale]

Evidence:
- [URL finale]
- [message visible]
- [signal réseau / console utile]
- [fichier ou config pertinent]

Recommended next step:
- [fix concret ou vérification ciblée]

Automation status:
- [full / partial / blocked by human step]
```

Si le problème est suffisamment clair et local, proposer directement le prochain mouvement:
- corriger le code
- ajuster l'env
- modifier callback/domain
- retester après patch

Si le diagnostic reste incomplet, dire exactement ce qui manque.

---

### Intégration avec ShipFlow

Utiliser `sf-auth-debug` comme capability intégrée au workflow existant:
- après `sf-spec` si la spec décrit un bug d'auth à confirmer
- depuis `sf-fix` quand un bug auth doit être trié rapidement
- pendant `sf-start` si l'implémentation dépend d'un diagnostic navigateur réel
- avant `sf-verify` pour prouver que le flux cassé a été reproduit
- après un fix pour confirmer que la rupture a disparu

Règle d'intégration:
- consommer d'abord la spec ou le bug report existant
- ne découvrir que ce qui manque au diagnostic
- ne pas refaire une spec implicite si une spec explicite existe déjà

---

### Rules

- Ne pas supposer que Playwright peut terminer un login Google complet
- Ne pas demander des cookies bruts par défaut
- Ne pas proposer de stocker les identifiants du compte principal comme solution standard
- Préférer une observation réelle à un raisonnement abstrait quand le flow est reproductible
- Toujours nommer l'étape exacte de rupture
- Toujours distinguer symptôme, preuve, hypothèse et correctif recommandé
- Si l'auth complète est bloquée, pousser le diagnostic aussi loin que possible au lieu d'abandonner trop tôt
