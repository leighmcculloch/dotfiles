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

# Blocks that don't depend on each other run in parallel as background subshells,
# with a single wait at the end. The apt packages are a prerequisite for the
# toolchain installs (curl fetches deno, build-essential compiles the cargo tools),
# so they install first while the independent blocks already run alongside.
pids=()

# inject git identity into ~/.zshenv so it is set in every shell on this instance.
# appends to GIT_CONFIG_* (rather than assuming a fixed count) so it layers onto
# any entries the environment already provides. guarded so re-runs don't duplicate it.
(
  zshenv="$HOME/.zshenv"
  marker="# dotfiles: auto added, do not remove"
  if ! grep -qF "$marker" "$zshenv" 2>/dev/null; then
    echo "Adding envs to $zshenv..."
    cat >> "$zshenv" <<'EOF'

# dotfiles: auto added, do not remove
_git_config_env() {
  local i=${GIT_CONFIG_COUNT:-0}
  export GIT_CONFIG_KEY_$i="$1"
  export GIT_CONFIG_VALUE_$i="$2"
  export GIT_CONFIG_COUNT=$((i + 1))
}
_git_config_env user.name "Leigh"
_git_config_env user.email "351529+leighmcculloch@users.noreply.github.com"
unset -f _git_config_env

# use sccache to cache rust compilation
export RUSTC_WRAPPER=sccache

# remove the stop-hook git check (-f so a missing file doesn't error in every shell)
rm -f ~/.claude/stop-hook-git-check.sh
rm -f ~/.claude/session-start-git-identity.sh
EOF
  fi
) &
pids+=($!)

# link claude files (independent of the installs)
(
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
) &
pids+=($!)

# apt packages: prerequisite for the toolchain installs, so install them first
echo "Installing apt packages..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  curl \
  xxd \
  build-essential \
  gh \
  wabt

# toolchain installs, fanned out in parallel now that the apt deps are present
(
  if (( ! $+commands[cargo-deny] )); then
    echo "Installing cargo-deny..."
    cargo install --locked cargo-deny
  fi
) &
pids+=($!)
(
  if (( ! $+commands[cargo-hack] )); then
    echo "Installing cargo-hack..."
    cargo install --locked cargo-hack
  fi
) &
pids+=($!)
(
  if (( ! $+commands[sccache] )); then
    echo "Installing sccache..."
    cargo install --locked sccache
  fi
) &
pids+=($!)
(
  if (( ! $+commands[cargo-nextest] )); then
    echo "Installing cargo-nextest..."
    cargo install --locked cargo-nextest
  fi
) &
pids+=($!)
(
  if (( ! $+commands[cargo-fuzz] )); then
    echo "Installing cargo-fuzz..."
    cargo install --locked cargo-fuzz
  fi
) &
pids+=($!)
(
  if (( ! $+commands[cargo-expand] )); then
    echo "Installing cargo-expand..."
    cargo install --locked cargo-expand
  fi
) &
pids+=($!)
(
  if (( ! $+commands[wasm-cs] )); then
    echo "Installing wasm-cs..."
    cargo install --locked wasm-cs
  fi
) &
pids+=($!)
(
  if (( ! $+commands[stellar] )); then
    echo "Installing stellar-cli..."
    cargo install --locked stellar-cli
  fi
) &
pids+=($!)
# deno and prettier share a subshell because prettier needs deno on PATH
(
  if (( ! $+commands[deno] )); then
    echo "Installing deno..."
    curl -fsSL https://deno.land/install.sh | sh
    # make deno (and its globally installed bins) available within this subshell
    export PATH="$HOME/.deno/bin:$PATH"
  fi
  if (( ! $+commands[prettier] )); then
    echo "Installing prettier..."
    deno install -gA npm:prettier
  fi
) &
pids+=($!)

# wait for every background block; fail if any of them did
fail=0
for pid in $pids; do
  wait $pid || fail=1
done
(( fail )) && exit 1

echo "Install complete."
