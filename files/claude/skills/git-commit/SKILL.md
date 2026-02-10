---
name: git-commit
description: Commit to Git.
---

# Git Commit

Given the git diff, suggest a concise commit message that says in present tense with imperative mood what has changed without saying why (max 50 characters).

Do not use conventional commit format. Start the commit message with a lower case letter and do not end with a full stop. Avoid generic phrases.

Check the environment variable `CLAUDE_SESSION_ID`. If it is set, append a git trailer `Agent-Session-Id` with its value. Use command:

```
git commit -m "$(cat <<'EOF' | git interpret-trailers --trailer "Agent-Session-Id: $CLAUDE_SESSION_ID"
<message>
EOF
)"
```

If `CLAUDE_SESSION_ID` is not set, use command:

```
git commit -m "<message>"
```
