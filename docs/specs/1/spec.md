# Bilingual visual documentation for oui
Feature-ID: atilla777/oui#1
Summary: An English/Russian visual guide to oui's real capabilities, selected packages and runnable examples.

## Requirements R1

### Purpose and audience

A prospective user can discover what oui does without first installing Odin,
inspect actual rendered examples, understand limitations, and follow a path to
running or integrating a selected capability. Maintainers can update the guide
from this repository without depending on a Slyx checkout or an old conversation.

### Scope and behavior

- A static VitePress site lives in oui. English and Russian have equivalent
  substantive coverage, navigation, search UI, captions and alternative text.
  Canonical locale paths are `/en/` and `/ru/`, beneath the hosting base path.
  The root offers English as the default entry and a visible Russian link.
  Changing language retains the corresponding logical page; anchors are retained
  only when they exist in the target language. Code/API names/section IDs stay unchanged.
- A visual catalogue covers all 19 actual gallery section IDs, plus an overview
  of the four Integration Lab screens. It supports localized search/filtering,
  keyboard-operable image enlargement and switching documented screenshot states.
  Empty search/filter results have a clear localized message and reset action.
- Each capability has real native-showcase imagery, purpose, observable supported
  behavior, limitations, selected package names, source/example links and a native
  launch command. Sample content must distinguish library behavior from app-owned
  demo state and must not imply that oui runs in the browser.
- Include getting started (native requirements, exact-revision vendor/submodule,
  build/run), a package/dependency map, experimental compatibility and lifecycle
  guidance, and four practical recipes: menu, settings, HUD and inventory.
  Explain the optional layout-only and diagnostic/tooling paths by linking the
  existing six recipes, without making the full showcase a minimal dependency.
- Screenshot labels/captions correspond to the actually displayed language.
  Use both ru/en captures where meaningful localized UI text differs; language-
  neutral imagery may be shared with that fact recorded. Provide at least one
  screenshot for each gallery ID and each Lab screen. Motion videos are optional,
  never the sole explanation of a capability, and do not block this increment.
- Screenshots come from the real native consumer through the approved ISD wrapper.
  Record exact oui revision, section, UI locale, window/drawable sizes, scale,
  relevant state, resource identity and image digest. Public metadata excludes
  local absolute paths, sockets, credentials and private raw logs. Captioned media
  is version-specific evidence, not a claim about every future revision.
- Existing technical Markdown remains accessible. Reuse/link authoritative
  contracts rather than creating a competing API specification. New examples
  must compile against their stated revision and selected dependency closure.
- The built site works through local HTTP preview and GitHub Pages, including
  direct page loads and the `/oui/` base. Core prose/images/links remain readable
  without JavaScript; interactive search/filter/enlargement may require it.
  Do not promise `file://` interactivity or add external analytics/services.
- Supply documented content/media update and local build procedures, a CI check,
  and a Pages delivery route. Validate one common integrated revision before
  declaring the whole feature complete. Deployment permissions/settings are
  checked separately; a build artifact alone is not a published website.

### Acceptance criteria

| ID | Observable outcome and verification |
| --- | --- |
| AC-001 | Fresh checkout + documented locked install builds and locally serves the static site without Slyx; verify HTTP entry, nested routes and assets under `/oui/`. |
| AC-002 | EN/RU logical-page sets match; switching language preserves the page and valid anchors, HTML language is correct, and navigation/search/empty-state/captions are localized; automated parity plus browser checks. |
| AC-003 | All 19 gallery IDs and four Lab IDs from `consumer/ui_showcase/model/catalogue.odin` are represented with actual media; automated ID/media checks plus individual image inspection. |
| AC-004 | Search/filter finds capabilities in each locale, handles no matches/reset, image viewer opens/closes/restores focus, and documented state switches work by pointer and keyboard; browser scenarios in both languages. |
| AC-005 | Every capability explains behavior, packages, example/source, launch command and limitations; source review confirms no invented API, no browser-runtime claim, and app-owned state is distinguished. |
| AC-006 | Menu/settings/HUD/inventory recipes in both languages identify narrow dependencies and link actual runtime references; executable snippets compile and launch commands are checked on the stated native environment. |
| AC-007 | Getting started, acquisition, package map, lifecycle and experimental limits exist in both languages and agree with actual packages/contracts; example checks and editorial review. |
| AC-008 | Every public image has complete revision/state/capture provenance and matching digest, uses genuine ISD capture with cleanup evidence, and contains no private data; metadata validation and media/privacy review. |
| AC-009 | At 360px and 1280px viewport widths, navigation/content are readable without page-level overflow (code/tables may scroll locally); keyboard focus, dialog close/focus return, image alternatives, no-JS prose and reduced-motion behavior are inspected. |
| AC-010 | CI rejects a broken internal link/asset, missing locale counterpart/gallery ID/provenance and failing snippet check using meaningful negative fixtures; documented recovery/update instructions allow a maintainer to update one page/media pair. |
| AC-011 | Reviewed integrated site is delivered by a least-privilege Pages workflow; fresh HTTP checks confirm EN/RU nested pages/assets/search at its actual URL. If hosting settings are unavailable, report blocked delivery, not completion. |
| AC-012 | No changes to `kit/` public APIs, native consumer behavior, Slyx files/pins or existing extraction inventory; inspect the complete implementation diff and preservation of existing docs/resource notices. |

### Exclusions

No WASM port, browser UI reimplementation, backend/CMS/authentication, API redesign,
automatic source-to-prose translation, new library feature, exhaustive requalification
of oui, video-production requirement, custom domain, release/tag or Slyx update.
Documentation Node tooling is not a dependency of native oui consumers.

## Basis and decision scope

R1 records the user's selected website plan and explicit EN/RU amendment, followed
by the request to save artifacts and tasks so implementation can start (2026-11-12).
The dialogue selected VitePress, the real-screenshot catalogue, Lab overview, four
recipes, technical guidance, checks and Pages preparation. English-default was
stated in the amended plan and not overridden. No claim is made that the user
reviewed this exact file line-by-line; measurable checks operationalize that scope.
Requirements R1 and technical design D1 are separately identifiable documents.
No RIS policy acceptance, independent approval or implementation pass is inferred
from saving these files or creating GitHub issues.

Observed source basis: oui `c32cd1f592ebe6056c37a4d3ad0fac22468a1a6e`,
[`catalogue`](../../../consumer/ui_showcase/model/catalogue.odin),
[`API map`](../../api.md), [`recipes`](../../recipes.md),
[`lifecycle`](../../lifecycle.md), [`resources`](../../resources.md),
[`ISD safety`](../../isd.md). Counts are 19 gallery entries (one combines G20/G21)
and four Lab entries, not 21 gallery pages. Preserve actual limitations.

No unresolved product choice is known. Hosting availability and the actual
Node/VitePress/native/ISD environment are implementation preflights, not assumed
successful checks. If satisfying these requirements requires materially changing
scope or library behavior, return that decision to the user before proceeding.
