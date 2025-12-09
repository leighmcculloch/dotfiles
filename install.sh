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

# install gh cli early so it is available for git credential helper
brew install --formula gh

# install packages via brew
if [ -z "${HOMEBREW_GITHUB_API_TOKEN:-}" ] && [ ! -t 0 ]; then
  # disable attestation when non-interactive and no GitHub token available
  export HOMEBREW_NO_VERIFY_ATTESTATIONS=1
fi
brew bundle install --no-upgrade

# install plugins/extensions
./install-docker-cli-plugins.sh
nvim +PlugInstall +qall
