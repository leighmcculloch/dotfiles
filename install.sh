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
  if [ -f "$dest" ] || [ -d "$dest" ]; then
    if [ -L "$dest" ]; then
      rm "$dest"
      ln -s "$src" "$dest"
      echo "done (replacing symlink)."
    else
      echo "$fg[red]skipping because exists$reset_color."
    fi
  else
    ln -sf "$src" "$dest"
    echo "done."
  fi
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
  git init -b master # The upstream oh-my-zsh's default branch is 'master'.
  git remote add origin https://github.com/robbyrussell/oh-my-zsh
  git fetch origin d41ca84af1271e8bfbe26f581cebe3b86521d0db
  git reset --hard FETCH_HEAD
  popd
fi

# install brew and minimal tools
if (( ! $+commands[brew] )); then
  if [ -t 0 ]; then; else
    export NONINTERACTIVE=1
  fi
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
source $PWD/files/zenv_brew

# if a gh personal access token is configured in an env var, as is the case in
# GitHub Codespaces, then use that as the Homebrew token.
if [ -n "$GITHUB_PERSONAL_ACCESS_TOKEN" ]; then
  export HOMEBREW_GITHUB_API_TOKEN=$GITHUB_PERSONAL_ACCESS_TOKEN
fi
brew bundle install --no-upgrade

# install plugins/extensions
./install-gh-extensions.sh
./install-docker-cli-plugins.sh
nvim +PlugInstall +qall
