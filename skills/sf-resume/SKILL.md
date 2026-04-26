---
name: sf-resume
description: SF résume / SF resume — summarize the current conversation thread very quickly in 3 to 5 concise bullets, list task statuses, and say whether the user can safely close the conversation or what important context might be lost.
disable-model-invocation: false
argument-hint: [optional: court | ultra-court]
---

# SF Résume

## Goal

Give the user a fast closure snapshot of the current conversation only.

This skill is for users who feel lost across many chats and need to know:
- what was done in this thread
- what is still planned or in progress
- whether some tasks mentioned earlier were quietly dropped, forgotten, or left implicit
- whether they can close the conversation
- what important context, idea, risk, next step, or product angle would be lost if they close it now

## Speed Rules

- Do not browse.
- Do not run commands.
- Do not inspect files.
- Do not spawn agents.
- Do not reconstruct every detail.
- Use only the visible conversation context.
- Prefer an approximate but useful answer over a slow exhaustive answer.

Target response time: immediate.

## Output Format

Always answer in French unless the user asks otherwise.

Keep the whole answer concise:
- 3 to 5 bullet points maximum for tasks
- one short commits section
- one short closure status line
- one short "À ne pas oublier" line

Use this structure:

```markdown
**Résumé du thread**
- [Terminé|En cours|Planifié] Tâche courte accomplie ou prévue.
- [Terminé|En cours|Planifié] Tâche courte accomplie ou prévue.
- [Terminé|En cours|Planifié] Tâche courte accomplie ou prévue.

**Commits effectués**
- Aucun commit effectué dans cette conversation.

**Statut**: Tu peux fermer / Garde ouvert / À vérifier avant de fermer.

**À ne pas oublier**: précise s'il reste un écart entre les tâches évoquées et les tâches réellement menées à terme, s'il y a un oubli concret probable, ou s'il existe une piste produit intéressante à creuser ensuite.
```

## Status Labels

Use only these labels in task bullets:
- `Terminé`: the task was actually completed in the conversation.
- `En cours`: work started but was not completed or not verified.
- `Planifié`: discussed or decided, but not started.

## Closure Verdict

Use:
- `Tu peux fermer` when all meaningful tasks are completed and no important unresolved action remains.
- `Garde ouvert` when work is actively incomplete, blocked, or depends on the current context.
- `À vérifier avant de fermer` when most work is done but there is a missing confirmation, test, commit, deployment, decision, or follow-up.

## Commits

Always include the `Commits effectués` section in the final summary.

Use only commits that are explicitly visible in the current conversation context. Do not run Git commands, inspect files, or infer commits from completed work.

If no commit is visible, write exactly:

```markdown
**Commits effectués**
- Aucun commit effectué dans cette conversation.
```

If one or more commits were made in the conversation, list only the short commit hash and 2 to 3 descriptive words:

```markdown
**Commits effectués**
- `a1b2c3d` Résumé bref
- `e4f5g6h` Fix tests
```

Do not include commit messages in full, branch names, authors, dates, or long explanations.

## What Counts as "À ne pas oublier"

Use this line as a compact coverage check of the thread, not just as a generic reminder.

It must answer, as directly as possible:
- did we actually finish the tasks we said we would do in this conversation
- is there a concrete discussed item that seems easy to forget
- is there a promising product or strategy angle mentioned in passing that deserves later follow-up

Prioritize in this order:
- a mismatch between discussed tasks and completed tasks
- a concrete forgotten follow-up, verification, decision, or deliverable
- a high-value idea or product angle worth capturing for later
- if none of the above exists, explicitly say that nothing important seems missing

When relevant, name the gap plainly:
- `On a parlé de X mais ce n'est pas fait.`
- `Y a été commencé mais pas confirmé.`
- `Aucun oubli concret repéré dans ce thread.`
- `Piste à creuser plus tard: Z.`

Do not invent hidden work. If the thread only shows discussion, mark it as not completed.
Do not claim "rien à signaler" unless the thread actually looks closed and coherent.

If there is nothing meaningful, say:

```markdown
**À ne pas oublier**: Rien de critique identifié dans ce thread.
```

## Style

- Be direct.
- No long explanations.
- No generic recap.
- No more than 5 task bullets.
- If the thread has more than 5 tasks, merge related items and keep only the most important.
- The "À ne pas oublier" line should be concrete, slightly adversarial, and optimized to catch omission rather than to sound polite.
- If evidence is unclear, mark the item `À vérifier avant de fermer` in the status line rather than overstating completion.
