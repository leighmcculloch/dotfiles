#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

# symlink files
links=(
  zshenv
  zshrc
  gitmessage
  gitignore_global
  gitconfig
  tmux.conf
  tmux
  tigrc
  vim
  tmux
  ssh/config
  ssh/known_hosts
  gnupg/gpg-agent.conf
  lazybin
  scripts
)
for f in "${links[@]}"; do
  dest="$HOME/.$f"
  if [[ "$f" == *\/* ]]; then
    echo "Creating directory $dest..."
    mkdir -m 700 -p "$dest"
  fi
  echo "Linking $PWD/files/$f at $dest..."
  ln -sf "$PWD/files/$f" "$dest"
done

# install oh-my-zsh
export ZSH="$HOME/.oh-my-zsh"
if [ ! -d "$ZSH" ]; then
  git clone https://github.com/robbyrussell/oh-my-zsh "$ZSH"
fi
mkdir -p "$ZSH/custom/themes"
ln -sf "$PWD/files/enormous.zsh-theme" "$ZSH/custom/themes/"

# install tmux plugins
~/.tmux/plugins/tpm/bin/install_plugins
