# Paste PR

A macOS menu bar app that converts a GitHub pull request link on the clipboard into a rich text entry. Copy a PR link, press **⇧⌘P**, and the clipboard contents are replaced with a formatted, rich text summary of the PR ready to paste anywhere (Slack, email, docs, etc.).

The pasted result looks like:

> :github-rainbow: Add the thing [my-repo#123](https://github.com/owner/my-repo/pull/123) `+42 -7`

## Requirements

Paste PR uses the [GitHub CLI](https://cli.github.com) (`gh`) to fetch pull request details, so `gh` must be installed and authenticated:

```
brew install gh
gh auth login
```

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

1. Copy a GitHub pull request link (e.g. `https://github.com/owner/repo/pull/123`).
2. Press **⇧⌘P**, or click the pull request icon in the menu bar and select **Convert PR Link to Rich Text**.
3. Paste. The clipboard now contains a rich text summary of the PR, with a Markdown plain-text fallback.

The menu bar icon briefly changes to a checkmark on success or an X if the clipboard has no PR link or the PR could not be fetched.

## Options

- **Launch at Login** — available in the menu bar dropdown.
