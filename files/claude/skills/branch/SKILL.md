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
