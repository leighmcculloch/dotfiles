---
name: branch
description: Create or rename a git branch with a concise kebab-case name describing the pending changes
---

# Git Branch Skill

Name a branch:

- concisely
- kebab-case
- describe the changes
- max 5 words
- never use `/`
- never add a prefix (e.g. no `claude/`, no `feature/`)

Choose the action based on the current branch:

- On `main` or `master`: create a new branch with `git switch -c <name>`.
- On any other branch: rename it in place with `git branch -m <name>`. If the current branch name is prefixed (e.g. `claude/fix-thing`), drop the prefix and its `/` when choosing the new name.

When renaming, if the branch has an upstream:

1. Capture upstream before renaming: `git rev-parse --abbrev-ref --symbolic-full-name @{upstream}` (e.g. `origin/old-name`).
2. Rename locally: `git branch -m <new-name>`.
3. Push the new branch: `git push -u <remote> <new-name>`.
4. Delete the old upstream: `git push <remote> --delete <old-name>`. If this fails, ignore the failure and move on.
