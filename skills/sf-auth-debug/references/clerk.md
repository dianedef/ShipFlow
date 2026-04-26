# Clerk Auth Debug Reference

Use this reference when the project uses Clerk directly or through `@clerk/nextjs`, `@clerk/clerk-react`, or Clerk-hosted Account Portal pages.

Sources checked:
- https://clerk.com/docs/reference/nextjs/overview
- https://clerk.com/docs/nextjs/components/clerk-provider
- https://clerk.com/docs/reference/nextjs/clerk-middleware
- https://clerk.com/docs/reference/nextjs/app-router/auth
- https://clerk.com/docs/nextjs/guides/development/custom-sign-in-or-up-page
- https://clerk.com/docs/guides/development/clerk-environment-variables
- https://clerk.com/docs/guides/custom-redirects
- https://clerk.com/docs/guides/configure/auth-strategies/social-connections/google
- https://clerk.com/docs/nextjs/reference/components/control/authenticate-with-redirect-callback
- https://clerk.com/docs/references/nextjs/errors/auth-was-called
- https://clerk.com/docs/guides/development/errors/frontend-api

Last reviewed: 2026-04-26

## Ideal Flow

1. App renders inside `<ClerkProvider>` at the root layout/provider boundary.
2. Public sign-in or sign-up route is reachable without middleware blocking it.
3. User starts sign-in from Clerk UI, Account Portal, or a custom flow.
4. For OAuth, Clerk redirects through the provider and receives the callback.
5. Clerk completes the auth process, creates or resumes the session, and sets the expected browser state.
6. App redirects to the intended post-login URL from `redirect_url`, force redirect, fallback redirect, or provider defaults.
7. Protected routes see an authenticated Clerk state through middleware/server helpers/client hooks.

## Files And Config To Inspect

- `middleware.ts` or `proxy.ts`
- `app/layout.tsx`, root providers, or framework-specific provider setup
- sign-in and sign-up catch-all routes such as:
  - `app/sign-in/[[...sign-in]]/page.tsx`
  - `app/sign-up/[[...sign-up]]/page.tsx`
- custom OAuth callback routes using `AuthenticateWithRedirectCallback`
- server components, route handlers, or actions using `auth()`
- client components using Clerk hooks or prebuilt components
- `.env*`, deployment env, and dashboard config for:
  - `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY`
  - `CLERK_SECRET_KEY`
  - `NEXT_PUBLIC_CLERK_SIGN_IN_URL`
  - `NEXT_PUBLIC_CLERK_SIGN_UP_URL`
  - `NEXT_PUBLIC_CLERK_SIGN_IN_FORCE_REDIRECT_URL`
  - `NEXT_PUBLIC_CLERK_SIGN_UP_FORCE_REDIRECT_URL`
  - `NEXT_PUBLIC_CLERK_SIGN_IN_FALLBACK_REDIRECT_URL`
  - `NEXT_PUBLIC_CLERK_SIGN_UP_FALLBACK_REDIRECT_URL`

## Middleware Checks

- Confirm whether the project expects `middleware.ts` or `proxy.ts`. Newer Next.js/Clerk examples may use `proxy.ts`; older Next.js projects commonly use `middleware.ts`.
- Confirm `clerkMiddleware()` is configured. Clerk server helpers such as `auth()` require it in Next.js App Router.
- Confirm protected routes are intentionally matched with `createRouteMatcher()`.
- Confirm sign-in, sign-up, OAuth callback, static assets, and framework internals are not accidentally protected.
- If the app protects everything by default, explicitly keep `/sign-in(.*)` and `/sign-up(.*)` public.
- Remember that current Clerk middleware does not protect all routes by default; apps must opt in to protected matchers.
- Confirm the matcher covers protected pages and API routes that rely on auth state.
- If a public link points to a protected page and Next.js prefetch causes confusing console errors, check whether `prefetch={false}` is needed on that link.
- In dev only, consider temporary `clerkMiddleware(..., { debug: true })` logging when the failure is in middleware routing.

