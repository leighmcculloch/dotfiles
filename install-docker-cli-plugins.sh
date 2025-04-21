#!/usr/bin/env zsh

set -o errexit
set -o pipefail
set -o nounset

# install docker cli plugins
mkdir -p $HOME/.docker/cli-plugins
ln -sf \
  "$(brew --prefix docker-buildx)/lib/docker/cli-plugins/docker-buildx" \
  "$HOME/.docker/cli-plugins/docker-buildx"
