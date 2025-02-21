#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

source $PWD/files/zenv_brew

brew bundle install

# brew install --formula aider \
# automake \
# clang-format \
# cmake \
# coreutils \
# csvlens \
# deno \
# docker \
# duckdb \
# ffmpeg \
# flyctl \
# fzf \
# gh \
# git \
# go \
# gron \
# gum \
# httpie \
# imagemagick \
# jless \
# jq \
# node \
# sccache \
# stellar-cli \
# stellar-core \
# tig \
# tmux \
# tree \
# vim \
# wasm-pack \
# zls \
# ;
