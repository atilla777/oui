# Lab inventory {#lab-inventory}

The Integration Lab's `lab-inventory` screen is a two-panel transfer screen built from the existing collections, gestures, layers and interaction families. The title `Lab / Inventory` sits above two list regions, `Backpack` and `Chest`. Each region is a non-nested uniform list of card IDs with localized display names: `card-01` is `Compass`, `card-07` is `Book`, and so on. The `Reverse display order` button changes only which data index is painted first.

Selecting a row stores the application's stable card ID, not a display position. The selection row then shows that ID, the localized name and the current container, for example `card-01 / Compass / Backpack`, and a separate `Drag selected item` button appears. That button is the only drag source; the two panel headers are the drop targets. Rows themselves are not drag sources.

A drag that ends on the other panel header does not move the item. It stores a copied pending proposal and opens a modal asking `Move selected item?` with the payload ID, `Cancel` and `Confirm move`. `Confirm move` re-checks the reader lifetime, pending token, model revision and source membership, then applies one application outcome and reports `Item moved once; stable selection preserved.` `Cancel` clears the pending proposal with no membership effect. Dropping on the source panel is refused with `Refused: item is already in this container.`; a changed inventory reports `Refused: inventory changed; make a new request.` and other rejected requests report `Transfer refused by the application.`

The cards are teaching data. The catalogue entry for `lab-inventory` is described as **Two uniform lists; no row drag-reorder**, and the section is marked experimental. Memberships, the selected ID, the display-order flag and the pending proposal are process-local: they are not read from or written to disk and they end with the process. The screen is a bounded demonstration of transfer and refusal, not an inventory system.

![Lab inventory initial screen with Backpack and Chest lists and Compass focused.](/media/lab-inventory-initial-en.png)

Native Lab inventory, EN UI; initial two lists with Compass focused.

![Backpack row Compass selected, with the selection row showing card-01 / Compass / Backpack and the Drag selected item button.](/media/lab-inventory-selected-en.png)

Native Lab inventory, EN UI; Compass selected, stable ID and drag handle visible.

![Same-panel drop refused with the message Refused: item is already in this container.](/media/lab-inventory-refused-en.png)

Native Lab inventory, EN UI; same-panel drop refused, membership unchanged.

![Pending transfer modal asking Move selected item? for card-01 with Cancel and Confirm move.](/media/lab-inventory-pending-en.png)

Native Lab inventory, EN UI; pending proposal for card-01, item not moved yet.

![Confirmed transfer: Compass left the Backpack, the selection row shows card-01 / Compass / Chest, and the status says the item moved once.](/media/lab-inventory-confirmed-en.png)

Native Lab inventory, EN UI; transfer confirmed once, stable selection preserved.

## Boundaries and packages {#boundaries}

This is experimental. The screen demonstrates two uniform list regions, stable selection across a membership change and a pending-then-confirmed transfer. It does not implement row drag-reorder: there is no promise that dragging a row reorders the list, and the only drag source is the selected item's handle. There are no stacks, equipment slots, item quantities, gameplay rules or persistence. The two lists are not nested and must not share a region ID or an ordinary scroll state; scroll offsets stay per region.

`consumer/ui_showcase/app/lab_inventory.odin` imports the UI families `ui_base`, `ui_collections`, `ui_gestures`, `ui_gestures/sdl`, `ui_interaction` and `ui_layout`, plus the showcase's own `sections` package and the `gestures_demo/model` reducer. `lab_input.odin` owns the combined Tab/arrow order over both lists, and `lab_transfer.odin` owns the pending token, retained reader stamp, Cancel and Confirm decisions. The shared `sections` composition also selects text, style and the SDL text adapter, and the running showcase is a **wider union**: it includes every gallery and Lab screen, the SDL backend and the consumer atlas loader with libpng and zlib. That union is not the dependency set of this screen alone. For the restricted headless recipe with two collections and one gesture chain, see the [Inventory recipe](../recipes/inventory).

## Source and native example {#source}

Pinned to `8bc09cff358aa629410437996520283ff98d77d9`:
[lab-inventory screen](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/app/lab_inventory.odin),
[pending transfer and confirmation](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/app/lab_transfer.odin),
[list navigation and pointer routing](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/app/lab_input.odin),
[Lab strings](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/app/lab_strings.odin),
[card reducer](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/gestures_demo/model/model.odin),
[selection and display-order model](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/model/model.odin),
[catalogue IDs and limits](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/model/catalogue.odin),
[recipe boundary](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/recipes.md#5-inventory), and
[resources](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/resources.md).

The showcase links the consumer atlas loader and therefore needs libpng and zlib in addition to Odin, SDL3 and SDL3_ttf. The current resource pins are libpng 1.6.59 and zlib 1.4. Prepare that pair in a private prefix and point both `pkg-config` and the runtime loader at the same libraries; do not mix system headers or libraries with it. The [resource documentation](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/resources.md) records the archives, digests and notices.

From a prepared native checkout or export with those dependencies:

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section lab-inventory --locale en --size 1280x960 --scale 1
# Russian UI:
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section lab-inventory --locale ru --size 1280x960 --scale 1
```

Tab visits each list once as a logical stop and then the remaining controls; the arrow keys move focus inside the focused list and Return selects the focused row. With a pointer, click a row to select it, then press on `Drag selected item` and release over the other panel header to raise the confirmation. In the modal, Tab moves between `Cancel` and `Confirm move`, Return activates the focused button and Escape cancels the proposal. `Reverse display order` repaints the rows in reverse without changing IDs or the selection.

This opens a native window, not a website. Agents must use the [isolated display wrapper](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/isd.md), not the main desktop. The five published captures come from verified isolated runs at 1280×960, scale 1, with normal mode, pixel-perfect off and the supplied fonts and atlases.