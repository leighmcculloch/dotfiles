# dotfiles

Personal configuration for macOS, development containers, and Claude Code Cloud.
Shared Claude instructions and skills live in one place so the local and cloud
setups stay consistent.

This repository is tailored to Leigh's environment. Review the scripts and
configuration before using them on another machine.

## Repository layout

- `macos/install.sh` links local dotfiles into the home directory, installs
  Homebrew when needed, and installs packages from `macos/Brewfile`.
- `macos/files/` contains files linked to `~/.<name>`, including shell, Git,
  SSH, Neovim, tmux, and Claude configuration.
- `macos/extensions/` contains source for browser extensions maintained here.
- `claude-cloud/install.sh` bootstraps a Claude Code Cloud environment and
  installs its development tools.
- `claude-cloud/sync.sh` copies shared Claude configuration into the active home
  directory.
- `shared/claude/` contains Claude instructions and skills shared by the local
  and cloud setups.

## macOS and development containers

The installer requires Zsh, `curl`, and an internet connection. Run it from any
directory after cloning the repository:

```sh
./macos/install.sh
```

For every item in `macos/files/`, the installer creates a corresponding hidden
symlink in the home directory. For example, `macos/files/gitconfig` becomes
`~/.gitconfig`. Existing symlinks are replaced; existing files and directories
are moved to the next available backup name, such as `~/.gitconfig.bak0`.

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

This installer is specifically for Claude Code Cloud environments, not as a
general-purpose Debian setup script. It uses `apt-get`, writes tools to
`/usr/local/bin`, installs configuration into the current home plus the standard
`root` and `claude` homes, and requires the permissions to do so.

The installed shell configuration runs `claude-cloud/sync.sh` whenever a shell
starts. Claude's session hooks run the same sync, keeping `CLAUDE.md`, settings,
and shared skills aligned with the checked-out repository. The sync preserves
skills in `~/.claude/skills` that are owned by other sources.

To refresh the active home directory manually, run:

```sh
./claude-cloud/sync.sh
```
