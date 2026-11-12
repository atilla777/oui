# Использование oui

## Выберите границу {#choose-a-boundary}

Выберите минимальную необходимую приложению композицию, затем изучите её авторитетный recipe и fixture. Ссылки ведут к существующим примерам, а не к новым API или универсальным профилям сборки.

| Задача | Recipe | Исходник / fixture |
| --- | --- | --- |
| Только headless-геометрия | [Layout-only](https://github.com/atilla777/oui/blob/main/docs/recipes.md#1-layout-only) | [layout fixture](https://github.com/atilla777/oui/blob/main/tests/ui_foundation/layout_only/main.odin) |
| Простой интерактивный экран | [Basic menu](https://github.com/atilla777/oui/blob/main/docs/recipes.md#2-basic-menu) | [standalone menu](https://github.com/atilla777/oui/tree/main/consumer/standalone_menu) |
| Layers и hold | [HUD](https://github.com/atilla777/oui/blob/main/docs/recipes.md#3-hud) | [HUD fixture](https://github.com/atilla777/oui/blob/main/tests/ui_recipes/hud/main.odin) |
| Controls и editor | [Settings](https://github.com/atilla777/oui/blob/main/docs/recipes.md#4-settings) | [settings fixture](https://github.com/atilla777/oui/blob/main/tests/ui_recipes/settings/main.odin) |
| Collections и gestures | [Inventory](https://github.com/atilla777/oui/blob/main/docs/recipes.md#5-inventory) | [inventory fixture](https://github.com/atilla777/oui/blob/main/tests/ui_recipes/inventory/main.odin) |
| Выборочные inspection и debugging | [Development tools](https://github.com/atilla777/oui/blob/main/docs/recipes.md#6-development-tools) | [tools fixture](https://github.com/atilla777/oui/blob/main/tests/ui_recipes/tools/main.odin) |

[Portable check](https://github.com/atilla777/oui/blob/main/scripts/test-ui-showcase#L132) собирает все шесть в отдельных ограниченных roots и в этом цикле запускает все, кроме menu. Fixtures HUD, settings и inventory проверяют headless publication с детерминированными входами; компиляция adapters не делает их проверкой native display. Связанный showcase — **более широкий union**, а не минимум зависимостей любого экрана. Отдельные свидетельства и их пределы описаны в [qualification](https://github.com/atilla777/oui/blob/main/docs/qualification.md).

## Карта пакетов и зависимостей {#package-map}

Используйте collection `-collection:ui=kit` и узкие импорты, например `import layout "ui:ui_layout"`; старый umbrella import не поддерживается. [Карта API](https://github.com/atilla777/oui/blob/main/docs/api.md) перечисляет declarations и прямые зависимости; фактический граф определяют [исходники kit](https://github.com/atilla777/oui/tree/main/kit) и компилятор.

- `ui_base` владеет примитивами publication; `ui_layout` зависит от base. Для layout-only не нужны interaction, text, SDL, шрифты и tools.
- `ui_interaction` добавляет routing и focus; `ui_style` предоставляет metadata для отрисовки; `ui_text` добавляет style и `unicode_graphemes`. Text сам по себе не выбирает backend SDL.
- Выбирайте нужные семейства: `ui_layers`, `ui_scroll`, `ui_controls`, `ui_hold`, `ui_editor`, `ui_collections`, `ui_gestures`, `ui_rich`, `ui_transitions`, `ui_custom`, `ui_composition` и `ui_world`. Их зависимости различаются: например, controls включают layers/scroll/style/text, а collections и gestures добавляют scroll. Проверяйте карту API и выбранный recipe, не предполагая независимость пакетов.
- `ui_sdl` и `ui_sdl_text` — отдельные варианты backend; `sdl` adapters семейств выбираются отдельно. Для SDL text нужны SDL3_ttf и предоставленные шрифты; сам по себе SDL adapter controls не требует TTF. Translations и atlas loader выбирает потребитель, они не входят в UI core.
- `ui_inspect`, `ui_wire`, `ui_debug` и `ui_testing` — выборочные инструменты; `ui_testing` нужен тестам, а не production binary. Headless-набор tools recipe не требует SDL, text и шрифтов. Debug endpoint требует явных gates и разрешения, а не только импорта.

## Владение и ресурсы {#ownership-and-resources}

Приложение владеет значимыми значениями модели, revisions и outcomes; семейства UI владеют выбранным техническим состоянием. Используйте одного владельца interaction/focus и одну publication. В SDL нормализуйте каждое физическое событие один раз и передавайте общий input выбранным adapters. Proposal ещё не применённый эффект: приложение проверяет его и принимает решение.

Следуйте [контракту жизненного цикла](https://github.com/atilla777/oui/blob/main/docs/lifecycle.md): подготовьте candidates, claims и все fallible copies до проверки и commit barrier; затем опубликуйте, обработайте input, примените outcome приложения, перестройте и отрисуйте. Ошибка prepare, copy или render снимает readiness; явное восстановление перестраивает принятую модель без повтора эффекта или input. Старые pixels и исторические readers не дают права на текущие действия или snapshots.

Owning copies уничтожаются ровно один раз исходным allocator; обычное присваивание struct не создаёт owning copy. Время жизни borrowed inputs и callbacks ограничено. Освободите retained readers и generations шрифтов/изображений до их allocator или backend; закройте выбранный editor input и уничтожьте readers до backend. Полный порядок shutdown и отказов — в lifecycle.

У шрифтов, данных Unicode и native codecs свои зависимости и notices; MIT-лицензия kit не перелицензирует их. См. [ресурсы](https://github.com/atilla777/oui/blob/main/docs/resources.md) для pins, notices и выбранных native-зависимостей и [быстрый старт](https://github.com/atilla777/oui/blob/main/docs/quickstart.md) для команд. Native-потребителям инструменты Node этого сайта не нужны.

## Экспериментальная совместимость {#compatibility}

Все узкие API экспериментальны. [Карта совместимости](https://github.com/atilla777/oui/blob/main/docs/compatibility.md) описывает первую среду и ограниченные комбинации; [scope](https://github.com/atilla777/oui/blob/main/docs/scope.md) перечисляет включённое и исключённое поведение. Наличие пакета или примера не квалифицирует все комбинации и платформы; историческая квалификация не означает нового PASS вашей сборки. В частности, примеры не гарантируют общий IME, bidi/shaping, physical gamepad, WCAG, другие платформы или native/GPU heap.
