brew "asciinema"
brew "agg"
brew "bat"
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
brew "tig"
brew "tmux"
brew "tree"
brew "watchexec"
brew "zstd"
brew "prettier"
brew "mermaid-cli"

brew "rustup"
brew "sccache"
brew "go"
brew "deno"
brew "node"
brew "uv"
brew "zig"

brew "neovim"
brew "lua-language-server"
brew "gopls"
brew "zls"
brew "vscode-langservers-extracted"

go "github.com/leighmcculloch/gas/v3"
go "github.com/leighmcculloch/gate"
go "github.com/github/github-mcp-server/cmd/github-mcp-server"

brew "stellar-cli"

if OS.mac?
  brew "autoconf"
  brew "automake"
  brew "clang-format"
  brew "cmake"
  brew "coreutils"
  brew "docker"
  brew "docker-buildx"
  brew "duckdb"
  brew "ffmpeg"
  brew "imagemagick"
  brew "wabt"
  brew "wasm-pack"
  brew "vhs"

  cask "obsidian"
  cask "arc"
  cask "font-fira-code"
  cask "font-fira-code-nerd-font"
  cask "orbstack"
  cask "descript"
  cask "discord"
  cask "ghostty"
  cask "sublime-text"

  # AI desktop tools
  cask "lm-studio"
  cask "voiceink"
  cask "claude"
  cask "claude"

  # AI CLI tools
  brew "lima"
  # brew "opencode" - updated too infrequently, must be installed with npm
  cask "claude-code"
  cask "copilot-cli"

  brew "mas"
  mas "Numbers", id: 409203825
  mas "Pages", id: 409201541
  mas "Day Progress", id: 6450280202
  mas "Termius", id: 1176074088

  brew "stellar-core"

  #cask "tailscale-app"

  mdm_enrolled = `profiles status -type enrollment`.include?("Yes")

  if mdm_enrolled
    cask "nordlayer"
    mas "Slack", id: 803453959
    mas "Telegram", id: 747648890
  else
    cask "nordvpn"
    cask "doxie"
    brew "cloudflare-wrangler"
    mas "1Blocker", id: 1365531024
    mas "1Password for Safari", id: 1569813296
    mas "House Designer", id: 779363176
    mas "Prime Video", id: 545519333
    mas "WhatsApp", id: 310633997
    mas "NetSpot", id: 514951692
  end
end
