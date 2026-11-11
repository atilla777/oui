# Standalone Menu — experimental consumer

Current portable acquisition/build/test instructions and selected MIT scope:
[Odin UI kit](../../README.md). `bash scripts/test-ui-showcase --portable`
from the source root creates and checks a fresh full portable tree including this
minimal consumer. The historical proof layout below remains a smaller option;
it is not the full distribution and does not change third-party font notices.

Реализация `slyx-iv1.1.5`, не приёмка всей F1. Основа: R1/D1 и
принятые R1-A1/D1-A1. Собственные строки — `strings.odin`, приложение/reducer —
`model/`, весь typed publisher и owning reader — `runtime.odin`, без showcase.

## Независимый root

Linux x86_64; Odin `dev-2026-10-nightly:84bc3fc`, SDL3 `3.4.16`, SDL3_ttf `3.2.2`
с установленными shared libraries. Другие платформы не квалифицированы.
Обычные build/runtime не требуют Python, RIS, OpenCode, ISD или других tools.

```text
proof/
  kit/{ui_base,ui_layout,ui_interaction,ui_style,ui_text,unicode_graphemes,ui_sdl,ui_sdl_text}/
  consumer/{*.odin,model/model.odin}
  resources/{font.ttf,font notices}
```

Из `proof/consumer/`:

```sh
odin build . -collection:ui=../kit -out:../menu
../menu --font ../resources/font.ttf --locale ru --size 480x320 --scale 2
```

Шрифт предоставляет caller: нет `#load` из Slyx, системного font lookup,
переводов Slyx, game/debug/inspection/showcase imports или endpoint/protocol.
Чтение/open/glyph validation обеих языковых версий проверяются до показа меню;
ошибки выводятся с контекстом, частичная инициализация освобождается.
Подготовка font не является runtime dependency, новая лицензия не выбирается.

Для локального proof отдельно разрешён fixture `resources/font.ttf` с его
DejaVu/Nerd Fonts/Octicons notices. Пример сбора **нового** внешнего root без symlinks
(SOURCE — выбранная исходная копия; не перезаписывать чужие каталоги):

```sh
SOURCE=$PWD
PROOF=$(mktemp -d /tmp/opencode/slyx-standalone-proof.XXXXXX)
mkdir "$PROOF/kit" "$PROOF/consumer" "$PROOF/consumer/model" "$PROOF/resources"
for p in ui_base ui_layout ui_interaction ui_style ui_text unicode_graphemes ui_sdl ui_sdl_text; do
  mkdir "$PROOF/kit/$p"
  find "$SOURCE/kit/$p" -maxdepth 1 -type f -name '*.odin' ! -name '*_test.odin' -exec cp {} "$PROOF/kit/$p/" \;
done
find "$SOURCE/consumer/standalone_menu" -maxdepth 1 -name '*.odin' ! -name '*_test.odin' -exec cp {} "$PROOF/consumer/" \;
cp "$SOURCE/consumer/standalone_menu/model/model.odin" "$PROOF/consumer/model/"
cp "$SOURCE/kit/unicode_graphemes/README.md" "$PROOF/kit/unicode_graphemes/"
mkdir "$PROOF/kit/unicode_graphemes/data"
cp "$SOURCE/kit/unicode_graphemes/data/LICENSE.txt" "$PROOF/kit/unicode_graphemes/data/"
cp "$SOURCE/resources/font.ttf" "$PROOF/resources/font.ttf"
cp "$SOURCE/assets/fonts/DejaVu-LICENSE.txt" "$SOURCE/assets/fonts/Nerd-Fonts-NOTICE.txt" "$SOURCE/assets/fonts/Octicons-LICENSE.txt" "$PROOF/resources/"
(cd "$PROOF/consumer" && odin build . -collection:ui=../kit -show-import-graph -out:../menu)
```

В kit физически нет optional families, старого `ui`, `ui_sdl/unported`, tools или
assets Slyx. Primitive-only fixture `tests/ui_backend/primitive_only` собирается
из ещё меньшего kit (base/layout/interaction/style/ui_sdl), без text/Unicode/TTF.
Unicode License v3 notice сохраняется вместе с derived tables; исходные Unicode
data/generator не требуются для build/runtime. Это существующая лицензия данных,
не новый выбор лицензии UI-кода или repository.

