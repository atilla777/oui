# Статический каталог и изображения сайта

Кандидат `oui-3no.2`, pending integration. Библиотека и native consumers не
изменены; сайт описывает существующий layout, а не реализует его в браузере.

- `site/en/` и `site/ru/` содержат `catalogue` и `capabilities/layout`.
  Страницы объясняют назначение, поведение, ограничения, узкие пакеты и отдельно
  полный showcase, с pinned source links и native build/run command.
- `site/data/catalogue.json` и `media.json` имеют `schemaVersion: 1`.
  Каталог объявляет sample coverage только `layout`. Native source catalogue
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

## Прокрутка и виртуальные коллекции

Кандидат `oui-3no.10`, pending integration: sample расширен до `layout`,
`scroll-table`, `collections`; остальные gallery/Lab IDs не объявлены готовыми.
Новые EN/RU страницы доступны из статического каталога, содержат purpose,
наблюдаемое поведение, ограничения, выбранные пакеты, pinned source links
и native build/run команды. Библиотека и native поведение не изменены.

`scroll-table` показывает обычную вертикальную невложенную прокрутку таблицы
с тремя фиксированными колонками, не виртуализацию. `collections` описывает
материализацию видимого диапазона однородного списка/сетки и единственного
владельца смещения: ordinary scroll state нельзя подключать к той же области.
Новые четыре PNG EN/RU показывают таблицу после прокрутки (строки 24–32)
и список из 10 000 элементов после действия Middle (элементы 04995–05000).
Снимки сетки, удаления/перестановки и иных состояний здесь не заявлены.

Native source export сверен с ревизией
`4da8d7a57bd2453227a4c37df6b0b4d171401681`; PNG 1280×960, scale 1,
с тем же version1 media-контрактом, resource hashes и публично безопасными
метаданными. Выбранная whole-source verified ISD `f8204c6` подтвердила
`linux-abstract-v1` в create/status; собственные runs остановлены.
Все четыре PNG просмотрены; использован ранее подготовленный private prefix
libpng 1.6.59/zlib 1.4 с проверкой фактической linkage, без системной установки.

Для этого кандидата прошли unit/parity/schema, build, loopback HTTP/digest,
свежий portable export/portable-check и отдельно разрешённый sandboxed headless
Chromium 152: EN/RU страницы на 360/1280, изображения/alt, отсутствие page overflow,
клавиатура, смена языка с valid/missing anchors, no-JS и reduced motion.
36 browser screenshots просмотрены, собственные browser/preview остановлены.
Это ограниченная приёмка sample, не полная квалификация всех 23 IDs,
не аудит доступности и не Pages deployment; прежние ограничения Vite 5 сохраняются.

Как увидеть локальный кандидат: из `site/` с Node `.nvmrc` выполнить
`npm run build`, `npm run check:http`, `npm run check:browser`, затем
`npm run preview -- --port 0`; открыть выданный URL с `/oui/en/catalogue`
или `/oui/ru/catalogue` и перейти к новым примерам. Остановить свой preview.
