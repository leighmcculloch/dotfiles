#!/usr/bin/env zsh

set -o errexit
set -o pipefail
set -o nounset

autoload -U colors && colors

# install apt packages needed by most scripts in this repo (non-interactive use)
echo "$fg[cyan]Installing apt packages...$reset_color"
DEBIAN_FRONTEND=noninteractive apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    zsh git jq curl gawk xxd docker.io gh

echo "$fg[cyan]Installing claude and git files for $(uname -s -p) in $(echo $0)...$reset_color"

# files to symlink as $HOME/.<name>
files=(
  claude
  gitallowedsignersfile
  gitattributes
  gitconfig
  gitignore_global
  gitmessage
)

for f in $files; do
  src="$PWD/files/$f"
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

echo "$fg[green]Install complete.$reset_color"
