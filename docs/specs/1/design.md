# Bilingual visual documentation — technical design D1

Input: [requirements R1](spec.md#requirements-r1), feature
[atilla777/oui#1](https://github.com/atilla777/oui/issues/1).
Baseline: oui `c32cd1f592ebe6056c37a4d3ad0fac22468a1a6e`.

## Approach and boundaries

Use VitePress for pre-rendered Markdown, localized navigation and local search;
small Vue components add a gallery, filters, state selector and accessible image
viewer. It is a documentation frontend, not another implementation of oui.
Existing Odin packages and native consumers stay unchanged. Screenshots are
generated outside the site build using the existing verified ISD route.

Use a separate `site/` root so existing technical docs, historical qualification
records and extraction `inventory.json` retain their meaning. Native builds do
not install Node. Prefer stable VitePress (1.6.4 is the observed stable line on
2026-11-12; the main upstream guide currently describes 2.0 alpha). During the
first task verify actual stable-version support, lock dependencies and a compatible
supported Node LTS/npm toolchain, and record them. Do not adopt alpha-only features
from current upstream docs by accident. A material framework change needs a decision;
an exact stable patch/toolchain pin is an implementation detail checked by build.

## Responsibilities and prospective paths

These are implementation contracts, not files already present:

| Owner | Path / responsibility |
| --- | --- |
| Site tooling | `site/package.json`, npm lockfile, Node version declaration; install/build/preview/check commands run from `site/`. |
| Routing/theme | `site/.vitepress/`; `/oui/` base, EN/RU locales, local search, localized chrome, small shared components. |
| Page content | `site/en/` and `site/ru/`; identical logical paths for guide, catalogue, recipes, architecture and limits. |
| Gallery data | `site/data/catalogue.json`; language-independent section IDs, category/package/source relationships, locale-specific display text and media references. |
| Media | `site/public/media/` plus `site/data/media.json`; committed optimized images and public-safe provenance, never raw private ISD run directories. |
| Check tooling | `site/scripts/` and browser tests; data/locale/link/media/snippet validation and interaction checks. |
| Maintainer guide | `site/README.md`; exact prerequisites/commands, capture/update/review and deployment procedures. |
| Delivery | `.github/workflows/`; PR checks and separate main/manual Pages deployment, root `README.md` links after verified delivery. |

Only the website owns browser filter/query/image-viewer state. No native model or
mutation is exposed. Technical contracts stay with `docs/` and actual Odin source.
Website pages summarize and link them at explicit revisions where version-sensitive;
do not move or rewrite the historical docs to make site routing easier.

## Stable content and media contracts

- Logical page key is the locale-relative path, e.g. `capabilities/text-input`.
  Every EN key has an RU counterpart. Root `site/index.md` is a static English
  entry with explicit EN/RU links, not a server-side redirect requirement.
  Locale switching uses page keys and the configured base, preserves an anchor
  only if present in the destination, and does not silently send readers home.
- `catalogue.json` has a schema version and records keyed by actual showcase
  section ID, group (`gallery` or `lab`), categories, selected packages, source and
  runnable reference. Localized title/summary/limitations use explicit `en`/`ru`
  entries. The data file is the site's index, not a native plugin registry.
  Prose stays Markdown; do not duplicate full contract text in JSON.
- `media.json` has a schema version and stable media IDs. Each record identifies
  the section, state, actual UI locale or justified language-neutral capture,
  full oui commit and source paths, logical window and physical drawable sizes,
  scale, resource hashes, relevant nonsecret fixture/options, public relative
  image path and SHA-256, localized caption/alt and a sanitized ISD identity.
  Keep private build/PNG/log/cleanup evidence locally for review; public manifests
  contain no absolute machine paths, socket addresses or session identities.
- Task 1 implements and tests these schemas using one real gallery sample and
  reusable components. Task 2 fills the remaining sections and Lab. Draft builds
  can explicitly validate only their declared sample set; final completion must
  enable the strict complete-source-catalogue check. Never satisfy coverage by
  fabricating images or disabling the check silently.
- Capture at a clean pinned source revision. If native source changes, recapture
  affected media or explicitly retain a visibly versioned historical example;
  unrelated docs-only commits do not require rerunning unchanged native captures.
  Do not edit `inventory.json` to masquerade new documentation as original export.

## Data flow and failure handling

1. Maintainer chooses exact oui revision/section/state and approved native/ISD
   environment. Existing `scripts/ui_isd.py` verifies the full selected ISD before
   create; require `linux-abstract-v1`, own run, explicit focus and stop in finally.
2. Capture, inspect PNG and preserve run/cleanup evidence. Sanitize a public copy,
   respecting resource notices. Record source/environment/state and image hash.
   Missing native dependencies, unsafe isolation or failed cleanup block that
   capture; never fall back to the main display or label stale media current.
3. Author EN/RU content referencing stable media IDs and actual code. Prefer linked
   complete existing consumers. A snippet presented as executable must have a
   complete compiled fixture with exact selected imports/collection/resource flags;
   genuinely illustrative fragments are labeled as fragments, not runnable examples.
4. Build validates data, locale parity, assets/links and examples before emitting
   static HTML. The build never launches the native app or downloads/captures media.
5. Browser gallery filters/searches published metadata; empty results offer reset.
   Viewer traps focus, closes with Escape/close button and restores its trigger.
   Images have useful alt/captions, reduced motion avoids nonessential animation,
   videos if present are optional/no autoplay. No-JS HTML retains prose and images.
6. PR builds need read-only permissions and do not deploy untrusted changes.
   Reviewed main/manual delivery uses the standard Pages artifact/deploy flow,
   scoped Pages/OIDC permissions and deployment concurrency. A failed build does
   not replace the live site; retry publication only after reconciling actual effects.
   Pages base is `/oui/`, without a custom domain. Never infer publication from CI
   success alone: inspect actual deployment and fresh HTTP routes/assets.

## Test seams and coverage

| Requirements | Owner / observation |
| --- | --- |
| AC-001,002 | Task 1: locked build/HTTP preview, page-key parity, locale routes/anchors, localized chrome and local search. |
| AC-003,005,008 | Task 2: compare catalogue IDs to source; validate all image references/digests/provenance; inspect each PNG and factual coverage. Task 1 establishes one genuine sample first. |
| AC-004,009 | Task 1 defines browser interaction/accessibility scenarios; task 2 exercises them with complete data; task 4 reruns both locales at 360/1280 widths. |
| AC-006,007 | Task 3: four recipes and acquisition/package/lifecycle guide, compile fixtures and actual native command verification with safe agent graphics. |
| AC-010 | Each task adds checks for its result; task 4 enforces strict integrated validation including negative link/asset/locale/media/ID/snippet fixtures and update rehearsal. |
| AC-011 | Task 4: CI/Pages least privilege, common integrated revision and deployed nested-page/search/asset read-back. |
| AC-012 | Every task checks its diff; task 4 verifies the integrated scope. |

Use a small browser smoke suite (e.g. Playwright) for both locales; record actual
supported test-browser/tool versions in task 1. Prefer library-provided search and
navigation before custom code. Do not assert accessibility conformance from an
automated scan alone. Native example checks require the pinned Odin/SDL/TTF and,
for showcase, codec resources documented in `docs/resources.md`; ordinary static
site builds do not require this native environment.

## Basis, alternatives and risks

D1 implements the selected VitePress/static/real-media plan. Path layout, schemas,
local search, stable tooling pins and check seams are bounded implementation
guidance, not new UI semantics or evidence of human line-by-line design approval.
The user requested saving actionable preparation; no additional unresolved product
choice is introduced. No configured RIS execution roles/tracker are assumed.

Hand-written HTML was rejected for duplicate navigation/translation maintenance;
a WASM port and HTML replicas are explicitly excluded. Main risks are misleading
screenshots, drifting translations, stale API prose and platform dependency failures;
versioned evidence, shared IDs, source links and separate native/site checks address
them. Pages API returned 404 during preparation: hosting is not established, and
must be enabled/verified during task 4 under then-applicable authority.

Upstream references consulted 2026-11-12:
[VitePress i18n](https://vitepress.dev/guide/i18n),
[deployment/base path](https://vitepress.dev/guide/deploy),
[stable documentation](https://vuejs.github.io/vitepress/v1/).
Native safety and package constraints: [`docs/isd.md`](../../isd.md),
[`docs/api.md`](../../api.md), [`docs/resources.md`](../../resources.md).
