# dotfiles

Personal configuration for macOS, development containers, and Claude Code Cloud.
The platform-specific installers share the Claude instructions and skills in
`shared/` while keeping the rest of each environment independent.

## Repository layout

| Path | Purpose |
| --- | --- |
| `macos/files/` | Home-directory files and application configuration |
| `macos/Brewfile` | Homebrew formulae, casks, and Mac App Store applications |
| `macos/extensions/` | Source for browser extensions |
| `claude-cloud/` | Installer, sync script, settings, and hooks for cloud instances |
| `shared/claude/` | Claude instructions and skills used by both environments |

## macOS and development containers

Run the installer from any directory:

```sh
./macos/install.sh
```

The installer:

- links each entry in `macos/files/` into the home directory (for example,
  `gitconfig` becomes `~/.gitconfig`);
- preserves an existing file or directory as the next available `*.bakN` backup;
- installs Homebrew when it is unavailable; and
- installs command-line tools and macOS applications from `macos/Brewfile`.

The script requires Zsh and an internet connection. A development container can
use this repository as its dotfiles source and invoke `macos/install.sh` after
cloning it.

Re-run the installer to refresh symlinks and install newly added packages.
Homebrew packages already installed are not upgraded automatically.

## Claude Code Cloud

Set the environment's setup command to:

```sh
./claude-cloud/install.sh
```

The installer targets the current home directory and the standard `root` and
`claude` homes. It installs its system dependencies, copies the shared Claude
instructions and skills into `~/.claude`, and configures hooks that keep those
files synchronized with the checkout. It requires a Debian-compatible environment
with `apt-get`, root privileges, and internet access.

To refresh only the Claude configuration in the current home directory, run:

```sh
./claude-cloud/sync.sh
```

The sync script updates files owned by this repository without removing unrelated
skills already present in `~/.claude/skills`.
