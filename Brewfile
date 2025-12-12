# Install brew formula only if the command doesn't exist outside of BREW_PREFIX
def brew_if_missing(formula, cmd: nil, override: false)
  cmd ||= formula
  brew_prefix = `zsh -lc 'echo $BREW_PREFIX'`.chomp
  # Check if command exists in PATH but not under brew prefix
  path_dirs = `zsh -lc 'echo $PATH'`.chomp.split(":").reject { |p| p.start_with?(brew_prefix) }
  found_path = path_dirs.find { |dir| File.executable?(File.join(dir, cmd)) }
  if found_path && !override
    puts "Skipping #{formula}: #{cmd} found at #{File.join(found_path, cmd)}"
  elsif found_path && override
    puts "Overriding #{formula}: #{cmd} found at #{File.join(found_path, cmd)}, but installing anyway"
    brew formula
  else
    brew formula
  end
end

brew_if_missing "asciinema"
brew_if_missing "agg"
brew_if_missing "bat"
brew_if_missing "csvlens"
brew_if_missing "fd"
brew_if_missing "fzf"
brew_if_missing "gh"
brew_if_missing "git", override: OS.mac?
brew_if_missing "git-delta", cmd: "delta"
brew_if_missing "gum"
brew_if_missing "httpie", cmd: "http"
brew_if_missing "jless"
brew_if_missing "jq", override: OS.mac?
brew_if_missing "ripgrep", cmd: "rg"
brew_if_missing "slides"
brew_if_missing "starship"
brew_if_missing "stellar-cli", cmd: "stellar"
brew_if_missing "tig"
brew_if_missing "tmux"
brew_if_missing "tree"
brew_if_missing "watchexec"
brew_if_missing "zstd"
brew_if_missing "prettier"

brew_if_missing "rustup"
brew_if_missing "sccache"
brew_if_missing "go"
brew_if_missing "deno"
brew_if_missing "node"
brew_if_missing "uv"
brew_if_missing "zig"

brew_if_missing "neovim", cmd: "nvim"
brew_if_missing "lua-language-server"
brew_if_missing "gopls"
brew_if_missing "zls"
brew_if_missing "vscode-langservers-extracted", cmd: "vscode-json-language-server"

go "github.com/leighmcculloch/gas/v3"
go "github.com/leighmcculloch/gate"
go "github.com/github/github-mcp-server/cmd/github-mcp-server"

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

  cask "arc"
  cask "font-fira-code"
  cask "font-fira-code-nerd-font"
  cask "orbstack"
  cask "descript"
  cask "discord"
  cask "ghostty"
  cask "sublime-text"
  cask "lm-studio"
  cask "motion"
  cask "voiceink"
  brew "opencode"
  cask "claude"
  cask "claude-code"
  brew "gemini-cli"
  cask "granola"

  brew "mas"
  mas "Numbers", id: 409203825
  mas "Pages", id: 409201541
  mas "Day Progress", id: 6450280202
  mas "Audible", id: 379693831

  brew "stellar-core"

  #cask "tailscale-app"

  mdm_enrolled = `profiles status -type enrollment`.include?("Yes")

  if mdm_enrolled
    cask "nordlayer"
    mas "Slack", id: 803453959
    mas "Telegram", id: 747648890
    tap "fastrepl/hyprnote"
    cask "fastrepl/hyprnote/hyprnote", args: { require_sha: false }
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
