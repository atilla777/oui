# Quickstart: два закреплённых способа получения

Нужен опубликованный владельцем **portable tree описанной формы**. Адрес
`<UI_REPOSITORY_URL>` — намеренно несуществующий placeholder, `<UI_COMMIT>` —
полный выбранный commit, не branch/tag/latest. До любой network-команды сознательно
подставьте оба значения. Этот документ не назначает имя/владельца/видимость remote.
Vendor и submodule равноправны; ни один не выбирается автоматически.

## Vendor

В Bash, в своём consumer repository, с новым свободным destination:

```sh
set -euo pipefail
UI_REPOSITORY_URL='<UI_REPOSITORY_URL>'
UI_COMMIT='<UI_COMMIT>'
# Сначала замените placeholders. Не выполняйте их буквально.
test "$UI_REPOSITORY_URL" != '<UI_REPOSITORY_URL>'
test "$UI_COMMIT" != '<UI_COMMIT>'
git clone --no-checkout "$UI_REPOSITORY_URL" ui-source
git -C ui-source checkout --detach "$UI_COMMIT"
test "$(git -C ui-source rev-parse HEAD)" = "$UI_COMMIT"
test ! -e vendor/odin-ui
mkdir -p vendor/odin-ui
git -C ui-source archive "$UI_COMMIT" | tar -x -C vendor/odin-ui
printf '%s\n' "$UI_COMMIT" > vendor/odin-ui/SOURCE_COMMIT
```

Сохраняйте notices, LICENSE и inventory выбранного комплекта. Для меньшей
поставки сначала выберите полный closure по recipes; не копируйте только один
leaf и не теряйте licenses его транзитивных ресурсов. `SOURCE_COMMIT` — запись
consumer, не обещание побитовой идентичности произвольного изменённого vendor.

## Git submodule

В Bash, в своём consumer repository, с новым свободным destination:

```sh
set -euo pipefail
UI_REPOSITORY_URL='<UI_REPOSITORY_URL>'
UI_COMMIT='<UI_COMMIT>'
# Сознательная подстановка обязательна и здесь.
test "$UI_REPOSITORY_URL" != '<UI_REPOSITORY_URL>'
test "$UI_COMMIT" != '<UI_COMMIT>'
git submodule add "$UI_REPOSITORY_URL" vendor/odin-ui
git -C vendor/odin-ui checkout --detach "$UI_COMMIT"
test "$(git -C vendor/odin-ui rev-parse HEAD)" = "$UI_COMMIT"
git add .gitmodules vendor/odin-ui
# Проверьте mode 160000 и exact commit перед своим commit:
git ls-files --stage vendor/odin-ui
```

Новый checkout consumer: `git submodule update --init -- vendor/odin-ui` получает
записанный gitlink. Не используйте `--remote` или автоматический upgrade.
Выбор и commit зависимости принадлежат consumer; эти команды не выполняются
экспортёром. Далее в обоих вариантах `cd vendor/odin-ui`.

## Сборка и запуск

Первая проверенная среда Linux x86_64, Odin `dev-2026-10-nightly:84bc3fc`,
SDL3 `3.4.16`, SDL3_ttf `3.2.2`; для showcase libpng `1.6.59`, zlib `1.4`
(F8 candidate; [подготовка и пределы](resources.md), historical F7 отдельно).
Shared libraries должны быть доступны loader/linker. Если они вне system paths,
задайте свои абсолютные `LIBRARY_PATH`/`LD_LIBRARY_PATH`. Установка/обновление
зависимостей здесь не выполняется. Bash/pkg-config нужны этим check/link commands,
Git — только acquisition, Python — только выбранным checks/tools/preparation.

Все следующие команды — **из корня portable tree**, не из maintained source:

```sh
mkdir -p build
odin build consumer/standalone_menu -collection:ui=kit -vet -vet-style -vet-tabs -vet-semicolon -show-import-graph -out:build/menu
build/menu --font resources/font.ttf --locale ru --size 800x600 --scale 1
build/menu --font resources/font.ttf --locale en --size 800x600 --scale 1
odin build consumer/ui_showcase -collection:ui=kit -vet -vet-style -vet-tabs -vet-semicolon -show-import-graph -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --locale ru --size 1280x960 --scale 1
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --locale en --size 1280x960 --scale 1
```

Эти интерактивные run-команды — для обычного пользователя. Агент не запускает их
на основном дисплее: использует отдельно предоставленную проверенную ISD wrapper
с этим consumer/kit/resources, own run, explicit focus и stop в finally. ISD не
обязателен обычному consumer и не входит в production kit.

Menu: Tab/Shift-Tab, Return/Space, pointer; две кнопки Action/Submenu,
Language/Back в отдельном submenu. Application counter меняется один раз.
Showcase: catalogue, gallery и Lab; `--section lab-menu|lab-settings|lab-hud|lab-inventory`
позволяет direct start. Строки consumer собственные, demo fonts явно supplied;
обычная игра предоставляет свои strings/fonts/assets, не обязана брать demo pack.

## Проверки без окна

```sh
bash scripts/test-ui-showcase --portable-check
bash scripts/test-ui-showcase --portable-acquisition
```

Этот режим существующего proof script собирает свежие minimal/showcase/tools,
проверяет ограниченные closures/snippets и запускает `core:testing` для реальных
consumer/model/Unicode контрактов. SDL tests serial/dummy — не display evidence.
В showcase app выбираются перечисленные в script bounded lifecycle/recipe/tools
и negative ownership/region contracts; exhaustive прежние allocation-fault walks
и полная gallery/platform qualification не повторяются этой командой.
`build/` — генерируемые binaries/logs, не supplied inventory. Generation/font
checks отдельно описаны в resources. Свежий binary запускается только после
успешной сборки; failed export остаётся диагностическим, не successful kit.
