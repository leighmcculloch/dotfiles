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
  [ -L "$dest" ] && rm "$dest"
  ln -sf "$src" "$dest"
done
popd

# symlink ssh config into existing .ssh dir
mkdir -p "$HOME/.ssh"
ln -sf "$HOME/.ssh_config" "$HOME/.ssh/config"
ln -sf "$HOME/.ssh_known_hosts" "$HOME/.ssh/known_hosts"

# symlink sublime settings
sublime_dir="$HOME/Library/Application Support/Sublime Text/Packages/User"
if [ -d "$sublime_dir" ]; then
  mv "$sublime_dir" "$sublime_dir.bak.$RANDOM"
fi
mkdir -p "$(dirname "$sublime_dir")"
ln -sf "$HOME/.sublime" "$sublime_dir"

# symlink config items on macos systems
if [ "$(uname)" = Darwin ]; then
  ln -sf "$PWD/files/config/zls.json" "$HOME/Library/Application Support/"
fi

# setup paths, etc
source $PWD/files/zenv

# install oh-my-zsh
export ZSH="$HOME/.oh-my-zsh"
if [ ! -d "$ZSH" ]; then
  git clone https://github.com/robbyrussell/oh-my-zsh "$ZSH"
fi
export ZSH_CUSTOM_THEMES="$ZSH/custom/themes"
rm -fr "$ZSH_CUSTOM_THEMES"
mkdir -p "$ZSH_CUSTOM_THEMES"
git clone --branch v1.15.0 --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM_THEMES/powerlevel10k"

# install some defaults
fzf --version
