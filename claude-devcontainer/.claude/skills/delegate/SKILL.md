---
name: delegate
description: Orchestrate features built by executor Claudes, each in its own git worktree and dev container with its own database. Use when the user wants a feature started, a task handed to a feature, an executor's question answered, its work reviewed, or a feature stopped.
---

# Delegate

You are the **orchestrator** on the host. Each feature is a git worktree `../<repo>-<name>` on
branch `<name>`, with its own dev container, its own database in the shared Postgres, and an
**executor**: a Claude in that container that does the work you hand it. You plan, hand out,
answer, review and commit; executors only build. Every action goes through
[`feature.sh`](feature.sh), run from the main checkout as
`.claude/skills/delegate/feature.sh`.

## 1. Start the feature

`feature.sh new <name>`, one per feature: a short branch name, distinct from every other
feature's. Done when it prints the feature's folder and database.

## 2. Hand it a task

`feature.sh ask <name> "<task>"`. The executor knows nothing of this conversation, so the task is
self-contained: the goal, the files or tables involved, and the check that proves it done. Hand
several features their tasks at once by running each `ask` in the background; you are told as
each one returns.

## 3. Read the last line

Every reply ends on one line:

- `QUESTION: …`: the executor stopped for a decision. Answer it when the user's request already
  settles it; otherwise put it to the user. Send the answer with `feature.sh ask <name>
  "<answer>"`, which resumes the same session, and read the next last line.
- `DONE: …`: go to step 4.

## 4. Review on the host

The executor's claim is a lead, not evidence. Read `git -C ../<repo>-<name> status` and `diff`,
and run the feature's checks yourself. Send what falls short back with `ask`, as concretely as a
failing check. Once it holds, commit from the worktree on the host: git does not work inside the
container.

## 5. Stop the feature

`feature.sh stop <name>` when the user is done with it: the dev container goes down and the
worktree is removed; the branch and the database stay. `git worktree remove` refuses a worktree
with uncommitted changes; commit them or ask the user. `feature.sh list` shows the features and
their sessions.

## Executors

- They run with prompts off (`--dangerously-skip-permissions`), as `vscode` in the container.
  Nothing limits their network, and they connect to Postgres as its superuser, so an executor
  can reach the other features' databases: hand each one only its own feature.
- They share one Claude sign-in and, because every worktree mounts at the same path inside,
  one project history and memory. Each feature's session id, kept by `feature.sh`, keeps the
  conversations apart.
