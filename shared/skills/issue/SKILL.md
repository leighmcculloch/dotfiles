---
name: issue
description: Drafts GitHub issues with context from linked issues/PRs, provides a prefilled URL for review by default, and creates one only after an explicit user request.
---

# GitHub Issue Creation Skill

Drafts GitHub issues for the user to review. The default handoff is a prefilled GitHub URL that the user can open and submit themselves; do not create the issue unless the user explicitly asks you to create or submit it.

**Formatting rules:**
- Do not hard-wrap lines. Write paragraphs as a single continuous line; let the renderer wrap.
- Minimal formatting. No diagrams or invented bullet lists. Use prose paragraphs for narrative and fenced code blocks for commands, code, and output the reader will copy or compare, including under template headings. Keep the template's headings and any literal checklists (e.g. `- [ ] Tested`) unchanged.
- When a template section poses several questions or prompts, answer each one in its own paragraph (in the order asked), separated by blank lines, rather than collapsing them into a single block. This keeps each section easy for a human to scan.
- Describe the problem, not the solution. For bug reports, write from the user's point of view, describing actions and user-visible behaviour. Code reading may uncover a bug, but distinguish observed behaviour from suspected behaviour; never imply an unverified scenario was run. Do not add internal source paths, line numbers, function names, types, code paths, diagnosis, severity commentary, or fix suggestions (even tentative ones); leave diagnosis to whoever picks it up. Internal details in verbatim captured output are allowed.
- Give a complete, minimal, copy-pasteable reproduction from scratch: all prerequisites, project setup, minimal source (with language-tagged fences), build, key generation/funding, deployment, and exact commands as applicable. Include a working control case and its output beside the failing case when helpful. For a theoretical report, label the reproduction and any control case as unverified.
- Under "What did you see instead?", quote actual captured stdout/stderr and exit status in fenced code blocks. Trim long noise such as backtraces with `...`, but never invent or paraphrase captured output. If reproduction remains unverified, say so, briefly explain what prevented confirmation, and describe the suspected user-visible symptom in explicitly tentative prose, not fabricated output.
- Under "What version are you using?", give the output of the version command for the tool actually used in the reproduction, or the commit it was built from for an unreleased build. For a theoretical report, identify the version or commit inspected and state that it was not verified by reproduction; never use "found by code reading" as a version. Keep "What did you expect to see?" to one or two plain sentences about correct user-visible behaviour, without proposing an implementation. Use the template's equivalent sections if its headings differ.
- Name the command and user-visible symptom in the title, with the command in backticks, e.g. "`contract invoke` crashes instead of showing an error for a malformed union argument".
- Draft one issue per distinct bug, even when related bugs share a symptom, each with its own minimal reproduction. Optionally add one closing sentence noting related reports.

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

### 4. Attempt Reproduction Before Drafting

For bug reports, make a serious attempt to run the complete minimal reproduction before drafting: install missing tools or dependencies, build the tool locally, and use testnet or a local network as needed. If an approach fails, try reasonable alternatives rather than stopping at the first blocker. Capture the version (or build commit), exact setup and commands, stdout/stderr, and exit status, including any control case. If confirmation remains blocked or attempts do not reproduce the bug, tell the user what you tried and proceed with a clearly labelled theoretical draft, noting blockers or contrary results and separating evidence from inference. Do not block drafting on tool availability or require permission to use this fallback.

### 5. Draft and Provide a Prefilled URL (REQUIRED)

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

### 6. Create the Issue (Only on Explicit Request)

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
If using a template, follow its structure. Otherwise use short prose paragraphs with no headings or bullets, incorporating relevant context from linked issues/PRs. For bug reports, include the version, complete reproduction, expected behaviour, and actual output required above, using fenced code blocks for commands, code, and output. Write each paragraph as a single continuous line.
