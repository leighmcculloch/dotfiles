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
)
for f in "${links}"; do
  ln -sf "$PWD/files/$f" "$HOME/.$f"
done

# install tmux plugins
~/.tmux/plugins/tpm/bin/install_plugins

# install vim plugins
vim +PlugInstall +qa
vim +GoInstallBinaries +qa
