---
name: pr
description: Create a GitHub pull request with AI-generated title and description based on the diff. Always shows the draft description for review and waits for approval before opening the PR.
---

# GitHub Pull Request Skill

Creates a draft pull request with a title and description generated from the diff between the current branch and the base branch. It never opens the PR until the user has reviewed the description and approved it.

**Formatting rules:**
- Concise above all. Write for a reader with ADHD: lead with the point, short sentences, no throat-clearing or filler. Every word earns its place — if a sentence can go, cut it. Aim shorter than feels natural.
- Do not hard-wrap lines. Write paragraphs as a single continuous line; let the renderer wrap.
- Minimal formatting. No examples, no diagrams. No bullet lists — write prose paragraphs, even when filling in template sections. If a template literally provides a checklist (e.g. `- [ ] Tested`), keep that as-is; do not invent prose bullets of your own.
- When no template exists, use only `### What` and `### Why` headings.

**Confirmation (always required):**
- NEVER open the PR without first showing the draft description and getting explicit approval. After writing the draft, always present it and wait for the user to review and confirm — no args or mode ever skips this. If the user asks for changes, revise the draft and present it again before opening.

## Workflow

### 1. Determine Base Branch

Get the default branch and check for ancestor branches:

```bash
git symbolic-ref refs/remotes/origin/HEAD --short | sed 's|origin/||'
```

If there's an ancestor branch that isn't the default branch, ask the user which to use as the base.

### 2. Verify Changes Exist

Get the diff between base branch and HEAD:

```bash
git log --patch {base_branch}..HEAD
```

If no changes are detected, inform the user and stop.

### 3. Gather Issue Context (Optional)

If the user provides an issue number or URL earlier in the conversation or now:

```bash
gh issue view {issue_number} --json url,number,title,body,comments
```

The issue's title, body, and comments contain the reasoning and motivation for the change. This context must be incorporated into the PR's "Why" section to echo the problem being solved.

### 4. Discover PR Templates

**Step 1: Find PR templates**
Do steps 1a and 1b in parallel.

**Step 1a: Check target repository**
Try each of these paths via `gh api repos/{owner}/{repo}/contents/{path}` until one returns content:
- `.github/pull_request_template.md`
- `.github/PULL_REQUEST_TEMPLATE.md`
- `.github/PULL_REQUEST_TEMPLATE/` (directory of multiple templates)
- `docs/pull_request_template.md`
- `pull_request_template.md`

**Step 1b: Check org's .github repository**
Query GitHub's public HTTP endpoints, not the GitHub API. Try the same paths under the org's `.github` repo via the raw endpoint with `curl -fsSL`, treating an HTTP 200 as "exists" and a 404 as "missing":
```
https://raw.githubusercontent.com/{repo_owner}/.github/HEAD/{path}
```
For the `.github/PULL_REQUEST_TEMPLATE/` directory, list its contents by fetching the public repo tree page with WebFetch:
```
https://github.com/{repo_owner}/.github/tree/HEAD/.github/PULL_REQUEST_TEMPLATE
```

**Step 2: Select template**
- If Step 1a returned a single template file, use it.
- If Step 1a returned a directory of templates, auto-select the one whose name best matches the change (bug fix, feature, etc.). If unclear, briefly list options and ask the user.
- Otherwise, use the result from Step 1b under the same rules.
- If neither location has a template, proceed with the What/Why fallback.

### 5. Generate PR Content

**Title:**
- Max 50 characters
- Start with a capital letter
- No trailing period
- Use imperative mood (Add, Fix, Update, not Adds, Fixes, Updates)

**Body — if a template was found:**
Populate the template's sections directly. Do not add `### What` or `### Why` headings unless the template itself has them. Keep paragraphs as single unwrapped lines.

**Body — if no template was found, use What/Why:**

**What section:**
- A single focused paragraph naming the overarching change. Not a list. When the change is simple, one tight sentence beats a paragraph.
- Write as one continuous line. Do not insert line breaks to wrap at any column width.
- Describe the change as one cohesive thing, not an enumeration of file edits or steps.
- Never list the *how* (e.g. "update X in lib.rs", "add test for Y", "rename Z"). The diff already shows that.
- Use imperative mood. Be direct, eliminate filler words. Lead with the point; no throat-clearing.

**Why section:**
- A single focused paragraph. Not a list.
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

### 6. Write Draft

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

**Always present the draft for review before opening the PR — there is no skip.** Show it and ask:
```
Draft PR is in NOTES_PR.md.

Open it with this, or change anything first?
```
Wait for explicit confirmation before proceeding to Step 7. If the user requests modifications, update `NOTES_PR.md` and present the revised draft again — do not open the PR until they approve.

### 7. Create the Pull Request

Assume the branch is already pushed — do not push:

```bash
gh pr create \
  --draft \
  --base "{base_branch}" \
  --title "{title}" \
  --body "{full_body}" \
  --reviewer "{reviewers}"
```

The body should be either the populated template or the `### What` and `### Why` sections (if no template). Append `Close #{issue_number}` if linked to an issue.

Pass all paragraphs to `--body` as single unwrapped lines.

### 8. Report Result

Output the created PR URL.
