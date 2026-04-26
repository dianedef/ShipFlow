# sf-resume

> Summarize the current thread fast so you know what was done, what remains, and whether you can close the conversation safely.

## What It Does

`sf-resume` gives a compact summary of the current conversation only. It lists the main completed, in-progress, or planned items, notes any commits made in the conversation when they are visible, then tells you whether the thread can be closed or whether something important would be lost.

For solo founders working across many chats, this is the lightweight memory aid that prevents loose ends from disappearing.

## Who It's For

- Founders juggling multiple parallel threads
- Developers returning to a conversation after context switching
- Anyone who wants a quick closure check before ending a session

## When To Use It

- at the end of a work session
- when you are unsure what this thread actually accomplished
- before closing a chat and moving to a fresh one

## What You Give It

- the current conversation thread
- optionally, a shorter mode such as `court` or `ultra-court`

## What You Get Back

- a short bullet summary
- a short commits section, either `Aucun commit effectué dans cette conversation.` or short hashes with 2-3 descriptive words
- a closure verdict
- one “do not forget” item if something important remains

## Typical Examples

```bash
/sf-resume
/sf-resume court
/sf-resume ultra-court
```

## Limits

- It only uses the visible thread, not external files or repo state.
- It does not inspect Git history; commit information is reported only when visible in the conversation.
- It is a memory snapshot, not a verification pass.
- If the thread itself is ambiguous, the summary will reflect that uncertainty.

## Related Skills

- `sf-start` to continue work in a fresh thread
- `sf-priorities` if the summary shows too many competing next steps
- `sf-ready` or `sf-verify` when the missing item is execution-critical
