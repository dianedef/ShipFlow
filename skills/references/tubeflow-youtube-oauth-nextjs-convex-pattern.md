# TubeFlow YouTube OAuth Next.js + Convex Pattern

## Purpose

This document describes the working TubeFlow YouTube OAuth flow in the Next.js implementation at `/home/claude/tubeflow`.

Use it as a reference when implementing or debugging YouTube connection in Flutter or other clients. The point is not to copy the Next.js code line-for-line, but to preserve the same security boundaries and token lifecycle.

Last reviewed: 2026-04-26

## Decision

TubeFlow uses two separate auth layers:

- Clerk authenticates the TubeFlow user.
- Google OAuth authorizes access to that user's YouTube account.

The YouTube OAuth tokens are stored server-side in Convex, scoped to the authenticated Clerk user. The frontend never calls YouTube Data API directly with long-lived credentials.

## Working Flow

```text
Signed-in Clerk user
  -> clicks Connect YouTube
  -> client stores Clerk sessionId in short-lived cookie
  -> browser navigates to /api/auth/youtube
  -> Next.js route creates OAuth state cookie
  -> route redirects to Google OAuth consent screen
  -> Google redirects to /api/auth/youtube/callback
  -> callback validates state cookie
  -> callback reads Clerk sessionId cookie
  -> callback asks Clerk for a Convex JWT for that session
  -> callback exchanges Google code for YouTube tokens
  -> callback authenticates ConvexHttpClient with Convex JWT
  -> callback calls Convex mutation saveYoutubeTokens
  -> Convex stores YouTube tokens on the current user
  -> browser redirects to /playlists?youtube_connected=true
  -> client queries Convex connection status and fetches playlists
```

## Key Files In TubeFlow

- `/home/claude/tubeflow/apps/web/src/app/api/auth/youtube/route.ts`
- `/home/claude/tubeflow/apps/web/src/app/api/auth/youtube/callback/route.ts`
- `/home/claude/tubeflow/apps/web/src/hooks/use-youtube.ts`
- `/home/claude/tubeflow/apps/web/src/components/youtube/YouTubeConnectPrompt.tsx`
- `/home/claude/tubeflow/packages/backend/convex/youtube.ts`
- `/home/claude/tubeflow/packages/backend/convex/schema.ts`
- `/home/claude/tubeflow/packages/backend/convex/auth.config.ts`
- `/home/claude/tubeflow/apps/web/src/lib/site.ts`
- `/home/claude/tubeflow/apps/web/.env.example`
- `/home/claude/tubeflow/turbo.json`

## Required Environment

Frontend / Next.js:

- `NEXT_PUBLIC_GOOGLE_CLIENT_ID`
- `GOOGLE_CLIENT_SECRET`
- `NEXT_PUBLIC_APP_URL`
- `NEXT_PUBLIC_CONVEX_URL`
- `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY`
- `CLERK_SECRET_KEY`

Convex:

- `CLERK_JWT_ISSUER_DOMAIN`
- Google OAuth credentials if token refresh actions run inside Convex:
  - `GOOGLE_CLIENT_ID` or `NEXT_PUBLIC_GOOGLE_CLIENT_ID`
  - `GOOGLE_CLIENT_SECRET`

Google Cloud Console:

- OAuth client type: Web application.
- Authorized redirect URI for local:
  - `http://localhost:3000/api/auth/youtube/callback`
- Authorized redirect URI for production:
  - `https://<APP_DOMAIN>/api/auth/youtube/callback`

TubeFlow has a production checklist item for this in `/home/claude/tubeflow/SPEC-production-checklist.md`.

## Initiation Route

Route: `GET /api/auth/youtube`

Implementation: `/home/claude/tubeflow/apps/web/src/app/api/auth/youtube/route.ts`

Responsibilities:

- require `NEXT_PUBLIC_GOOGLE_CLIENT_ID`
- compute `REDIRECT_URI`
- generate random `state`
- store `youtube_oauth_state` as an HTTP-only cookie
- redirect to `https://accounts.google.com/o/oauth2/v2/auth`

