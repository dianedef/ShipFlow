# Flutter Web ClerkJS Auth Pattern

## Purpose

This document defines the preferred ShipFlow pattern for implementing authentication in Flutter web apps without relying on Clerk Flutter/Dart beta SDKs.

Use it as the technical reference when fixing or implementing auth in other Flutter repositories.

Reference implementation: `/home/claude/contentflow/contentflow_app`

Last reviewed: 2026-04-26

## Decision

For Flutter web applications, use the official Clerk JavaScript runtime on app-domain auth routes, then expose the authenticated session to Dart through a small JS interop bridge.

Do not use Clerk Flutter/Dart beta SDKs in the production web path unless a project explicitly accepts that beta risk.

## Why

The Clerk Flutter/Dart packages are official but still beta. ContentFlow moved production auth away from that path and now uses ClerkJS directly for the browser flow.

This gives us:
- official Clerk web behavior for Google OAuth
- app-domain sign-in and callback routes
- explicit diagnostics on the auth pages
- a small Dart integration surface
- stable FastAPI bearer-token calls after login

## Architecture

```text
Flutter web build
  -> inject /sign-in and /sso-callback into build/web
  -> /sign-in loads ClerkJS and starts Google OAuth
  -> Google redirects to /sso-callback
  -> ClerkJS handles callback and creates browser session
  -> redirect to /#/entry
  -> Flutter restores session through JS bridge
  -> Dio sends Authorization: Bearer <fresh Clerk token>
  -> FastAPI validates Clerk JWT
  -> /api/bootstrap decides app access state
```

## Required Files

Each Flutter web app using this pattern should have equivalents of:

- `web_auth/clerk-runtime.js.template`
- `web_auth/sign-in.html`
- `web_auth/sso-callback.html`
- `web_auth/clerk-auth.css`
- `scripts/install-web-auth.sh`
- `lib/data/services/clerk_auth_service.dart`
- `lib/data/services/clerk_auth_service_web.dart`
- `lib/data/services/clerk_auth_service_stub.dart`
- app state provider for session restoration
- API client that injects a fresh Clerk bearer token

ContentFlow implementation:
- `/home/claude/contentflow/contentflow_app/web_auth/clerk-runtime.js.template`
- `/home/claude/contentflow/contentflow_app/web_auth/sign-in.html`
- `/home/claude/contentflow/contentflow_app/web_auth/sso-callback.html`
- `/home/claude/contentflow/contentflow_app/scripts/install-web-auth.sh`
- `/home/claude/contentflow/contentflow_app/lib/data/services/clerk_auth_service_web.dart`
- `/home/claude/contentflow/contentflow_app/lib/providers/providers.dart`
- `/home/claude/contentflow/contentflow_app/lib/data/services/api_service.dart`

## Build Requirements

The Flutter web build must receive:

- `CLERK_PUBLISHABLE_KEY`
- `API_BASE_URL`
- `APP_WEB_URL`
- `APP_SITE_URL` when the app links back to a public site
- build metadata such as commit, environment, and timestamp when diagnostics need it

After `flutter build web`, run the auth asset installer:

```bash
bash ./scripts/install-web-auth.sh ./build/web
```

Production build scripts must fail or warn loudly when `CLERK_PUBLISHABLE_KEY` is missing.

## ClerkJS Runtime Contract

The generated `clerk-runtime.js` should expose one global bridge:

```text
window.contentflowClerkBridge
```

Other apps can rename the bridge, but the Dart service and runtime must agree.

Required bridge methods:

- `load()`
- `isSignedIn()`
- `getToken({ skipCache })`
- `getUser()`
- `signOut()`
- `mountSignIn(node, options)`
- `startGoogleSignIn(options)`
- `handleRedirectCallback(options)`
- `getDiagnostics()`

Dart should fail loudly when the bridge is missing. A missing bridge usually means the auth installer did not run, the generated script is not served, or the static server does not expose the expected route.

## Auth Routes

`/sign-in` should:

- load `clerk-runtime.js`
- call `bridge.load()`
- redirect to the app if `bridge.isSignedIn()` is already true
- mount Clerk sign-in UI with Google OAuth redirect flow
- expose a diagnostics copy button

`/sso-callback` should:

- load `clerk-runtime.js`
- call `bridge.handleRedirectCallback()`
- redirect back to `/#/entry` or the intended same-origin route
- expose diagnostics when callback fails

## Redirect Rules

Use same-origin redirects by default.

The runtime should:

