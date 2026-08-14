---
name: pr-rewrite
description: Rewrite an existing GitHub pull request's title and description from the current diff, like /pr but applied to an existing PR
---

# GitHub Pull Request Rewrite Skill

Same as the `pr` skill, but instead of creating a new PR, fully rewrites the title and body of the PR already open for the current branch.

This is a full rewrite (not an enhancement). For incremental enhancement of an existing description, use `pr-enhance` instead.

## Workflow

Follow the `pr` skill, with these changes:

### 1. Determine Base Branch

Fetch the existing PR to source the base branch:

```bash
gh pr view --json number,url,title,body,baseRefName,headRefName
```

If no PR exists for the current branch, inform the user and stop. Use `baseRefName` from the PR as the base branch — do not ask the user to choose.

### 2–6. Unchanged

Verify changes, gather issue context, discover templates, generate title and body, and write the draft to `NOTES_PR.md` exactly as in `pr`.

### 7. Update the Pull Request

Instead of `gh pr create`, use `gh pr edit` to overwrite the title and body:

```bash
gh pr edit \
  --title "{title}" \
  --body "{full_body}"
```

### 8. Report Result

Output the updated PR URL.
