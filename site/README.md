# oui site foundation

The static site is separate from the native kit; building it does not run Odin or
capture graphics. It uses VitePress 1.6.4 (stable), Node 24.22.3 LTS and npm 11.
Node's [release schedule](https://nodejs.org/en/about/previous-releases) lists 24
as LTS; the [stable VitePress documentation](https://vuejs.github.io/vitepress/v1/)
identifies 1.6.4. Use the Node version in `.nvmrc` with a compatible npm 11.

VitePress 1.6.4 depends on unsupported Vite 5.4.21; the observed npm audit
reports unresolved findings (two moderate, one high). On 2026-11-12 the owner
accepted this limitation for the foundation. Do not run the VitePress dev server:
use the build and the site's own loopback-only static preview. This exception
does not establish that the risks are gone; future support changes require
assessment.

From `site/`:

```sh
npm ci
npm run check
npm run build
npm run check:http
npm run check:browser
npm run preview -- --port 4173
```

Open `http://127.0.0.1:4173/oui/`; stop the preview with Ctrl-C. Choose another
free port if needed. The preview binds only to `127.0.0.1`; it never accepts a
host option. `check` validates page-key and explicit anchor parity and includes
a missing-counterpart negative fixture; `build` runs `check` before compiling.
Run `check:http` separately after the build: it starts and stops an isolated
preview on a dynamically allocated port and checks routes, chrome and assets.
`check:browser` requires Linux Chromium at `/usr/bin/chromium`, a working Chromium
sandbox and readable `/proc`. It uses pinned `playwright-core` without downloading
a browser, starts its own loopback preview, and launches headless Chromium with
fresh temporary profiles and no desktop connection. Page requests outside the
preview are blocked. Set `OUI_BROWSER_ARTIFACT_ROOT` to a writable directory to
retain the generated screenshots and profiles there; capture the command's output
separately as a log. It closes its browsers and preview even on failure.
For example, on this machine:

```sh
PROOF="$(mktemp -d /tmp/opencode/oui-site-browser.XXXXXXXX)"
OUI_BROWSER_ARTIFACT_ROOT="$PROOF" npm run check:browser 2>&1 | tee "$PROOF/browser.log"
```

The browser check observes keyboard interaction, locale switching, no-JS content,
reduced motion and layout at 360 and 1280 pixels. Its screenshots need human
inspection; automated checks do not establish accessibility conformance or cover
other browsers and devices.
Both locale trees must contain each page. Explicit matching heading IDs are the
stable cross-language anchors. The language link retains the page key; with JS it
retains a hash only when that ID exists in the destination HTML. Without JS the
ordinary link still reaches the corresponding page without a hash.

This is a local preview, not a deployment or native qualification. Search,
gallery, media, and deployment are outside this foundation.
