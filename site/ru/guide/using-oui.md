# Использование oui

## Выберите границу {#choose-a-boundary}

Начните с интерфейса, необходимого приложению. Headless layout можно выбрать отдельно; interaction, text, семейства компонентов и backend SDL3 подключаются по необходимости. Выбирайте пакеты и их зависимости по реальной интеграции, а не исходя из того, что нужен весь репозиторий.

## Владение и ресурсы {#ownership-and-resources}

Модель приложения и значимые значения принадлежат потребителю. При подготовке, использовании и восстановлении ресурсов следуйте контрактам времени жизни и обработки ошибок библиотеки. У шрифтов, данных Unicode и native codecs свои зависимости и notices; MIT-лицензия kit не перелицензирует их.

[Быстрый старт](https://github.com/atilla777/oui/blob/main/docs/quickstart.md), [рецепты](https://github.com/atilla777/oui/blob/main/docs/recipes.md) и [ресурсы](https://github.com/atilla777/oui/blob/main/docs/resources.md) — авторитетные источники команд и предпосылок. Native-потребителям инструменты Node этого сайта не нужны.

## Предпосылки {#prerequisites}

Первая проверенная среда — Linux x86_64, Odin `dev-2026-10-nightly:84bc3fc`, SDL3 `3.4.16` и SDL3_ttf `3.2.2`. Установите или выберите их отдельно: kit их не поставляет. Native linker и loader должны находить shared libraries. Если библиотеки вне системных путей, задайте `LIBRARY_PATH` и `LD_LIBRARY_PATH` со своими абсолютными каталогами библиотек. Для получения ниже нужны Bash и Git, для экспортёра — Python 3. Node для native-примера не нужен. Другие конфигурации этим руководством не подтверждены.

## Исходники и portable tree {#source-and-portable}

[Опубликованный репозиторий GitHub](https://github.com/atilla777/oui) — сопровождаемые исходники, **не** репозиторий portable-зависимости. Чтобы изучить его и получить локальное portable tree, выберите полный commit исходников и новый каталог:

```sh
set -euo pipefail
SOURCE_COMMIT='<full-maintained-source-commit>'
git clone --no-checkout https://github.com/atilla777/oui.git oui-source
git -C oui-source checkout --detach "$SOURCE_COMMIT"
test "$(git -C oui-source rev-parse HEAD)" = "$SOURCE_COMMIT"
python3 -B oui-source/scripts/export-ui-kit.py ./oui-portable
```

Замените placeholder перед запуском; `oui-source` и `oui-portable` не должны существовать. Экспортёр копирует файлы из allowlist и inventory, без истории Git; он не публикует репозиторий. Для способов получения через Git ниже найдите опубликованный владельцем репозиторий **portable tree** и выберите его полный commit либо создайте собственный Git-репозиторий из экспорта и сделайте commit. Публичный URL portable-репозитория здесь не обещается. Commit portable tree отличается от commit исходников; запишите их связь самостоятельно. Сохраняйте `LICENSE`, inventory и относящиеся к ресурсам notices.

## Закрепление и получение {#acquire}

В своём consumer-репозитории выберите один способ. Замените оба placeholder на URL portable-репозитория и его точный полный commit; ни `main`, ни tag не являются таким закреплением. Каталог `vendor/odin-ui` должен быть новым. Команды требуют Bash и останавливаются при ошибках.

### Vendor-копия {#vendor}

```sh
set -euo pipefail
UI_REPOSITORY_URL='<portable-repository-url>'
UI_COMMIT='<full-portable-commit>'
test "$UI_REPOSITORY_URL" != '<portable-repository-url>'
test "$UI_COMMIT" != '<full-portable-commit>'
git clone --no-checkout "$UI_REPOSITORY_URL" ui-source
git -C ui-source checkout --detach "$UI_COMMIT"
test "$(git -C ui-source rev-parse HEAD)" = "$UI_COMMIT"
test ! -e vendor/odin-ui
mkdir -p vendor/odin-ui
git -C ui-source archive "$UI_COMMIT" | tar -x -C vendor/odin-ui
printf '%s\n' "$UI_COMMIT" > vendor/odin-ui/SOURCE_COMMIT
```

Используйте свободное имя `ui-source`; если оно уже занято клоном сопровождаемых исходников, выберите другое. `SOURCE_COMMIT` записывает выбранный commit, но не подтверждает неизменность последующих правок. При необходимости закоммитьте скопированные файлы в consumer.

### Submodule {#submodule}

```sh
set -euo pipefail
UI_REPOSITORY_URL='<portable-repository-url>'
UI_COMMIT='<full-portable-commit>'
test "$UI_REPOSITORY_URL" != '<portable-repository-url>'
test "$UI_COMMIT" != '<full-portable-commit>'
git submodule add "$UI_REPOSITORY_URL" vendor/odin-ui
git -C vendor/odin-ui checkout --detach "$UI_COMMIT"
test "$(git -C vendor/odin-ui rev-parse HEAD)" = "$UI_COMMIT"
git add .gitmodules vendor/odin-ui
git ls-files --stage vendor/odin-ui
```

Проверьте mode `160000` и выбранный commit в индексе, затем закоммитьте gitlink и `.gitmodules` в consumer. В новом checkout consumer команда `git submodule update --init -- vendor/odin-ui` получает записанный commit; не используйте `--remote` для закреплённой версии.

## Сборка и запуск меню {#build-and-run}

Из корня полученного portable tree соберите существующий standalone-пример и явно передайте включённый шрифт:

```sh
cd vendor/odin-ui
mkdir -p build
odin build consumer/standalone_menu -collection:ui=kit -vet -vet-style -vet-tabs -vet-semicolon -show-import-graph -out:build/menu
build/menu --font resources/font.ttf --locale en --size 800x600 --scale 1
# Или по-русски:
build/menu --font resources/font.ttf --locale ru --size 800x600 --scale 1
```

Запускайте по одной команде в подходящей графической сессии. Меню управляется Tab/Shift-Tab и Return/Space или указателем. В примере собственные строки; приложения предоставляют свои строки и шрифты. У включённого шрифта отдельные notices в `resources/`; сохраняйте их при распространении. Замыкания пакетов, другие ресурсы и подробности native-зависимостей описаны в авторитетных ссылках выше. Успешная сборка сама по себе не подтверждает графическую работу или пригодность других платформ.

Эти интерактивные команды предназначены обычным пользователям. Агентам нельзя использовать основной дисплей: нужна отдельно предоставленная проверенная ISD через wrapper проекта, с собственным запуском, явным focus и очисткой.
