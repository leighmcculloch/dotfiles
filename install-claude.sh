#!/usr/bin/env bash

# Bootstraps in bash because zsh may not be installed yet. The bash step below
# installs only zsh, then re-execs the rest of this script under zsh.

set -o errexit
set -o pipefail
set -o nounset

# ZSH_VERSION is set only when running under zsh, so an empty value means we are
# still in the bash bootstrap and need to switch. Installing zsh is conditional
# (only when missing), but the exec is not: the shebang always starts us in bash,
# so every bash pass must re-exec into zsh — even when zsh is already installed —
# otherwise the zsh-only body below would run under bash and fail.
if [ -z "${ZSH_VERSION:-}" ]; then
  # install zsh first so the rest of this script can run under it
  if ! command -v zsh >/dev/null 2>&1; then
    echo "Installing zsh..."
    DEBIAN_FRONTEND=noninteractive apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y zsh
  fi
  # re-exec the remainder under zsh
  exec zsh "$0" "$@"
fi

# ----- everything below runs under zsh -----

# install remaining apt packages needed by most scripts in this repo (non-interactive use)
echo "Installing apt packages..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  curl \
  xxd \
  build-essential \
  gh
if (( ! $+commands[cargo-deny] )); then
  echo "Installing cargo-deny..."
  cargo install --locked cargo-deny
fi
if (( ! $+commands[cargo-hack] )); then
  echo "Installing cargo-hack..."
  cargo install --locked cargo-hack
fi
if (( ! $+commands[deno] )); then
  echo "Installing deno..."
  curl -fsSL https://deno.land/install.sh | sh
  # make deno (and its globally installed bins) available to the rest of this script
  export PATH="$HOME/.deno/bin:$PATH"
fi
if (( ! $+commands[prettier] )); then
  echo "Installing prettier..."
  deno install -gA npm:prettier
fi

echo "Installing claude files..."
mkdir -p "$HOME/.claude"
mkdir -p "$HOME/.claude/skills"
links=(
  "$PWD/files/claude/CLAUDE.md:$HOME/.claude/CLAUDE.md"
)
for src in "$PWD"/files/claude/skills/*(/); do
  links+=("$src:$HOME/.claude/skills/${src:t}")
done
for link in $links; do
  src="${link%%:*}"
  dest="${link#*:}"
  echo -n "Linking $src at $dest... "
  # check if destination already exists (including a broken symlink)
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    if [ -L "$dest" ]; then
      # existing destination is a symlink, safe to replace
      rm "$dest"
      ln -s "$src" "$dest"
      echo "done (replacing symlink)."
    else
      # existing destination is a real file/dir, back it up first
      # find next available backup name
      i=0
      while [ -e "$dest.bak$i" ]; do
        ((i++))
      done
      backup="$dest.bak$i"
      mv "$dest" "$backup"
      ln -s "$src" "$dest"
      echo "done (backed up to $backup)."
    fi
  else
    # destination doesn't exist, create symlink
    ln -s "$src" "$dest"
    echo "done."
  fi
done

# set the git identity in the global config so it persists across shells on this instance
echo "Setting git identity..."
git config --global user.name "Leigh"
git config --global user.email "351529+leighmcculloch@users.noreply.github.com"

echo "Install complete."
