#!/bin/zsh
set -e

SCRIPT_DIR="${0:a:h}"
CASK_FILE="$SCRIPT_DIR/hyprnote.rb"

# Get latest release tag
TAG=$(curl -s "https://api.github.com/repos/fastrepl/hyprnote/releases/latest" | jq -r '.tag_name')
VERSION="${TAG#desktop_v}"

# Get sha256
SHA256=$(curl -sL "https://github.com/fastrepl/hyprnote/releases/download/$TAG/hyprnote-macos-aarch64.dmg.sha256" | awk '{print $1}')

# Update cask file
sed -i '' "s/version \".*\"/version \"$VERSION\"/" "$CASK_FILE"
sed -i '' "s/sha256 \".*\"/sha256 \"$SHA256\"/" "$CASK_FILE"

echo "Updated hyprnote.rb to version $VERSION"
