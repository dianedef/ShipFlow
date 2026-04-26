# ShipFlow Auth SDK Policy

Use this reference before adding or changing auth-related dependencies in ShipFlow projects.

Sources checked:
- https://clerk.com/docs/astro/getting-started/quickstart
- https://clerk.com/docs/reference/astro/integration
- https://pub.dev/packages/clerk_flutter
- https://pub.dev/packages/clerk_auth
- https://clerk.com/changelog/2025-03-26-flutter-sdk-beta
- https://docs.convex.dev/client/python
- https://docs.convex.dev/quickstart/python
- https://pub.dev/packages/convex_dart

Last reviewed: 2026-04-26

## Default Stack Assumption

- Apps: Flutter.
- Sites: Astro.
- Backend/data: Convex.
- Scripts/jobs/tools: Python.
- Auth: mostly Clerk, often Google sign-in.

When debugging or implementing auth, start from this stack before assuming React/Next.js patterns.

## Recommended SDK Choices

- Astro + Clerk: use official `@clerk/astro`.
- Convex + Python: use official Python client package `convex` and keep Convex backend functions in TypeScript under `convex/`.
- Flutter web + Clerk: prefer the ContentFlow pattern: official ClerkJS on app-domain HTML auth routes plus a small Dart JS-interop bridge.
- Clerk + Flutter/Dart native: `clerk_flutter` and `clerk_auth` are official but beta. Do not use for production auth unless the project explicitly accepts beta SDK risk.
- Convex + Flutter/Dart: `convex_dart` exists and provides codegen/realtime APIs, but treat it as third-party unless Convex official docs explicitly adopt it.
- Google OAuth: prefer Clerk-managed Google social connection when the app already uses Clerk.

## Avoid By Default

- Personal Google credentials for automated tests.
- Raw cookie sharing as the default auth strategy.
- Unpinned beta packages in production apps.
- Reintroducing Clerk Flutter/Dart beta into the production path when the app can use ClerkJS on web.
- Mixing dev/prod Clerk keys or Google OAuth clients.
- Adding an unofficial SDK when the same job can be handled by official HTTP/API patterns with less risk.
- Copying Next.js auth assumptions into Astro or Flutter without checking the platform-specific SDK.

## Beta And Unofficial Rules

- Beta official SDKs are allowed only when the project needs them and the version is pinned exactly or narrowly.
- Any beta SDK use should document the version, known limitations, and fallback plan.
- Unofficial SDKs require an explicit justification in the spec or implementation report.
- For auth-critical paths, prefer fewer moving parts over developer convenience.
- If a beta SDK participates in login/session state, validation must include a real device/browser flow and not only unit tests.

## Debug Priority

1. Confirm the platform: Flutter app, Astro site, Python script, or Convex backend.
2. Confirm the auth owner: Clerk, Google direct, or custom backend.
3. Confirm whether the package is official, beta, or third-party.
4. Confirm environment split: local, staging, production.
5. Confirm session propagation: browser/app -> Clerk -> Convex or Python job.

## Known ShipFlow Pattern

ContentFlow Flutter web intentionally removed Clerk Flutter beta from the production path.
It uses:
- generated `/sign-in` and `/sso-callback` HTML routes in `build/web`
- official ClerkJS loaded from the Clerk frontend API
- a `window.contentflowClerkBridge` JS object
- Dart `dart:js_interop` service to call `isSignedIn`, `getToken`, `getUser`, and `signOut`
- Dio bearer token injection into FastAPI

Use this as the preferred reference pattern for Flutter web auth bugs.
