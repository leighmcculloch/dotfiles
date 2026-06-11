#!/usr/bin/env zsh

# SessionStart hook, wired up via claude-cloud/settings.json. Refreshes this
# repo's Claude config from the repo, then asks Claude Code to re-scan skills so
# a config that lands after launch still takes effect in the already-running
# session.

# resolve the repo root from this script's own location (${0:A} is the absolute
# script path; :h:h strips the filename and the claude-cloud/ dir) so sync.sh
# finds its sources without depending on DOTFILES_DIR being exported.
export DOTFILES_DIR="${0:A:h:h}"

# refresh the config, but never fail the hook over it: the re-scan below is the
# point, and it still picks up whatever is already on disk.
"$DOTFILES_DIR/claude-cloud/sync.sh" || true

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","reloadSkills":true}}'
