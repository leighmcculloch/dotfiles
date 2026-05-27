---
name: issue
description: Create GitHub issues with context from linked issues/PRs
---

# GitHub Issue Creation Skill

**Formatting rules:**
- Do not hard-wrap lines. Write paragraphs as a single continuous line; let the renderer wrap.
- Minimal formatting. The only headings are `### What` and `### Why`. No bullet lists, no tables, no diagrams.

## Workflow

### 1. Gather Context from Linked Issues/PRs

If the user provides GitHub issue or PR links:
- Use `mcp__github__issue_read` with `method: "get"` to fetch issue details
- Use `mcp__github__pull_request_read` with `method: "get"` to fetch PR details
- Review the linked content and incorporate relevant context into the new issue

### 2. Generate Issue Content

**Title:**
- Concise, capitalized, no trailing period.
- Imperative mood for proposals (Add, Fix, Update); descriptive for bugs.

**What section:**
- A single focused paragraph naming the problem or proposal. Not a list.
- Write as one continuous line. Do not insert line breaks to wrap at any column width.

**Why section:**
- A single focused paragraph. Not a list.
- Write as one continuous line. Do not insert line breaks to wrap at any column width.
- Name the specific problem, behavior, or constraint motivating this — not generic justifications.
- If linked to other issues/PRs, echo the concrete reasoning.

### 3. Draft and Review (REQUIRED)

**IMPORTANT: Always write the draft to a file and present it to the user for review before creating the issue.**

**Step 1: Write the draft to NOTES_ISSUE.md**

Write the complete draft issue to `NOTES_ISSUE.md` in the current working directory. Write the What and Why paragraphs as single unwrapped lines:

```markdown
# Draft Issue

**Repository:** {owner}/{repo}
**Title:** {title}

### What
{what}

### Why
{why}
```

**Step 2: Present for review**

After writing the file, inform the user:
```
I've written the draft issue to NOTES_ISSUE.md for your review.

Would you like me to create this issue, or would you like to make any changes?
```

Wait for explicit user confirmation before proceeding. If the user requests modifications, update `NOTES_ISSUE.md` with the changes before creating the issue.

### 4. Create the Issue

Only after user confirmation, use `mcp__github__issue_write` with:
```
method: "create"
owner: {repo_owner}
repo: {repo_name}
title: {issue_title}
body: {issue_body}
```

The body should include:
- `### What` section
- `### Why` section

Pass the What and Why paragraphs to `body` as single unwrapped lines.
