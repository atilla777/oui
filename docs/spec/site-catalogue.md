# Статический каталог и изображения сайта

Контракт введён `oui-3no.2`; расширение `oui-3no.5` — pending integration.
Библиотека и native consumers не изменены; сайт описывает существующие layout,
controls и styling, а не реализует их в браузере.

- `site/en/` и `site/ru/` содержат `catalogue` и `capabilities/layout`,
  `capabilities/controls`, `capabilities/styling`.
  Страницы объясняют назначение, поведение, ограничения, узкие пакеты и отдельно
  полный showcase, с pinned source links и native build/run command.
- `site/data/catalogue.json` и `media.json` имеют `schemaVersion: 1`.
  Каталог объявляет sample coverage `layout`, `controls`, `styling`. Native source catalogue
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

Для расширения `oui-3no.5` получены восемь дополнительных PNG 1280×960, scale 1,
на source revision `4da8d7a57bd2453227a4c37df6b0b4d171401681`: controls и styling,
EN/RU, начальное состояние и после Space для checkbox либо Return для Theme. Portable export
связан с исходной ревизией; verified ISD той же версии, `linux-abstract-v1`,
явный focus и остановка собственных runs подтверждены в артефактах проверки.
PNG просмотрены; публичные копии без метаданных сохраняют пиксели captures.
Существующие media layout и их provenance сохранены.

Controls описывает application-owned values/proposals и slider 0–100 с шагом 1;
styling — существующий cascade defaults → role → named → local, visual states
и ограничения. Изменение модели и темы наблюдалось через настоящий native input;
проверка всех состояний и полная native qualification не заявляются.
Свежие portable-check, шесть unit/parity/schema tests, build и HTTP прошли.
После отдельного разрешения владельца пройден sandboxed Chromium 152 для
EN/RU страниц controls/styling и прежних foundation/layout/catalogue сценариев:
360/1280, клавиатура, locale/anchors, no-JS content/images и reduced motion.
Собственные browser/preview остановлены. Это ограниченная приёмка sample,
не полная квалификация 23 IDs, всех браузеров, доступности или Pages deployment.

Из `site/` с Node из `.nvmrc`: `npm ci`, `npm run check`, `npm run build`,
`npm run check:http`, затем `npm run preview -- --port 0` и выданный локальный
URL с `/oui/en/capabilities/layout` либо `/oui/ru/capabilities/layout`.
Для новых страниц заменить `layout` на `controls` или `styling`; переключение
языка сохраняет страницу. `npm run check:browser` запускает разрешённую
изолированную браузерную приёмку (Linux Chromium с sandbox).
Остановить свой preview — Ctrl-C. Подробнее: [site README](../../site/README.md).
