# sf-prod

> Check whether production is actually healthy after a push, not just whether one URL returned `200`.

## What It Does

`sf-prod` verifies the latest deployment by combining deploy status, live URL checks, and build-log access when something failed. It is intentionally skeptical: a green homepage alone is not treated as proof that the shipped feature works.

For a solo founder, this is the post-deploy confidence pass that catches “looks live, still broken” situations before users do.

## Who It's For

- Founders deploying their own apps
- Developers using Vercel, Netlify, or GitHub-based deployment flows
- Teams that want a repeatable production check after shipping

## When To Use It

- right after a push or deploy
- when a deployment is pending longer than expected
- when production might be green at the platform level but risky at the product level

## What You Give It

- the current repo, project name, or production URL
- optionally, enough project context to identify the expected live domain

## What You Get Back

- deploy-status confirmation or failure signal
- health-check results on the live URL
- log access or a dashboard link when the build failed
- a short risk statement about what remains unverified
- a clear reminder when auth or protected flows still need `sf-auth-debug`

## Typical Examples

```bash
/sf-prod
/sf-prod my-project
/sf-prod https://app.example.com
```

## Limits

- It cannot prove every critical flow unless those flows are explicitly checked.
- Auth, payments, webhooks, and background jobs may still need targeted verification.
- Rollback decisions remain human-approved.

## Related Skills

- `sf-check` before pushing
- `sf-ship` to send the change
- `sf-auth-debug` when production doubts are really about login, callbacks, redirects, or private app flows
- `sf-research` or `sf-fix` if the failure needs investigation
