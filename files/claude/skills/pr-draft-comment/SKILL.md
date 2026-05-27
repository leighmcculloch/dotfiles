---
name: pr-draft-comment
description: Post pending (draft) review comments on a GitHub PR that stay unsubmitted and visible only to the author until they manually submit the review. Use when the user asks to "post a pending comment", "add a draft review comment", "leave a draft comment on the PR", or similar. Do NOT use for immediately-visible standalone PR comments.
---

# GitHub PR Draft (Pending) Review Comments

Posts inline review comments to a PR as **pending drafts** that remain invisible to everyone but the author until they submit the review via the GitHub UI (or another tool call). Useful for AI-generated code-review findings that the user wants to triage before publishing.

## Key concepts

- A **pending review** is a personal draft review attached to a PR. Each authenticated user has at most **one pending review per PR**.
- Inline comments live inside a pending review until the user submits it. They are not visible to other collaborators while pending.
- `gh pr review` and `gh pr comment` do **not** create pending comments — they publish immediately. You must use the GraphQL API.

## Workflow

### 1. Find the PR and any existing pending review

```bash
gh pr view --json number,url,headRefName
gh pr view <number> --json reviews
```

In the `reviews` array, look for the entry where `author.login` matches the current `gh api user --jq .login` AND `state == "PENDING"`. Save its `id` (looks like `PRR_kwDO...`) — call it `REVIEW_ID`.

If no pending review exists, you'll need the PR's node ID instead:

```bash
gh api graphql -f query='query { repository(owner:"OWNER", name:"REPO") { pullRequest(number: N) { id } } }'
```

### 2. Verify the comment anchor line is inside a diff hunk

**Critical gotcha:** `addPullRequestReviewThread` returns `{ thread: null }` with no error if the target line is not inside any added/changed hunk of the PR. Always anchor comments to lines that appear in the diff.

```bash
git diff <base>...HEAD -- <path> | grep '^@@'
```

Each `@@ -old,oldN +new,newN @@` header tells you the new-file line range `[new, new+newN-1]` is in a hunk. If the line you want to comment on falls outside every hunk, pick the nearest in-hunk line and reference the off-hunk line in the comment body.

For findings on context lines that the diff didn't touch but a hunk surrounds (e.g. a function that the PR re-exposes a bug in), use the closest in-hunk line and explain the connection in the body.

### 3. Post the comment via GraphQL

Use a JSON file rather than `-f`/`-F` flags so multi-line bodies with backticks, quotes, and code fences round-trip correctly:

```bash
cat > /tmp/draft_comment.json <<'EOF'
{
  "query": "mutation($input: AddPullRequestReviewThreadInput!) { addPullRequestReviewThread(input: $input) { thread { id line path } } }",
  "variables": {
    "input": {
      "pullRequestReviewId": "PRR_kwDO...",
      "path": "path/to/file.rs",
      "line": 123,
      "side": "RIGHT",
      "body": "Comment body with `code` and ```fences``` and \"quotes\"."
    }
  }
}
EOF
gh api graphql --input /tmp/draft_comment.json
```

Required fields:
- `pullRequestReviewId` — the existing pending review's ID. **Or** use `pullRequestId` (the PR node ID) instead — that creates a new pending review on the fly with this comment as its first entry.
- `path` — file path from repo root.
- `line` — 1-based line number in the **new** (right-side) file.
- `side` — `"RIGHT"` for new-file line, `"LEFT"` for old-file line. Default is `"RIGHT"`; include it explicitly for clarity.
- `body` — the comment markdown.

Optional fields for multi-line comments:
- `startLine` — 1-based start line for a range.
- `startSide` — `"RIGHT"` or `"LEFT"`.
- `subjectType` — `"LINE"` (default) or `"FILE"` for file-level comments.

A successful response returns `{ thread: { id: "PRRT_...", line, path } }`. Save the thread ID if you might need to edit or delete the comment.

### 4. Verify the comments are pending, not published

```bash
gh api graphql -f query='query { node(id: "PRR_kwDO...") { ... on PullRequestReview { state comments(first: 20) { totalCount nodes { path line } } } } }'
```

`state` should still be `"PENDING"`. The user submits via the GitHub UI (Files Changed → Finish your review) or with the `submitPullRequestReview` mutation if asked.

## Editing or deleting a pending draft

Get the **comment** ID (not the thread ID — they're different):

```bash
gh api graphql -f query='query { node(id: "PRRT_THREAD_ID") { ... on PullRequestReviewThread { comments(first: 5) { nodes { id body } } } } }'
```

Edit:
```bash
gh api graphql -f query='mutation { updatePullRequestReviewComment(input: {pullRequestReviewCommentId: "PRRC_...", body: "new body"}) { pullRequestReviewComment { id } } }'
```

Delete:
```bash
gh api graphql -f query='mutation { deletePullRequestReviewComment(input: {id: "PRRC_..."}) { pullRequestReview { id } } }'
```

The thread is removed when its last comment is deleted.

## Common pitfalls

1. **Silent `thread: null`** — Line is outside every diff hunk. Anchor to an in-hunk line; reference the real location in the body if needed.
2. **`"Pull request review thread position is invalid"`** — You used the older `addPullRequestReviewComment` mutation, which wants a 1-based **diff position** (not file line) and is more painful to compute. Prefer `addPullRequestReviewThread`.
3. **Two pending reviews** — You can't have two pending reviews on the same PR. If one exists, add to it via `pullRequestReviewId`; don't pass `pullRequestId`.
4. **Comment ID vs. thread ID** — `PRRT_...` is a thread; `PRRC_...` is a comment. Delete/update mutations want `PRRC_...`.
5. **`gh pr review` body publishes immediately** — Don't use it for drafts. It always creates a non-pending review.
6. **Escaping in `-f query='...'`** — For mutations with complex bodies, prefer the `--input file.json` form. Single quotes around backticks and code fences fight shell quoting.

## Quick reference

| Need | Mutation |
|------|----------|
| Add draft comment to existing pending review | `addPullRequestReviewThread` with `pullRequestReviewId` |
| Start a new pending review with first draft comment | `addPullRequestReviewThread` with `pullRequestId` |
| Edit a draft comment | `updatePullRequestReviewComment` with `pullRequestReviewCommentId` |
| Delete a draft comment | `deletePullRequestReviewComment` with comment `id` |
| Submit (publish) the pending review | `submitPullRequestReview` with `event: COMMENT` / `APPROVE` / `REQUEST_CHANGES` |
| Discard pending review entirely | `deletePullRequestReview` with `pullRequestReviewId` |
