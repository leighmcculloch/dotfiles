#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

# update vim-plug
curl -fLo autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

# update vim plugins
rm -f vimrc.lock
vim +PlugUpdate '+PlugSnapshot vimrc.lock' +qa
sed -i '/^PlugUpdate/d' vimrc.lock
