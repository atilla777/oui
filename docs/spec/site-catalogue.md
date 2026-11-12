# Статический каталог и изображения сайта

Основа — `oui-3no.2`; расширение `oui-3no.8` — кандидат, pending integration.
Библиотека и native consumers не изменены; сайт описывает существующие
возможности, а не реализует их в браузере.

- `site/en/` и `site/ru/` содержат `catalogue` и `capabilities/layout`,
  `capabilities/text`, `capabilities/rich-text`.
  Страницы объясняют назначение, поведение, ограничения, узкие пакеты и отдельно
  полный showcase, с pinned source links и native build/run command.
- `site/data/catalogue.json` и `media.json` имеют `schemaVersion: 1`.
  Каталог объявляет sample coverage `layout`, `text`, `rich-text`. Native source catalogue
  остаётся владельцем допустимых IDs; `npm run check:catalogue:strict` требует
  полного покрытия gallery/Lab и на этом sample ожидаемо завершается ошибкой.
- Media records связывают изображения с section/state/UI locale, полной source
  revision и clean state, source paths, window/drawable/scale, hashes ресурсов,
  sanitized ISD revision, image SHA-256 и EN/RU captions/alt. Публичные manifest
  не содержат локальных путей или identities сессий.
- `npm run build` проверяет schema/coverage/references/digests до VitePress.
  Static build не запускает Odin, ISD или native consumer. Изображения находятся
  в `site/public/media/` и включены в предварительно построенный HTML без JS.

## Наблюдённые проверки и пределы

Получены и просмотрены два настоящих PNG layout EN/RU, 1280×960, scale 1,
на source revision `646dc817cd1b9e3149d6a018ef8bf83f5c87b3bb`.
Portable source export сверен с файлами этой ревизии. Выбранная ISD
`f8204c61615406ce5628b15692628e146476a008` прошла whole-source verification;
create/status подтвердили `linux-abstract-v1`, собственные runs остановлены.
libpng 1.6.59/zlib 1.4 собраны в private prefix с проверенными archive hashes,
upstream tests и фактической runtime linkage, без замены системных библиотек.

Unit/parity/schema negative tests, build, loopback HTTP и свежий portable-check
прошли. HTTP проверяет HTML references/alt и полученные media digests.
После отдельного разрешения владельца для `oui-3no.2` пройдена приёмка
в изолированном headless Chromium 152 с sandbox, собственными профилями и
loopback-only preview. EN/RU catalogue/layout проверены на ширинах 360/1280:
нет page overflow, доступны prose и загруженные изображения, работают
клавиатура, смена языка с valid/missing anchors и no-JS content/links/images.
Проверен reduced motion. Все 20 browser PNG просмотрены; собственные процессы
остановлены. На мобильном экране native screenshot уменьшен; viewer и zoom
не входят в эту задачу. Другие браузеры, полный аудит доступности,
полная квалификация всех IDs и Pages deployment не проверены.
Унаследованное ограничение unsupported Vite 5 остаётся раскрытым
в `site/README.md`; dev server не разрешён.

Из `site/` с Node из `.nvmrc`: `npm ci`, `npm run check`, `npm run build`,
`npm run check:http`, затем `npm run preview -- --port 0` и выданный локальный
URL с `/oui/en/capabilities/layout` либо `/oui/ru/capabilities/layout`.
Остановить свой preview — Ctrl-C. Подробнее: [site README](../../site/README.md).

## Текст и форматированный текст (`oui-3no.8`)

EN/RU страницы описывают локализованные native fixtures: переносы, обрезание,
многоточие, выравнивание и выбор короткого текстового ключа; rich card со стилями,
встроенным изображением, запасным шрифтом и переключением в одну строку.
Указаны выбранные пакеты, ссылки на исходники и native build/run команды.
Грамматика rich text ограничена; это не HTML и не редактор. Shaping/bidi не
обещаются, лимиты текста — 65 536 байт и 4096 строк, покрытие зависит от шрифтов.

Для каждого из двух разделов сняты начальное и переключённое состояния EN/RU:
восемь PNG, 1280×960, scale 1, source revision
`4da8d7a57bd2453227a4c37df6b0b4d171401681`. Свежий portable export сверен
с 630 файлами этой ревизии. Снимки получены выбранной и повторно проверенной
ISD `f8204c61615406ce5628b15692628e146476a008`, с `linux-abstract-v1`, явным
focus и остановкой собственных runs в `finally`. Использован проверенный
private prefix libpng 1.6.59/zlib 1.4 без изменения системных библиотек.
Каждый PNG просмотрен; публичные изображения очищены от metadata с сохранением
пикселей, provenance не содержит локальных путей. Проверены unit/parity/schema,
build, HTTP всех новых страниц и media digests, свежий portable-check.
После отдельного разрешения владельца пройдена браузерная приёмка новых
страниц и прежних сценариев: Chromium 152 с sandbox, собственными профилями
и loopback-only preview; EN/RU, ширины 360/1280, клавиатура, смена языка с
valid/missing anchors, reduced motion и no-JS prose/images/links. В каждой
новой странице проверены оба загруженных изображения. Все 36 browser PNG
просмотрены исполнителем либо подтверждены побайтово/попиксельно идентичными
уже просмотренным снимкам; браузеры и preview остановлены. Это не аудит
доступности и не проверка других браузеров.

Открыть на собственном preview `/oui/en/capabilities/text` или
`/oui/en/capabilities/rich-text` (либо `/oui/ru/…`): видны описание, два реальных
состояния, границы, исходники и команды запуска. Полное покрытие 23 IDs и
Pages deployment этим расширением не устанавливаются.
