# Astro + Clerk Auth Debug Reference

Use this reference when a ShipFlow site is built with Astro and Clerk.

Sources checked:
- https://clerk.com/docs/astro/getting-started/quickstart
- https://clerk.com/docs/reference/astro/integration

Last reviewed: 2026-04-26

## Ideal Flow

1. `@clerk/astro` is installed.
2. `.env` contains `PUBLIC_CLERK_PUBLISHABLE_KEY` and `CLERK_SECRET_KEY`.
3. `astro.config.mjs` registers the `clerk()` integration.
4. Astro runs in SSR mode with an adapter when auth state is needed server-side.
5. `src/middleware.ts` or root `middleware.ts` exports `onRequest = clerkMiddleware()`.
6. Routes are public by default, and protected routes explicitly opt in to protection.
7. UI uses `@clerk/astro/components` such as `Show`, `SignInButton`, `SignUpButton`, and `UserButton`, or Account Portal links.

## Files And Config To Inspect

- `astro.config.mjs`
- `src/middleware.ts` or root `middleware.ts`
- `.env`, hosting env, and build/deploy env
- layouts importing `@clerk/astro/components`
- pages that expect signed-in/signed-out rendering
- integration options passed to `clerk()`

## Astro-Specific Checks

- `PUBLIC_CLERK_PUBLISHABLE_KEY` is public by design; `CLERK_SECRET_KEY` must stay server-only.
- `output: "server"` and an SSR adapter are required for server-side auth behavior.
- `clerkMiddleware()` does not protect routes by default. Protection must be explicit.
- If using `/src`, middleware belongs in `/src/middleware.ts`.
- If not using `/src`, middleware belongs at project root next to `.env`.
- Account Portal is used by default when no custom sign-in/sign-up URLs are configured.
- Integration options such as `proxyUrl`, `isSatellite`, `signInFallbackRedirectUrl`, and `prefetchUI` can affect auth behavior.

## Browser Evidence To Capture

- Whether the Astro page renders signed-in or signed-out content correctly.
- Whether sign-in opens modal mode or navigates to Account Portal as expected.
- Redirect URL before and after Account Portal.
- Network failures for `@clerk/ui`, Clerk Frontend API, or middleware-protected routes.
- Whether SSR output and client hydration disagree about auth state.

## Common Failure Modes

- Missing SSR adapter or `output: "server"` when server auth is expected.
- Middleware file placed in the wrong directory for the Astro project layout.
- Assuming `clerkMiddleware()` protects all routes automatically.
- `CLERK_SECRET_KEY` absent in the deploy environment.
- Using Next.js env names like `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY` in an Astro site instead of `PUBLIC_CLERK_PUBLISHABLE_KEY`.
- Account Portal redirect works but returns to a missing or protected route.
- CSP or script loading blocks Clerk UI, especially with strict CSP and missing `nonce` handling.
- Reverse proxy setup needs `proxyUrl` but the integration config does not provide it.

## Debug Checklist

- Confirm this is an Astro site, not Next.js.
- Verify `@clerk/astro` and the `clerk()` integration are present.
- Verify env names match Astro conventions.
- Verify SSR adapter and `output: "server"` when needed.
- Verify middleware location and exported `onRequest`.
- Reproduce with Playwright and capture Account Portal or modal behavior.
- If route protection is wrong, inspect explicit route matcher/protection code rather than assuming global protection.
