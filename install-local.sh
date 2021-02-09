#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

# symlink files
links=(
  gitignore_global
  gitconfig
)
for f in "${links[@]}"; do
  dest="$HOME/.$f"
  if [[ "$f" == *\/* ]]; then
    destdir="$(dirname $dest)"
    echo "Creating directory $destdir..."
    mkdir -m 700 -p "$destdir"
  fi
  echo "Linking $PWD/files/$f at $dest..."
  ln -sf "$PWD/files/$f" "$dest"
done
