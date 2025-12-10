#!/usr/bin/env zsh

set -o errexit
set -o pipefail
set -o nounset

autoload -U colors && colors

echo "Installing for $(uname -s -p) in $(echo $0)..."

# symlink files
pushd files
for f in *; do
  src="$PWD/$f"
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
      echo "$fg[yellow]done (backed up to $backup)$reset_color."
    fi
  else
    # destination doesn't exist, create symlink
    ln -sf "$src" "$dest"
    echo "done."
  fi
done
popd

# symlink ssh config into existing .ssh dir
mkdir -p "$HOME/.ssh"
ln -sf "$HOME/.ssh_config" "$HOME/.ssh/config"
ln -sf "$HOME/.ssh_known_hosts" "$HOME/.ssh/known_hosts"

# symlink docker cli plugins
mkdir -p $HOME/.docker/cli-plugins
ln -sf \
  "$BREW_PREFIX/opt/docker-buildx/lib/docker/cli-plugins/docker-buildx" \
  "$HOME/.docker/cli-plugins/docker-buildx"

# install brew
if (( ! $+commands[brew] )); then
  if [ -t 0 ]; then; else
    export NONINTERACTIVE=1
    export HOMEBREW_NO_VERIFY_ATTESTATIONS=1
  fi
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# setup paths, etc
source $PWD/files/zenv

# install some commands ahead of everything else as they are a bare requirement for the dot files to work
# - gh cli so it is available for git credential helper and scripts
# - starship so it available to the prompt
brew install --formula gh starship

# install nvim plugins
nvim +PlugInstall +qall

# install additional packages via brew
if [ -z "${HOMEBREW_GITHUB_API_TOKEN:-}" ] && [ ! -t 0 ]; then
  # disable attestation when non-interactive and no GitHub token available
  export HOMEBREW_NO_VERIFY_ATTESTATIONS=1
fi
brew bundle install --no-upgrade
