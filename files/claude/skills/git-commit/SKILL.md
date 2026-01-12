---
name: git-commit
description: Commit to Git.
---

# Git Commit

Given the git diff, suggest a concise commit message that says in present tense with imperative mood what has changed without saying why (max 50 characters).

Do not use conventional commit format. Start the commit message with a lower case letter and do not end with a full stop. Avoid generic phrases.

## Specific Files

Use `ga <file> [file]...` to add a file.

Use `gcy` to create the commit.

## All Files

Use `gaacy` to add all files and create the commit.
