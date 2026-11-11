# Frozen capability scope: UI-001–040

All included narrow APIs are **experimental**, none stable. This is the inherited
capability/limitation map, not a passing verdict for the relocated tree. Historical
qualification and the new checks are distinct; see [qualification](qualification.md).
Legacy umbrella/old hosts are excluded, but applicable behavioral oracles remain
required. `partial` never means the entire broad product requirement is delivered.

| ID | Included owners / observable seam | Partial or excluded boundary |
|---|---|---|
| UI-001 | ui_layout Node/prepare/find, app IDs; G01 | Not arbitrary native widgets/plugins |
| UI-002 | ui_interaction routed dispatch/register/unsubscribe/Stop; G15/C04 | Checked target→ancestor routing; callbacks do not mutate publication |
| UI-003 | ui_layout Row/Column/Stack/Grid/Absolute; G01 | No Row/Column wrap or Grid span/auto-placement |
| UI-004 | ui_layout owning resolved bounds/clip; G01/G02 | Finite constraints/explicit tracks, not CSS |
| UI-005 | Normal/Pixel_Perfect geometry, app scale; G02 | Pixel_Perfect only1/2; fractional refusal; app-owned safe area |
| UI-006 | ui_world.place_anchor; G19 | Hide/Clamp/Direction helper, no engine/camera/bridge |
| UI-007 | App model→typed description→checked publication; Lab settings/HUD | Explicit rebuild, no reactive binding engine |
| UI-008 | Interaction Context, family State, Publication/Frame_Stamp; G03/G09/G11 | Technical state by ID; significant values app-owned, no persistence |
| UI-009 | ui_style Description/Theme/Presentation; G05/G16 | Explicit tokens/states, no stylesheet parser |
| UI-010 | ui_style nine_slice_patches and ui_sdl.render; G05/G06 | Bounded primitives/9-slice, no arbitrary vector renderer |
| UI-011 | Resource_Catalog/atlas_resources/SDL Generation; G05/G06 | Explicit fallback/metadata/generation, no global asset manager |
| UI-012 | Atlas loader/retained image generations; G06 A/B/Reload | Explicit Reload only; no watcher/hot-reload promise |
| UI-013 | ui_text owning Frame/source ranges and ui_sdl_text; G07 | Source≤65536B/frame≤4096lines; bounded wrapping/ellipsis, no shaping |
| UI-014 | ui_rich and selected SDL fonts; G08/C07 | Supplied fallback fixtures; no bidi/IME/shaping/arbitrary fallback |
| UI-015 | Explicit consumer translations keys/locale; G07 | Core is not a translator; normal/short keys/EGC limits, no service |
| UI-016 | One ui_sdl.Input/normalizer and family adapters; G03/G09–14/C04 | Synthetic SDL is not physical-gamepad qualification |
| UI-017 | ui_layers scopes/shields/tooltip/focus; G12/C02/C06 | Supported layer grammar, no arbitrary compositor |
| UI-018 | ui_gestures prepare/dispatch/block and SDL adapter; G14/C04 | Typed Drop proposal, threshold6/repeat400/100; no inertia |
| UI-019 | ui_hold prepare/dispatch/Progress; G13/C02/C05 | App owns sound/outcome; Activate cannot bypass hold |
| UI-020 | ui_transitions geometry binding/external clock; G17/C05/C07 | Bounded properties/easing/presence, no animation engine |
| UI-021 | Typed layout/style/text/control/scroll/layer/hold composition | Primitive/recipe composition, no universal Widget base |
| UI-022 | Controlled ui_controls and single-line ui_editor; G04/G09/C01 | No multiline/IME/undo/bidi/shaping |
| UI-023 | ui_collections materialize/project_layout/validate_regions; G11/C03/G21 | Uniform vertical List/Grid, bounded overscan; no variable row/span/nested scroll |
| UI-024 | ui_composition namespaced compose_panel/node_id/slot_id/copy; G16 | Explicit recipe, no external template system |
| UI-025 | ui_custom measure/hit/selected SDL; G16/C06/C07 | Immutable payload/pure callbacks; no plugin or second input owner |
| UI-026 | ui_inspect owning common Inspection/family projections; G20/v19 | Selected families; no universal setters/style editor |
| UI-027 | Opt-in ui_debug and owning screen JSON+BMP snapshot | v19 has **no overlays**; old overlay contracts not restored |
| UI-028 | Owning errors/layout diagnostics/family inspect; G20 | Source hints where available; expected warnings are not unexpected errors |
| UI-029 | ui_wire/ui_debug/shared guarded v19 CLI | Bounded actions; no invented editing/drag injection |
| UI-030 | **Excluded:** no Game Bridge capability | Tools do not bypass app logic; game integration is outside this kit |
| UI-031 | ui_testing.expect_* and ordinary core:testing | No mandatory runner/SDL/debug dependency for ordinary tests |
| UI-032 | ui_base.invalidate, app R/rebuild, compile/runtime tools gates | Historical views readable, never current authority; release endpoint off |
| UI-033 | G21/four native workloads; owner/observer/native ledgers | Historical B1 FAIL retained; B1-A1 cycle/memory limits require new qualification; cold/cleanup diagnostic, no SLA/native-GPU heap claim |
| UI-034 | Focus/navigation/visible style/accessibility projection; G18/C08 | Contrast/target/reduced-motion assessment, not WCAG/platform certification |
| UI-035 | Interaction handler tokens/unsubscribe/dispose/app reducer | No global bus; callbacks cannot reenter/mutate checked commit |
| UI-036 | Portable API/lifecycle/recipes/docs and odin-ui skill | Static skill checks do not imply agent reliability/cost experiments |
| UI-037 | App-owned alternative Confirm/Cancel with one token/effect; G18 | Explicit fixture, not automatic replacement of every hold |
| UI-038 | Supplied theme/whitebox atlas A/B/fonts/notices | No runtime SVG generator or asset-authoring tool |
| UI-039 | Independent layout metrics and native SDL/text rendering | Headless geometry is not display evidence; GPU/native heaps unmeasured |
| UI-040 | Interaction result→app request→reducer outcome/revision | Dispatch success is not applied effect; unknown reply never resends |

G01–G21 retain `gallery-f479-v1`: G01/G02 share layout; G20/G21 share
diagnostics-performance. Thus 19 gallery + catalogue + four Lab selectors =24.
C01 profiles; C02 layers/scroll/hold; C03 editor/collections; C04 editor/gestures;
C05 transitions+controls/hold; C06 custom+layers; C07 rich/custom/transitions;
C08 combined accessibility. No arbitrary powerset composition is qualified.

Actual declarations and package tests are in [kit](../kit), connected oracles in
[showcase app](../consumer/ui_showcase/app) and [selected tests](../tests).
This portable summary derives only the technical scope table from the historical
Slyx report at `833d6ecead540fcd1dbd1d2da88985cff0552387`; it does not copy private
raw or source-session decisions, or reinterpret old results as a new-tree PASS.
