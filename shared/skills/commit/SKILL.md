---
name: commit
description: Commit to Git.
model: haiku
---

# Git Commit

If the conversation already establishes what changed (recent edits, prior diff output, explicit user description), skip `git status`/`git diff`/`git log` and commit from that context. Only run those commands when the changes are genuinely unknown to you.

Suggest a concise commit message in present tense, imperative mood, describing what changed (not why), max 50 characters.

Do not use conventional commit format. Start with a lower case letter and do not end with a full stop. Avoid generic phrases.

Never add a `Co-Authored-By: Claude...` or a `Claude-Session: ` line to the commit.

Use command:

```
git commit -m "<message>"
```
