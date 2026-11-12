# Статический каталог и изображения сайта

Контракт введён `oui-3no.2`, расширен `oui-3no.3`, `oui-3no.4`, `oui-3no.5`, `oui-3no.6` и text-input `oui-3no.9`;
расширение `oui-3no.8` — кандидат, pending integration.
Библиотека и native consumers не изменены; сайт описывает существующие
возможности, а не реализует их в браузере.

- `site/en/` и `site/ru/` содержат `catalogue` и `capabilities/layout`,
  `capabilities/controls`, `capabilities/styling`, `capabilities/profiles`,
  `capabilities/text`, `capabilities/rich-text`, `capabilities/text-input`.
  Страницы объясняют назначение, поведение, ограничения, узкие пакеты и отдельно
  полный showcase, с pinned source links и native build/run command.
- `site/data/catalogue.json` и `media.json` имеют `schemaVersion: 1`.
  Каталог объявляет sample coverage `layout`, `controls`, `styling`, `profiles`,
  `text`, `rich-text`, `text-input`. Native source catalogue
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
Для новых страниц заменить `layout` на `controls`, `styling`, `profiles` или `text-input`; переключение
языка сохраняет страницу. `npm run check:browser` запускает разрешённую
изолированную браузерную приёмку (Linux Chromium с sandbox).
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

## Однострочный ввод текста

Результат `oui-3no.9` добавляет EN/RU описание существующего редактора имени:
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
Обе предназначенные для сайта PNG просмотрены, capture metadata удалены.
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

## Просмотр двух состояний layout

Результат `oui-3no.4` добавляет viewer на обе
layout-страницы. Это просмотр изображений, не браузерная реализация native UI.
`viewerStates` записи layout связывает `large` (1280×960) и `small` (960×720)
с соответствующими EN/RU media records. Проверка каталога отвергает несовпадение
состояния, locale, window/drawable dimensions и scale. Настоящие новые 960×720
captures получены на clean source revision
`4da8d7a57bd2453227a4c37df6b0b4d171401681`, с прежними ресурсами и проверенной
ISD `f8204c61615406ce5628b15692628e146476a008`. Это два начальных состояния
разных размеров окна, без изменения модели и без анимации layout.

Кнопка открытия появляется только после подключения JavaScript. Модальный
`dialog` содержит локализованные заголовок, закрытие, selector, alt и подпись
выбранного изображения. Tab/Shift+Tab удерживают фокус внутри; Escape и кнопка
закрытия возвращают его к открывшему элементу. Автопереключения и анимации нет.
Оба статических изображения и ссылки на оригинальные PNG доступны без JS.

На этом кандидате пройдены Node/schema negative tests, build, loopback HTTP,
свежий portable export/portable-check и отдельно разрешённый sandboxed headless
Chromium: EN/RU на 360/1280, keyboard/pointer open, переключение изображения и
подписи, focus containment, Escape/close/return, reduced motion и no-JS fallback.
Оба новых native PNG просмотрены; ISD runs остановлены с проверкой отсутствия
своих живых процессов. Это не полная проверка доступности, других браузеров,
всей галереи или Pages deployment.

Как увидеть: после build запустить указанный выше static preview, открыть
layout-страницу EN или RU, нажать кнопку просмотра, выбрать 960×720, пройти
controls клавишей Tab и закрыть Escape. Ожидаются другой настоящий capture
и возврат фокуса на кнопку просмотра.

## Profiles (`oui-3no.6`)

EN/RU страницы описывают consumer-owned draft/applied workflow: Apply, Cancel,
подтверждение смены профиля и Reset. Применённые значения существуют только
в памяти, disk persistence нет. Узкие пакеты отделены от зависимостей полного
showcase; ссылки и native build/run команды закреплены на source revision.

Для каждого языка получены три настоящих PNG 1280×960, scale 1: начальный
применённый Aurora, неприменённое изменение Show help с диалогом смены профиля,
и выключенный Show help после Apply со статусом Applied/«Применено».
Source revision `4da8d7a57bd2453227a4c37df6b0b4d171401681`;
portable source сверен с ревизией, ISD и allocation проверены по тем же правилам
выше. Все шесть PNG просмотрены; публичные файлы очищены от metadata,
provenance и digests находятся в `site/data/media.json`. Собственные runs остановлены.

Пройдены sample/schema/unit, build, HTTP и свежий portable-check. После отдельного
разрешения владельца пройдены sandboxed headless Chromium profiles EN/RU
360/1280, три загруженных изображения на страницу, keyboard locale/anchors,
no-JS prose/images и reduced motion; сохранены логи/снимки и cleanup.
Отмена и Reset описаны по исходному коду, не заявлены как отдельная native
приёмка этого кандидата. Мобильное уменьшение изображений и остальные ограничения
выше сохраняются; полный каталог, новые viewer/search, Pages/deploy не входят
в эту работу. Проверенные local preview маршруты:
`/oui/en/capabilities/profiles` и `/oui/ru/capabilities/profiles`.

## Локальный поиск и фильтр каталога

Поиск сайта, добавленный `oui-3no.3`, использует локальный
индекс VitePress; внешнего поискового сервиса нет. Кнопка поиска и Ctrl+K
открывают поиск текущего языка. Стрелки и Enter выбирают результат;
пустая выдача и очистка локализованы. Результаты ведут под `/oui/en/` либо
`/oui/ru/` соответственно.

На странице каталога запрос проверяет опубликованные title/summary/limitations
текущего языка и общие ID, group, categories, packages, source и runnable.
Регистр и крайние пробелы не влияют на совпадение; все слова запроса должны
входить в объединённый текст. Категория дополнительно ограничивает результат.
Категории `text` и `input` показываются как Text/Input или Текст/Ввод в
соответствующем языке; их стабильные IDs при этом не меняются.
Пустая выдача показывает сообщение; «Сбросить фильтры» очищает запрос и категорию.
Область остаётся sample `layout`, `controls`, `styling`, `profiles`, `text`, `rich-text`, `text-input`, не полный каталог;
фильтрация применяется к каждому разделу отдельно. Поиск и фильтры требуют
JavaScript; без него исходные описания и ссылки всех семи разделов остаются в HTML.

В интеграционном кандидате повторно проверены build, HTTP и sandboxed Chromium
для четырёх разделов на EN/RU и ширинах 360/1280, включая фильтр `ui_editor`
с категорией `input`, клавиатурный переход и no-JS ссылки. Просмотрены 64 browser
PNG; собственные browser и preview остановлены. Это проверка кандидата, а не
заявление о публикации или deployment.

После объединения с profiles повторены site tests, build, HTTP и sandboxed
Chromium для пяти разделов, EN/RU и 360/1280; просмотрены 72 browser PNG,
собственные browser и preview остановлены. Это проверка интеграционного снимка,
не утверждение о публикации или deployment.

После объединения с layout viewer site tests, build, HTTP и sandboxed Chromium
повторены для пяти разделов и viewer; просмотрены 76 browser PNG, собственные
browser и preview остановлены. Это проверка интеграционного снимка, не deployment.

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
