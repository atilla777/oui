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

## Локальный поиск и фильтр каталога

Кандидат `oui-3no.3`, pending integration. Поиск сайта использует локальный
индекс VitePress; внешнего поискового сервиса нет. Кнопка поиска и Ctrl+K
открывают поиск текущего языка. Стрелки и Enter выбирают результат;
пустая выдача и очистка локализованы. Результаты ведут под `/oui/en/` либо
`/oui/ru/` соответственно.

На странице каталога запрос проверяет опубликованные title/summary/limitations
текущего языка и общие ID, group, categories, packages, source и runnable.
Регистр и крайние пробелы не влияют на совпадение; все слова запроса должны
входить в объединённый текст. Категория дополнительно ограничивает результат.
Пустая выдача показывает сообщение; «Сбросить фильтры» очищает запрос и категорию.
Область остаётся sample `layout`, не полный каталог. Поиск и фильтры требуют
JavaScript; без него исходные описание и ссылка layout остаются в HTML.

Проверены unit positive/negative queries, schema/parity, build, HTTP и свежий
portable-check. С отдельным разрешением владельца для этой задачи пройдены
изолированные Chromium 152 / Node 24.22.3 проверки EN/RU на 360/1280:
запрос, пустая выдача, reset, клавиатурный переход по результату поиска и
ссылке каталога, сохранение no-JS content и прежних locale/reduced-motion
сценариев. Это не полная квалификация, аудит доступности или deployment.

Как увидеть: из `site/` с Node из `.nvmrc` выполнить команды выше и открыть
выданный URL с `/oui/en/catalogue` либо `/oui/ru/catalogue`. Ввести `ui_layout`,
затем `zzznomatch`, сбросить фильтры и перейти на layout. Для поиска сайта
нажать Ctrl+K, ввести `Layout` либо `Компоновка`, выбрать результат клавиатурой.
