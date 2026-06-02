---
name: branch
description: Create a git branch with a concise kebab-case name describing the pending changes
---

# Git Branch Skill

Creates a new git branch with a concise, kebab-case name that describes the current changes, derived from the pending diff and the conversation context.

## Branch Name Rules

- Concise, kebab-case, describing the changes (max 5 words).
- Lowercase only.
- The name must not collide with any existing local or remote branch.

## Workflow

### 1. Determine the Diff Source

Identify what changes the branch name should describe, in this priority order:

1. **On the default branch with commits ahead of upstream** — the goal is to move those commits onto a new branch. Use `@{upstream}..HEAD`.
2. **Staged changes exist** — use `--staged`.
3. **Unstaged changes exist** — use `HEAD`.

```bash
current_branch="$(git rev-parse --abbrev-ref HEAD)"
default_branch="$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name)"
```

Capture the diff for the chosen source (truncate to ~10000 chars if very large). If there are no changes and no conversation context to go on, stop and say so.

### 2. Gather Existing Branch Names

```bash
git branch --all --format='%(refname:short)'
```

The generated name must not be any of these.

### 3. Generate the Branch Name

Generate a name following this prompt:

> You are a senior software engineer.
>
> Suggest a concise, kebab-case branch name that describes the changes (max 5 words).
>
> Reply only with the branch name, nothing else.
>
> Do not use any of these names: {existing branches}.
>
> Original user request: {first user request in the conversation}
>
> Latest user request: {most recent user request}
>
> Diff: {diff}

Use the original and latest user requests from the conversation plus the diff as the basis for the name.

### 4. Ensure Uniqueness

If the name already exists as a branch, append a numeric suffix and bump it until free:

```bash
candidate="$name"; i=2
while git show-ref --verify --quiet "refs/heads/$candidate"; do
  candidate="${name}-${i}"; ((i++))
done
name="$candidate"
```

### 5. Create the Branch

Preserve the current upstream so the new branch tracks the same remote:

```bash
previous_upstream="$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || true)"
```

**If on the default branch with commits ahead of upstream** — move the commits to the new branch and rewind the default branch:

```bash
git branch --no-track "$name"      # new branch at current HEAD (includes the commits)
git reset --hard @{upstream}       # rewind default branch to match upstream
git checkout "$name"
```

**Otherwise** — create and switch in place:

```bash
git checkout -b "$name" --no-track
```

Then restore tracking if there was an upstream:

```bash
[ -n "$previous_upstream" ] && git branch --set-upstream-to="$previous_upstream" "$name"
```
