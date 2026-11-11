# Content display fixture

Предынтеграционный `slyx-iv1.1.4`, не menu/showcase qualification. Отдельный consumer
выбранных rich/custom/transitions/style/layout/interaction, один normalized input
owner и typed publication barrier. Строки ru/en и font принадлежат host.
Нет game/debug/RIS runtime imports. Window title и палитра совпадают с existing
external-root ISD harness только для discovery/smoke, не доказывают menu behavior.

```sh
odin build tests/ui_content/content_display -collection:ui=kit -out:/tmp/opencode/content-display
python3 scripts/ui_isd.py start --profile standalone-menu \
  --consumer-root tests/ui_content/content_display --kit-root libs \
  --font resources/font.ttf --locale ru --size 800x600 --scale 2 --test-controls
# Только возвращённый RUN: explicit focus, screenshot, input; stop в finally.
```

Параметры: `--font FILE`, `--locale ru|en`, `--size 800x600|480x320`,
`--scale 1|1.5|2`; `--window-check` проверяет render/readback/present и выходит.
F10 resize/F12 exit/F2 one-shot next-rebuild refusal работают только при test
build и `--test-controls`. R восстанавливает current model, не replay.
Painter рисует layout-space circle с frozen +30 offset, rich явно выбирает
WordWrap/Ellipsis/max_lines=3. Малое окно использует явный overflow, не NoWrap.
Лог содержит model effects/sequence/stamp и tracked destroy live/bad-frees;
Odin tracking не измеряет SDL/driver/GPU memory.
