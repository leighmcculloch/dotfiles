#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

# symlink files
pushd files
for f in *; do
  dest="$HOME/.$f"
  echo "Linking $PWD/$f at $dest..."
  ln -sf "$f" "$dest"
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
