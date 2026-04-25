---
artifact: documentation
metadata_schema_version: "1.0"
artifact_version: "0.1.0"
project: "[project name]"
created: "YYYY-MM-DD"
updated: "YYYY-MM-DD"
status: draft
source_skill: "[manual|sf-docs|sf-init]"
scope: "context"
owner: "[user or team]"
confidence: "medium"
risk_level: "medium"
security_impact: "none"
docs_impact: "yes"
linked_systems: []
depends_on: []
supersedes: []
evidence: []
next_step: "/sf-docs update CONTEXT.md"
---

# CONTEXT

## Purpose

[Explain what this file is for. Keep it short. This file should accelerate orientation, not duplicate the whole codebase.]

## What The Project Is

- [One sentence on the product/system.]
- [Optional second sentence on runtime model or deployment shape.]

## Entry Points

- `[main entrypoint file]`: [why it matters]
- `[secondary entrypoint]`: [why it matters]
- `[operator or local tool entrypoint]`: [why it matters]

## Repo Map

- `[top-level path]`: [role]
- `[top-level path]`: [role]
- `[top-level path]`: [role]

## Core Flows

### 1. [Primary Flow]

```text
[entry]
  -> [step]
  -> [step]
  -> [result]
```

### 2. [Secondary Flow]

```text
[entry]
  -> [step]
  -> [step]
  -> [result]
```

## Technical Decisions

- [Important decision and why it exists]
- [Important dependency and why it is used]
- [Important storage/runtime/networking choice]

## Invariants

- [Rule that must remain true]
- [Rule that must remain true]
- [Failure mode that must be avoided]

## Hotspots

- `[file::function or module]`: [why it is risky or central]
- `[file::function or module]`: [why it is risky or central]

## Where To Edit What

- [Kind of change] -> `[files to read first]`
- [Kind of change] -> `[files to read first]`
- [Kind of change] -> `[files to read first]`

## Read First By Task

- [Task category] -> `[docs/files]`
- [Task category] -> `[docs/files]`
- [Task category] -> `[docs/files]`

## Linked Docs

- `[AGENT.md or CLAUDE.md]`
- `[README.md]`
- `[architecture or function tree doc]`
- `[business/guidelines/spec docs]`

## Maintenance Rule

Update this file when:

- [entry points changed]
- [major flow changed]
- [important invariant changed]
- [official context docs changed]