## Поведение, публикация и lifetime

Главная страница: `action`/`open`; подменю: `language`/`back`. Action увеличивает
счётчик ровно один раз с checked overflow. Open/Language/Back тоже отдельные
application outcomes. Effects/model revision считаются независимо от rebuilds;
resize/focus/recovery не дают application effects. Потреблённый sequence повторно
не применяется. Tab/Shift-Tab, Return/Space, mouse/gamepad идут через один
interaction owner; Escape без layers не возвращает страницу, для этого есть Back.
Фокус — отдельная толстая рамка. Новая страница получает первую кнопку;
locale/resize сохраняют доступный stable focus ID без скрытой памяти исчезнувшего ID.

Runtime хранится по стабильному адресу: Context заимствует его Publication.
Входные nodes/text/style/строковый buffer заимствуются только на prepare.
Publisher явно готовит text/layout, interaction и style; проверяет owner/attempt,
model revision, viewport/scale и renderer/font/image generations. Все fallible
reader copies — до enter_commit. В commit только infallible swaps, затем finish,
reconciliation и освобождение прежних owners. Никаких family callback registries.

Reader владеет layout/interaction/text/style и retained backend generations.
`copy_reader` — checked owning copy; `destroy_reader` — единственное освобождение.
Присваивание ownership не создаёт. Reader переживает destroy Runtime; renderer,
allocator, SDL/TTF init и optional resource ledger должны пережить reader. Историю
можно читать/рисовать при совместимом drawable, но она не разрешает current UI
action/snapshot. Destroy: input → live reader → runtime resources → Context →
Publication, затем renderer/window/TTF/SDL у host.

