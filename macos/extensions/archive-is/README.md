# Archive.is Redirect

A Chrome extension that redirects the current page through [archive.is](https://archive.is). Click the extension icon and the current tab navigates to the archived version of the page.

## Usage

Click the extension icon in the toolbar. The extension follows HTTP redirects (including chains such as t.co → bit.ly → article) and unwraps HTTP/HTTPS destination URLs embedded in query parameters, such as a subscription page's `dest` or `url` parameter. Nested wrappers and repeatedly URL-encoded destinations are supported.

The current tab then navigates to `https://archive.is/<destination_url>`. If a request fails or times out, it uses the last resolved URL. JavaScript and HTML meta-refresh redirects are not followed.

HTTP/HTTPS host permissions are needed to resolve redirects across sites. Requests are made only when the extension icon is clicked, without sending cookies. Reload the extension at `chrome://extensions` after updating it and approve the new permissions if prompted.

## Tests

Run `node --test macos/extensions/archive-is/background.test.js` from the repository root.
