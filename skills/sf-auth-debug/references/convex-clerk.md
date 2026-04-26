# Convex + Clerk Auth Debug Reference

Use this reference when the app uses Clerk for identity and Convex for backend data or realtime state.

Sources checked:
- https://docs.convex.dev/auth/clerk
- https://docs.convex.dev/auth/debug
- https://docs.convex.dev/auth/functions-auth
- https://docs.convex.dev/api/modules/react_clerk
- https://docs.convex.dev/api/classes/react.ConvexReactClient
- https://docs.convex.dev/api/interfaces/server.UserIdentity
- https://clerk.com/docs/integrations/databases/convex
- https://clerk.com/docs/guides/development/customize-redirect-urls

Last reviewed: 2026-04-26

## Ideal Flow

1. User starts login in the app.
2. Clerk authenticates the user through the configured method.
3. Clerk redirects back to the app.
4. `ClerkProvider` sees the user as authenticated.
5. `ConvexProviderWithClerk` fetches the Clerk JWT expected by Convex, commonly the `convex` template.
6. `ConvexReactClient` sends that token to the Convex backend.
7. Convex validates the token using `convex/auth.config.ts`, where `domain` must match the token issuer and `applicationID` must match the audience.
8. Convex auth state becomes authenticated, `useConvexAuth()` returns authenticated, and `Authenticated` renders protected children.

## Files And Config To Inspect

- `convex/auth.config.ts`
- root provider setup where `ClerkProvider`, `ConvexReactClient`, and `ConvexProviderWithClerk` are wired
- Convex client initialization
- app components using `Authenticated`, `Unauthenticated`, or `useConvexAuth()`
- queries/mutations that call `ctx.auth.getUserIdentity()`
- deployment env for Clerk issuer and Convex deployment URL
- Clerk dashboard integration/JWT template for Convex, especially whether a `convex` token template exists
- Convex dashboard Authentication settings and deployed auth config

## Critical Config Checks

- `convex/auth.config.ts` must use the Clerk issuer/frontend API URL that matches the Clerk instance.
- If using `process.env.CLERK_JWT_ISSUER_DOMAIN`, confirm it exists in the Convex dashboard/environment for the deployed Convex backend.
- Confirm the app's frontend Clerk keys, Clerk dashboard instance, and Convex auth issuer all point to the same environment.
- Confirm provider order lets Convex receive Clerk state. The Convex provider with Clerk must be inside the Clerk context in the pattern expected by the app/framework.
- Confirm `applicationID` matches the JWT audience. The common default is `convex`.
- Confirm `npx convex dev` or `npx convex deploy` synchronized new auth config.
- In Next App Router, confirm the combined provider wrapper is a client component when required.

## Browser Evidence To Capture

- Whether Clerk UI shows signed-in state.
- Whether Convex-side UI still shows unauthenticated after Clerk login.
- Whether `Authenticated` content renders after login.
- Console/network errors from Convex websocket or HTTP calls after login.
- Whether queries/mutations fail because `ctx.auth.getUserIdentity()` is null.
- Whether the app briefly authenticates and then drops back to unauthenticated after token refresh.
- WebSocket `sync` authenticate messages or HTTP requests with `Authorization: Bearer <jwt>`.
- Decoded JWT `iss`, `aud`, and `sub`, redacted before sharing.
- Temporary Convex server log of `await ctx.auth.getUserIdentity()` in one affected query/mutation.

## Common Failure Modes

- Clerk login succeeds but Convex still sees unauthenticated.
- `auth.config.ts` issuer does not match the Clerk instance used by the frontend.
- Convex deployment env is missing the Clerk issuer variable.
- App has correct local env but stale Convex dashboard env for staging/prod.
- Provider tree is misordered or split across server/client boundaries incorrectly.
- Protected UI gates on Convex auth while Clerk auth is still loading, causing false redirects or flashes.
- Convex queries assume identity is present without handling unauthenticated states.
- `ConvexReactClient` is recreated inside a render path instead of being stable.
- Wrong Clerk `useAuth` import for the framework integration.
- JWT template is missing, misnamed, or has an audience that does not match Convex config.
- Local uses `pk_test` while Convex issuer points to prod, or prod uses `pk_live` while issuer points to dev.
- App stores users by `subject` alone instead of the globally stable `tokenIdentifier`.

## Debug Checklist

- First separate Clerk auth from Convex auth: is Clerk signed in in the browser?
- If Clerk is signed in but Convex is not, inspect provider wiring and `convex/auth.config.ts`.
- Confirm Convex deployment env, not only local `.env`.
- Check `useConvexAuth()` state transitions: loading, unauthenticated, authenticated.
- Inspect one failing query or mutation and confirm whether `ctx.auth.getUserIdentity()` is null.
- Decode the JWT sent to Convex and compare `iss` with `domain`, `aud` with `applicationID`.
- Use `identity.tokenIdentifier` for stable app user mapping unless the project has a documented reason not to.
- If `null` occurs only during initial load, gate protected queries under `Authenticated` or `useConvexAuth()` and handle loading explicitly.
- After a fix, test both UI rendering and at least one authenticated Convex operation.
