# GitHub Events

GitHub Events is a macOS menu bar app that keeps an activity column for each
configured GitHub username. Click the menu bar icon to browse recent public
events, including full Markdown-rendered issue, pull request, and commit
comments.

## Install

Requires macOS 13 or later and Swift 5.9 or later.

```sh
make install
open "/Applications/GitHub Events.app"
```

## Use

Open the menu bar popover, select the gear button, and add one or more GitHub
usernames. Each username gets its own vertically scrollable column; the whole
popover can scroll horizontally when several usernames are configured.

The app polls GitHub's public events endpoint using conditional requests. It
stores fetched events, page cursors, HTTP validators, and seen event IDs in
Application Support so reopening the app does not download historical pages
again. Scroll toward the bottom of a column to fetch the next historical page.
Events that were visible in a previous session are shown more subtly.

No GitHub token is required. GitHub's public events feed is limited to recent
activity and may have delivery latency.
