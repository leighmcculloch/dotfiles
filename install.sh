#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

echo "Installing for $(uname)..."

# symlink files
pushd files
for f in *; do
  src="$PWD/$f"
  dest="$HOME/.$f"
  echo "Linking $src at $dest..."
  ln -sf "$src" "$dest"
done
popd

# setup paths, etc
source $PWD/files/zshenv

# install oh-my-zsh
export ZSH="$HOME/.oh-my-zsh"
if [ ! -d "$ZSH" ]; then
  git clone https://github.com/robbyrussell/oh-my-zsh "$ZSH"
fi
mkdir -p "$ZSH/custom/themes"
ln -sf "$PWD/files/enormous.zsh-theme" "$ZSH/custom/themes/"

# install some defaults
fzf --version
