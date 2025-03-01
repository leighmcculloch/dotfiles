#!/usr/bin/env zsh
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
  mkdir -p "$ZSH"
  pushd "$ZSH"
  git init
  git remote add origin https://github.com/robbyrussell/oh-my-zsh
  git fetch origin d41ca84af1271e8bfbe26f581cebe3b86521d0db
  git reset --hard FETCH_HEAD
  popd
fi

# install vim plugins
vim +PlugInstall +qall

# install brew and minimal tools
if [ -t 0 ]; then; else
  export NONINTERACTIVE=1
fi
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
source $PWD/files/zenv_brew
brew bundle install

