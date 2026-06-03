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

# everything runs serially; errexit/pipefail abort the script on the first failure.

# curl options to retry transient network failures on downloads
curl_opts=(-fsSL --retry 3 --retry-delay 2 --retry-all-errors)

# inject git identity into ~/.zshenv so it is set in every shell on this instance.
# appends to GIT_CONFIG_* (rather than assuming a fixed count) so it layers onto
# any entries the environment already provides. guarded so re-runs don't duplicate it.
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

# link claude files
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

# apt packages: prerequisite for the curl downloads below, so install them first
echo "Installing apt packages..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  curl \
  xxd \
  build-essential \
  gh \
  wabt

# install prebuilt dev tool binaries from the stellar/binaries release instead of
# compiling them with cargo. only the tools listed below, newest version of each.
# downloads run serially with anonymous curl (a parallel burst gets HTTP 403 rate limited).
binaries_tag=v65
api="https://api.github.com/repos/stellar/binaries/releases/tags/$binaries_tag"
base_url="https://github.com/stellar/binaries/releases/download/$binaries_tag"
tools=(cargo-hack cargo-deny cargo-fuzz cargo-semver-checks cargo-expand cargo-nextest wasm-cs sccache)
echo "Installing dev tool binaries ($binaries_tag)..."
# find the newest version of each wanted tool among the Linux X64 assets
typeset -A latest
for name in ${(f)"$(curl $curl_opts "$api" | grep -oE '[A-Za-z0-9._-]+-Linux-X64\.tar\.gz' | sort -u)"}; do
  base=${name%-Linux-X64.tar.gz}     # e.g. cargo-deny-0.19.0
  tool=${base%-*}                    # e.g. cargo-deny
  ver=${base##*-}                    # e.g. 0.19.0
  (( ${tools[(I)$tool]} )) || continue   # skip tools not in our list
  if [[ -z ${latest[$tool]:-} ]] || [[ $(print -rl -- ${latest[$tool]} $ver | sort -V | tail -1) == $ver ]]; then
    latest[$tool]=$ver
  fi
done
# download and extract each selected binary into /usr/local/bin
for tool ver in ${(kv)latest}; do
  echo "  ${tool} ${ver}"
  curl $curl_opts "$base_url/${tool}-${ver}-Linux-X64.tar.gz" | tar -C /usr/local/bin -xz
done

# install the stellar cli from its github releases
if (( ! $+commands[stellar] )); then
  echo "Installing stellar-cli..."
  # resolve the latest version from the releases/latest redirect (avoids needing jq)
  stellar_tag=$(curl $curl_opts -o /dev/null -w '%{url_effective}' https://github.com/stellar/stellar-cli/releases/latest)
  stellar_version=${${stellar_tag##*/}#v}
  curl $curl_opts "https://github.com/stellar/stellar-cli/releases/download/v${stellar_version}/stellar-cli-${stellar_version}-x86_64-unknown-linux-gnu.tar.gz" | tar -C /usr/local/bin -xz
fi

# install deno, then prettier (which needs deno on PATH)
if (( ! $+commands[deno] )); then
  echo "Installing deno..."
  curl $curl_opts https://deno.land/install.sh | sh
  # make deno (and its globally installed bins) available to the rest of this script
  export PATH="$HOME/.deno/bin:$PATH"
fi
if (( ! $+commands[prettier] )); then
  echo "Installing prettier..."
  deno install -gA npm:prettier
fi

echo "Install complete."
