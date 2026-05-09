chrome.action.onClicked.addListener(async (tab) => {
  if (!tab.id || !tab.url || !tab.windowId) return;

  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

  const runInPage = async (func, args = []) => {
    const [{ result }] = await chrome.scripting.executeScript({
      target: { tabId: tab.id },
      func,
      args,
    });
    return result;
  };

  const m = await runInPage(() => ({
    totalWidth: Math.max(
      document.documentElement.scrollWidth,
      document.body ? document.body.scrollWidth : 0
    ),
    totalHeight: Math.max(
      document.documentElement.scrollHeight,
      document.body ? document.body.scrollHeight : 0
    ),
    viewportWidth: window.innerWidth,
    viewportHeight: window.innerHeight,
    originalScrollX: window.scrollX,
    originalScrollY: window.scrollY,
    originalScrollBehavior: document.documentElement.style.scrollBehavior,
    dpr: window.devicePixelRatio || 1,
  }));

  await runInPage(() => {
    document.documentElement.style.scrollBehavior = "auto";
    window.scrollTo(0, 0);
  });
  await sleep(300);

  const segments = [];
  let targetY = 0;
  let guard = 0;
  while (targetY < m.totalHeight && guard < 500) {
    const actualY = await runInPage((y) => {
      window.scrollTo(0, y);
      return window.scrollY;
    }, [targetY]);
    await sleep(250);

    const dataUrl = await chrome.tabs.captureVisibleTab(tab.windowId, {
      format: "png",
    });
    segments.push({ y: actualY, dataUrl });

    targetY += m.viewportHeight;
    guard++;
    await sleep(350);
  }

  await runInPage(
    (sx, sy, behavior) => {
      window.scrollTo(sx, sy);
      document.documentElement.style.scrollBehavior = behavior || "";
    },
    [m.originalScrollX, m.originalScrollY, m.originalScrollBehavior]
  );

  const canvas = new OffscreenCanvas(
    Math.round(m.totalWidth * m.dpr),
    Math.round(m.totalHeight * m.dpr)
  );
  const ctx = canvas.getContext("2d");

  for (const seg of segments) {
    const blob = await (await fetch(seg.dataUrl)).blob();
    const bmp = await createImageBitmap(blob);
    ctx.drawImage(bmp, 0, Math.round(seg.y * m.dpr));
    bmp.close();
  }

  const finalBlob = await canvas.convertToBlob({ type: "image/png" });
  const finalUrl = await new Promise((resolve) => {
    const reader = new FileReader();
    reader.onloadend = () => resolve(reader.result);
    reader.readAsDataURL(finalBlob);
  });

  const domain = new URL(tab.url).hostname;
  const now = new Date();
  const pad = (n) => String(n).padStart(2, "0");
  const stamp =
    `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())} ` +
    `${pad(now.getHours())}-${pad(now.getMinutes())}-${pad(now.getSeconds())}`;
  const filename = `Web Page ${domain} - ${stamp}.png`;

  await chrome.downloads.download({
    url: finalUrl,
    filename,
    saveAs: false,
  });
});
