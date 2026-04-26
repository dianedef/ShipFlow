# sf-start

> Start a task by actually implementing it, while forcing spec-first discipline when the scope is too risky to wing.

## What It Does

`sf-start` is the execution entrypoint for ShipFlow work. It decides whether a task is small enough to implement directly or whether it needs a ready spec first. Once the contract is clear, it reads only the necessary code, makes the change, runs focused validation, and reports what was done.

The skill is designed to preserve the promised user outcome, not just complete a technical diff.

## Who It's For

- Solo founders who want one command to begin real work
- Developers moving from task selection to implementation
- Teams that want guardrails without adding ceremony to simple changes

## When To Use It

- when you want to begin a task and expect code changes now
- when a tracker item should become implementation work
- when you want automatic routing between direct execution and spec-first flow
- when implementation depends on reproducing a broken auth or protected browser flow before fixing it

## What You Give It

- a task description or a selected `TASKS.md` item
- the current repo context
- optionally a ready spec if the work is non-trivial

## What You Get Back

- implemented code changes for the scoped task
- task tracking moved to in-progress
- focused validation results tied to the user story
- a concise execution report with files changed, checks run, and documentation impact
- or a reroute to `sf-spec` and `sf-ready` if the contract is not strong enough
- when needed, an explicit diagnostic pass through `sf-auth-debug` before or during the implementation

## Typical Examples

```bash
/sf-start fix session timeout banner
/sf-start add project export endpoint
/sf-start
```

## Limits

`sf-start` is not meant to improvise through high-ambiguity work. If permissions, data boundaries, money movement, destructive actions, or external side effects are unclear, it should stop and require a better contract instead of coding a guess.

## Related Skills

- `sf-spec` to define non-trivial work
- `sf-ready` to validate the spec contract
- `sf-auth-debug` when the task depends on reproducing a Clerk, OAuth, or browser-session failure
- `sf-verify` to judge whether the finished work is ready to ship
- `sf-ship` once the implementation is ready to commit and push
