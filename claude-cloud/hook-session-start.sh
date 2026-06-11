#!/usr/bin/env zsh

# SessionStart hook, wired up via claude-cloud/settings.json. Refreshes this
# repo's Claude config, then asks Claude Code to re-scan skills so a config that
# lands after launch still takes effect in the already-running session.

set -o errexit
set -o pipefail

# sync.sh is a sibling; resolve it from this script's own dir (${0:A:h}). If the
# sync fails, errexit aborts before the JSON below, so the hook fails loudly
# rather than reporting a successful reload over a stale or partial config.
"${0:A:h}/sync.sh"

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","reloadSkills":true}}'
