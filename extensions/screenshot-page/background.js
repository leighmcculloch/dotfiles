chrome.action.onClicked.addListener(async (tab) => {
  if (!tab.id || !tab.url) return;

  const debuggee = { tabId: tab.id };

  try {
    await chrome.debugger.attach(debuggee, "1.3");

    const metrics = await chrome.debugger.sendCommand(
      debuggee,
      "Page.getLayoutMetrics"
    );
    const { width, height } = metrics.cssContentSize || metrics.contentSize;

    const result = await chrome.debugger.sendCommand(
      debuggee,
      "Page.captureScreenshot",
      {
        format: "png",
        captureBeyondViewport: true,
        clip: { x: 0, y: 0, width, height, scale: 1 },
      }
    );

    const domain = new URL(tab.url).hostname;
    const now = new Date();
    const pad = (n) => String(n).padStart(2, "0");
    const stamp =
      `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())} ` +
      `${pad(now.getHours())}-${pad(now.getMinutes())}-${pad(now.getSeconds())}`;
    const filename = `Web Page ${domain} - ${stamp}.png`;

    await chrome.downloads.download({
      url: "data:image/png;base64," + result.data,
      filename,
      saveAs: false,
    });
  } finally {
    try {
      await chrome.debugger.detach(debuggee);
    } catch (_) {}
  }
});
