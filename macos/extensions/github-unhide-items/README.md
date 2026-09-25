# GitHub Unhide Items

A Chrome extension that automatically loads hidden timeline items on GitHub pull request and issue pages.

When a page contains GitHub's `Load more…` pagination button for hidden items, the extension clicks it and waits for the next batch to load. It continues until there are no more hidden-item buttons.

The extension only runs on `https://github.com` pull request and issue URLs. It has no permissions and does not make any requests itself; it uses GitHub's own page controls and session.

## Install locally

1. Open `chrome://extensions`.
2. Enable **Developer mode**.
3. Select **Load unpacked**.
4. Choose this directory: `macos/extensions/github-unhide-items`.
