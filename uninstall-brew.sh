#!/bin/bash

packages=$(brew list)
for pkg in $packages; do
  #if [[ "$pkg" == "starship" ]]; then
  #  continue
  #fi
  brew uninstall "$pkg"
done
