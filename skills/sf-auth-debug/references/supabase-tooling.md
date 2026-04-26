# Supabase Tooling Reference

Use this reference when the bug touches Supabase project state, database/auth debugging, local stack behavior, or Supabase-assisted agent workflows.

Sources checked:
- https://supabase.com/docs/guides/getting-started/mcp
- https://supabase.com/docs/guides/local-development/cli/getting-started
- https://supabase.com/docs/reference/cli/supabase-db-dump

Last reviewed: 2026-04-26

## Standard ShipFlow Setup

- Supabase MCP endpoint: `https://mcp.supabase.com/mcp`
- Codex config requires remote MCP support; ShipFlow enables `rmcp = true` in `~/.codex/config.toml`
- Supabase CLI install in ShipFlow: standalone binary, not `npm install -g supabase`
- Local Supabase CLI MCP endpoint: `http://127.0.0.1:54321/mcp` after `supabase start`

## Use Supabase MCP When

- The agent needs project-aware access to tables, migrations, SQL, logs, advisors, edge functions, or docs.
- You want schema-aware help without manually copying dashboard state.
- The issue may depend on Supabase platform state rather than only app code.

Typical MCP use cases:

- inspect tables or migrations
- inspect auth, database, or edge-function logs
- run targeted SQL in a development environment
- generate types from schema context
- inspect project metadata and docs

## Use Supabase CLI When

- You need to operate the local Supabase stack.
- You need to link a repo to a real Supabase project.
- You need migration sync, schema pull/push, or type generation in a terminal workflow.

Primary commands:

- `supabase login`
- `supabase init`
- `supabase start`
- `supabase status`
- `supabase link`
- `supabase db pull`
- `supabase db push`
- `supabase migration list`
- `supabase gen types`

## Use Playwright Or Browser Evidence When

- The bug is in the real browser auth flow: OAuth redirects, callback routes, cookies, SSR session refresh, or post-login navigation.
- You need proof of where the browser flow breaks.
- Supabase Auth appears correct in config, but the app still loops, drops session state, or fails after callback.
- For the concrete testing playbook, load `references/supabase-testing.md`.

## Security And Scope Rules

- Prefer development or staging projects, not production.
- If production data must be touched, prefer `read_only=true`.
- Scope the MCP to a single project with `project_ref=...` when possible.
- Review SQL/tool calls before approving them.

## Do Not Use Supabase MCP For

- Proving browser cookie behavior on its own.
- Replacing SSR cookie inspection, middleware analysis, or callback-route debugging.
- Treating a successful MCP query as proof that the browser session is healthy.

## Default Debug Policy

1. Use Supabase MCP when the issue may depend on schema, logs, advisors, SQL, or project state.
2. Use Supabase CLI when the operator needs local stack control, linking, migrations, or generated types.
3. Use Playwright/browser evidence when the failure is in the actual auth/session flow seen by the user.
