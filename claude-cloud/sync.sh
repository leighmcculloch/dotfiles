#!/usr/bin/env zsh

# Copies this repo's Claude config into ~/.claude. Run from claude-cloud/install.sh
# at environment setup (so the config is on disk before the Claude runtime
# launches and scans skills), from ~/.zshenv on every shell (to refresh it from
# the repo), and from the SessionStart hook.

set -o errexit
set -o pipefail
set -o nounset

# resolve the repo root from this script's own location (${0:A} is the absolute
# script path; :h:h strips the filename and the claude-cloud/ dir), so callers
# don't have to pass it.
dotfiles_dir="${0:A:h:h}"

# there's no cheap "already correct" check like a symlink's readlink, so just
# overwrite our own copies each time.
mkdir -p ~/.claude/skills
cp "$dotfiles_dir/shared/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"

# settings.json's hook commands reference the hook scripts by absolute path via the
# __CLAUDE_CLOUD_DIR__ placeholder. Substitute the real claude-cloud dir as we copy
# so the deployed config carries a literal path and the hooks don't depend on
# DOTFILES_DIR being set in whatever shell Claude runs them from. sed (not jq) so
# this works during install.sh, which installs jq only after first running sync.sh.
sed "s|__CLAUDE_CLOUD_DIR__|$dotfiles_dir/claude-cloud|g" \
  "$dotfiles_dir/claude-cloud/settings.json" > "$HOME/.claude/settings.json"

# ~/.claude/skills may also hold skills from elsewhere, so copy our skills in one
# at a time rather than replacing the whole directory, which would clobber any
# skills this repo doesn't own.
for src in "$dotfiles_dir"/shared/claude/skills/*; do
  dest="$HOME/.claude/skills/${src:t}"
  rm -rf "$dest"
  cp -R "$src" "$dest"
done
