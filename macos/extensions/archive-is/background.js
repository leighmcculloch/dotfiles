chrome.action.onClicked.addListener((tab) => {
  if (tab.url && !tab.url.startsWith("https://archive.is/")) {
    const archiveUrl = "https://archive.is/" + tab.url;
    chrome.tabs.update(tab.id, { url: archiveUrl });
  }
});