## Redirect Checks

- Identify the first requested URL, sign-in URL, OAuth callback URL, and final URL.
- Check whether `redirect_url` is present in the URL and whether it is preserved.
- Check force redirect variables before fallback variables. Force redirect wins over user-intended return flows.
- Check that server-side redirects only use URLs available through environment variables or middleware dynamic keys.
- If the app returns to `/` instead of the dashboard, suspect missing fallback redirect config.
- If the app loops back to sign-in, suspect session not established, callback not handled, or middleware protecting the callback/return path.
- Prefer current `fallbackRedirectUrl` / `forceRedirectUrl` props or matching env variables. Treat older `afterSignInUrl` / `afterSignUpUrl` patterns as legacy unless the app version requires them.

## Google Social Connection Through Clerk

- Development Clerk instances can use Clerk-provided shared Google OAuth credentials and redirect URIs.
- Production should use custom Google credentials and the corresponding Clerk Authorized Redirect URI.
- In the Clerk dashboard, Google should be enabled for sign-up and sign-in if users must authenticate with it.
- Google sign-in is not allowed in WebViews. Treat in-app browsers as a platform limitation unless a supported setup is explicitly configured.
- Google OAuth apps in Testing mode are limited; production apps should use a Google OAuth app with publishing status set to production when required.

## Browser Evidence To Capture

- Initial URL and final URL.
- Whether the sign-in page renders Clerk UI or Account Portal correctly.
- Whether clicking Google starts an external redirect or fails in-place.
- Whether the callback route renders or immediately redirects.
- Visible Clerk or provider error text.
- Network statuses for sign-in, callback, and protected route requests.
- Console errors around missing Clerk keys, invalid publishable key, hydration/provider failure, or failed prefetch.
- Cookies after login: presence, domain, `Secure`, `SameSite`, and expiry for Clerk-related cookies.
- Server logs containing messages like `auth() was called but Clerk can't detect usage of clerkMiddleware()`.

## Common Failure Modes

- Missing or wrong `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY`.
- Secret key configured in local but missing in preview/production.
- Mixed key families, such as `pk_test_` with `sk_live_` or `pk_live_` with `sk_test_`.
- Middleware protects the sign-in, sign-up, callback, or return route.
- Middleware matcher is too broad or misses API routes that need auth.
- App uses `auth()` without Clerk middleware configured.
- `<ClerkProvider>` is absent, placed too low, or split from components that need Clerk state.
- Redirect variables point to an old route or wrong environment domain.
- `NEXT_PUBLIC_CLERK_SIGN_IN_URL` or sign-up URL points outside the current primary app unexpectedly.
- Force redirect hides the intended `redirect_url`.
- Custom OAuth flow forgets to render `AuthenticateWithRedirectCallback` on the configured callback route.
- Production Google social connection uses the wrong Google OAuth credentials or redirect URI.
- Google OAuth app remains in Testing mode and the user is not allowed.
- Env changes were made in the hosting provider but the app was not redeployed.
- Session cookie is absent because of domain, HTTPS/local mismatch, subdomain, or authorized party configuration.
- Asset or route `404` interacts badly with middleware/root layout and surfaces as an auth error.
- `<SignIn />` or `<SignUp />` renders while already signed in and redirects according to Clerk session settings.

## Debug Checklist

- Identify whether the failure occurs before provider redirect, at provider, at Clerk callback, after session creation, or inside app protection.
- Confirm the Next.js version and whether the auth boundary file should be `proxy.ts` or `middleware.ts`.
- Verify env keys are from the same Clerk instance as the dashboard/provider config.
- Verify sign-in/sign-up/callback routes are public.
- Verify the protected route matcher only matches intended app areas.
- Verify post-login redirect variables and URL params.
- Test once in a clean browser profile or private context to separate stale cookie state from app behavior.
- Use Playwright to capture URL transitions and visible errors before reading too much code.
- After a fix, retest the original URL and the protected destination, not only the login page.
