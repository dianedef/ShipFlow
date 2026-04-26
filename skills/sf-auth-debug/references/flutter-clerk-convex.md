# Flutter + Clerk + Convex Auth Debug Reference

Use this reference when a ShipFlow application is a Flutter app using Clerk, Convex, or both.

Sources checked:
- https://clerk.com/changelog/2025-03-26-flutter-sdk-beta
- https://pub.dev/packages/clerk_flutter
- https://pub.dev/packages/clerk_auth
- https://pub.dev/packages/convex_dart
- https://docs.convex.dev/client/python
- https://docs.convex.dev/home

Last reviewed: 2026-04-26

## SDK Status

- `clerk_flutter` is official Clerk Flutter SDK, currently beta. Current pub.dev version reviewed: `0.0.14-beta`.
- `clerk_auth` is official Clerk Dart SDK, currently beta. Current pub.dev version reviewed: `0.0.14-beta`.
- Clerk beta docs warn that breaking changes should be expected before `1.0.0`.
- `convex_dart` exists on pub.dev and provides Dart codegen/realtime APIs. Treat it as third-party unless Convex official docs explicitly list it as an official client.
- Convex official docs list Python, iOS Swift, Android Kotlin, JavaScript, React, Vue, Svelte, Node/Bun and other clients, but no first-party Flutter/Dart client in the reviewed docs.

## Recommended Default

- For Flutter web apps, prefer the ContentFlow pattern documented in `flutter-web-clerkjs-bridge.md`: official ClerkJS on app-domain auth routes plus Dart JS interop.
- For native Flutter apps that need Clerk today, avoid production reliance on `clerk_flutter` / `clerk_auth` unless the project explicitly accepts beta SDK risk; if used, pin versions carefully and test login on real target platforms.
- For Convex from Flutter, prefer a documented project decision:
  - use `convex_dart` with explicit acceptance of third-party dependency risk, or
  - expose a small official HTTP/API layer if auth-critical reliability matters more than realtime client convenience.
- For Google sign-in, prefer Clerk-managed social auth when using Clerk, and avoid hand-rolling direct Google OAuth unless the app has a strong reason.

## Files And Config To Inspect

- `pubspec.yaml`
- `lib/main.dart`
- root app auth/provider setup
- `AndroidManifest.xml` for `android.permission.INTERNET`
- iOS/macOS URL scheme or associated domain config if OAuth redirect depends on it
- any storage/persistor setup for Clerk auth state
- code passing session tokens to Convex or custom backend calls
- environment injection for publishable keys, Convex URL, and Google client ID

## Clerk Flutter Checks

- `ClerkAuth` wraps the app area that needs auth state.
- `ClerkAuthConfig` uses the correct publishable key for the environment.
- `ClerkErrorListener` exists where useful during debugging.
- `ClerkAuthBuilder` or equivalent signed-in/signed-out state is not bypassed by custom state.
- Android has `android.permission.INTERNET`.
- For Google token OAuth, `google_client_id` is present when required by the chosen implementation.
- `clerk_auth` session token polling behavior matches the package version. In `0.0.13-beta+`, token polling defaults changed compared with earlier beta versions.

## Convex From Flutter Checks

- Identify whether the app uses `convex_dart`, a custom HTTP layer, or generated API calls.
- If using `convex_dart`, confirm generated client files are up to date after Convex function changes.
- Confirm Flutter points to the correct Convex deployment URL for local/staging/prod.
- Confirm authenticated Convex calls receive a Clerk token or app-specific bearer token.
- Confirm type conversions and generated IDs match the Convex schema.
- For realtime issues, separate WebSocket connectivity from auth failures.

## Browser / Device Evidence To Capture

- Platform: Android, iOS, web, macOS, Windows, Linux.
- Package versions from `pubspec.lock`.
- Signed-in/signed-out state from Clerk UI or auth builder.
- Token/session polling logs in debug builds.
- Network calls to Clerk and Convex, redacted.
- Redirect URI or deep link observed during Google/OAuth flow.
- Whether the bug occurs on emulator, simulator, real device, Flutter web, or all targets.

## Common Failure Modes

- Beta SDK breaking change after loose version upgrade.
- Reintroducing the old Clerk Flutter beta path into a web app that should use ClerkJS bridge auth.
- Missing Android internet permission.
- Wrong publishable key for the environment.
- Auth state persisted in a platform path that does not work on the current target.
- Google OAuth flow works on web but fails on native due to redirect/deep link configuration.
- Session token exists in Clerk but is never forwarded to Convex/custom backend.
- Convex deployment URL points to dev while Clerk keys point to prod, or the reverse.
- `convex_dart` generated client is stale after backend function changes.
- Flutter web uses browser cookie/session assumptions that do not match native platforms.

## Debug Checklist

- Pin and record SDK versions before debugging.
- Confirm whether the dependency is official stable, official beta, or third-party.
- If the target is Flutter web, check whether the app should follow the ClerkJS bridge path instead of a Dart SDK path.
- Reproduce on the target platform where the bug was reported.
- Verify publishable key and Convex URL are from the same environment.
- Confirm Clerk signs in before debugging Convex.
- Confirm a session token reaches the backend before debugging app data.
- For Google login, capture redirect/deep link behavior and do not assume Playwright browser behavior equals native behavior.
- After a fix, test cold start, sign-in, app restart, token refresh, sign-out, and one protected backend call.
