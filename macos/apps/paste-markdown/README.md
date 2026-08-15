# Paste Markdown

A macOS menu bar app that converts HTML on the clipboard to Markdown. Copy rich text from a website, press **⇧⌘M**, and the clipboard contents are replaced with Markdown ready to paste anywhere.

## Install

### Homebrew

```
brew tap leighmcculloch/paste-markdown
brew install --HEAD paste-markdown
```

To upgrade:

```
brew upgrade --fetch-head paste-markdown
```


## Use

1. Copy rich text (e.g. select text on a web page and copy).
2. Press **⇧⌘M**, or click the clipboard icon in the menu bar and select **Convert Clipboard to Markdown**.
3. Paste. The clipboard now contains Markdown.

The menu bar icon briefly changes to a checkmark on success or an X if the clipboard has no HTML content.

## Options

- **Launch at Login** — available in the menu bar dropdown.
