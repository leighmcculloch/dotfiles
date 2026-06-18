#!/usr/bin/env zsh

# Stop hook, wired up via claude-cloud/settings.json. Refreshes this repo's Claude
# config (the same sync as SessionStart), then blocks the stop once to re-inject the
# commit/PR/branch workflow rules so Claude verifies it complied before finishing.

set -o errexit
set -o pipefail
set -o nounset

# Claude Code passes the Stop event as JSON on stdin. Read it before anything else
# so the pipe is drained; we only need the stop_hook_active flag out of it.
input=$(cat)

# always refresh the config on stop, on both the blocking and the allow-stop pass.
# `zsh -f` skips ~/.zshenv so the sync subshell doesn't re-invoke sync.sh and recurse.
zsh -f "${0:A:h}/sync.sh"

# once we block, the next Stop call arrives with stop_hook_active:true. honour it and
# let the stop through so we re-inject the rules exactly once and never loop. matched
# with a glob that tolerates whitespace around the JSON colon.
if [[ $input == *'"stop_hook_active"'*:*true* ]]; then
  exit 0
fi

# build the reason (a lead-in line plus the shared rules) and let jq escape it into
# JSON, including the embedded newlines. jq is installed by install.sh.
rules=$(cat "${0:A:h}/hook-reminder.txt")
reason="Before finishing, verify this session followed these rules; fix anything that does not comply, then stop again.
$rules"
jq -nc --arg reason "$reason" '{decision:"block",reason:$reason}'
