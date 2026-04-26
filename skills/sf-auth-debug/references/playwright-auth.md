# Playwright Auth Debug Reference

Use this reference when `sf-auth-debug` needs browser-level evidence or a repeatable auth validation pass.

Sources checked:
- https://clerk.com/docs/guides/development/testing/playwright/test-helpers
- https://developers.google.com/identity/gsi/web/guides/supported-browsers
- https://clerk.com/docs/guides/secure/bot-protection

Last reviewed: 2026-04-26

## What Playwright Should Prove

- The expected page is reachable before login.
- The sign-in trigger is visible and clickable.
- The auth provider redirect starts.
- The callback or return route is reached.
- The final app route is correct.
- The browser has or does not have an authenticated app state.
- Protected app behavior works after auth, not only the login page.

## What Playwright Should Not Promise

- Stable automation of a personal Google account.
- Bypassing MFA, passkeys, captcha, device approval, bot checks, or Workspace policy.
- Secret-safe handling of real account passwords as the default path.
- Full production readiness from one `200` response or one visible dashboard render.

## Preferred Strategies

- Public flow debug: navigate, click login, inspect redirect chain and visible errors.
- Assisted OAuth debug: Playwright reaches the human step, user completes it, Playwright resumes observation.
- Session reuse: use a dedicated test browser/profile/session state when the environment supports it.
- Test auth path: use a test-only email/password or Clerk test helper strategy when available.
- Provider-level diagnosis: inspect Google/Clerk errors without completing login when the provider blocks automation.

## Evidence To Capture

- Initial URL, login URL, provider URL, callback URL, and final URL.
- Accessibility snapshot or page text at each major step.
- Console errors and warnings related to auth, middleware, cookies, CSP, or provider scripts.
- Network requests for sign-in, callback, session, protected routes, Convex auth, and API calls.
- Cookie presence and domain attributes when browser tools expose them.
- Screenshots only when text/snapshots are insufficient.

## Safe Handling

- Redact cookies, authorization headers, OAuth codes, tokens, client secrets, and session IDs before reporting.
- Do not ask the user for raw personal Google cookies by default.
- Do not write real credentials into repo files, specs, README, or task trackers.
- If a secret is required for a script, use the project's secret manager pattern and keep it out of logs.

## Debug Checklist

- Start from the exact URL in the bug report or spec.
- Capture a baseline unauthenticated page state.
- Click the same user-facing control the user would click.
- Follow redirects until success, visible failure, or a human gate.
- Classify the stop point: app UI, Clerk, Google, callback, middleware, session, or downstream backend.
- After a fix, replay the same scenario and prove the final protected behavior.
