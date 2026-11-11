# Совместимость и пределы

Experimental narrow APIs; legacy umbrella/old hosts не рабочие recipes и не
восстанавливаются этой поставкой. Единственный maintained source экспортируется
с inventory/parity; наличие страницы/API не квалифицирует все их сочетания.

Первая среда: Linux x86_64, Odin `dev-2026-10-nightly:84bc3fc`, SDL3 `3.4.16`,
SDL3_ttf `3.2.2`; atlas loader libpng `1.6.59`, zlib `1.4` (F8 candidate,
pending integration/qualification; historical F7 не переписан). Core headless без SDL;
SDL renderer отдельно; Unix debug transport Linux-only. Иные platforms, physical
gamepad, WCAG, числовой SLA, SDL/TTF/driver/GPU heap и ускорение по прежним
measurements не обещаны. Pins не обновляются автоматически.

## Supported combinations

| ID | Явно ограниченная композиция |
|---|---|
| C01 | text/layout/style/base + controls/layers/scroll; profiles |
| C02 | layers + text/ordinary scroll/hold/controls, один publisher |
| C03 | independent editor + collections, common focus/publication |
| C04 | editor + gestures + scroll, один normalizer/claim gate |
| C05 | transitions + controls/slider либо hold, frozen inverse/hit |
| C06 | custom + layers, shield-aware hit |
| C07 | rich + custom + transitions, согласованные generations; не rich editor |
| C08 | explicit selected accessibility projections; assessment, не arbitrary composer |

Дополнительные connected Lab recipes: layers+editor+controls (menu/settings),
layers+hold (HUD), две ненестированные collections + отдельные Drag/Drop targets
+ layers (inventory). Они не расширяют C01–C08 до powerset.

## Unsupported и обязательные отказы

- Row/Column без wrap; Grid без span/auto-placement.
- Scroll vertical/non-nested. Uniform virtual geometry, overscan bounds задаёт
  collections. Duplicate/nested regions и ordinary+virtual offset для одной
  области отказывают, не выбирают скрыто другого owner.
- Collection row activation и drag handle — **разные targets**; editor/slider/
  hold/gesture/custom double ownership отвергается до publication.
- Single-line editor, Unicode15.1 EGC, source ceiling65536 bytes; text frame
  ceiling4096 lines. Нет normalization/trim/undo/IME/preedit/bidi/shaping или
  произвольного editor glyph fallback. Unsupported glyph/UTF-8 — refusal.
- Rich — существующая bounded grammar, не HTML/rich editable.
- Normal scale1/1.5/2; Pixel_Perfect1/2. Fractional Pixel_Perfect отвергается.
  Tight viewport даёт реальный clip/overflow/No_Space, не скрытый меньший текст.
- Wrong owner/attempt/model/generation/noninvertible geometry не current bundle.
  Historical reader не разрешает actions/current snapshot; explicit R без replay.

Полный showcase имеет большой union closure. Restricted recipe compile/import
graphs — отдельное свидетельство, не сокрытие union. Bounded ru/en display smoke
не заменяет full platform/family qualification. Software/dummy/synthetic SDL,
isolated real display и hardware evidence различаются.