OAuth params:

- `client_id`
- `redirect_uri`
- `response_type=code`
- `scope=https://www.googleapis.com/auth/youtube`
- `access_type=offline`
- `prompt=consent`
- `state`

Important detail:

`access_type=offline` and `prompt=consent` are used so Google returns a `refresh_token`.

## Client Session Handoff

Before navigating to `/api/auth/youtube`, the React client stores the current Clerk session ID in a short-lived cookie:

```ts
document.cookie = `clerk_session_id=${sessionId}; path=/; max-age=600; SameSite=Lax`;
window.location.href = "/api/auth/youtube";
```

This appears in:

- `useYoutubeConnection()` in `/home/claude/tubeflow/apps/web/src/hooks/use-youtube.ts`
- `YouTubeConnectPrompt` in `/home/claude/tubeflow/apps/web/src/components/youtube/YouTubeConnectPrompt.tsx`

Purpose:

The callback route needs a way to prove which Clerk user started the OAuth flow after Google redirects back. It uses the Clerk session ID to request a Convex JWT from Clerk.

Security note:

The cookie is short-lived and same-site. It is not the Google token and should be deleted after callback. In a future hardening pass, this handoff could be replaced by a server-issued signed nonce that maps to the Clerk session.

## Callback Route

Route: `GET /api/auth/youtube/callback`

Implementation: `/home/claude/tubeflow/apps/web/src/app/api/auth/youtube/callback/route.ts`

Responsibilities:

- read `code`, `state`, and `error` from query params
- reject Google OAuth errors
- verify `state` against `youtube_oauth_state` cookie
- read `clerk_session_id` cookie
- exchange `code` for Google tokens at `https://oauth2.googleapis.com/token`
- use `clerkClient().sessions.getToken(sessionId, "convex")`
- authenticate `ConvexHttpClient` with that Convex JWT
- call `api.youtube.saveYoutubeTokens`
- delete `youtube_oauth_state` and `clerk_session_id`
- redirect to `/playlists?youtube_connected=true`

## Convex JWT Requirement

Clerk must have a JWT template named `convex`.

Convex must be configured with:

```ts
{
  domain: process.env.CLERK_JWT_ISSUER_DOMAIN!,
  applicationID: "convex",
}
```

If this template or issuer config is wrong, the callback can reach Google successfully but fail before saving tokens to Convex.

## Convex Storage

Table: `users`

Fields:

- `youtubeConnected`
- `youtubeAccessToken`
- `youtubeRefreshToken`
- `youtubeTokenExpiry`

Mutation: `saveYoutubeTokens`

Location: `/home/claude/tubeflow/packages/backend/convex/youtube.ts`

Behavior:

- gets authenticated Clerk user via Convex auth
- finds the `users` row by Clerk ID
- stores access token, refresh token, expiry, and connected flag

## Token Refresh

Action: `refreshYoutubeToken`

Location: `/home/claude/tubeflow/packages/backend/convex/youtube.ts`

Behavior:

- requires authenticated Convex identity
- loads current user's stored YouTube refresh token
- posts to `https://oauth2.googleapis.com/token`
- sends `grant_type=refresh_token`
- updates the stored access token and expiry

Helper: `getValidAccessToken`

Behavior:

- loads user tokens
- throws if YouTube is not connected
- refreshes if token expires within 5 minutes
- returns a valid access token for YouTube Data API calls

## YouTube API Calls

Convex actions call YouTube Data API using the stored Google access token.

Example: `fetchYoutubePlaylists`

- requires authenticated Convex identity
- calls `getValidAccessToken`
- requests `https://www.googleapis.com/youtube/v3/playlists`
- uses `mine=true`
- stores playlist data in Convex cache tables
- logs quota metrics

The frontend reads cached data from Convex queries instead of calling YouTube directly.

## UI Contract

Connection status hook:

- `useYoutubeConnection()`
- reads `api.youtube.getYoutubeConnectionStatus`
- exposes `isConnected`, `isLoading`, `connect`, `disconnect`

When not connected:

