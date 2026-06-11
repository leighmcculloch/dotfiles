#!/usr/bin/env zsh

# Copies this repo's Claude config into ~/.claude. Run twice: from
# claude-cloud/install.sh at environment setup, so the config is on disk before
# the Claude runtime launches and scans skills, and from ~/.zshenv on every
# shell, to refresh it from the repo. DOTFILES_DIR must point at the repo root.

set -o errexit
set -o pipefail
set -o nounset

# there's no cheap "already correct" check like a symlink's readlink, so just
# overwrite our own copies each time.
mkdir -p ~/.claude/skills
cp "$DOTFILES_DIR/shared/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
cp "$DOTFILES_DIR/claude-cloud/settings.json" "$HOME/.claude/settings.json"

# ~/.claude/skills may also hold skills from elsewhere, so copy our skills in one
# at a time rather than replacing the whole directory, which would clobber any
# skills this repo doesn't own.
for src in "$DOTFILES_DIR"/shared/claude/skills/*; do
  dest="$HOME/.claude/skills/${src:t}"
  rm -rf "$dest"
  cp -R "$src" "$dest"
done
