---
name: pr
description: Drafts a GitHub pull request with an AI-generated title and description based on the diff, provides a prefilled URL for review by default, and opens one only after an explicit user request.
---

# GitHub Pull Request Skill

Drafts a pull request with a title and description generated from the diff between the current branch and the base branch. The default handoff is a prefilled GitHub URL that the user can open and submit themselves; do not create the PR unless the user explicitly asks you to create or submit it.

**Formatting rules:**
- Concise above all. Write for a reader with a very very very short attention span: lead with the point, short sentences, no throat-clearing or filler. Every word earns its place — if a sentence can go, cut it. One sentence per section is the target; a second only if one genuinely can't carry it. Aim far shorter than feels natural.
- Do not hard-wrap lines. Write paragraphs as a single continuous line; let the renderer wrap.
- Minimal formatting. No examples, no diagrams. No bullet lists — write prose paragraphs, even when filling in template sections. If a template literally provides a checklist (e.g. `- [ ] Tested`), keep that as-is; do not invent prose bullets of your own.
- When no template exists, use only `### What` and `### Why` headings.

**Opening method (always required):**
- The default is to show the draft and provide a prefilled URL. Do not run `gh pr create` merely because the user approved the draft; let the user open and submit the URL themselves.
- If the user asks for changes, revise `NOTES_PR.md` and regenerate the URL before presenting it again.
- Only a later user message explicitly asking you to create, open, or submit the PR on their behalf permits running `gh pr create`.

## Workflow

### 1. Determine Repository Roles

Inspect the repository remotes, especially `upstream` and `origin`, and GitHub fork metadata when needed. If the current checkout is a fork with an upstream repository, set `{target_owner}/{target_repo}` to the upstream repository, `{fork_owner}/{fork_repo}` to the fork containing the code, `{base_remote}` to the upstream remote, and `{head_remote}` to the fork remote. Set `{head_ref}` to `{fork_owner}:{head_branch}` for the GitHub PR form. Use the upstream repository as the PR target; the fork is only the source of the code. If there is no fork/upstream relationship, use the current repository as both target and source and set `{head_ref}` to `{head_branch}`. If the target or remotes are ambiguous, ask the user before proceeding.

### 2. Determine Base Branch

Get the default branch and check for ancestor branches:

```bash
git symbolic-ref refs/remotes/{base_remote}/HEAD --short | sed 's|{base_remote}/||'
```

Use the upstream remote's default branch when working from a fork; otherwise use the current repository's default branch. If the remote-tracking symbolic ref is unavailable, query the target repository's default branch instead. If there's an ancestor branch that isn't the default branch, ask the user which to use as the base.

### 3. Verify Changes Exist

Get the diff between base branch and HEAD:

```bash
git log --patch {base_remote}/{base_branch}..HEAD
```

If no changes are detected, inform the user and stop.

When working from a fork, the current branch must be pushed to `{head_remote}` (the fork), never to `{base_remote}` (the upstream). Do not push as part of this workflow; use the fork branch as the PR head.

### 4. Gather Issue Context (Optional)

If the user provides an issue number or URL earlier in the conversation or now:

```bash
gh issue view {issue_number} --repo "{target_owner}/{target_repo}" --json url,number,title,body,comments
```

The issue's title, body, and comments contain the reasoning and motivation for the change. This context must be incorporated into the PR's "Why" section to echo the problem being solved.

### 5. Discover PR Templates

**Step 1: Find PR templates**
Do steps 1a and 1b in parallel.

**Step 1a: Check target repository**
Try each of these paths via `gh api repos/{target_owner}/{target_repo}/contents/{path}` until one returns content:
- `.github/pull_request_template.md`
- `.github/PULL_REQUEST_TEMPLATE.md`
- `.github/PULL_REQUEST_TEMPLATE/` (directory of multiple templates)
- `docs/pull_request_template.md`
- `pull_request_template.md`

**Step 1b: Check org's .github repository**
Query GitHub's public HTTP endpoints, not the GitHub API. Try the same paths under the org's `.github` repo via the raw endpoint with `curl -fsSL`, treating an HTTP 200 as "exists" and a 404 as "missing":
```
https://raw.githubusercontent.com/{target_owner}/.github/HEAD/{path}
```
For the `.github/PULL_REQUEST_TEMPLATE/` directory, list its contents by fetching the public repo tree page with WebFetch:
```
https://github.com/{target_owner}/.github/tree/HEAD/.github/PULL_REQUEST_TEMPLATE
```

**Step 2: Select template**
- If Step 1a returned a single template file, use it.
- If Step 1a returned a directory of templates, auto-select the one whose name best matches the change (bug fix, feature, etc.). If unclear, briefly list options and ask the user.
- Otherwise, use the result from Step 1b under the same rules.
- If neither location has a template, proceed with the What/Why fallback.