Prepare/resource/copy/precommit failure оставляет прежние owners историческими,
выключает ready и отменяет capture. Render/readback/present failure тоже блокирует
ready. Старые видимые pixels не являются успешным current snapshot. Терминал
показывает stage и уже принятое состояние. R — независимая host recovery-команда,
перестраивающая **эту** model, не повторяющая intention. Произвольный UI input или
resize после failure не восстанавливает ready автоматически. Current boundary:
immutable reader → primitive/text render → owning readback → present, без reducer
между стадиями. [Backend](../../kit/ui_sdl/README.md),
[fonts](../../kit/ui_sdl_text/README.md), [foundation](https://github.com/atilla777/slyx/blob/8c55d0da6a28fe7d15f58f828b10a25a2851fea7/libs/UI_FOUNDATION.md).

## Проверки

```sh
odin test consumer/standalone_menu/model -vet -vet-style -vet-tabs -vet-semicolon -out:<fresh-model-tests>
odin test consumer/standalone_menu -collection:ui=kit -define:STANDALONE_MENU_TEST=true -define:ODIN_TEST_THREADS=1 -vet -vet-style -vet-tabs -vet-semicolon -out:<fresh-consumer-tests>
odin test kit/ui_sdl -define:ODIN_TEST_THREADS=1 -out:<fresh-backend-tests>
odin test kit/ui_sdl_text -define:ODIN_TEST_THREADS=1 -out:<fresh-font-tests>
python3 -B scripts/test-slyx-isd.py
```

Tests: независимый model oracle; effects/rebuilds; SDL event composition; 64 rebuild
без роста live; reader после destroy с настоящим software draw; все наблюдённые
allocation positions init/prepare/copy/font replacement/image/font create;
частичная инициализация с native resource ledger; resource/copy/publication/render/
readback/present faults и recovery без replay. Software pixels и synthetic SDL
events не заменяют реальный дисплей/ввод.

Для графики используйте только project wrapper над внешним ISD:

```sh
python3 scripts/ui_isd.py start --profile standalone-menu --consumer-root "$PROOF/consumer" --kit-root "$PROOF/kit" --font "$PROOF/resources/font.ttf" --locale ru --size 800x600 --scale 2 --test-controls
# RUN — точный run ответа. Focus только явно, input/PNG только своему run.
python3 scripts/ui_isd.py focus "$RUN"
python3 scripts/ui_isd.py key "$RUN" tap Return
python3 scripts/ui_isd.py screenshot "$RUN" --output "$RUN/action.png"
python3 scripts/ui_isd.py key "$RUN" tap F12
python3 scripts/ui_isd.py stop "$RUN"
```

Каждый start завершается stop в finally даже при ошибке, logs/PNGs сохраняются,
каждый PNG осматривается отдельно. Нет fallback на основной дисплей. Матрица:
ru/en × 800×600/480×320 × normal scale 1/1.5/2, обе страницы, смена языка и native
resize туда-обратно. Для resize стартовать с 800×600, чтобы private display вмещал
большое окно. `check` проверяет render/readback/present, app_exit=0 и stop, не OCR.

Только test build `-define:STANDALONE_MENU_TEST=true` **и** runtime `--test-controls`
разрешают F2/F3/F4/F5 (следующий prepare/resource/copy/precommit fault), F6/F7/F8
(render/readback/present), F10 (настоящий resize), F12 (graceful exit).
Release parser отвергает --test-controls, injection branches исключены.
Нет debug endpoint/setter/protocol. После F2/Action проверяйте один принятый effect,
ready=false, отказ дальнейшего UI input, затем R и отсутствие replay.

## Измерения и пределы

Наблюдение 2026-11-05 на коде этой реализации поверх
`f0394310e92c69cc172efaeb27f71fcbde52bb62`: Linux x86_64, указанные версии,
SDL software renderer под внешним ISD, обычный `odin build` без optimization flags,
7 structural nodes / 4 text blocks / 2 targets, один запуск на условие матрицы.
Числа allocation/bytes накопительные, live/peak — bytes, не RSS:

| Условие/фаза | Allocations | Bytes | Live | Peak |
|---|---:|---:|---:|---:|
| Общий publication lifetime, отдельный primitive fixture | 1 | 32 | 32 | 32 |
| Primitive/image fixture: один red image, 100×60, scale 1 | 14 | 4985 | 4873 | 4873 |
| Меню cold init, один font, без images/handlers | 9 | 34320 | 34320 | 34320 |
| Первый main publish, en, 800×600, scale 1 | 233 | 90868 | 54901 | 73408 |
| Первый main publish, ru, 800×600, scale 1 | 233 | 91048 | 54961 | 73528 |
| en 480×320 scale 1.5 после action/locale/failure/recovery/repeat, destroy | 2697 | 714000 | 0 | 94169 |

Из cold init общая lifetime — 1 allocation / 32 bytes; выбранные backend/font
owners — оставшиеся 8 / 34288. Это не цена отключённых families. Размеры static
owners (bytes): Runtime 984, Publication 72, Context 216, Reader 528,
image Generation 72, font Generation 80; последние два включают по одному
необязательному ledger pointer. Внешний Resource_Ledger — 32 bytes observer state.
Native counts: 1 retained font, 0 menu images, 0 handlers; primitive fixture —
1 texture и 0 fonts. Partial init/refusal tests проверяют баланс resource ledger.
В consumer проверены 539 отказных allocation positions по шести операциям
(9/224/62/230/5/9), включая reader copy и замену font при scale change;
64 одинаковых rebuild сохраняют live bytes, destroy возвращает их в ноль.
Fractional-scale regression проверяет сохранение каждого однопиксельного ребра
на 600 Y-позициях при scale 1.5; physical edges округляются до integer conversion.

Программа печатает cold init, rebuild/locale/resize/failure/recovery и destroy:
allocations/bytes/live/peak, размеры Runtime/Publication/Context/Reader/generations,
число выбранных fonts/images/handlers. Primitive fixture отдельно называет common
lifetime. Это Odin allocator, не RSS, TTF heap или driver bytes. Optional native
Resource_Ledger считает acquired/released retained handles; transient line
surfaces/textures освобождаются на каждом draw. Ledger pointer — цена выбранного
backend, внешний ledger — observer bookkeeping. Он живёт дольше всех readers.

Сравнивайте одинаковые locale/scale/tree/backend. Нет numerical SLA. Отсутствие
отключённых owners/init/handlers/allocations доказывается ограниченным kit и import
graph, а не разностью RSS. Publication/geometry/ID/reader/font — явно общая/выбранная
цена. Остальные families, совместимость старых consumers, qualification F7,
выбор новой лицензии и отдельный repository/extraction F8 не входят в область
этой реализации.