- default completion to `/#/entry`
- build OAuth callback as `/sso-callback?redirect_url=<final-app-url>`
- reject cross-origin `redirect_url` values and fall back to the default route
- use `forceRedirectUrl` and `fallbackRedirectUrl` consistently for sign-in and sign-up

## Dart Service Contract

The Dart web implementation should:

- use conditional exports so non-web builds do not depend on browser APIs
- call the JS bridge with `dart:js_interop`
- restore session with `isSignedIn()`, `getToken()`, and `getUser()`
- expose `bearerToken`, `userId`, and email to app state
- provide `getFreshToken({ skipCache })` for the API client
- call `signOut()` for remote sign-out

The non-web stub should not silently fake auth. It should return signed out or throw clear errors for removed beta SDK paths.

## App State Contract

The app should model auth state explicitly:

- loading/restoring session
- signed out
- demo mode if supported
- authenticated

After restoring a Clerk session, the app should call the backend bootstrap endpoint before opening the main workspace.

Useful app access states:

- restoring session
- signed out
- checking backend
- checking workspace
- unauthorized
- degraded/API unavailable
- needs onboarding
- ready

## API Client Contract

The API client should:

- add `Authorization: Bearer <token>` for authenticated requests
- fetch a fresh token before each request or before sensitive requests
- remove the auth header if no token is available
- treat backend `401` as a re-auth signal
- keep enough diagnostics to prove whether a request had authorization

In ContentFlow, Dio performs this through an `authTokenProvider` that calls `ClerkAuthService.getFreshToken()`.

## Backend Contract

The backend should:

- validate Clerk JWTs server-side
- reject invalid or expired tokens with `401`
- derive user identity from the token, not from client-provided email
- expose a bootstrap endpoint that returns workspace/onboarding state
- keep product authorization decisions on the backend

For ContentFlow, FastAPI validates the Clerk bearer token and `/api/bootstrap` decides whether the app should open onboarding, workspace, degraded mode, or re-auth.

## Diagnostics To Include

Auth pages should expose copyable diagnostics:

- build commit
- build environment
- build timestamp
- configured app URL
- current origin
- current host
- current path/current URL
- whether current origin matches configured app host
- OAuth callback URL
- redirect complete URL
- Clerk frontend API
- masked publishable key preview
- visible status and last error

Never include secrets, tokens, cookies, OAuth codes, or full bearer values.

## Common Failure Modes

- `CLERK_PUBLISHABLE_KEY` missing at build time.
- `install-web-auth.sh` did not run after `flutter build web`.
- `/sign-in` or `/sso-callback` is not served by the host.
- `clerk-runtime.js` is missing from `build/web`.
- Current host differs from `APP_WEB_URL`.
- ClerkJS cannot derive the frontend API from the publishable key.
- Google OAuth returns to the wrong callback URL.
- `handleRedirectCallback()` fails on `/sso-callback`.
- Callback succeeds but Flutter cannot find the JS bridge.
- Flutter restores the Clerk session but FastAPI rejects the bearer token.
- API client sends stale or missing bearer token.
- Non-web build tries to use removed Clerk Flutter beta auth methods.

## Validation Checklist

1. Confirm `pubspec.yaml` does not include `clerk_flutter` or `clerk_auth` for the web auth path.
2. Build with `CLERK_PUBLISHABLE_KEY` and `APP_WEB_URL`.
3. Confirm `build/web/sign-in/index.html` exists.
4. Confirm `build/web/sso-callback/index.html` exists.
5. Confirm `build/web/clerk-runtime.js` exists.
6. Open `/sign-in` and verify Clerk UI reaches `Ready`.
7. Copy diagnostics and confirm origin matches configured app host.
8. Start Google sign-in and follow redirects to `/sso-callback`.
9. Confirm callback completes and redirects to `/#/entry`.
10. Confirm Flutter auth state becomes authenticated.
11. Confirm API requests include `Authorization`.
12. Confirm `/api/bootstrap` succeeds.
13. Refresh the app and confirm session restore works without re-login.
14. Sign out and confirm the app returns to signed-out state.

## When Not To Use This Pattern

This pattern is for Flutter web.

For native mobile Flutter apps, this pattern may still inform architecture, but native OAuth redirect/deep-link handling needs a separate implementation. Do not assume the browser bridge works on iOS or Android native targets.

For Astro sites, use `@clerk/astro`.

For Python scripts, use the official Convex Python client or a backend service token path rather than browser cookies.
