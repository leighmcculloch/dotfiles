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

autoload -U colors && colors

# install remaining apt packages needed by most scripts in this repo (non-interactive use)
echo "$fg[cyan]Installing apt packages...$reset_color"
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  git \
  jq \
  curl \
  xxd \
  docker.io \
  build-essential \
  gh

echo "$fg[cyan]Installing claude and git files for $(uname -s -p) in $(echo $0)...$reset_color"

# files to symlink as $HOME/.<name>
files=(
  claude
  gitallowedsignersfile
  gitattributes
  gitconfig
  gitignore_global
  gitmessage
)

for f in $files; do
  src="$PWD/files/$f"
  dest="$HOME/.$f"
  echo -n "Linking $src at $dest... "
  # check if destination already exists
  if [ -f "$dest" ] || [ -d "$dest" ]; then
    # destination already exists
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
    ln -sf "$src" "$dest"
    echo "done."
  fi
done

echo "$fg[green]Install complete.$reset_color"
