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
      const redirected = new URL(response.url);
      if (redirected.origin === new URL(url).origin && /^\/nocookies\/?$/.test(redirected.pathname)) {
        // A cookie-check page is not an article destination. Keep the URL
        // we requested rather than archiving the interstitial.
        if (response.body) await response.body.cancel();
        break;
      }
      // Even a blocked article (e.g. HTTP 403) gives us its final URL.
      url = response.url;
      let destination = embeddedDestination(url);
      if (!destination && new URL(url).hostname === "t.co") {
        // Chrome receives an HTTP 200 page, not a 301. Read its literal
        // destination without executing any of the page's JavaScript.
        const html = await response.text();
        const match = html.match(/location\.replace\(\s*("(?:\\.|[^"\\])*")\s*\)/);
        if (match) {
          const target = new URL(JSON.parse(match[1]), url);
          if (target.protocol === "http:" || target.protocol === "https:") {
            destination = target.href;
          }
        }
      } else if (response.body) {
        await response.body.cancel();
      }
      if (!destination) break;
      url = destination;
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
