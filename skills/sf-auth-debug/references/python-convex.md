# Python + Convex Auth Debug Reference

Use this reference when Python scripts, jobs, CLIs, importers, or automation call Convex.

Sources checked:
- https://docs.convex.dev/client/python
- https://docs.convex.dev/quickstart/python
- https://pypi.org/project/convex/
- https://docs.convex.dev/database/types

Last reviewed: 2026-04-26

## Ideal Flow

1. Convex backend functions remain TypeScript files under `convex/`.
2. Python uses the official `convex` Python client to call queries, mutations, or actions.
3. `.env` or secret manager provides the Convex deployment URL and any required auth token.
4. Python serializes arguments to Convex-supported values.
5. Convex functions enforce auth/authorization server-side.
6. Python handles errors and retries without duplicating business rules.

## Files And Config To Inspect

- Python script/job entrypoint
- `requirements.txt`, `pyproject.toml`, or lock file
- `.env` / Doppler / hosting secrets
- `convex/` functions called by the script
- function validators and return types
- auth token acquisition and `Authorization` header or client auth setup

## SDK Status

- Convex docs point Python users to the Python quickstart and the `convex` PyPI package.
- The Python quickstart installs both npm `convex` for backend function development and Python `convex` plus `python-dotenv` for scripts.
- Latest PyPI version observed during review: `convex 0.7.0`.

## Type And Data Checks

- Convex backend functions run as JavaScript/TypeScript, even when called from Python.
- Python `None` maps to Convex `null`.
- Python `str`, `bool`, `list`, `dict`, and `bytes` map to corresponding Convex-supported values.
- Python `int`/`float` conversion can matter. Use the package's `ConvexInt64` when a JavaScript `bigint`/Convex Int64 is required.
- Do not send Python-specific objects, datetimes, decimals, or custom classes without explicit serialization.

## Auth Checks

- Confirm the Python job is allowed to call the target Convex function.
- Prefer service/job credentials or a documented server-side auth path over user session reuse.
- Do not paste Clerk browser cookies into Python jobs as an auth mechanism.
- If Python impersonates a user, require a spec-level security decision and clear audit trail.
- Convex functions should still validate identity and authorization using server-side logic.

## Common Failure Modes

- Python script points to the wrong Convex deployment URL.
- `.env` loaded locally but missing in CI/production.
- Script calls a protected function without a valid token.
- Function name/path changed but script still calls the old API.
- Python sends values that do not match Convex validators.
- Int64/bigint values are silently wrong because plain Python numbers were used.
- Import jobs bypass app invariants by writing through overly broad mutations.
- Logs print secrets, tokens, or user data.

## Debug Checklist

- Confirm package version and whether the script uses the official `convex` client.
- Confirm deployment URL and environment.
- Confirm the exact Convex function path being called.
- Confirm Python argument values match Convex validators.
- Confirm auth token source and expiry.
- Check Convex logs for identity and validator errors.
- For import/backfill scripts, test against a small fixture before touching production data.
- Redact tokens and payloads before sharing logs.
