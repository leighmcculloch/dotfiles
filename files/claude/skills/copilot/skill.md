---
name: copilot
description: Run a task using GitHub Copilot CLI as an agent
---

# Copilot Skill

Runs GitHub Copilot CLI with `-p` flag to execute a task as an agent.

## Usage

Pass the user's task to copilot-cli:

```bash
copilot -p "<task>"
```

## Options

- Use `--model <model>` with one of: `claude-opus-4.5`, `gpt-5.1-codex-max`, `gemini-3-pro-preview`
- Use `--stream on` for streaming output

## Example

```bash
copilot --stream on -p "explain what this repository does"
```

## Workflow

1. Take the user's request
2. Run copilot with the `-p` flag and the user's task as the prompt
3. Display the output to the user
