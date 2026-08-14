# dotfiles

Personal dotfiles for two independent setups, with the small overlap kept in one place.

## Structure

- `macos/` — local macOS (and devcontainer) setup
  - `install.sh` — symlinks everything in `macos/files/` to `~/` (e.g. `files/gitconfig` becomes `~/.gitconfig`), installs Homebrew and packages
  - `files/` — dotfiles symlinked to `~/`
  - `Brewfile` — Homebrew packages, casks, and Mac App Store apps
  - `extensions/` — browser extensions
- `claude-cloud/` — Claude Code Cloud instance setup
  - `install.sh` — copies the shared config (`AGENTS.md` and `skills/`) into `~/.claude` and `~/.agents`
- `shared/` — files used by both setups
  - `AGENTS.md`, `skills/` — the agent config common to both (macOS symlinks these into `macos/files/claude/` and `macos/files/agents/`, as `CLAUDE.md`/`AGENTS.md` respectively)

## Install

macOS:

```
./macos/install.sh
```

Claude Code Cloud: configure the environment's setup command to run `./claude-cloud/install.sh`.
