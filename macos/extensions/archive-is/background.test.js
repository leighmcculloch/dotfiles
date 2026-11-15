import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { createServer } from "node:http";
import { test } from "node:test";
import { runInNewContext } from "node:vm";

const source = readFileSync(new URL("./background.js", import.meta.url), "utf8");

async function click(url, fetchImplementation = fetch) {
  let listener;
  let updated;
  runInNewContext(source, {
    URL,
    AbortSignal,
    fetch: fetchImplementation,
    chrome: {
      action: { onClicked: { addListener: (fn) => { listener = fn; } } },
      tabs: { update: (id, options) => { updated = { id, url: options.url }; } },
    },
  });
  await listener({ id: 42, url });
  return updated;
}

test("follows redirect chains, unwraps subscriptions, and archives a blocked article", async (t) => {
  const article = "/news/story?id=3511&edition=test%20edition";
  const server = createServer((req, res) => {
    if (req.url === "/t.co") {
      res.writeHead(301, { Location: "/bit.ly" });
    } else if (req.url === "/bit.ly") {
      res.writeHead(302, {
        Location: "/subscribe?dest=" + encodeURIComponent(base + "/article-link"),
      });
    } else if (req.url === "/article-link") {
      res.writeHead(307, { Location: article });
    } else if (req.url === article) {
      res.writeHead(403);
    }
    res.end();
  });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  t.after(() => new Promise((resolve) => {
    server.close(resolve);
    server.closeAllConnections();
  }));
  const base = `http://127.0.0.1:${server.address().port}`;

  assert.deepEqual(await click(base + "/t.co"), {
    id: 42,
    url: "https://archive.is/" + base + article,
  });
});

test("unwraps nested, double-encoded URLs without decoding the article's own query", async () => {
  const article = "https://news.example/story?name=A%26B&next=%2Fnews#section";
  const subscription = "https://news.example/subscribe?dest=" + encodeURIComponent(article);
  const wrapper = "https://news.example/login?returnTo=" +
    encodeURIComponent(encodeURIComponent(subscription));
  let request;
  const result = await click(wrapper, async (url, options) => {
    request = { url, credentials: options.credentials };
    throw new Error("Network unavailable");
  });
  assert.deepEqual(request, { url: article, credentials: "omit" });
  assert.equal(result.url, "https://archive.is/" + article);
});

test("ignores malformed and non-HTTP destinations", async () => {
  const url = "https://news.example/subscribe?bad=%E0%A4%A&next=javascript%3Aalert(1)";
  assert.equal((await click(url, async () => { throw new Error("Offline"); })).url,
    "https://archive.is/" + url);
});

test("leaves archive.is and non-web tabs alone", async () => {
  for (const url of [undefined, "chrome://extensions", "file:///tmp/story", "https://archive.is/abc"]) {
    assert.equal(await click(url, () => assert.fail("must not fetch")), undefined);
  }
});

test("stops when redirects and embedded destinations form a cycle", async () => {
  const url = "https://news.example/article";
  let requests = 0;
  const result = await click(url, async () => {
    requests++;
    return { url: "https://news.example/subscribe?dest=" + encodeURIComponent(url) };
  });
  assert.equal(result.url, "https://archive.is/" + url);
  assert.equal(requests, 1);
});
