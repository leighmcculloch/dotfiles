---
name: pr-draft-comment
description: Post pending (draft) review comments on a GitHub PR — including replies to existing review comments — that stay unsubmitted and visible only to the author until they manually submit the review. This is the REQUIRED way to leave ANY comment on a PR (autofixing CI, addressing feedback, replying to a review); never post an immediately-visible PR comment. Works with the GitHub MCP tools (Claude Code Cloud) or gh/GraphQL (local).
---

# GitHub PR Draft (Pending) Review Comments

Posts review comments to a PR as **pending drafts** that remain invisible to everyone but the author until they submit the review via the GitHub UI (or another tool call). Useful for AI-generated code-review findings that the user wants to triage before publishing.

## This is the only way to comment on a PR here

NEVER post a plain, immediately-visible comment on a pull request — not when autofixing CI, not when addressing review feedback, not even when replying to an existing review comment. Every comment on a PR goes through this skill as a **pending** review comment, and **you never submit the pending review yourself** — the author publishes it. That means:

- Do NOT use `add_issue_comment` (on a PR), `add_reply_to_pull_request_comment`, `gh pr comment`, or `gh pr review` — they all publish on the spot.
- Do NOT call `pull_request_review_write` with `method: submit_pending` (or the `submitPullRequestReview` GraphQL mutation) unless the author explicitly asks you to publish.
- A status update or "here's why CI is red" note is still a PR comment: post it as a pending comment (anchored to a relevant file/line, or a FILE-level comment), not a plain conversation comment.

## Claude Code Cloud (GitHub MCP tools)

In the cloud setup `gh` is not authenticated — use the GitHub MCP tools. The GraphQL sections below are the local fallback.

1. **Ensure a pending review exists.** Each user has at most one pending review per PR. Create one with `pull_request_review_write` using `method: "create"` and **no `event`** (omitting `event` is what makes it pending rather than submitted):

   `pull_request_review_write(method: "create", owner, repo, pullNumber)`

2. **Add each draft comment** to that pending review with `add_comment_to_pending_review`:

   `add_comment_to_pending_review(owner, repo, pullNumber, path, body, subjectType: "LINE", line, side: "RIGHT")`

   Use `subjectType: "FILE"` (omit `line`/`side`) for a file-level note. Anchor `LINE` comments to a line inside a diff hunk (see the gotcha below).

3. **Do NOT submit.** Leave the review pending. Do not call `pull_request_review_write` with `method: "submit_pending"`.

`add_comment_to_pending_review` has no reply field, so for replies to an existing review comment see the next section.

## Replying to an existing review comment (pending)

A reply to a review comment must **also** be a pending draft — never a published reply. `add_reply_to_pull_request_comment` publishes immediately, so do not use it.

- **True threaded pending reply (gh/GraphQL):** attach the reply to your pending review with `addPullRequestReviewThreadReply`, passing the pending review's `pullRequestReviewId` and the comment you're replying to as `inReplyTo`. Because it belongs to the pending review, it stays a draft until the review is submitted.

  ```bash
  gh api graphql -f query='mutation($rid:ID!,$cid:ID!,$body:String!) {
    addPullRequestReviewThreadReply(input: {pullRequestReviewId:$rid, inReplyTo:$cid, body:$body}) {
      comment { id }
    }
  }' -f rid="PRR_..." -f cid="PRRC_..." -f body="Reply text."
  ```

  `cid` is the target review comment's node ID (`PRRC_...`), and `rid` is the pending review's ID (`PRR_...`) — create one first if none exists (see the workflow below).

- **MCP-only fallback (Claude Code Cloud):** `add_comment_to_pending_review` cannot thread onto an existing comment. Instead add a pending inline comment at the **same file and line** as the original review comment, quoting or referencing it in the body (e.g. "Re your comment on this line: …"). It won't render as a threaded reply, but it stays pending and lands next to the original.

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
5. **These publish immediately — never use them for a comment that should be pending:** `gh pr review` / `gh pr comment`, and the MCP tools `add_issue_comment` and `add_reply_to_pull_request_comment`. A reply routed through `add_reply_to_pull_request_comment` is public the instant it posts.
6. **Escaping in `-f query='...'`** — For mutations with complex bodies, prefer the `--input file.json` form. Single quotes around backticks and code fences fight shell quoting.

## Quick reference

| Need | Mutation |
|------|----------|
| Add draft comment to existing pending review | `addPullRequestReviewThread` with `pullRequestReviewId` |
| Start a new pending review with first draft comment | `addPullRequestReviewThread` with `pullRequestId` |
| Reply to an existing review comment, as a draft | `addPullRequestReviewThreadReply` with `pullRequestReviewId` + `inReplyTo` |
| Edit a draft comment | `updatePullRequestReviewComment` with `pullRequestReviewCommentId` |
| Delete a draft comment | `deletePullRequestReviewComment` with comment `id` |
| Submit (publish) the pending review | `submitPullRequestReview` with `event: COMMENT` / `APPROVE` / `REQUEST_CHANGES` |
| Discard pending review entirely | `deletePullRequestReview` with `pullRequestReviewId` |
