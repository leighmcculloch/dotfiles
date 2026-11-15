function embeddedDestination(url) {
  for (let value of new URL(url).searchParams.values()) {
    // URLSearchParams decodes once; some subscription links encode twice.
    for (let depth = 0; depth < 5; depth++) {
      if (/^https?:\/\//i.test(value)) {
        try {
          return new URL(value).href;
        } catch {
          break;
        }
      }
      try {
        const decoded = decodeURIComponent(value);
        if (decoded === value) break;
        value = decoded;
      } catch {
        break;
      }
    }
  }
}

async function resolveDestination(url) {
  const visited = new Set();
  const signal = AbortSignal.timeout(10000);

  for (let hop = 0; hop < 10 && !visited.has(url); hop++) {
    visited.add(url);
    const embedded = embeddedDestination(url);
    if (embedded) {
      url = embedded;
      continue;
    }

    try {
      const response = await fetch(url, {
        redirect: "follow",
        credentials: "omit",
        signal,
      });
      // Even a blocked article (e.g. HTTP 403) gives us its final URL.
      if (response.body) await response.body.cancel();
      url = response.url;
      if (!embeddedDestination(url)) break;
    } catch {
      // Still allow archiving when the destination cannot be fetched.
      break;
    }
  }

  return url;
}

chrome.action.onClicked.addListener(async (tab) => {
  if (!tab.url || !/^https?:\/\//i.test(tab.url)) return;
  if (new URL(tab.url).hostname === "archive.is") return;

  const destination = await resolveDestination(tab.url);
  await chrome.tabs.update(tab.id, {
    url: "https://archive.is/" + destination,
  });
});
