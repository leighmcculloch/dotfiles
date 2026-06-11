#!/usr/bin/env zsh

# SessionStart hook, wired up via claude-cloud/settings.json. Refreshes this
# repo's Claude config, then asks Claude Code to re-scan skills so a config that
# lands after launch still takes effect in the already-running session.

# sync.sh is a sibling; resolve it from this script's own dir (${0:A:h}). It
# never fails the hook: the re-scan below is the point, and it still picks up
# whatever is already on disk.
"${0:A:h}/sync.sh" || true

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","reloadSkills":true}}'
