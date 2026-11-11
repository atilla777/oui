# Selected editing/gesture consumer

Кандидат `slyx-iv1.1.3` до review/integration; не старое text_input_demo и не
новая приёмка standalone-menu. Содержит editor + drag/drop/repeat/pan + scroll,
два ordinary buttons, text/font и один interaction/publication/input owner.
Нет game/debug/showcase/RIS runtime dependency или translation-library import.
Русские/английские labels принадлежат consumer; внешний font передаётся явно.

`publish.odin` показывает полный typed barrier: text/layout → scroll geometry →
common claims/interaction → editor/gestures/style → все owning reader copies и
retained font → повторная validation → infallible swaps → ready. Отказ сохраняет
old readers и блокирует current input. Application reducer применяется один раз,
recovery строит текущую model, не проигрывает intention. Historical reader не
разрешает current rendering/input. Geometry/stamps/fonts используются согласованно.

```sh
odin test tests/ui_editing/selected_input -collection:ui=kit
odin build tests/ui_editing/selected_input -collection:ui=kit -out:/tmp/opencode/editing-consumer
```

Обычный GUI вручную: `editing-consumer --font /absolute/font.ttf --locale ru`
(агент **не** запускает на основном дисплее). Допустимы `--size 800x600|480x320`,
`--scale 1|1.5|2`; маленький экран при scale2 не является full qualification.
Поле initially `Имя / Name` — controlled model value, не переведённый semantic ID.
Card→Drop даёт один app effect; '+' repeat и pan — technical scrolling без reducer.
RU/EN меняет labels, Rebuild/R — recovery; на not-ready действует независимый R,
не обычная кнопка. Unsupported IME composition не выдаётся за committed input.

Существующий ISD wrapper умеет external consumer root. Для его discovery title
сохранён `Standalone Menu`; profile здесь используется **только как готовый
изолированный external-consumer harness**, не как заявление о menu requirements:

```sh
python3 scripts/ui_isd.py start --profile standalone-menu \
  --consumer-root tests/ui_editing/selected_input --kit-root libs \
  --font resources/font.ttf --locale ru --size 800x600 --scale 1 --test-controls
# Только возвращённый RUN: focus, key/mouse, screenshot; всегда stop в finally.
python3 scripts/ui_isd.py check --profile standalone-menu \
  --consumer-root tests/ui_editing/selected_input --kit-root libs \
  --font resources/font.ttf --size 800x600 --scale 2
```

Check использует default English; `--locale` доступен start, не check. Test build
`STANDALONE_MENU_TEST=true` плюс runtime `--test-controls` включают только F2
(отказ следующего rebuild), F10 (native resize), F12 (graceful exit). Обычный
consumer не требует этих флагов. R после failed model mutation не увеличивает
effects повторно. Логи печатают value/revisions/sequence/effects и final tracked
live/bad-frees; renderer-state, real font generation и temporary cleanup проверяются
отдельными library tests. Raw Odin accounting не включает SDL/driver/GPU heap.

Для внешнего standalone build скопируйте только selected package closure из
[UI_EDITING](https://github.com/atilla777/slyx/blob/8c55d0da6a28fe7d15f58f828b10a25a2851fea7/libs/UI_EDITING.md), consumer production files и notices;
сборка из consumer: `odin build . -collection:ui=../kit -out:<fresh-binary>`.
Font и notices предоставляет caller, не symlink в Slyx. Дополнительный runner,
отладчик, assets manifest или установка зависимостей не нужны.
