# Статический каталог и изображения сайта

Контракт введён `oui-3no.2`; расширения `oui-3no.5`, `oui-3no.6` и локальный
кандидат `oui-3no.11` pending integration.
Библиотека и native consumers не изменены; сайт описывает существующие layout,
controls, styling, profiles, layers и HUD, а не реализует их в браузере.

- `site/en/` и `site/ru/` содержат `catalogue` и `capabilities/layout`,
  `capabilities/controls`, `capabilities/styling`, `capabilities/profiles`,
  `capabilities/layers`, `capabilities/hud`.
  Страницы объясняют назначение, поведение, ограничения, узкие пакеты и отдельно
  полный showcase, с pinned source links и native build/run command.
- `site/data/catalogue.json` и `media.json` имеют `schemaVersion: 1`.
  Каталог объявляет sample coverage `layout`, `controls`, `styling`, `profiles`,
  `layers`, `hud`. Native source catalogue
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

## Расширение layers/HUD — oui-3no.11

В локальном кандидате EN/RU страницы слоёв показывают popup с неинтерактивной
подсказкой и модальную область A; страницы HUD — начальный HP 60 и HP 100/count 1
после полного удержания и отпускания. Тексты отделяют механизмы от app-owned
эффектов, описывают экспериментальные границы и запрет обхода hold через Activate.
Native API и поведение не менялись.

Восемь новых PNG 1280×960, scale 1 получены из portable export, все 630 inventory
entries которого сверены с `4da8d7a57bd2453227a4c37df6b0b4d171401681`.
Каждый PNG просмотрен; личных данных не обнаружено. Та же явно выбранная ISD
проверена целиком; create/status подтвердили `linux-abstract-v1`, выполнен явный
focus, собственные runs остановлены в `finally`. Использован существующий private
prefix libpng 1.6.59/zlib 1.4 с проверенной фактической linkage.
Unit/parity/schema, static build, HTTP всех новых страниц и image digests прошли.
Portable-check прошёл на свежем export; site-only изменения не меняют его байты.

После отдельного разрешения владельца для `oui-3no.11` пройдена браузерная
приёмка в изолированном headless Chromium 152 с sandbox, собственными временными
профилями и loopback-only static preview. EN/RU layers/HUD и сохранённые
catalogue/layout/guide сценарии проверены на ширинах 360/1280: prose без page
overflow, все ожидаемые изображения загружены с локализованным alt, клавиатурные
переходы из каталога, смена языка с valid/missing anchors, no-JS и reduced motion.
Все 36 исходных browser PNG, затем все 80 PNG объединённого с опубликованными
controls/styling/profiles, поиском/фильтрами и layout viewer кандидата просмотрены
исполнителем; собственные браузеры и preview остановлены в `finally`.
Объединённые unit/schema/parity, build, HTTP и браузерные проверки прошли;
portable source остался побайтово неизменным. Изображения на мобильном экране
уменьшены; viewer/zoom для layers/HUD и полная квалификация остальных IDs
не входят в этот результат. Существующий layout viewer сохранён.
Публикация и deployment не выполнены.
После сборки открыть `/oui/en/capabilities/layers` или `/oui/en/capabilities/hud`
(либо соответствующие `/ru/` страницы); ожидаются текст и два настоящих
изображения на каждой странице. HTTP и браузерное представление проверены.
Браузерные проверки воспроизводятся командой `npm run check:browser` из `site/`
в разрешённой sandboxed Chromium-среде; другие браузеры и полный аудит доступности
не проверены.
## Просмотр двух состояний layout

Локальный кандидат `oui-3no.4`, pending integration, добавляет viewer на обе
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

## Profiles: локальный кандидат oui-3no.6

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
Область остаётся sample `layout`, `controls`, `styling`, `profiles`, `layers`, `hud`,
не полный каталог; фильтрация применяется к каждому разделу отдельно. Поиск и фильтры требуют
JavaScript; без него исходные описания и ссылки всех шести разделов остаются в HTML.

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
