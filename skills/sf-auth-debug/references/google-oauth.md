# Google OAuth Debug Reference

Use this reference when the bug involves Google login directly or as a Clerk social connection.

Sources checked:
- https://developers.google.com/identity/protocols/oauth2/web-server
- https://developers.google.com/identity/openid-connect/openid-connect
- https://support.google.com/cloud/answer/15549257
- https://developers.google.com/identity/protocols/oauth2/production-readiness/policy-compliance
- https://developers.google.com/identity/protocols/oauth2/production-readiness/sensitive-scope-verification
- https://developers.google.com/identity/gsi/web/guides/supported-browsers
- https://clerk.com/docs/guides/configure/auth-strategies/social-connections/google
- https://clerk.com/docs/guides/development/testing/playwright/test-helpers
- https://clerk.com/docs/guides/secure/bot-protection

Last reviewed: 2026-04-26

## Ideal Flow

1. App or auth provider creates an authorization request with client ID, scopes, redirect URI, response type, and state.
2. Browser redirects the user to Google for account selection, consent, or authentication.
3. Google redirects back to the exact authorized redirect URI with an authorization code and state.
4. The backend or auth provider validates state and exchanges the code for tokens.
5. The auth provider establishes the application session.
6. App redirects the user to the intended post-login page.

## Config To Inspect

- Google Cloud OAuth Client ID and Client Secret.
- OAuth application type, usually Web application for web apps.
- Authorized redirect URIs in Google Cloud.
- Authorized JavaScript origins for client-side flows.
- OAuth consent screen status, app publishing status, scopes, and test users.
- Clerk SSO connection settings when Clerk owns the Google flow.
- The Clerk-provided Authorized Redirect URI copied into Google credentials for production custom credentials.
- Local, preview, staging, and production domains.
- Whether dev/staging/prod share one OAuth client or use separate clients. Separate clients/projects are easier to reason about.

## Redirect URI Rules

- The redirect URI in the request must match an authorized redirect URI for the OAuth client.
- Compare scheme, host, path, case, port, and trailing slash. Treat it as byte-for-byte strict for debugging.
- Google OAuth redirect URIs do not support wildcard shortcuts for this diagnosis.
- Environment mismatches are common: localhost, Vercel preview, staging, and production may each need correct handling.
- When Clerk owns the flow, the app usually should not invent a Google callback route. The Google redirect URI should be the one Clerk provides.
- Capture the actual `redirect_uri` in the outgoing Google request when possible and compare it to provider/dashboard config.

## State And CSRF

- OAuth flows should use state to bind the callback to the request.
- If state is missing, invalid, expired, or not persisted through cookies/session storage, the callback can fail even when Google auth succeeded.
- Debug signs include provider callback reaching the app/auth provider followed by a generic invalid request or immediate restart of sign-in.
- For OpenID Connect, expect `openid email` scopes and often `profile`; custom flows may also use `nonce`.

## Browser Evidence To Capture

- The URL that leaves the app.
- The Google URL host and query parameters relevant to diagnosis, especially `client_id`, `redirect_uri`, `scope`, `response_type`, `state`, `prompt`, `login_hint`, and `hd`.
- Whether Google shows account chooser, consent, app blocked, test-user, admin policy, origin mismatch, or redirect mismatch errors.
- The exact callback URL reached after Google.
- Final app URL and whether a session exists afterward.
- Provider error names such as `redirect_uri_mismatch`, `origin_mismatch`, `invalid_client`, `disallowed_useragent`, `org_internal`, `admin_policy_enforced`, `access_denied`, or `invalid_grant`.
- HAR/network traces only after redacting codes, tokens, cookies, and secrets.

## Common Failure Modes

- `redirect_uri_mismatch` because the URI is absent or differs between Google Cloud and Clerk/app config.
- `origin_mismatch` because JavaScript origin or local port is missing.
- `invalid_client` because the client ID/secret is wrong, rotated, deleted, or from the wrong environment.
- `invalid_grant` because the authorization code expired, was reused, or was exchanged with a different redirect URI.
- Wrong OAuth client for the environment.
- OAuth consent screen still in Testing and user not listed as a test user.
- App requesting scopes that require verification or trigger additional consent.
- Workspace/admin restrictions such as `org_internal` or `admin_policy_enforced`.
- Google blocks sign-in in WebViews or embedded browsers.
- Human challenge, MFA, captcha, or device approval stops full automation.
- State/cookie continuity lost between the outbound auth request and callback.
- Clerk production app uses development/shared assumptions instead of production custom credentials.

## Playwright Guidance

- Playwright can validate that the app reaches Google and can observe visible provider errors.
- Do not rely on Playwright to permanently automate a real Google account login with MFA or anti-abuse checks.
- If a human step appears, capture the state before the step and continue after the user completes it when possible.
- Do not store a personal Google password as the standard solution. Prefer test users, session reuse, or provider-level diagnostic observation.
- For durable E2E on Clerk apps, prefer Clerk test helpers, a session fixture, or a non-Google test login path when available.

## Debug Checklist

- Confirm who owns the OAuth flow: Clerk, another auth library, or app code.
- Compare actual outgoing `redirect_uri` with the configured allowed URI.
- Confirm the OAuth client belongs to the same environment being tested.
- Check Google consent screen publishing status and test users.
- If account selection is suspicious, try `prompt=select_account` when the app/provider supports it to rule out a hidden wrong Google session.
- Test a non-Workspace account and a Workspace account separately when admin policy is suspected.
- Check whether the visible failure is a Google provider error or an app/Clerk callback error.
- If Google succeeds but the app is signed out, inspect callback handling, state/cookies, and post-login session creation.
