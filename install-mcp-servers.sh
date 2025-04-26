#!/usr/bin/env zsh

set -o errexit
set -o pipefail
set -o nounset

# install mcp servers

claude mcp add \
  --transport stdio \
  --scope user \
  mcp-stellar-xdr-json \
  -- \
  npx deno run \
  --allow-read \
  https://github.com/leighmcculloch/mcp-stellar-xdr-json/raw/refs/heads/main/mcp-stellar-xdr-json.ts

claude mcp add \
  --transport stdio \
  --scope user \
  mcp-gemini \
  -- \
  npx deno run \
  --allow-read \
  --allow-env \
  --allow-net=generativelanguage.googleapis.com:443 \
  https://github.com/leighmcculloch/mcp-gemini/raw/refs/heads/main/mcp-gemini.ts

claude mcp add \
  --transport stdio \
  --scope user \
  mcp-github \
  -- \
  go run github.com/github/github-mcp-server/cmd/github-mcp-server@latest stdio
