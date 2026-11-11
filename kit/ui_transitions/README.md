# ui_transitions — experimental

До интеграции `slyx-iv1.1.4`. [API, frozen geometry и migration](https://github.com/atilla777/slyx/blob/8c55d0da6a28fe7d15f58f828b10a25a2851fea7/libs/UI_CONTENT.md).
Headless closure: ui_base/ui_layout/ui_interaction/ui_style; нет SDL, text,
Unicode, hold или controls imports. Время передаётся явно в Step/Transition_Clock.

`prepare → project_nodes → layout → bind_geometry → selected projections →
validate_candidate → общий commit`. Hidden исключается до layout; sampled visual
bounds не меняют layout. `geometry_view` синхронно заимствуется consumers;
owning adapters материализуют нужную capture geometry. `sample_interaction`
не снимает modal/disabled gates. Нулевая scale/opacity выключает input.
`try_copy_frame` сохраняет historical metadata; destroy обязателен.

`odin test kit/ui_transitions`;
`odin test tests/ui_content/transition_controls -collection:ui=kit`.
