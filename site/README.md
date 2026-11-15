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
host option. `check` validates page-key and explicit anchor parity, internal page
links and published `/media` assets, and includes negative fixtures for a missing
counterpart, a broken link and a digest mismatch; `build` runs `check` before
compiling.
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
layout, controls, styling, profiles, layers, HUD, text-input, Atlas, scroll-table,
collections, Lab menu and basic menu recipe pages and their localized images. Its screenshots need human
inspection; automated checks do not establish accessibility conformance or cover
other browsers and devices.
Both locale trees must contain each page. Explicit matching heading IDs are the
stable cross-language anchors. The language link retains the page key; with JS it
retains a hash only when that ID exists in the destination HTML. Without JS the
ordinary link still reaches the corresponding page without a hash.

The catalogue is an explicit `layout`, `controls`, `styling`, `profiles`, `layers`,
`hud`, `text`, `rich-text`, `text-input`, `atlas`, `scroll-table`, `collections` and
`lab-menu` sample of twelve gallery sections and one of the four Lab screens, not complete coverage. The
schema-versioned `data/catalogue.json` and `data/media.json` are checked before
the build against the actual native section IDs, locale media, provenance,
PNG dimensions and digests. `npm run check:catalogue:strict` deliberately fails
until all 19 gallery and four Lab IDs have records and media. Do not change the
declared sample merely to hide missing coverage. Validation does not replace
image inspection, privacy review, or native qualification.

## Continuous integration

`.github/workflows/pr-site.yml` defines one pull-request workflow with three
required jobs. It runs only for pull requests that touch `site/**`,
`consumer/**`, `kit/**`, `resources/**` or the workflow itself. Permissions are
`contents: read`; there are no secrets, deploy steps, Pages configuration or
`pull_request_target` trigger, because the site has no deployment. The `static`
job installs from the lockfile and runs `npm run check`, `npm run build` and
`npm run check:http`; it never runs Odin, native snippets, captures or graphics.
The `browser` job rebuilds and runs `npm run check:browser`; it needs Linux
Chromium at `/usr/bin/chromium` with a working sandbox. The `native` job runs
`npm run check:native` without `npm ci` (those scripts use Node builtins only):
it executes the `odin` build/test commands published by the recipe, Lab and
capability pages from the repository root and verifies their launch lines
structurally. It requires the pinned toolchain and fails loudly when any part is
missing; it does not skip. The guide pages' acquisition and portable-root shell
blocks are not executed, but they are reported explicitly and their launch lines
are still verified; the no-skip guarantee applies to the pinned toolchain,
command failures and timeouts.

The pinned native environment is Odin `dev-2026-10-nightly:84bc3fc`, SDL3
`3.4.16`, SDL3_ttf `3.2.2` and libpng `1.6.59` with zlib `1.4` in a private
prefix, as recorded in `docs/resources.md`. On this machine the commands of all
three lanes were verified with Node 24.22.3, Chromium 152 and the pinned Odin.
Their execution on GitHub-hosted runners (the ubuntu-24.04 image lists Chromium
157) has not been observed from this work, and no verified native CI runner
exists yet. That is an open environment blocker: a successful native-free
`static` lane does not replace the required native gate.

`npm run check:catalogue:strict` is deliberately not in CI. It fails until all 19
gallery and four Lab IDs have records and media; CI validates the declared sample
and does not hide the coverage gap by changing it.

To update a capture, choose a clean pinned source and verify its native inputs;
use the isolated wrapper and retain its private logs and stop evidence as described
in `docs/isd.md`. Inspect each original image. Publish only a sanitized PNG and
relative, public-safe provenance; update its digest, locale, revision, source,
geometry, selected resource hashes, options, caption and alt in `data/media.json`,
and the corresponding localized pages. The site build never launches Odin or
captures images. Run `npm run check && npm run build && npm run check:http &&
npm run check:browser`. A stale digest is rejected by the
digest negative fixture, and broken internal pages or `/media` assets are rejected
by the link check.

The Lab menu initial English capture rehearsed this flow for `oui-3no.24`: the
coordinator re-captured from the clean `b4c8be17b81125f4d1ef44b97de99d8c327825fb`
worktree through the ISD wrapper, confirmed the state log (Lab menu page,
`lab/submenu` focus, ready) and recomputed the SHA-256. The render was
byte-identical to the committed PNG
(`1d0d0a6e4d3235d9015501696de231562347ab2a51b1d0c986f200442fecd17c`), so the
digest was unchanged and only `revision` in `data/media.json` plus the page's
runtime-sources pin changed; the runtime-sources pin records where the shown
image was captured, not every document the page references. A capture whose bytes
differ must update its digest explicitly. To run `npm run check:native` locally,
point `PKG_CONFIG_PATH` and `LD_LIBRARY_PATH` at the private codec prefix described
in `docs/resources.md` (`pkg-config --libs libpng zlib` and the matching loader
path).
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
