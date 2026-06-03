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
  build-essential \
  gh
if (( ! $+commands[rustc] )); then
  echo "$fg[cyan]Installing rust...$reset_color"
  curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs | sh -s -- -y
  # make cargo available to the rest of this script in the same session
  source "$HOME/.cargo/env"
fi
if (( ! $+commands[cargo-deny] )); then
  echo "$fg[cyan]Installing cargo-deny...$reset_color"
  cargo install cargo-deny
fi
if (( ! $+commands[cargo-hack] )); then
  echo "$fg[cyan]Installing cargo-hack...$reset_color"
  cargo install cargo-hack
fi
if (( ! $+commands[go] )); then
  echo "$fg[cyan]Installing go...$reset_color"
  go_version=$(curl -fsSL "https://go.dev/dl/?mode=json" | jq -r '.[0].version')
  curl -fsSL "https://go.dev/dl/${go_version}.linux-amd64.tar.gz" | tar -C /usr/local -xz
fi
if (( ! $+commands[deno] )); then
  echo "$fg[cyan]Installing deno...$reset_color"
  curl -fsSL https://deno.land/install.sh | sh
fi

echo "$fg[cyan]Installing claude files...$reset_color"
links=(
  "$PWD/files/claude/CLAUDE.md:$HOME/.claude/CLAUDE.md"
)
for src in "$PWD"/files/claude/skills/*(/); do
  links+=("$src:$skills_dest/${src:t}")
done
skills_dest="$HOME/.claude/skills"
mkdir -p "$skills_dest"
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

# verify the active global git config matches the name/email in files/gitconfig
echo "$fg[cyan]Checking global git config...$reset_color"
expected_name=$(git config -f "$PWD/files/gitconfig" user.name)
expected_email=$(git config -f "$PWD/files/gitconfig" user.email)
actual_name=$(git config --global user.name || true)
actual_email=$(git config --global user.email || true)
if [ "$actual_name" = "$expected_name" ] && [ "$actual_email" = "$expected_email" ]; then
  echo "$fg[green]Global git config active (user.name=$actual_name, user.email=$actual_email).$reset_color"
else
  echo "$fg[red]Global git config mismatch:$reset_color"
  echo "  expected user.name  = $expected_name, got ${actual_name:-<unset>}"
  echo "  expected user.email = $expected_email, got ${actual_email:-<unset>}"
  if [ -z "$actual_name" ] || [ -z "$actual_email" ]; then
    echo "Set these env vars to configure git:"
    echo "  export GIT_CONFIG_COUNT=2"
    echo "  export GIT_CONFIG_KEY_0=user.name"
    echo "  export GIT_CONFIG_VALUE_0=$expected_name"
    echo "  export GIT_CONFIG_KEY_1=user.email"
    echo "  export GIT_CONFIG_VALUE_1=$expected_email"
  fi
  exit 1
fi

echo "$fg[green]Install complete.$reset_color"
