#!/usr/bin/env zsh

set -o errexit
set -o pipefail
set -o nounset

autoload -U colors && colors

echo "$fg[cyan]Installing claude files for $(uname -s -p) in $(echo $0)...$reset_color"

# symlink files/claude at $HOME/.claude
src="$PWD/files/claude"
dest="$HOME/.claude"
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

echo "$fg[green]Install complete.$reset_color"
