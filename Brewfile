brew "asciinema"
brew "agg"
brew "bat"
brew "cloudflare-wrangler"
brew "csvlens"
brew "fd"
brew "fzf"
brew "gh"
brew "git"
brew "git-delta"
brew "gum"
brew "httpie"
brew "jless"
brew "jq"
brew "ripgrep"
brew "slides"
brew "starship"
brew "stellar-cli"
brew "tig"
brew "tmux"
brew "tree"
brew "watchexec"
brew "zstd"
brew "prettier"

brew "rustup"
brew "sccache"
brew "go"
brew "deno"
brew "node"
brew "uv"

brew "neovim"
brew "lua-language-server"
brew "gopls"
brew "vscode-langservers-extracted"

if OS.mac?
  brew "autoconf"
  brew "automake"
  brew "clang-format"
  brew "cmake"
  brew "coreutils"
  brew "docker"
  brew "docker-credential-helper"
  brew "docker-buildx"
  brew "duckdb"
  brew "ffmpeg"
  brew "flyctl"
  brew "glow"
  brew "imagemagick"
  brew "mas"
  brew "stellar-core"
  brew "zig"
  brew "zls"
  brew "wabt"
  brew "wasm-pack"
  brew "vhs"

  cask "font-fira-code"
  cask "font-fira-code-nerd-font"
  cask "orbstack"
  cask "descript"
  cask "discord"
  cask "ghostty"
  cask "sublime-text"
  #cask "lm-studio"
  cask "motion"
  cask "voiceink"

  mas "Numbers", id: 409203825
  mas "Pages", id: 409201541
  mas "Day Progress", id: 6450280202
end

cask "tailscale-app"
cask "nordvpn"
if OS.mac? && `hostname`.chomp == "Concrete.local"
  #cask "nordlayer"
  mas "Slack", id: 803453959
  mas "Telegram", id: 747648890
end
if OS.mac? && `hostname`.chomp != "Concrete.local"
  cask "doxie"
  mas "1Blocker", id: 1365531024
  mas "1Password for Safari", id: 1569813296
  mas "House Designer", id: 779363176
  mas "Prime Video", id: 545519333
  mas "WhatsApp", id: 310633997
  mas "NetSpot", id: 514951692
end
