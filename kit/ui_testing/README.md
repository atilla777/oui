# Native UI assertions — experimental, opt-in

Кандидат `slyx-iv1.1.6`, до ревью/интеграции. Используется **обычный core:testing**;
нового runner нет. Полная migration/closure карта: [UI_TOOLS](https://github.com/atilla777/slyx/blob/8c55d0da6a28fe7d15f58f828b10a25a2851fea7/libs/UI_TOOLS.md).

`ui_testing` импортирует только common inspector/interaction и core. Доступны
`expect_exists`, `expect_geometry`, `expect_visible`, `expect_available`,
`expect_state`, `expect_no_errors`, `expect_event`. Geometry проверяет finite
tolerance; event assertion различает dispatch и Applied/Rejected app outcome.
Assertions не мутируют model и не создают renderer/socket.

Семейства подключаются отдельно:

- `ui_style/testing.expect_selected(t, frame, id, selected)`;
- `ui_collections/testing.expect_logical_item(t, frame, collection_id, item_id,
  encoded_id, Logical_State)`; поля bounds существуют iff materialized;
- `ui_gestures/testing.gesture(state, interaction, scroll, action)` устанавливает
  Agent source и вызывает обычный dispatcher один раз, без rebuild/retry.

Отдельный `scroll_to_item` facade монолита не сохраняется: используйте
`ui_collections.dispatch` с обычным guarded Agent action, затем publish/rebuild
до последующей activation. Ни assertion, ни UI intention не доказывают applied
application outcome. Семейные fields больше не включаются в common State.

Обычные package tests могут напрямую использовать core:testing без ui_testing
и без любой debugger/tooling зависимости. Прежние tests в `unported/` сохраняют
исходные oracles старого API, но не являются runnable suite нового API.
