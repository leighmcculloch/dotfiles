---
name: review
description: Code review using GitHub Copilot with multiple AI models concurrently
---

# Code Review Skill

Performs code reviews using GitHub Copilot CLI with multiple models running concurrently.

## Models

Run ALL three models concurrently:
- `claude-opus-4.5`
- `gpt-5.1-codex-max`
- `gemini-3-pro-preview`

## Workflow

### 1. Determine What to Review

Based on user request:

| User Says | Action |
|-----------|--------|
| "review this PR" / "review PR #123" | Get PR diff with `gh pr diff` |
| "review my changes" / "review staged" | Get staged diff with `git diff --staged` |
| "review <file>" | Read the specific file(s) |
| No specific request | Ask user what to review |

### 2. Get the Diff/Content

For staged changes:
```bash
git diff --staged
```

For PR (current branch):
```bash
gh pr diff
```

For specific PR:
```bash
gh pr diff <number>
```

### 3. Run Copilot Reviews Concurrently

Launch ALL THREE models in parallel using background processes:

```bash
# Create unique directory for this review session
workdir=$(mktemp -d /tmp/claude/review-XXXXXX)

diff=$(git diff --staged)
prompt="You are a senior code reviewer. Review the following git diff for:
- Code quality issues
- Potential bugs
- Security concerns
- Suggestions for improvement

Be concise and actionable. If the code looks good, say so briefly.

Diff:
$diff"

# Run all three concurrently
copilot --model "claude-opus-4.5" --stream on -p "$prompt" > "$workdir/opus.txt" 2>&1 &
copilot --model "gpt-5.1-codex-max" --stream on -p "$prompt" > "$workdir/codex.txt" 2>&1 &
copilot --model "gemini-3-pro-preview" --stream on -p "$prompt" > "$workdir/gemini.txt" 2>&1 &
wait

echo "=== claude-opus-4.5 ===" && cat "$workdir/opus.txt"
echo "=== gpt-5.1-codex-max ===" && cat "$workdir/codex.txt"
echo "=== gemini-3-pro-preview ===" && cat "$workdir/gemini.txt"

# Cleanup
rm -rf "$workdir"
```

### 4. Present Reviews

Show all three review outputs to the user, labeled by model.

### 5. Synthesize (Optional)

If useful, summarize the common themes across all three reviews.

### 6. PR Comments (Optional)

If reviewing a PR and user wants to leave comments:

```bash
gh pr review <number> --comment --body "<comment>"
```

Or for line-specific comments:
```bash
gh api repos/{owner}/{repo}/pulls/{pr}/comments \
  --method POST \
  -f body="<comment>" \
  -f commit_id="<sha>" \
  -f path="<file>" \
  -f line=<line>
```

Ask user before posting any comments.
