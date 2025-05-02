#!/usr/bin/env zsh

set -o errexit
set -o pipefail
set -o nounset

# install mcp servers

pushd mcp
for f in *.json; do
  name="${f%.*}"
  claude mcp remove --scope user "$name" || true
  claude mcp add-json --scope user "$name" "$(jq --compact-output '.' $f)"
done
