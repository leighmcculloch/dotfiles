chrome.action.onClicked.addListener((tab) => {
  if (!tab.url) return;

  const match = tab.url.match(/^https:\/\/github\.com\/([^/]+\/[^/]+)\/pull\/(\d+)/);
  if (!match) return;

  const repo = match[1];
  const prNumber = match[2];
  const prUrl = `https://github.com/${repo}/pull/${prNumber}`;
  const prompt = `/pr-code-review-pr-draft-comments ${prUrl}`;
  const claudeUrl = `https://claude.ai/code?prompt=${encodeURIComponent(prompt)}&repositories=${repo}`;

  chrome.tabs.create({ url: claudeUrl });
});
