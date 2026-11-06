# Paste PR

A macOS menu bar app that converts a GitHub pull request, stack, issue, or discussion link on the clipboard into a rich text entry. Copy a GitHub link, press **⇧⌘P**, and the clipboard contents are replaced with a formatted, rich text summary ready to paste anywhere (Slack, email, docs, etc.).

The pasted result looks like:

> :github-rainbow: Add the thing [my-repo#123](https://github.com/owner/my-repo/pull/123) `+42 -7`

Stack links (for example, `https://github.com/owner/my-repo/stack/13`) include every PR in stack order:

> :github-rainbow: Stack of 2 changes [my-repo#13](https://github.com/owner/my-repo/stack/13):
> - :one: Add the thing [my-repo#123](https://github.com/owner/my-repo/pull/123) `+42 -7`
> - :two: Extend the thing [my-repo#124](https://github.com/owner/my-repo/pull/124) `+12 -3`

## Requirements

Paste PR uses the [GitHub CLI](https://cli.github.com) (`gh`) to fetch pull request details, so `gh` must be installed and authenticated:

```
brew install gh
gh auth login
```

Discussion links require a GitHub CLI version that provides `gh discussion view`.

## Install

### Homebrew

```
brew install --HEAD leighmcculloch/paste-pr/paste-pr
```

To upgrade:

```
brew upgrade --fetch-head paste-pr
```


## Use

1. Copy a GitHub pull request, stack, issue, or discussion link (for example, `github.com/owner/repo/pull/123/changes`). The `https://` prefix is optional.
2. Press **⇧⌘P**, or click the menu bar icon and select **Convert GitHub Link to Rich Text**.
3. Paste. The rich-text clipboard contains the formatted summary, while the plain-text clipboard keeps the original link.

The menu bar icon briefly changes to a checkmark on success or an X if the clipboard has no supported GitHub link or the resource could not be fetched.

## Options

- **Launch at Login** — available in the menu bar dropdown.
- **Automatically Convert GitHub Links** — off by default. When enabled, newly copied supported GitHub pull request, stack, issue, and discussion links are converted automatically. Enabling it does not convert the clipboard value already present.
- **Configure Slack Emojis…** — choose the Slack emoji for pull requests and stack headers (shared default `:github-rainbow:`), issues (default `:github-link-issue:`), and discussions (default `:github-link-discussion:`). Previously saved emoji choices are preserved.
  - **PRs in stacks** accepts a comma-separated list of emojis for the 1st, 2nd, 3rd PR, and so on. Defaults are `:one:`, `:two:`, …, `:nine:`, `:keycap_ten:`. Blank or unspecified entries use the numbered default; positions beyond ten use plain numbers (`11.`, `12.`, …) unless configured. Colons are optional.

Automatic conversion rechecks clipboard ownership before and after replacement. macOS does not provide an atomic compare-and-write operation for the pasteboard, so a simultaneous external clipboard change can only be detected after the write.
