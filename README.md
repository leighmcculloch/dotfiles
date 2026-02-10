# dotfiles

Personal dotfiles managed with symlinks and Homebrew.

## Install

```
./install.sh
```

The install script:

1. Symlinks everything in `files/` to `~/` as dotfiles
2. Installs Homebrew (if not present)
3. Installs packages from `Brewfile`

## Structure

- `files/` - Dotfiles symlinked to `~/` (e.g. `files/gitconfig` becomes `~/.gitconfig`)
- `Brewfile` - Homebrew packages, casks, and Mac App Store apps
- `install.sh` - Setup script
