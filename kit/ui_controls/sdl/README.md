# Controls SDL input adapter — candidate

`handle(&adapter,&controls,&interaction,&matched_geometry,normalized_input)`
не нормализует SDL и не выполняет application reducer. Возвращает controlled
Result и consumed; при consumed нельзя делать повторный base dispatch.
Common Input владеет всеми fronts/releases, включая Home/End. Keyboard и gamepad
Left/Right дают Adjust, keyboard Home/End — exact Set_Value; mouse down/drag —
grid-rounded Set_Value по track bounds/paint clip. Label width не является rail.

Adapter владеет capture ID/scope strings и frozen track bounds/clip, не UI frames
или SDL resources. `create(allocator)` / `destroy` обязательны. После successful
typed swap вызывайте `reconcile` с matched geometry и известным drawable pointer;
scope/role/availability/stamp/removal или moved-outside projection отменяют capture
до disposal callbacks. `block` вызывается на любом publication/render failure и
очищает capture/press/readiness; release/loss cleanup выполняется даже при Not_Ready.

Перед handle selected composition применяет layer hit/shield; этот adapter не
импортирует layers и не подменяет его hit owner. Остальные control actions,
List→scroll, Cancel priority и ordinary press/release связывает explicit caller:
[полный selected input fixture](../../../tests/ui_navigation/selected_input/README.md).
Current completion — input only, не renderer/SDL window verification.