- `YouTubeConnectPrompt` checks Clerk signed-in state.
- if not signed in to TubeFlow, it shows Clerk sign-in.
- if signed in, it shows Connect YouTube.

After callback:

- `/playlists?youtube_connected=true` shows success toast.
- `/playlists?youtube_error=...` shows error toast.
- router removes the query param after displaying feedback.

## What Flutter Can Reuse

Flutter should preserve the same backend-owned token lifecycle:

- user authenticates with Clerk
- app obtains a server/Convex-authenticated identity
- YouTube OAuth happens through a web route or browser session
- backend exchanges the Google code for tokens
- backend stores refresh token server-side
- Flutter never stores the YouTube refresh token locally
- Flutter calls Convex/FastAPI app APIs, not YouTube Data API directly

For Flutter web:

- reuse the browser redirect pattern.
- start YouTube OAuth by opening a backend/Next-style route.
- return to a same-origin callback route.
- then refresh app state from Convex/backend.

For native Flutter:

- use a system browser/custom tab, not an embedded webview.
- use platform deep links or an app-domain callback handoff.
- keep code exchange and refresh-token storage on the backend.
- do not put `GOOGLE_CLIENT_SECRET` in the app.

## Common Failure Modes

- `NEXT_PUBLIC_GOOGLE_CLIENT_ID` missing.
- `GOOGLE_CLIENT_SECRET` missing.
- `NEXT_PUBLIC_APP_URL` does not match the actual app domain.
- Google Cloud lacks the exact callback URI.
- `youtube_oauth_state` cookie missing or mismatched.
- `clerk_session_id` cookie missing at callback.
- Clerk `convex` JWT template missing or wrong.
- Convex `CLERK_JWT_ISSUER_DOMAIN` mismatches the Clerk instance.
- Convex URL points to the wrong deployment.
- Google returns no `refresh_token` because consent was not forced or user already granted consent differently.
- Token refresh action lacks Google OAuth credentials in Convex environment.
- YouTube API returns 401/403 because scopes are insufficient or tokens were revoked.
- Callback returns JSON 500 instead of redirecting, which helps debugging but is not ideal final UX.

## Security Notes

- Do not expose `GOOGLE_CLIENT_SECRET` to Flutter or any browser bundle.
- Do not store YouTube refresh tokens in Flutter local storage.
- Do not log Google authorization codes, access tokens, refresh tokens, Convex JWTs, or Clerk session IDs.
- Token storage should remain backend-side and user-scoped.
- All YouTube cache reads and mutations must be scoped by authenticated user.
- If using cookies for OAuth handoff, keep them short-lived and delete them after callback.

## Validation Checklist

1. User is signed in to Clerk.
2. `sessionId` exists before starting YouTube connect.
3. `clerk_session_id` cookie is set before navigating to `/api/auth/youtube`.
4. `/api/auth/youtube` sets `youtube_oauth_state`.
5. Google OAuth URL contains expected `client_id`, `redirect_uri`, `scope`, `access_type=offline`, `prompt=consent`, and `state`.
6. Google Cloud contains the exact callback URI.
7. Callback receives `code` and `state`.
8. Callback state matches cookie.
9. Callback can get Clerk Convex JWT from `sessions.getToken(sessionId, "convex")`.
10. Convex mutation `saveYoutubeTokens` succeeds.
11. User row has `youtubeConnected=true` and both access/refresh tokens.
12. `/playlists?youtube_connected=true` appears, then query param is cleared.
13. `getYoutubeConnectionStatus` returns connected.
14. `fetchYoutubePlaylists` succeeds.
15. Expired access token triggers refresh and updates Convex.

## Open Hardening Opportunities

- Replace client-written `clerk_session_id` cookie with a signed server-side OAuth nonce linked to Clerk identity.
- Encrypt YouTube tokens at rest if Convex/project policy requires it.
- Redirect with user-friendly errors instead of returning JSON 500 in production.
- Use narrower YouTube scopes if full `https://www.googleapis.com/auth/youtube` is not required for all features.
- Add an explicit reconnect flow when refresh token is revoked.
