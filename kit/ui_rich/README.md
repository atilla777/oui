# ui_rich — experimental

До интеграции `slyx-iv1.1.4`. [API, lifecycle и migration](https://github.com/atilla777/slyx/blob/8c55d0da6a28fe7d15f58f828b10a25a2851fea7/libs/UI_CONTENT.md).
Headless closure: ui_base/ui_layout/ui_style/ui_text/unicode_graphemes.
Parser, immutable documents/source mappings, resource/fallback metadata, Unicode
wrapping/ellipsis и width-dependent layout staging не требуют SDL.

`prepare` возвращает owning Candidate с geometry/frame; `try_copy_frame` создаёт
owning historical reader. Все результаты требуют явного destroy. Font metrics
заимствуются на вызов; frame не владеет native handles. `options` задают wrapping
и overflow явно. SDL generation/metrics/render — отдельный `ui_rich/sdl`;
generation имеет retain/release и typed constructor errors. Передавайте именно
согласованный frozen transform в renderer, не изменяйте layout bounds.

`odin test kit/ui_rich`; `odin test kit/ui_rich/sdl -define:ODIN_TEST_THREADS=1`.
Real-display consumer/ISD: [content_display](../../tests/ui_content/content_display/README.md).
