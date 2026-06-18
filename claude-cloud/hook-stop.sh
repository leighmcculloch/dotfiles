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

# hook-reminder.sh prints the rules already JSON-escaped. the \\n in the format is a
# literal backslash-n (a JSON newline escape) separating the lead-in from the rules.
reminder=$(zsh -f "${0:A:h}/hook-reminder.sh")
printf '{"decision":"block","reason":"Before finishing, verify this session followed these rules; fix anything that does not comply, then stop again.\\n%s"}' "$reminder"
