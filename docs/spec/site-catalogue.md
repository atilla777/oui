# Статический каталог и изображения сайта

Основа — `oui-3no.2`; дополнение text-input — кандидат `oui-3no.9`, pending
integration. Библиотека и native consumers не изменены; сайт описывает
существующие возможности, а не реализует их в браузере.

- `site/en/` и `site/ru/` содержат `catalogue`, `capabilities/layout`
  и `capabilities/text-input`.
  Страницы объясняют назначение, поведение, ограничения, узкие пакеты и отдельно
  полный showcase, с pinned source links и native build/run command.
- `site/data/catalogue.json` и `media.json` имеют `schemaVersion: 1`.
  Каталог объявляет sample coverage только `layout` и `text-input`. Native source catalogue
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

## Однострочный ввод текста

Кандидат `oui-3no.9` добавляет EN/RU описание существующего редактора имени:
черновик и применённое значение принадлежат приложению, редактор обеспечивает
взаимодействие. Указаны выбранные пакеты `ui_editor`, `ui_text`,
`unicode_graphemes`, pinned source и команда native build/run. Описаны
Unicode 15.1 EGC, ограничение showcase 1–64 EGC при применении и допустимость
пустого черновика; IME, undo, нормализация, shaping и bidi не обещаются.

Два настоящих PNG EN/RU показывают поле в фокусе после вставки символа:
черновик изменён, применённое значение осталось прежним. Source revision
`4da8d7a57bd2453227a4c37df6b0b4d171401681`, 1280×960, scale 1;
media manifest сохраняет полные source/resource/image identities.
Выбранная ISD `f8204c61615406ce5628b15692628e146476a008` проверена целиком,
create/status подтвердили `linux-abstract-v1`; собственные процессы остановлены.
Оба опубликованных PNG просмотрены, capture metadata удалены.
Это демонстрация конкретного состояния, не полная квалификация редактора.

Свежие portable export/check, site unit/parity/negative validation, build и
loopback HTTP прошли. Последний проверяет новые EN/RU маршруты, HTML images/alt
и image digests без исполнения JS. Для просмотра после сборки открыть
`/oui/en/capabilities/text-input` либо `/oui/ru/capabilities/text-input`
через каталог. После отдельного разрешения владельца для `oui-3no.9`
пройдена изолированная headless Chromium приёмка: EN/RU на 360/1280,
клавиатура и смена языка, reduced motion и no-JS content/images.
Все 28 browser PNG просмотрены; sandbox проверен, собственные browser/preview
остановлены. Другие браузеры, полный аудит доступности, полная native
квалификация и deployment не заявляются. В native cleanup оба app exit равны 1:
логи содержат X11 I/O error при остановке дисплея, без предшествующей ошибки
редактора; точный порядок сигналов не установлен. Это не подтверждение
штатного завершения приложения.
