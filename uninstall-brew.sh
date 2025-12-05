#!/bin/bash

# Uninstall all Homebrew packages.
# Useful when migrating to a new machine or cleaning up before reinstalling.

# Get all installed packages (formulae and casks)
packages=$(brew list)

# Uninstall each package one by one
for pkg in $packages; do
  # Uncomment below to skip specific packages
  #if [[ "$pkg" == "starship" ]]; then
  #  continue
  #fi
  brew uninstall "$pkg"
done
