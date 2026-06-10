#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

# update vim-plug
curl -fLo autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

git diff -- autoload/plug.vim

# update vim plugins
rm -f vimrc.lock
vim +PlugUpdate '+PlugSnapshot vimrc.lock' +qa
sed -i.bak '/^PlugUpdate/d' vimrc.lock

git diff -- autoload/plug.vim
