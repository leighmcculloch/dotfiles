---
allowed-tools: Bash(claude --remote *)
description: Run a prompt remotely with claude --remote
---

Run the following command and return the output to the user:

```
claude --remote "$(cat <<'PROMPT'
$ARGUMENTS
PROMPT
)"
```
