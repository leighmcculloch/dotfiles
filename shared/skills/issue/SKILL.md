---
name: issue
description: Drafts GitHub issues with context from linked issues/PRs, provides a prefilled URL for review by default, and creates one only after an explicit user request.
---

# GitHub Issue Creation Skill

Drafts GitHub issues for the user to review. The default handoff is a prefilled GitHub URL that the user can open and submit themselves; do not create the issue unless the user explicitly asks you to create or submit it.

**Formatting rules:**
- Do not hard-wrap lines. Write paragraphs as a single continuous line; let the renderer wrap.
- Minimal formatting. No diagrams. No bullet lists — write prose paragraphs, even when filling in template sections. If a template literally provides a checklist (e.g. `- [ ] Tested`), keep that as-is; do not invent prose bullets of your own.
- When a template section poses several questions or prompts, answer each one in its own paragraph (in the order asked), separated by blank lines, rather than collapsing them into a single block. This keeps each section easy for a human to scan.
- Describe the problem, not the solution. Never prescribe a fix or state what the solution is with certainty. If you mention a possible approach, weaken it with tentative language (e.g. "one option might be", "perhaps", "could") so it reads as a suggestion to consider, not a decision already made.

## Workflow

### 1. Determine the Target Repository

Inspect the repository remotes, especially `upstream` and `origin`, and GitHub fork metadata when needed. If the current checkout is a fork with an upstream repository, set `{repo_owner}` and `{repo_name}` to the upstream repository and use those values for all issue work: template discovery, the draft's repository field, the prefilled URL, and direct issue creation. Never prepare or create the issue on the fork. If there is no fork/upstream relationship, use the current repository. If the target is ambiguous, ask the user before proceeding.

### 2. Gather Context from Linked Issues/PRs

If the user provides GitHub issue or PR links:
- Use `mcp__github__issue_read` with `method: "get"` to fetch issue details
- Use `mcp__github__pull_request_read` with `method: "get"` to fetch PR details
- Review the linked content and incorporate relevant context into the new issue

### 3. Discover Issue Templates

**Step 1: Find issue templates**
Do steps 1a and 1b in parallel:

**Step 1a: Check target repository**
Use `mcp__github__get_file_contents` to check for templates:
```
owner: {repo_owner}
repo: {repo_name}
path: .github/ISSUE_TEMPLATE/
```

**Step 1b: Check org's .github repository**
Query GitHub's public HTTP endpoints, not the GitHub API. List the templates by fetching the public repo tree page with WebFetch:
```
https://github.com/{repo_owner}/.github/tree/HEAD/.github/ISSUE_TEMPLATE
```
Read a template's contents from the raw endpoint with `curl -fsSL` (a 404 means it doesn't exist):
```
https://raw.githubusercontent.com/{repo_owner}/.github/HEAD/.github/ISSUE_TEMPLATE/{template_file}
```

**Step 2: Make list of issue templates to choose from**
Make a list of issue templates to choose from:
- Use the results from Step 1a if available.
- Otherwise use the results from Step 1b.

**Step 3: Select appropriate template from the list**
Analyze the user's request and auto-select the most appropriate template:
- Bug reports: templates containing "bug" in name
- Feature requests: templates containing "feature" or "request" or "proposal" or "rfc"

If multiple templates exist and the best match is unclear, briefly list options and ask the user.

### 4. Draft and Provide a Prefilled URL (REQUIRED)

**IMPORTANT: Always write the draft to a file and present it to the user together with a prefilled URL. The default is to let the user open and submit that URL themselves; do not create the issue merely because the user approved the draft.**

**Step 1: Write the draft to NOTES_ISSUE.md**

Write the complete draft issue to `NOTES_ISSUE.md` in the current working directory:

```markdown
# Draft Issue

**Repository:** {repo_owner}/{repo_name}
**Title:** {title}
**Labels:** {labels}

---

{full issue body}
```

**Step 2: Build the prefilled issue URL**

Build a URL for the new issue form:

```
https://github.com/{repo_owner}/{repo_name}/issues/new?title={title}&body={body}&labels={labels}&template={template}
```

URL-encode every query parameter value, including all line breaks and Markdown in the body. Include only parameters that have values; include `template` when a repository template was selected, and use a comma-separated value for multiple labels.
When the checkout is a fork, `{repo_owner}/{repo_name}` must be the upstream repository; never use the fork in this URL.

**Step 3: Present the draft and URL for review**

After writing the file, inform the user:
```
I've written the draft issue to NOTES_ISSUE.md for your review.

Prefilled issue URL: {prefilled_url}

Open the URL to review and submit the issue yourself. I will not create it unless you explicitly ask me to.
```

If the user requests modifications, update `NOTES_ISSUE.md` and regenerate the URL. If the user approves the draft without explicitly asking you to create or submit the issue, do not call `mcp__github__issue_write`.

### 5. Create the Issue (Only on Explicit Request)

Only after a later user message explicitly asks you to create, open, or submit the issue on their behalf, use `mcp__github__issue_write` with:
```
method: "create"
owner: {repo_owner}
repo: {repo_name}
title: {issue_title}
body: {issue_body}
labels: {from_template_if_available}
```

When the checkout is a fork, `{repo_owner}/{repo_name}` must identify the upstream repository.

**Fallback Body Structure (when no template available):**
If using a template, follow its structure. Otherwise write a short paragraph (or two) with no headings, no bullets, and no other formatting — describing the issue or proposal and incorporating any relevant context from linked issues/PRs. Write each paragraph as a single continuous line.
