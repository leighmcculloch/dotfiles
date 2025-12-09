#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

# Vendor Homebrew installation to GitHub Container Registry
# Usage: ./vendor-brew.sh [push|pull]

# Check BREW_PREFIX is set
if [ -z "${BREW_PREFIX:-}" ]; then
  echo "Error: BREW_PREFIX environment variable not set" >&2
  echo "Hint: Run 'brew --prefix' to find it" >&2
  exit 1
fi

PLATFORM="$(echo $(uname -s)-$(uname -m) | tr '[:upper:]' '[:lower:]')"
IMAGE="ghcr.io/leighmcculloch/dotfiles/homebrew-${PLATFORM}:latest"

usage() {
  echo "Usage: $0 [push|pull]"
  echo ""
  echo "Commands:"
  echo "  push    Package and upload Homebrew installation to ghcr.io"
  echo "  pull    Download and extract Homebrew installation from ghcr.io"
  echo ""
  echo "Platform detected: ${PLATFORM}"
  echo "Brew prefix: ${BREW_PREFIX}"
  exit 1
}

push() {
  echo "==> Packaging Homebrew installation for ${PLATFORM}..."

  if [ ! -d "$BREW_PREFIX" ]; then
    echo "Error: Homebrew prefix not found at ${BREW_PREFIX}" >&2
    exit 1
  fi

  # Login to ghcr.io
  echo "==> Logging in to ghcr.io..."
  gh auth token | docker login ghcr.io -u leighmcculloch --password-stdin

  # Build and push image
  echo "==> Building and pushing ${IMAGE}..."
  docker build -t "$IMAGE" -f - "$BREW_PREFIX" <<'EOF'
FROM scratch
COPY . /homebrew
EOF

  docker push "$IMAGE"

  echo "==> Done! Pushed ${IMAGE}"
}

pull() {
  echo "==> Pulling Homebrew installation for ${PLATFORM}..."

  # Login to ghcr.io
  echo "==> Logging in to ghcr.io..."
  gh auth token | docker login ghcr.io -u leighmcculloch --password-stdin

  # Pull image
  echo "==> Pulling ${IMAGE}..."
  docker pull "$IMAGE"

  # Extract from image
  echo "==> Extracting to ${BREW_PREFIX}..."

  # Create parent directory if needed
  sudo mkdir -p "$(dirname "$BREW_PREFIX")"

  # Remove existing installation if present
  if [ -d "$BREW_PREFIX" ]; then
    echo "==> Removing existing installation..."
    sudo rm -rf "$BREW_PREFIX"
  fi

  # Create container and copy files out
  CONTAINER=$(docker create "$IMAGE")
  docker cp "$CONTAINER:/homebrew" "$BREW_PREFIX"
  docker rm "$CONTAINER"

  # Fix ownership (linuxbrew user may not exist on Linux)
  sudo chown -R "$(whoami)" "$BREW_PREFIX"

  echo "==> Done! Homebrew installed at ${BREW_PREFIX}"
  echo ""
  echo "Add to your PATH:"
  echo "  export PATH=\"${BREW_PREFIX}/bin:\$PATH\""
}

case "${1:-}" in
  push)
    push
    ;;
  pull)
    pull
    ;;
  *)
    usage
    ;;
esac
