# sf-verify

> Check whether work is actually ready to ship by testing it against the user story, the contract, and the obvious risks.

## What It Does

`sf-verify` performs a pre-ship verification pass that goes beyond lint and tests. It checks whether the promised user outcome is really delivered, whether success and error behavior are observable, whether the implementation matches the spec or task contract, and whether linked systems, docs, dependencies, or risks were overlooked.

It complements technical checks with product, documentation, and security-minded validation.

## Who It's For

- Solo founders who need an honest “ready or not?” pass
- Developers shipping features that touch users, data, or permissions
- Teams that want more than a green test run before pushing

## When To Use It

- when a task feels finished and you want a ship-readiness verdict
- when a feature changed user-facing behavior or error handling
- when a spec exists and you want to verify the build against the contract
- when auth, payments, data, docs, or dependencies may be involved
- when protected routes or browser auth flows need real evidence before you call the work done

## What You Give It

- a repo with recent changes
- optionally a specific task or scope to verify
- ideally a ready spec or clear task description

## What You Get Back

- a structured verification report
- findings across user story, completeness, correctness, coherence, dependencies, and risk
- focused technical checks where practical
- explicit warnings when behavior is only partially demonstrated
- guidance on what to fix before shipping
- a push toward `sf-auth-debug` when auth behavior was not proven in a real browser

## Typical Examples

```bash
/sf-verify
/sf-verify invite flow
/sf-verify billing webhook retry handling
```

## Limits

`sf-verify` is not a full audit and it is not purely technical. It can correct stable code in some cases, but its main job is to judge evidence honestly. If the contract is weak or validation is missing, the result should stay uncertain rather than pretending the work is safe.

## Related Skills

- `sf-check` for broader technical validation
- `sf-auth-debug` when ship-readiness depends on a real Clerk, OAuth, or session-flow confirmation
- `sf-spec` and `sf-ready` to strengthen the contract before implementation
- `sf-ship` once verification is good enough to push
