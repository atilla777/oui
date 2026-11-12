# Using oui

## Choose a boundary {#choose-a-boundary}

Choose the smallest composition your application needs, then follow its authoritative recipe and fixture. The links describe existing examples, not new APIs or universal build profiles.

| Need | Recipe | Source / fixture |
| --- | --- | --- |
| Headless geometry only | [Layout-only](https://github.com/atilla777/oui/blob/main/docs/recipes.md#1-layout-only) | [layout fixture](https://github.com/atilla777/oui/blob/main/tests/ui_foundation/layout_only/main.odin) |
| Simple interactive screen | [Basic menu](https://github.com/atilla777/oui/blob/main/docs/recipes.md#2-basic-menu) | [standalone menu](https://github.com/atilla777/oui/tree/main/consumer/standalone_menu) |
| Layers and hold | [HUD](https://github.com/atilla777/oui/blob/main/docs/recipes.md#3-hud) | [HUD fixture](https://github.com/atilla777/oui/blob/main/tests/ui_recipes/hud/main.odin) |
| Controls and editor | [Settings](https://github.com/atilla777/oui/blob/main/docs/recipes.md#4-settings) | [settings fixture](https://github.com/atilla777/oui/blob/main/tests/ui_recipes/settings/main.odin) |
| Collections and gestures | [Inventory](https://github.com/atilla777/oui/blob/main/docs/recipes.md#5-inventory) | [inventory fixture](https://github.com/atilla777/oui/blob/main/tests/ui_recipes/inventory/main.odin) |
| Opt-in inspection and debugging | [Development tools](https://github.com/atilla777/oui/blob/main/docs/recipes.md#6-development-tools) | [tools fixture](https://github.com/atilla777/oui/blob/main/tests/ui_recipes/tools/main.odin) |

The [portable check](https://github.com/atilla777/oui/blob/main/scripts/test-ui-showcase#L132) builds these six in separate restricted roots and runs all except the menu in that loop. HUD, settings and inventory fixtures exercise headless publication with deterministic inputs; their compiled adapters do not make them native display tests. The connected showcase is a **larger union**, not the minimum dependency set for any screen. See [qualification](https://github.com/atilla777/oui/blob/main/docs/qualification.md) for the distinct evidence and its limits.

## Package and dependency map {#package-map}

Use the collection mapping `-collection:ui=kit` and narrow imports such as `import layout "ui:ui_layout"`; there is no supported legacy umbrella import. The [API map](https://github.com/atilla777/oui/blob/main/docs/api.md) lists declarations and direct dependency relationships; the [kit source](https://github.com/atilla777/oui/tree/main/kit) and compiler determine the actual graph.

- `ui_base` owns publication primitives; `ui_layout` depends on base. Layout-only needs neither interaction nor text, SDL, fonts or tools.
- `ui_interaction` adds routing and focus; `ui_style` provides paint metadata; `ui_text` adds style and `unicode_graphemes`. Text does not itself select an SDL backend.
- Select families as needed: `ui_layers`, `ui_scroll`, `ui_controls`, `ui_hold`, `ui_editor`, `ui_collections`, `ui_gestures`, `ui_rich`, `ui_transitions`, `ui_custom`, `ui_composition` and `ui_world`. Their dependencies differ: for example controls include layers/scroll/style/text, while collections and gestures add scroll. Consult the API map and chosen recipe rather than assuming independence.
- `ui_sdl` and `ui_sdl_text` are separate backend choices; family `sdl` adapters are selected separately. SDL text needs SDL3_ttf and supplied font resources; a controls SDL adapter alone does not require TTF. Translations and the atlas loader are consumer choices, not UI core.
- `ui_inspect`, `ui_wire`, `ui_debug` and `ui_testing` are opt-in tooling; `ui_testing` is for tests, not a production binary. The tools recipe's headless set does not require SDL, text or fonts. A debug endpoint requires explicit gates and permission, not merely an import.

## Ownership and resources {#ownership-and-resources}

The application owns meaningful model values, revisions and outcomes; UI families own selected technical state. Use one interaction/focus owner and one publication. With SDL, normalize each physical event once and share that input with selected adapters. A proposal is not an applied effect: the application checks it and decides the outcome.

Follow the [lifecycle contract](https://github.com/atilla777/oui/blob/main/docs/lifecycle.md): prepare candidates, claims and all fallible copies before validation and the commit barrier; then publish, dispatch, apply an app outcome, rebuild and render. A failed prepare, copy or render invalidates readiness; explicit recovery rebuilds the accepted model without replaying an effect or input. Old pixels and historical readers are not authority for current actions or snapshots.

Owning copies must be destroyed once with their original allocator; ordinary struct assignment is not an owning copy. Borrowed inputs and callbacks have bounded lifetimes. Retained readers and font/image generations must be released before their allocator or backend; close selected editor input and destroy readers before the backend. Consult the lifecycle for the full shutdown and failure order.

Fonts, Unicode data and native codecs have separate dependencies and notices; the kit's MIT license does not relicense them. See [resources](https://github.com/atilla777/oui/blob/main/docs/resources.md) for pins, notices and selected native dependencies and [quickstart](https://github.com/atilla777/oui/blob/main/docs/quickstart.md) for commands. Native consumers do not need this website's Node tooling.

## Experimental compatibility {#compatibility}

All narrow APIs are experimental. The [compatibility map](https://github.com/atilla777/oui/blob/main/docs/compatibility.md) identifies the first environment and bounded combinations; the [scope](https://github.com/atilla777/oui/blob/main/docs/scope.md) lists included and excluded behavior. A listed package or example does not qualify every combination or platform, and historical qualification is not a new pass for your build. In particular, no general IME, bidi/shaping, physical-gamepad, WCAG, other-platform or native/GPU heap guarantee follows from these examples.
