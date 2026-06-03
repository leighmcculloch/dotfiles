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
  cargo install --locked cargo-deny
fi
if (( ! $+commands[cargo-hack] )); then
  echo "$fg[cyan]Installing cargo-hack...$reset_color"
  cargo install --locked cargo-hack
fi
if (( ! $+commands[go] )); then
  echo "$fg[cyan]Installing go...$reset_color"
  go_version=$(curl -fsSL "https://go.dev/dl/?mode=json" | jq -r '.[0].version')
  curl -fsSL "https://go.dev/dl/${go_version}.linux-amd64.tar.gz" | tar -C /usr/local -xz
fi
if (( ! $+commands[deno] )); then
  echo "$fg[cyan]Installing deno...$reset_color"
  curl -fsSL https://deno.land/install.sh | sh
  # make deno (and its globally installed bins) available to the rest of this script
  export PATH="$HOME/.deno/bin:$PATH"
fi
if (( ! $+commands[prettier] )); then
  echo "$fg[cyan]Installing prettier...$reset_color"
  deno install -gA npm:prettier
fi

echo "$fg[cyan]Installing claude files...$reset_color"
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

# inject git identity into ~/.bashrc so it is set in every shell on this instance.
# appends to GIT_CONFIG_* (rather than assuming a fixed count) so it layers onto
# any entries the environment already provides. guarded so re-runs don't duplicate it.
bashrc="$HOME/.bashrc"
marker="# dotfiles: git identity via GIT_CONFIG_*"
if ! grep -qF "$marker" "$bashrc" 2>/dev/null; then
  echo "$fg[cyan]Adding git identity to $bashrc...$reset_color"
  cat >> "$bashrc" <<'EOF'

# dotfiles: git identity via GIT_CONFIG_*
_count=${GIT_CONFIG_COUNT:-0}
export GIT_CONFIG_KEY_$_count=user.name
export GIT_CONFIG_VALUE_$_count=Leigh
_count=$((_count + 1))
export GIT_CONFIG_KEY_$_count=user.email
export GIT_CONFIG_VALUE_$_count=351529+leighmcculloch@users.noreply.github.com
_count=$((_count + 1))
export GIT_CONFIG_COUNT=$_count
EOF
fi

echo "$fg[green]Install complete.$reset_color"
