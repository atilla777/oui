# ui_composition — experimental, work in progress

Предынтеграционный API в ветке `task/slyx-iv1.1.4`; не объявляет завершение
экстракции content/visual families. Прямые UI-зависимости: `ui_layout`, `ui_style`.
Нет text, Unicode, interaction, SDL, handlers или retained live runtime.

`compose_panel(namespace, parent, layout, appearance, slots, allocator)` возвращает
owning `Composition` и `Error`. Узлы — обычные `layout.Node` с `style.Appearance`;
текстовые и интерактивные описания приложение связывает с их ID отдельно.
Порядок слотов фиксирован: title/content/footer. Каждый слот имеет локальное
пространство ID; пустой, повторный ID, чужой parent и цикл отвергаются.
`node_id`, `root_id`, `slot_id` возвращают owning string и allocator error.
Адреса содержат длины UTF-8 byte segments, а не экранированный delimiter.

Входные строки, tracks и style declarations заимствуются только на вызов.
Результат владеет их глубокими копиями в checked rollback storage; используется
только переданный allocator. `try_copy` создаёт независимую owning копию.
Для каждого результата нужен `destroy`, включая отказ; присваивание структуры
не копирует и не передаёт владение. Ошибка не сохраняет ссылок на input.
Composition — pre-layout description, а не опубликованный кадр: общего
publication stamp, dispatch, clock и отдельного focus owner у неё нет.

Проверки: `odin test kit/ui_composition`; для внешнего импорта —
`import composition "ui:ui_composition"` с `-collection:ui=<kit-root>`.
Проверены namespace/order, input/copy ownership, отказы каждой backing allocation
позиции prepare/copy и очистка, в том числе многостраничного storage.
SDL/render и полная композиция с остальными семействами здесь не проверены.
