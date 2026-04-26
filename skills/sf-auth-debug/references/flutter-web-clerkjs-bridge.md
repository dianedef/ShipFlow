# Flutter Web + ClerkJS Bridge Auth Reference

Use this reference for ShipFlow Flutter web apps that avoid Clerk Flutter/Dart beta SDKs and authenticate with official ClerkJS on the app domain.

Reference implementation inspected:
- `/home/claude/contentflow/contentflow_app/pubspec.yaml`
- `/home/claude/contentflow/contentflow_app/lib/data/services/clerk_auth_service.dart`
- `/home/claude/contentflow/contentflow_app/lib/data/services/clerk_auth_service_web.dart`
- `/home/claude/contentflow/contentflow_app/lib/data/services/clerk_auth_service_stub.dart`
- `/home/claude/contentflow/contentflow_app/web_auth/clerk-runtime.js.template`
- `/home/claude/contentflow/contentflow_app/web_auth/sign-in.html`
- `/home/claude/contentflow/contentflow_app/web_auth/sso-callback.html`
- `/home/claude/contentflow/contentflow_app/scripts/install-web-auth.sh`
- `/home/claude/contentflow/contentflow_app/scripts/validate-clerk-runtime.sh`
- `/home/claude/contentflow/contentflow_app/scripts/vercel-build.sh`
- `/home/claude/contentflow/contentflow_app/lib/providers/providers.dart`
- `/home/claude/contentflow/contentflow_app/lib/data/services/api_service.dart`

Last reviewed: 2026-04-26

## Why This Pattern Exists

ContentFlow deliberately removed the Clerk Flutter beta SDK from the production web auth path.
The stable web path uses ClerkJS directly in generated HTML routes, while Flutter/Dart only restores and consumes the resulting session through a small JS bridge.

This avoids betting production web auth on beta Dart SDK behavior while still keeping the Flutter app authenticated.

## Ideal Flow

1. Flutter web build receives `CLERK_PUBLISHABLE_KEY`, `API_BASE_URL`, `APP_SITE_URL`, and `APP_WEB_URL` through `--dart-define`.
2. Build script runs `scripts/install-web-auth.sh build/web`.
3. The script creates:
   - `build/web/sign-in/index.html`
   - `build/web/sso-callback/index.html`
   - `build/web/clerk-runtime.js`
   - `build/web/clerk-auth.css`
4. `/sign-in` loads `clerk-runtime.js` and mounts ClerkJS sign-in UI.
5. ClerkJS starts Google sign-in with `oauthFlow: "redirect"`.
6. OAuth callback returns to `/sso-callback?redirect_url=...`.
7. `/sso-callback` calls `clerk.handleRedirectCallback()`.
8. Callback redirects back to `/#/entry`.
9. Flutter starts or refreshes, `ClerkAuthService.restoreSession()` calls `window.contentflowClerkBridge`.
10. The Dart bridge calls:
   - `isSignedIn()`
   - `getToken()`
   - `getUser()`
11. Riverpod stores `AuthSession(status: authenticated, bearerToken, email)`.
12. Dio injects `Authorization: Bearer <fresh Clerk token>` on authenticated FastAPI requests.
13. FastAPI validates the Clerk JWT and returns `/api/bootstrap`.
14. App access state becomes `ready`, `needsOnboarding`, degraded, or unauthorized.

## Key Files

- `web_auth/clerk-runtime.js.template`: owns ClerkJS load, redirects, callback, diagnostics, and bridge methods.
- `web_auth/sign-in.html`: app-domain sign-in page and diagnostics copy UI.
- `web_auth/sso-callback.html`: app-domain OAuth callback page.
- `scripts/install-web-auth.sh`: injects env values and copies auth routes into `build/web`.
- `lib/data/services/clerk_auth_service.dart`: conditional export.
- `lib/data/services/clerk_auth_service_web.dart`: Dart JS interop bridge for web.
- `lib/data/services/clerk_auth_service_stub.dart`: non-web stub that rejects beta SDK auth path.
- `lib/providers/providers.dart`: `authSessionProvider`, session restore, bootstrap resolution.
- `lib/data/services/api_service.dart`: Dio bearer token refresh and 401 handling.

## Bridge Contract

Expected global object:
- `window.contentflowClerkBridge.load()`
- `window.contentflowClerkBridge.isSignedIn()`
- `window.contentflowClerkBridge.getToken({ skipCache })`
- `window.contentflowClerkBridge.getUser()`
- `window.contentflowClerkBridge.signOut()`
- `window.contentflowClerkBridge.mountSignIn(node, options)`
- `window.contentflowClerkBridge.startGoogleSignIn(options)`
- `window.contentflowClerkBridge.handleRedirectCallback(options)`
- `window.contentflowClerkBridge.getDiagnostics()`

Dart should fail loudly if the bridge is missing. A missing bridge usually means `install-web-auth.sh` did not run or `clerk-runtime.js` is not served from `build/web`.

## Build And Env Checks

- `CLERK_PUBLISHABLE_KEY` must be present for auth routes to work.
- `APP_WEB_URL` should match the deployed app origin, for example `https://app.contentflow.winflowz.com`.
- `API_BASE_URL` must point to the FastAPI environment that accepts the Clerk token.
- `scripts/vercel-build.sh` must run `scripts/install-web-auth.sh` after `flutter build web`.
- Local validation can use `scripts/validate-clerk-runtime.sh`.
- Static server must support directory index routes like `/sign-in` and `/sso-callback`.

## Runtime Checks

- `/sign-in` renders ClerkJS UI and reports `Ready`.
- `getDiagnostics()` shows current origin matches configured app host.
- OAuth callback URL uses the current origin `/sso-callback`.
- Redirect complete URL resolves to `/#/entry` or another same-origin route.
- After callback, Flutter `authSessionProvider` becomes `authenticated`.
- `apiServiceProvider` obtains a fresh token through `getFreshToken()`.
- Dio requests log `hasAuthorization: true`.
- `/api/bootstrap` succeeds or returns an explicit 401/degraded state.

## Common Failure Modes

- `CLERK_PUBLISHABLE_KEY` missing during build.
- `install-web-auth.sh` not run after `flutter build web`.
- `/sign-in` or `/sso-callback` not served because hosting lacks directory index support.
- `clerk-runtime.js` missing from `build/web`.
- Current host differs from `APP_WEB_URL`, causing wrong redirect assumptions.
- ClerkJS script URL cannot be derived from publishable key.
- OAuth callback reaches `/sso-callback` but `handleRedirectCallback()` fails.
- Callback succeeds but Flutter cannot find `window.contentflowClerkBridge`.
- Flutter restores session but FastAPI rejects the bearer token.
- Dio uses stale token because token refresh path is broken.
- Non-web path tries to use removed Clerk Flutter beta methods.

## Debug Checklist

- Confirm `pubspec.yaml` does not include `clerk_flutter` or `clerk_auth` when debugging the web path.
- Confirm generated files exist in `build/web/sign-in`, `build/web/sso-callback`, and `build/web/clerk-runtime.js`.
- Open `/sign-in` directly and copy diagnostics.
- Confirm `Current origin matches configured app: yes`.
- Click Google and record the redirect chain through `/sso-callback`.
- On callback, confirm `Callback completed. Redirecting...`.
- Back in Flutter, confirm `auth.restore` logs restored authenticated session.
- Confirm a fresh bearer token is sent to `/api/bootstrap`.
- If bootstrap returns 401, debug FastAPI Clerk JWT validation instead of the browser flow.
- After a fix, refresh the app and confirm session restore still works without re-login.
