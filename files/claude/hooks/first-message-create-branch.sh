#!/bin/bash
#
# UserPromptSubmit hook. On the first prompt of a Claude Code session, if the
# working directory is a git worktree, create and switch to a new branch named
# after the prompt — so Claude's changes land on their own branch, not
# wherever the worktree happened to be checked out.
#
# Input (JSON on stdin, from Claude Code):
#   .session_id — session UUID, used to fire-once-per-session
#   .prompt     — user's prompt text, fed to the model for naming
#
# Output:
#   stdout      — optional {"systemMessage": "..."} so Claude Code confirms
#                 the new branch in the UI
#   /tmp/claude-first-msg-<session_id> — per-session marker
#
# Fails open: every precondition (missing session/prompt, not a worktree,
# gemma unavailable, empty model response, checkout failure) exits 0 silently
# so a broken hook never blocks the user's prompt.

input=$(cat)

# Skip when invoked from gprd — that flow operates on the current branch to
# create a PR, so renaming the branch mid-run would break it.
[ "${SCRIPT:-}" = "gprd" ] && exit 0

# jq twice over the same captured input — we need both fields and piping stdin
# into two separate jq calls would fail.
session_id=$(printf '%s' "$input" | jq -r '.session_id // ""')
[ -z "$session_id" ] && exit 0

# Fire-once marker. Created before the remaining checks on purpose: if the
# first prompt doesn't qualify (e.g., not in a worktree), we still consume the
# "first message" slot so later prompts in the same session don't suddenly
# branch off mid-conversation.
marker="/tmp/claude-first-msg-$session_id"
[ -e "$marker" ] && exit 0
touch "$marker"

# Worktree detection. In a git worktree, `.git` is a regular file containing a
# `gitdir:` pointer. In the main clone, `.git` is a directory. We only branch
# in worktrees — the main clone is assumed to be the long-lived checkout.
[ -f .git ] || exit 0

# Skip if the current branch already tracks a remote. The user has pushed
# work under that name, so renaming via a new branch would orphan the remote
# and be an annoyance to recover from. An upstream on another LOCAL branch
# doesn't count — that's a transient setup, not published work.
upstream=$(git rev-parse --symbolic-full-name '@{u}' 2>/dev/null || true)
case "$upstream" in refs/remotes/*) exit 0 ;; esac

prompt=$(printf '%s' "$input" | jq -r '.prompt // ""')
[ -z "$prompt" ] && exit 0

# Local LM Studio model via the `gemma` wrapper script. No fallback — if it's
# not installed the hook just skips naming.
command -v gemma >/dev/null 2>&1 || exit 0

# Unquoted newline-separated branch list passed verbatim to the model so it
# can avoid proposing an existing name. Using --all includes remote-tracking
# branches, which reduces the chance of a remote collision surfacing later.
branches=$(git branch --all --format='%(refname:short)' 2>/dev/null)

ai_prompt="You are a senior software engineer.

Suggest a concise, kebab-case branch name that describes the changes (max 5 words).

Reply only with the branch name, nothing else.

Do not use any of these names: ${branches}.

User request:
${prompt}"

# Sanitize the model's reply: lowercase, spaces → hyphens, drop blank lines,
# take the first remaining line. Guards against chatty responses that spill
# onto multiple lines despite the "reply only with the branch name" instruction.
name=$(gemma "$ai_prompt" 2>/dev/null | tr '[:upper:] ' '[:lower:]-' | awk 'NF' | head -1)
[ -z "$name" ] && exit 0

# Collision fallback. The model is told to avoid existing names, but obeys
# imperfectly. If the suggested name collides with a local branch, append
# -2, -3, ... until free. Cap at 99 so pathological inputs can't loop forever.
candidate="$name"
i=2
while git show-ref --verify --quiet "refs/heads/$candidate" && [ "$i" -le 99 ]; do
  candidate="$name-$i"
  i=$((i+1))
done

# Branch and report. checkout output is silenced because the systemMessage is
# the user-facing confirmation; on failure we stay quiet and let the prompt
# proceed on the current branch.
if git checkout -b "$candidate" >/dev/null 2>&1; then
  jq -n --arg n "$candidate" '{systemMessage: ("branched to " + $n)}'
fi
exit 0
