#!/usr/bin/env zsh

# SessionStart hook, wired up via claude-cloud/settings.json. Refreshes this
# repo's Claude config, then asks Claude Code to re-scan skills so a config that
# lands after launch still takes effect in the already-running session.

set -o errexit
set -o pipefail

# sync.sh is a sibling; resolve it from this script's own dir (${0:A:h}). If the
# sync fails, errexit aborts before the JSON below, so the hook fails loudly
# rather than reporting a successful reload over a stale or partial config.
# `zsh -f` skips ~/.zshenv so the sync subshell doesn't re-invoke sync.sh and recurse.
zsh -f "${0:A:h}/sync.sh"

# emit the commit/PR/branch workflow rules as additionalContext so they are present
# from the first turn. reloadSkills stays so a config that lands after launch takes
# effect. hook-reminder.sh prints the rules already JSON-escaped, so %s splices in
# safely (printf interprets backslashes only in the format, not in the argument).
reminder=$(zsh -f "${0:A:h}/hook-reminder.sh")
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","reloadSkills":true,"additionalContext":"%s"}}' "$reminder"
