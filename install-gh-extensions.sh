#!/usr/bin/env zsh

set -o errexit
set -o pipefail
set -o nounset

# install gh plugins
gh extension install github/gh-models
gh extension install github/gh-copilot
gh extension install meiji163/gh-notify --pin 556df2eecdc0f838244a012759da0b76bcfeb2e7
