---
name: pr
description: Create a GitHub pull request with AI-generated title and description based on the diff
---

# GitHub Pull Request Skill

Creates a draft pull request with a title and description generated from the diff between the current branch and the base branch.

**Never push.** The user always handles pushing themselves. Always assume the branch has already been pushed when creating the PR. Do not run `git push` under any circumstances.

**Formatting rules:**
- Do not hard-wrap lines. Write paragraphs as a single continuous line; let the renderer wrap.
- Minimal formatting. No examples, no diagrams. No bullet lists — write prose paragraphs, even when filling in template sections. If a template literally provides a checklist (e.g. `- [ ] Tested`), keep that as-is; do not invent prose bullets of your own.
- When no template exists, use only `### What` and `### Why` headings.

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
Try the same paths under the org's `.github` repo.

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
- A single focused paragraph naming the overarching change. Not a list.
- Write as one continuous line. Do not insert line breaks to wrap at any column width.
- Describe the change as one cohesive thing, not an enumeration of file edits or steps.
- Never list the *how* (e.g. "update X in lib.rs", "add test for Y", "rename Z"). The diff already shows that.
- Use imperative mood. Be direct, eliminate filler words.

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

### 6. Write Draft and Present for Review

**Step 1: Write the draft to NOTES_PR.md**

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

**Step 2: Present for review**

After writing the file, inform the user:
```
I've written the draft PR to NOTES_PR.md for your review.

Would you like me to create the PR with this content, or would you like to make changes?
```

Wait for user confirmation before proceeding. If the user requests modifications, update `NOTES_PR.md` with the changes before creating the PR.

### 7. Create the Pull Request

After user confirmation. Assume the branch is already pushed — do not push:

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