### 6. Generate PR Content

**Title:**
- Max 50 characters
- Start with a capital letter
- No trailing period
- Use imperative mood (Add, Fix, Update, not Adds, Fixes, Updates)

**Body — if a template was found:**
Populate the template's sections directly. Do not add `### What` or `### Why` headings unless the template itself has them. Keep paragraphs as single unwrapped lines.

**Body — if no template was found, use What/Why:**

**What section:**
- One sentence naming the overarching change. Not a paragraph, not a list. Add a second sentence only if a single one genuinely can't carry the change.
- Write as one continuous line. Do not insert line breaks to wrap at any column width.
- Describe the change as one cohesive thing, not an enumeration of file edits or steps.
- Never list the *how* (e.g. "update X in lib.rs", "add test for Y", "rename Z"). The diff already shows that.
- Use imperative mood. Be direct, eliminate filler words. Lead with the point; no throat-clearing.

**Why section:**
- One sentence naming the specific problem that motivated the change. Not a paragraph, not a list.
- Write as one continuous line. Do not insert line breaks to wrap at any column width.
- Name the specific problem, behavior, or constraint that motivated the change — not generic justifications ("improves clarity", "better UX", "for consistency").
- If linked to an issue, echo the concrete reasoning from the issue.
- Think like a journalist: what would a reader need to know to understand why this exists?

**Style contrast (study before writing):**

Avoid (machine-generated, lists the *how*):
> - Emit a warning from the build script when X cannot be derived.
> - Document in lib.rs and README that downstream should use `option_env!`.
> - Update the example snippet from `env!` to `option_env!`.
> - Add test covering the no-git path.

Prefer (hyperfocused, names the overarching change):
> Expand the crate-level docs with sections covering builds without version info, shallow clone support, and the stripping of path-redirecting `GIT_*` env vars.

If linked to an issue, include `Close #{issue_number}` in the body before building the prefilled URL or creating the PR.

### 7. Write Draft and Provide a Prefilled URL

**Step 1: Write the draft**

Write the complete draft PR to `NOTES_PR.md` in the current working directory. Write all paragraphs as single unwrapped lines:

```markdown
# Draft Pull Request

**Base branch:** {base_branch}

## Title
{title}

## Body
{body}
```

`{body}` is either the populated template (if one was found) or the What/Why sections (if not).

**Step 2: Build the prefilled PR URL**

Build a compare URL for the pull request form. When working from a fork, target the upstream repository and use the fork-qualified head branch:

```
https://github.com/{target_owner}/{target_repo}/compare/{base_branch}...{fork_owner}:{head_branch}?quick_pull=1&title={title}&body={body}&template={template}
```

For a non-fork checkout, use `{head_ref}` in the same URL in place of `{fork_owner}:{head_branch}`. URL-encode every query parameter value, including all line breaks and Markdown in the body. Include only parameters that have values; include `template` when a repository template was selected. Use the full body shown in the draft, including `Close #{issue_number}` when applicable. Never use the fork repository as the URL target when an upstream exists.

**Step 3: Present the draft and URL for review**

Always present the draft for review. Show it and say:
```
Draft PR is in NOTES_PR.md.

Prefilled PR URL: {prefilled_url}

Open the URL to review and submit the PR yourself. I will not create it unless you explicitly ask me to.
```

If the user approves the draft without explicitly asking you to create or submit the PR, do not run `gh pr create`.

### 8. Create the Pull Request (Only on Explicit Request)

Only after a later user message explicitly asks you to create, open, or submit the PR on their behalf, proceed. Assume the branch is already pushed — do not push:

```bash
gh pr create \
  --repo "{target_owner}/{target_repo}" \
  --head "{head_ref}" \
  --draft \
  --base "{base_branch}" \
  --title "{title}" \
  --body "{full_body}" \
  --reviewer "{reviewers}"
```

The body should be either the populated template or the `### What` and `### Why` sections (if no template), including `Close #{issue_number}` when linked to an issue.

For a fork, `{target_owner}/{target_repo}` is the upstream repository and `{head_ref}` is `{fork_owner}:{head_branch}`. This opens the PR on the upstream without pushing code there; the code remains on the fork.

Pass all paragraphs to `--body` as single unwrapped lines.

### 9. Report Result

Output the created PR URL.

### 10. Strip the Auto-Appended Trailer

The cloud integration appends a `_Generated by [Claude Code](...)_` trailer, under a `---` rule, to the PR description when the PR is opened. Immediately after creating the PR, re-read its description and, if that trailing block is present, edit the description to remove it — via `gh pr edit --body` or the GitHub MCP `update_pull_request` tool, whichever this environment uses. Leave the rest of the description untouched.
