# Проверки и доказательства

Политика согласована владельцем при подготовке MIS 2026-11-12. Ограниченная
проверка задачи и полная квалификация — разные результаты; успешный минимум
не означает готовность выпуска. Существующие требования
[qualification](../qualification.md) сохраняются.

## Минимум перед интеграцией/публикацией

- Только документация: `git diff --check`, проверка локальных Markdown-ссылок
  в изменённых документах и чтение diff на непротиворечивость контрактам.
  Для новых untracked документов также проверь whitespace до commit.
  Сборка/графика не нужны, если команды, код, ресурсы и поведение не менялись.
- Код, ресурсы, build/export/tooling: `git diff --check`, свежий portable export
  и `bash scripts/test-ui-showcase --portable-check` из export, плюс адресные
  проверки затронутых пакетов и зависимых потребителей по таблице ниже.
  Неизвестную область влияния сначала исследуй, затем расширь проверки и явно
  сообщи остаточную неопределённость.
- Обязательные hooks/CI, если настроены, не обходятся. На момент подготовки
  MIS версионируемые hooks/CI не заданы; эта документация их не устанавливает.

Portable export использует allowlist `inventory.json`; maintainer-документы,
Beads и MIS не нужно добавлять в поставку ради структуры процесса. Проверки
inventory запускай **в export**, а не против всего maintainer checkout.

Пример из корня oui (новый уникальный каталог; сохрани путь с логами):

```sh
PROOF="$(mktemp -d /tmp/opencode/oui-check.XXXXXXXX)"
python3 -B scripts/export-ui-kit.py "$PROOF/kit"
UI_KIT_ROOT="$PROOF/kit" TMPDIR="$PROOF" python3 -B "$PROOF/kit/scripts/test-ui-kit.py" -v
(cd "$PROOF/kit" && TMPDIR="$PROOF" bash scripts/test-ui-showcase --portable-check)
```

## Адресные проверки

| Область | Команда / выбор |
| --- | --- |
| Пакет Odin | `odin test <directory> -collection:ui=kit -define:ODIN_TEST_THREADS=1 -vet -vet-style -vet-tabs -vet-semicolon`; выбери реальные test directories и нужные defines по исходникам/qualification, `odin test` не рекурсивен |
| Layout/foundation | `bash scripts/test-ui-foundation` |
| ISD wrapper | `python3 -B scripts/test-ui-isd.py -v` |
| CLI | `python3 -B scripts/test-ui-showcase-cli.py -v` |
| Export/distribution | `UI_KIT_ROOT="$PROOF/kit" python3 -B "$PROOF/kit/scripts/test-ui-kit.py" -v` |
| Acquisition / внешний consumer | `TMPDIR="$PROOF" bash scripts/test-ui-showcase --portable-acquisition`; `TMPDIR="$PROOF" python3 -B scripts/test-external-consumer.py` |
| Шрифты, Unicode, atlas, native codecs | Соответствующие generation/hash/native-fault команды и закреплённые входы из [resources](../resources.md) и [qualification](../qualification.md) |
| Визуальный вывод / input / lifetime / performance | Затронутые сценарии и их зависимые потребители из [qualification](../qualification.md); assertions отдельно от просмотра PNG и измерений |

Если для конкретной проверки необходимы экспортированные ресурсы, выполняй её
из свежего export. Настраивай native linker/runtime paths по resources; отсутствие
проверенной зависимости — blocker проверки, не разрешение молча обновить систему.
Для SDL headless-тестов используй serial/dummy согласно qualification; это не
свидетельство отображения на реальном дисплее.

## Полная приёмка и графическая безопасность

Полный package walk, gallery/Lab/input/tools, native recipes, fault walks,
ресурсные и нагрузочные проверки — отдельная приёмка по qualification перед
выпуском либо при затрагивании соответствующих гарантий. Не запускай весь набор
автоматически для каждого изменения. При изменении гарантии выполни относящуюся
к ней приёмку; без этого не объявляй гарантию подтверждённой. План проверки
не равен её успешному выполнению; skips и недоступные входы указываются явно.

Графика агента — только `scripts/ui_isd.py` с явно выбранной полностью
проверенной ISD-копией. Требуется `linux-abstract-v1` до create и в create/status;
одного protocol1 недостаточно. Собственные run/input/PNG, явный focus, stop
в `finally`, сохранение screenshots/logs. Нет fallback на основной desktop.
Подробности — [ISD](../isd.md).

Для браузерной приёмки основы сайта `oui-3no.1`, layout/catalogue `oui-3no.2`,
поиска/фильтра `oui-3no.3`, viewer `oui-3no.4`, controls/styling `oui-3no.5`
profiles `oui-3no.6` и Atlas `oui-3no.7`
владелец 2026-11-12 отдельно
разрешил headless Chromium: без подключения к рабочему столу, с собственным
временным профилем и собственным loopback-only HTTP static preview. Этот
ограниченный путь не использует native-only ISD wrapper и не распространяется
на native-графику. Не подключайся к чужому браузеру/профилю, не отключай sandbox
и не запускай dev-сервер Vite/VitePress. Сохраняй screenshots/logs; закрывай
собственные браузер и preview в `finally`. Это не разрешение Git/Dolt push,
deploy или отмена критериев приёмки.

Изолируй build/временные данные по запуску и worktree; не используй и не
останавливай чужие процессы. Сохраняй доказательства с точным снимком/входами;
повтор неизменённой проверки без причины не нужен, но после изменения байтов
пересмотри применимость результата. Исторические PASS не являются новым PASS.
