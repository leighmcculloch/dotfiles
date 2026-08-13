# dotfiles

Personal configuration for macOS, dev containers, and Claude Code Cloud. Shared
Claude instructions and skills live in one place so the local and cloud setups
stay consistent.

This repository is tailored to Leigh's environment. Review the scripts and
configuration before using them on another machine.

## Repository layout

| Path | Purpose |
| --- | --- |
| `macos/install.sh` | Links the local dotfiles into the home directory, installs Homebrew when needed, and installs the packages in `macos/Brewfile`. |
| `macos/files/` | Files linked to `~/.<name>`, including shell, Git, SSH, Neovim, tmux, and Claude configuration. |
| `macos/extensions/` | Source for the browser extensions maintained in this repository. |
| `claude-cloud/install.sh` | Bootstraps a Claude Code Cloud environment and installs its development tools. |
| `claude-cloud/sync.sh` | Copies shared Claude configuration into the active home directory. |
| `shared/claude/` | Claude instructions and skills shared by the local and cloud setups. |

## macOS and dev containers

The installer requires `zsh`, `curl`, and an internet connection. Run it from
any directory after cloning the repository:

```sh
./macos/install.sh
```

For every item in `macos/files/`, the installer creates a corresponding hidden
symlink in the home directory. For example, `macos/files/gitconfig` becomes
`~/.gitconfig`. Existing symlinks are replaced; existing files and directories
are moved to the next available backup name such as `~/.gitconfig.bak0`.

The installer also:

- links the repository's SSH configuration into `~/.ssh/`;
- installs Homebrew if it is unavailable;
- installs `gh`, `nvim`, and `delta` as required tools; and
- runs `brew bundle install --no-upgrade` for the remaining formulae, casks, and
  Mac App Store apps in `macos/Brewfile`.

Homebrew bundle failures are reported but do not stop the installer, so review
its output for packages that need manual attention. The script is safe to rerun;
new backups are numbered rather than overwriting earlier ones.

## Claude Code Cloud

Set the environment's setup command to:

```sh
./claude-cloud/install.sh
```

This installer is specifically for the cloud environments provided by Claude
Code; it is not intended as a general-purpose Debian setup script. Within those
instances it uses `apt-get`, writes to `/usr/local/bin`, installs `zsh` and other
development packages, copies the shared Claude configuration into each known
home directory, and installs the repository's selected Stellar development
tools.

The installed shell configuration runs `claude-cloud/sync.sh` whenever a shell
starts. Claude's session hooks run the same sync, keeping `CLAUDE.md`, settings,
and shared skills aligned with the checked-out repository. The sync preserves
skills in `~/.claude/skills` that are owned by other sources.

To refresh the active home directory manually, run:

```sh
./claude-cloud/sync.sh
```
