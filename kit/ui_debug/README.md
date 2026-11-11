# Optional UI debugger — experimental host API, unchanged wire versions

Кандидат `slyx-iv1.1.6`, до ревью/интеграции. Новый Host не содержит editor,
gesture, rich, collection или transition types. Подключение/cleanup и проверенная
граница новых APIs: [UI_TOOLS](https://github.com/atilla777/slyx/blob/8c55d0da6a28fe7d15f58f828b10a25a2851fea7/libs/UI_TOOLS.md).

Common import: `ui:ui_debug`; wire DTO: `ui:ui_wire`.
Выбранные codecs: `ui_editor/debug` (11), `ui_rich/debug` (12),
`ui_collections/debug` (13), `ui_gestures/debug` (14), `ui_custom/debug` (15),
`ui_transitions/debug` (16), `ui_accessibility/debug` (17),
`ui_debug/performance` (18). Protocol10 остаётся common grammar.

`Host` содержит один protocol/parser и синхронные capture/execute/query/snapshot
callbacks. `configure(&host)` соответствующего adapter выбирает один профиль;
не накладывайте несколько configure на один host. Accessibility имеет собственный
typed Host и `transport(&host)` для common socket server.

`Capture` передаёт owning common inspection, owning encoded selected fragments,
wire nodes и observation bytes; `destroy_capture` освобождает их тем же allocator.
Selected native bundle удерживается через owner/release только до завершения
операции. Encoder не удерживает stack `any`, не сериализует allocator/callbacks.
Request extension — scratch-owned typed value только на текущий вызов.

`open_server`, `service_server`, `close_server` сохраняют private endpoint и
limits/gates. Release/build gate и runtime opt-in независимы. Snapshot encoder
проверяет ready/metadata; он не рисует, не делает PNG и не принимает feature.
Protocol17 требует отдельного owning accessibility capture/snapshot helper.

Кандидат F5 добавляет transport-only шов
`service_server_with_handler(&server, user, handler, now)`: handler синхронно
получает `(user, line, allocator)` и возвращает owned reply bytes на этом
allocator. Сервер копирует ответ до завершения вызова и не удерживает callback
или user. Выбранный handler сам проверяет build/runtime gates и свою grammar
до capture; `open_server` по-прежнему проверяет transport gate. Обычный
`service_server` делегирует прежнему `handle_line` без изменения wire10–18.
Шов не является регистрацией протоколов, parser или готовым showcase-v19 host.

Не выводите wire codes из нового `interaction.Code`. Выбранный hold сохраняет
Hold_Required; gesture Busy отображается только для соответствующего Begin.
Непредставимый новый случай не становится success или новым wire version:
используется прежний Unsupported_Projection envelope. Не отказывайте так
прежнему поддержанному случаю вместо его корректной проекции.

Тесты: common grammar, legacy/modern DTO field sets, exact u64 observation,
single execution/recovery, bounds, metadata mismatch, private socket и selected
grammars/projections — команды в UI_TOOLS. `unported/` хранит прежние monolithic
oracles; старые Host flags/functions не являются API нового пакета.
