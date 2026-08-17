# menu-bar-usage-codex

Show remaining usage of a Codex subscription in the macOS menu bar.

Codex Usage is a small, native menu bar app. It shows the lowest remaining percentage across the active Codex rate-limit windows with a compact countdown to the next reset, such as `83% 2d 4h`.

## How it works

The app does not implement another login flow and never asks for an API key. It launches the `codex app-server` shipped with the installed ChatGPT/Codex client and calls its `account/rateLimits/read` method. The app-server reuses the existing Codex authentication in `~/.codex`, so the app only works when Codex is already installed and signed in.

The displayed percentage is `100 - usedPercent`, using the lowest value from the primary and secondary rate-limit windows. Hover over it to see each window's reset date and time remaining. A `—` means the installed client is unavailable, not signed in, offline, or returned no usable window. Click the status item for refresh, usage settings, launch-at-login, and quit.

## Homebrew

The formula currently installs the latest commit from `main`:

```sh
brew install --HEAD leighmcculloch/menu-bar-usage-codex/codex-usage
ln -sf "$(brew --prefix codex-usage)/Codex Usage.app" /Applications/
open "/Applications/Codex Usage.app"
```

To upgrade to the latest commit later:

```sh
brew upgrade --fetch-head codex-usage
```

## Build and install

Requires macOS 13 or later and Swift 5.9 or later.

```sh
make install
open "/Applications/Codex Usage.app"
```

The app keeps the Codex app-server running, polls at most once per minute, avoids overlapping requests, backs off after errors, restarts the process if it exits unexpectedly, and also supports manual refresh from its menu.

## Important limitation

The personal ChatGPT-plan usage surface is provided by the Codex client/app-server rather than the public OpenAI API. The app intentionally uses the installed Codex client protocol instead of scraping ChatGPT pages or storing a second copy of the authentication token. Because that protocol ships with Codex, future Codex releases may change its response shape; malformed or unavailable responses fail closed to `—`.
