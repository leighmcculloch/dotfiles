---
name: impl-random
description: Pick a random small unassigned GitHub issue from a locally checked-out repo, implement it with an agent team, code-review and iterate until clean, then Slack DM the PR. Use when asked to "find an issue and fix it", "tackle an issue", "pick up an issue", or run autonomously on whatever's open.
---

# Tackle an Issue

Autonomously find, implement, and ship a fix for an open GitHub issue end to end.

## Workflow

### 1. Pick a repo

Scan the directory where repos are checked out on this instance (the workspace
root containing the cloned GitHub repos) for git repositories with GitHub
remotes. Pick one.

### 2. Pick an issue

List open, **unassigned** issues for that repo:

```
gh issue list --repo <owner>/<repo> --state open --search "no:assignee" --limit 100
```

From the candidates, pick a **random** issue, but **favour small, narrow,
isolated, easy-to-review changes**. Skip issues that are:

- Large, vague, or open-ended (epics, "discussions", design questions).
- Blocked, awaiting decision, or with unresolved disagreement in the thread.
- Already linked to an open PR.

If a repo has no suitable issue, pick a different repo. Read the full issue and
its comments before starting so you understand the actual requirement.

### 3. Create a branch

Name the branch with the [branch](../branch/SKILL.md) skill.

### 4. Implement

Run `/impl` with the issue as the argument to implement it with an agent team.
Make sure the implementation meets **all** the requirements stated in the issue.

### 5. Code review

Run `/code-review` on the change with an agent team.

### 6. Loop until clean

Run `/loop` to iterate: address every concern raised, then re-review. **Only
stop when both**:

- `/code-review` finds no new issues, AND
- the implementation meets all requirements of the GitHub issue.

### 7. Open the PR

Create the PR with the `/pr` skill. Reference the issue (e.g. `Closes #<n>`).

### 8. Slack DM

Send a **self DM** in Slack with a link to the PR and a brief summary: which
issue it addresses, what changed, and that review passed clean.

## Rules

- One issue per run. Don't batch.
- Never pick an assigned issue or one that already has an open PR.
- If no suitable issue exists across the repos, stop and say so — don't force a
  low-quality pick.
- Name the branch with the [branch](../branch/SKILL.md) skill; commits are
  handled by `/impl` per the [commit](../commit/SKILL.md) skill.
