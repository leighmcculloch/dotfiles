#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

echo "Installing for $(uname -s -p) in $(echo $0)..."

# symlink files
pushd files
for f in *; do
  src="$PWD/$f"
  dest="$HOME/.$f"
  echo "Linking $src at $dest..."
  [ -L "$dest" ] && rm "$dest"
  ln -sf "$src" "$dest"
done
popd

# symlink ssh config into existing .ssh dir
mkdir -p "$HOME/.ssh"
ln -sf "$HOME/.ssh_config" "$HOME/.ssh/config"
ln -sf "$HOME/.ssh_known_hosts" "$HOME/.ssh/known_hosts"

# setup paths, etc
source $PWD/files/zenv

# install oh-my-zsh
export ZSH="$HOME/.oh-my-zsh"
if [ ! -d "$ZSH" ]; then
  git clone https://github.com/robbyrussell/oh-my-zsh "$ZSH"
fi

# install some defaults
fzf --version
