#!/usr/bin/env zsh

set -o errexit
set -o pipefail
set -o nounset

autoload -U colors && colors

echo "$fg[cyan]Installing for $(uname -s -p) in $(echo $0)...$reset_color"

# symlink files
echo "$fg[cyan]Symlinking files...$reset_color"
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
      echo "done (backed up to $backup)."
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
  echo "$fg[cyan]Installing brew...$reset_color"
  if [ -t 0 ]; then; else
    export NONINTERACTIVE=1
    export HOMEBREW_NO_VERIFY_ATTESTATIONS=1
  fi
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# setup paths, etc
echo "$fg[cyan]Sourcing zenv...$reset_color"
source $PWD/files/zenv

# install some commands ahead of everything else as they are a bare requirement for the dot files to work
# - gh cli so it is available for git credential helper and scripts
# - starship so it available to the prompt
echo "$fg[cyan]Installing critical programs with brew...$reset_color"
brew install --formula gh starship

echo "$fg[green]Critical install complete.$reset_color"

# install nvim plugins
echo "$fg[cyan]Installing nvim plugins...$reset_color"
nvim +PlugInstall +qall

# install additional packages via brew
echo "$fg[cyan]Installing additional programs with brew...$reset_color"
if [ -z "${HOMEBREW_GITHUB_API_TOKEN:-}" ] && [ ! -t 0 ]; then
  # disable attestation when non-interactive and no GitHub token available
  export HOMEBREW_NO_VERIFY_ATTESTATIONS=1
fi
brew bundle install --no-upgrade

echo "$fg[green]Install complete.$reset_color"
