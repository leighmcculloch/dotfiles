(() => {
  "use strict";

  const PULL_OR_ISSUE_PATH = /^\/[^/]+\/[^/]+\/(?:pull|issues)\/\d+(?:\/|$)/;
  const LOAD_MORE_BUTTON_SELECTOR =
    "form.ajax-pagination-form button.ajax-pagination-btn, " +
    "form.js-ajax-pagination button.ajax-pagination-btn";
  const MAX_CLICKS_PER_PASS = 1000;
  const REQUEST_TIMEOUT_MS = 15000;
  const POLL_INTERVAL_MS = 100;
  const SETTLE_DELAY_MS = 200;

  let expansionInProgress = false;
  let expansionRequested = false;

  const sleep = (milliseconds) =>
    new Promise((resolve) => setTimeout(resolve, milliseconds));

  const isPullRequestOrIssuePage = () =>
    window.location.hostname === "github.com" &&
    PULL_OR_ISSUE_PATH.test(window.location.pathname);

  const isLoadMoreButton = (button) => {
    const label = (button.textContent || "").replace(/\s+/g, " ").trim();
    return /^load more\b/i.test(label);
  };

  const getLoadMoreButtons = () =>
    Array.from(document.querySelectorAll(LOAD_MORE_BUTTON_SELECTOR)).filter(
      (button) =>
        isLoadMoreButton(button) &&
        !button.disabled &&
        button.getAttribute("aria-disabled") !== "true"
    );

  const waitForPaginationToFinish = async (
    button,
    form,
    beforeAction,
    startRequest
  ) => {
    let sawChange = false;
    let settled = false;
    const observedNode = form.parentElement || form;

    const observer = new MutationObserver(() => {
      sawChange = true;
    });

    observer.observe(observedNode, {
      attributes: true,
      childList: true,
      characterData: true,
      subtree: true,
    });

    try {
      startRequest();
      const deadline = Date.now() + REQUEST_TIMEOUT_MS;

      while (Date.now() < deadline) {
        await sleep(POLL_INTERVAL_MS);

        const buttonWasReplaced = !button.isConnected;
        const formWasReplaced = !form.isConnected;
        const isLoading =
          !buttonWasReplaced &&
          (button.disabled || /loading/i.test(button.textContent || ""));
        const actionChanged =
          !formWasReplaced && form.getAttribute("action") !== beforeAction;

        if (buttonWasReplaced || formWasReplaced || actionChanged) {
          sawChange = true;
        }

        if (sawChange && !isLoading) {
          settled = true;
          await sleep(SETTLE_DELAY_MS);
          return true;
        }
      }
    } finally {
      observer.disconnect();
    }

    return settled || sawChange;
  };

  const clickAndWaitForPagination = async (button) => {
    const form = button.closest("form");
    if (!form) return false;

    const beforeAction = form.getAttribute("action");
    return waitForPaginationToFinish(button, form, beforeAction, () => {
      button.click();
    });
  };

  const expandHiddenItems = async () => {
    let clicks = 0;

    while (clicks < MAX_CLICKS_PER_PASS) {
      if (!isPullRequestOrIssuePage()) return;

      const button = getLoadMoreButtons()[0];
      if (!button) return;

      const requestStarted = await clickAndWaitForPagination(button);
      clicks += 1;

      if (!requestStarted) return;
    }
  };

  const scheduleExpansion = () => {
    if (!isPullRequestOrIssuePage()) return;

    if (expansionInProgress) {
      expansionRequested = true;
      return;
    }

    expansionInProgress = true;
    expandHiddenItems().finally(() => {
      expansionInProgress = false;

      if (expansionRequested) {
        expansionRequested = false;
        scheduleExpansion();
      }
    });
  };

  const observer = new MutationObserver(() => {
    if (expansionInProgress) {
      expansionRequested = true;
    } else if (getLoadMoreButtons().length > 0) {
      scheduleExpansion();
    }
  });

  const start = () => {
    observer.observe(document.documentElement, {
      childList: true,
      subtree: true,
    });
    scheduleExpansion();
  };

  window.addEventListener("load", scheduleExpansion, { once: true });
  document.addEventListener("turbo:load", scheduleExpansion);
  window.addEventListener("popstate", scheduleExpansion);
  window.addEventListener("hashchange", scheduleExpansion);

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", start, { once: true });
  } else {
    start();
  }
})();
