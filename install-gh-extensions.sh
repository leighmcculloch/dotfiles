#!/usr/bin/env zsh

set -o errexit
set -o pipefail
set -o nounset

# install gh plugins
gh extension install github/gh-models
gh extension install github/gh-copilot
gh extension install meiji163/gh-notify --pin 556df2eecdc0f838244a012759da0b76bcfeb2e7
gh extension install dlvhdr/gh-dash --pin 605b25ac07928bfc13cde36c312a506d5bb01779 # v4.14.0
