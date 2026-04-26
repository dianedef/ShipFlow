# Supabase Testing Reference

Use this reference when the agent must test a Supabase-backed auth flow instead of only reading code.

Sources checked:
- https://supabase.com/docs/guides/local-development
- https://supabase.com/docs/guides/local-development/cli/testing-and-linting
- https://supabase.com/docs/guides/local-development/testing/overview
- https://supabase.com/docs/guides/auth/server-side
- https://supabase.com/docs/guides/auth/server-side/creating-a-client?queryGroups=framework&framework=nextjs
- https://supabase.com/docs/guides/auth/social-login

Last reviewed: 2026-04-26

## Default Testing Strategy

Prefer this order:

1. Run the local Supabase stack with the CLI for repeatable auth testing.
2. Test SSR/cookie behavior in the app with real browser evidence.
3. Use local Mailpit for email-based auth flows.
4. Use database tests for RLS and auth-to-data boundaries.

Supabase does not provide an official Playwright auth helper equivalent to Clerk's `clerk.signIn()`.
Do not assume there is a supported shortcut for browser auth session setup.

## Best Default Test Environment

Prefer local development for repeatable tests:

- install the Supabase CLI
- run `npx supabase init` in the repo if needed
- run `npx supabase start`

Important local endpoints:

- local API/Auth stack: `http://127.0.0.1:54321`
- local Studio: `http://127.0.0.1:54323`
- local Mailpit: `http://127.0.0.1:54324`

Why this path is preferred:

- local Auth, Storage, and Postgres are available together
- auth emails can be inspected without sending real mail
- config is reproducible from `supabase/config.toml`
- schema and policy tests can run against the same local stack

## Email And Magic-Link Testing

When the flow sends email through local Supabase Auth:

- run the local stack with `supabase start`
- inspect auth emails in Mailpit at `localhost:54324`

Use this for:

- magic links
- email OTP
- confirmation flows
- password reset flows

Do not rely on production email delivery behavior when debugging locally. Local Mailpit proves app wiring, not external email-provider correctness.

## Social OAuth Testing

For local OAuth with the Supabase CLI, configure providers in `supabase/config.toml`.

Example shape from Supabase docs:

- provider section like `[auth.external.github]`
- `enabled = true`
- `client_id` and `secret` from env vars
- local callback `http://localhost:54321/auth/v1/callback`

Use browser observation for:

- provider consent
- callback redirects
- `redirectTo` mismatches
- final post-login navigation

Do not promise full automation when the provider flow includes MFA, captcha, device approval, or account chooser behavior outside the app.

## SSR And Cookie Testing

For SSR apps, test the full browser flow, not just direct API calls.

Critical Supabase rule:

- server-side auth uses cookies
- server code should trust `supabase.auth.getClaims()`
- server code should not trust `supabase.auth.getSession()` as proof of identity

Testing implications:

- if login appears successful but protected pages still fail, inspect cookie refresh and proxy/middleware behavior
- if Server Components depend on auth, verify the proxy refresh path is actually running
- reproduce with a browser to capture callback URL, cookie writes, and first protected navigation

## RLS And Auth-To-Data Boundary

A successful login does not prove that data access works.

Use database tests when the real risk is policy enforcement:

- write pgTAP tests
- run `supabase test db`
- model authenticated users by setting role and JWT claims inside the test

Supabase's testing docs show RLS tests that:

- insert test rows in `auth.users`
- `set local role authenticated`
- `set local request.jwt.claim.sub = '<user-id>'`

Use this when:

- the user signs in but cannot read or write expected rows
- the app mixes browser user-context and server admin-context
- storage or table policies may be wrong

## What The Agent Should Assume

- Local Supabase is good for reproducible auth and schema tests, but not identical to hosted production.
- SSR auth depends on correct cookie wiring and proxy/middleware refresh.
- Browser success does not prove RLS correctness.
- Database test success does not prove browser callback correctness.

## Decision Rules

Use local Supabase + browser when:

- the issue is in sign-in, callback, cookie refresh, or post-login navigation

Use Mailpit when:

- the flow depends on magic links, password reset, or email confirmation

Use pgTAP / `supabase test db` when:

- the issue is really about RLS, claims, ownership, or auth-to-data enforcement

Use browser diagnosis only when:

- the issue depends on real redirects, provider pages, cookies, or SSR navigation

## Minimal Local Test Checklist

1. Start local Supabase with `npx supabase start`.
2. Confirm the app points to the local URL and keys you intend to test.
3. For email auth, inspect Mailpit at `localhost:54324`.
4. For SSR apps, verify proxy/middleware refresh behavior and first protected navigation.
5. For OAuth, verify provider config plus callback URL `http://localhost:54321/auth/v1/callback` where relevant.
6. If auth succeeds but data fails, switch to policy/database testing instead of repeating browser clicks.
