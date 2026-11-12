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

The browser check observes local site search and catalogue query/filter/reset,
keyboard interaction, locale switching, no-JS content,
reduced motion and layout at 360 and 1280 pixels, including the catalogue,
layout, controls, styling, profiles and text-input pages and their localized images. Its screenshots need human
inspection; automated checks do not establish accessibility conformance or cover
other browsers and devices.
Both locale trees must contain each page. Explicit matching heading IDs are the
stable cross-language anchors. The language link retains the page key; with JS it
retains a hash only when that ID exists in the destination HTML. Without JS the
ordinary link still reaches the corresponding page without a hash.

The catalogue is an explicit `layout`, `controls`, `styling`, `profiles` and `text-input` sample, not complete coverage. The
schema-versioned `data/catalogue.json` and `data/media.json` are checked before
the build against the actual native section IDs, locale media, provenance,
PNG dimensions and digests. `npm run check:catalogue:strict` deliberately fails
until all 19 gallery and four Lab IDs have records and media. Do not change the
declared sample merely to hide missing coverage. Validation does not replace
image inspection, privacy review, or native qualification.

To update a capture, choose a clean pinned source and verify its native inputs;
use the isolated wrapper and retain its private logs and stop evidence as described
in `docs/isd.md`. Inspect each original image. Publish only a sanitized PNG and
relative, public-safe provenance; update its digest, locale, revision, source,
geometry, selected resource hashes, options, caption and alt in `data/media.json`,
and the corresponding localized pages. Run `npm run check`, `npm run build`,
and `npm run check:http`. The site build never launches Odin or captures images.
The private evidence is not part of the website. The layout viewer is a progressive
enhancement: both native initial viewport captures (1280×960 and 960×720) and
direct image links remain available without JavaScript. Open the viewer by pointer
or keyboard, select a viewport, and close with the button or Escape; focus stays in
the dialog and returns to its opener. There is no autoplay.

Site search uses VitePress's
local index; open it with the search button or Ctrl+K (Cmd+K on macOS), type a
query and use arrows and Enter to select a result. The catalogue searches the
active locale's title, summary and limitations plus shared IDs, category, package
and source metadata. Combine a query with a category and use Reset filters to
clear both. Search and filtering need JavaScript; static catalogue links and prose
remain available without it. Final coverage remains future work;
browser and deployment checks are separate.
