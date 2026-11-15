# Статический каталог и изображения сайта

Контракт введён `oui-3no.2`; опубликованные расширения включают `oui-3no.5`,
`oui-3no.6`, Atlas `oui-3no.7`, text-input `oui-3no.9`, прокрутку/коллекции
`oui-3no.10` и layers/HUD `oui-3no.11`. Text/rich-text `oui-3no.8` и
menu recipe/Lab menu `oui-3no.20` — интеграционные кандидаты. Жесты `oui-3no.12` и
переходы состояния `oui-3no.14` — локальные кандидаты, pending integration.
Библиотека и native consumers не изменены; сайт описывает существующие возможности,
а не реализует их в браузере.

- `site/en/` и `site/ru/` содержат `catalogue`, `capabilities/layout`,
  `capabilities/controls`, `capabilities/styling`, `capabilities/profiles`,
  `capabilities/layers`, `capabilities/hud`, `capabilities/transitions`,
  `capabilities/text-input`, `capabilities/atlas`,
  `capabilities/scroll-table`, `capabilities/collections`, `capabilities/text`, `capabilities/rich-text`,
  `capabilities/gestures`, а также рецепты и экраны Lab — опубликованные
  `recipes/menu` и `lab/menu` (`oui-3no.20`) и `recipes/hud`/`lab/hud` этого кандидата.
  Страницы объясняют назначение, поведение, ограничения, узкие пакеты и отдельно
  полный showcase, с pinned source links и native build/run command.
  Кандидат `oui-3no.20` добавляет `recipes/menu` (узкий standalone-menu рецепт
  без собственных изображений) и первый Lab обзор `lab/menu`.
- `site/data/catalogue.json` и `media.json` имеют `schemaVersion: 1`.
  Каталог объявляет sample coverage `layout`, `controls`, `styling`, `profiles`,
  `layers`, `hud`, `transitions`, `text-input`, `atlas`, `scroll-table`, `collections`, `text`,
  `rich-text`, `gestures`, `lab-menu` и `lab-hud`. Native source catalogue
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
Для других страниц заменить `layout` на `controls`, `styling`, `profiles`, `layers`, `hud`,
`text-input`, `atlas`, `scroll-table`, `collections`, `recipes/hud` или `lab/hud`; переключение
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

## Прокрутка и виртуальные коллекции

Кандидат `oui-3no.10`, pending integration: sample расширен до `layout`,
`scroll-table`, `collections` наряду с опубликованными разделами; остальные gallery/Lab IDs не объявлены готовыми.
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

После интеграции опубликованных разделов, discovery и layout viewer повторены
девять unit/parity/schema tests, build, HTTP и sandboxed Chromium 152.
Проверены все восемь sample-разделов EN/RU на 360/1280, прежние search/filter/viewer
сценарии и категории прокрутки/коллекций. Все 112 browser screenshots итогового
запуска просмотрены исполнителем; собственные browser/preview остановлены.
Применимость portable-check сохранена: 630 экспортированных файлов совпадают
по байтам и executable mode с интеграционным снимком, site/docs в export не входят.

После объединения с опубликованными layers/HUD повторены site checks, build,
HTTP и разрешённый sandboxed Chromium для десяти разделов EN/RU на 360/1280,
включая прежние search/filter/viewer и no-JS сценарии. Все 128 итоговых browser
PNG просмотрены либо совпали с ранее просмотренными; browser и preview остановлены.
Это проверка интеграционного кандидата, не полная квалификация или deployment.

Как увидеть локальный кандидат: из `site/` с Node `.nvmrc` выполнить
`npm run build`, `npm run check:http`, `npm run check:browser`, затем
`npm run preview -- --port 0`; открыть выданный URL с `/oui/en/catalogue`
или `/oui/ru/catalogue` и перейти к новым примерам. Остановить свой preview.

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
controls/styling/profiles, поиском/фильтрами и layout viewer кандидата, а также
все 92 PNG после следующего объединения с text-input просмотрены
исполнителем; собственные браузеры и preview остановлены в `finally`.
После объединения с Atlas повторены site checks, build, HTTP и sandboxed Chromium;
все 108 browser PNG просмотрены, собственные browser и preview остановлены.
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

## Переходы состояния — oui-3no.14

Кандидат `oui-3no.14`, pending integration: sample расширен до тринадцати
gallery-разделов добавлением `transitions`. Новые EN/RU страницы доступны из
статического каталога и боковой навигации и описывают существующий fixture G17
card-presence: активация «Цели B» перецеливает paint-дорожки карточки
(смещение (120, 24), масштаб 0.8, прозрачность 0.6, новые цвета, прогресс
0.25 → 0.75), удержание Space 1000 мс инкрементирует счёт после отпускания;
проекции компоновки и попадания остаются замороженными, анимации layout нет.
Указаны purpose/observable behavior/ограничения, выбранные пакеты, pinned source
links и native build/run команды. Kit/native API и поведение не изменены.

Для каждого языка сняты два настоящих состояния PNG 1280×960, scale 1:
`initial` (Цель A, счёт 0) и `after-b` (после активации Цели B). Состояния
достигнуты настоящим вводом через изолированный запуск (explicit focus,
Tab/Return, ожидание завершения перехода), без правки изображений. Source
revision `8bc09cff358aa629410437996520283ff98d77d9`, `sourceState: clean`;
media manifest версии 1 сохраняет resource hashes, ISD identity, digests и
EN/RU captions/alt. Выбранная whole-source verified ISD
`f8204c61615406ce5628b15692628e146476a008` подтвердила `linux-abstract-v1`
в create и в каждом status перед graphics/input; собственные runs остановлены
в `finally`. Private prefix libpng 1.6.59/zlib 1.4 подготован заново по
документированной процедуре `docs/resources.md` (проверенные archive digests,
upstream tests, C ABI и фактическая ldd linkage, включая транзитивный zlib),
без системных изменений. Каждый PNG просмотрен исполнителем (нет приватных
данных, состояния соответствуют заявленным); координатор подтвердил размер
1280×960 и отсутствие metadata/text-чанков (только IHDR/cHRM/bKGD/IDAT/IEND).

На этом кандидате прошли девять unit/parity/schema tests (coverage 13 IDs),
static build, loopback HTTP новых маршрутов EN/RU с media digests, свежий
portable export/portable-check и отдельно разрешённая владельцем для
`oui-3no.14` изолированная browser-приёмка headless Chromium 152 с sandbox,
собственными профилями и loopback-only static preview: EN/RU transitions на
360/1280, изображения с alt, клавиатурный переход из каталога, смена языка
с anchors, no-JS и reduced motion; сохранены прежние сценарии. Representative
browser-скриншоты финального прогона просмотрены исполнителем, включая
transitions EN/RU 360/1280 и no-JS; transitions-скриншоты между прогонами
побайтово совпали; собственные browser/preview остановлены. Скрытое состояние
presence, motion video и полный каталог 19 IDs этим результатом не заявлены.
Публикация и deployment не выполнены.

Как увидеть локальный кандидат: из `site/` с Node из `.nvmrc` выполнить
`npm run build`, `npm run check:http`, `npm run check:browser`, затем
`npm run preview -- --port 0`; открыть выданный URL с
`/oui/en/capabilities/transitions` либо `/oui/ru/capabilities/transitions`,
или перейти через каталог. Ожидается два настоящих изображения на страницу.
Native состояние B воспроизводится командой со страницы: Tab к «Target B»
и Return; удержание Space 1 с инкрементирует счёт.

## Галерея жестов — oui-3no.12

Локальный кандидат, pending integration. EN/RU страницы `capabilities/gestures`
описывают существующий native fixture `cards-repeat-pan`: две панели карточек,
кнопки повторной прокрутки ±24, обрезанные строки по 48 px, ручка прокрутки и
заголовок-цель на каждой панели. Нажатие на карточку начинает перетаскивание;
пока кнопка мыши удерживается, UI сообщает предложение и помечает заголовок
панели «Drop: accepted»/«Перенос: разрешён», карточка остаётся в исходной панели.
Приложение применяет ровно один перенос после отпускания; запросы из той же
панели, устаревшие, повторные или недоступные отклоняются; инерции нет. Узкие
пакеты `ui_base`, `ui_layout`, `ui_interaction`, `ui_scroll`, `ui_sdl`,
`ui_gestures` отделены от полного showcase; pinned source links и native
build/run команды закреплены на ревизии кандидата.

Для каждого языка сняты три настоящих состояния PNG 1280×960, scale 1:
начальное (по шесть карточек), предложение при нажатой кнопке и применённый
перенос (5/7 карточек). Снимки выполнены на clean source revision
`8bc09cff358aa629410437996520283ff98d77d9`; app log независимо подтверждает
`phase=Active target="panel-right" accepted=true` с revision 0 и effects 0 при
предложении, затем revision 1 effects 1 после отпускания. Выбранная ISD
`f8204c61615406ce5628b15692628e146476a008` проверена целиком; create/status
подтвердили `linux-abstract-v1`, выполнен явный focus, собственные runs
остановлены. Private prefix libpng 1.6.59/zlib 1.4 пересобран для этого запуска
по документированной процедуре из опубликованных archives: digest, upstream
tests, C ABI и фактическая `ldd` linkage (включая transitive zlib) проверены,
системные библиотеки не менялись. Все шесть PNG просмотрены исполнителем;
координатор проверил структуру чанков (только
IHDR/cHRM/bKGD/IDAT/IEND, без text-метаданных), digest и попиксельные отличия
состояний; личных данных не обнаружено. Media manifest сохраняет полные state/locale/resource/image
identities по контракту версии 1.

Для этого кандидата прошли unit/parity/schema tests (включая новые привязки
gestures: три состояния на язык, уникальные digest, публично безопасные state
тексты), static build, loopback HTTP новых EN/RU маршрутов с image digests и
свежий portable export/portable-check. После отдельного разрешения владельца
для `oui-3no.12` (записано в rules) пройдена изолированная headless
браузерная приёмка: Chromium 152 с sandbox (renderer seccomp 2, без
no-sandbox флагов), собственный временный профиль и loopback-only static
preview. EN/RU страницы жестов и сохранённые прежние сценарии (catalogue,
guide, поиск/фильтры, viewer, reduced motion, no-JS) проверены на ширинах
360/1280: prose без overflow, ровно три изображения на страницу с
локализованным alt и натуральными размерами 1280×960, клавиатурный переход из
каталога, смена языка с valid/missing anchors, no-JS prose/images/links.
Исполнитель просмотрел 14 screenshots жестов/каталога; все 152 browser PNG
сохранены в артефактах, собственные браузер и preview остановлены (cleanup
подтверждён). Это ограниченная приёмка sample, не полная квалификация 23 IDs,
не аудит доступности и не Pages deployment. Как увидеть локальный кандидат:
из `site/` с Node из `.nvmrc` выполнить `npm run build`, `npm run check:http`,
`npm run check:browser`, затем `npm run preview -- --port 0`; открыть выданный
URL с `/oui/en/capabilities/gestures` либо `/oui/ru/capabilities/gestures` или
перейти через каталог. Публикация и deployment не выполнены.

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
выше сохраняются; полный каталог, viewer и Pages/deploy не входят
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
Область остаётся sample `layout`, `controls`, `styling`, `profiles`, `layers`, `hud`, `text-input`, `atlas`, `scroll-table`, `collections`, `text`, `rich-text`,
не полный каталог; фильтрация применяется к каждому разделу отдельно. Поиск и фильтры требуют
JavaScript; без него исходные описания и ссылки всех двенадцати разделов остаются в HTML.

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

## Atlas: кандидат oui-3no.7

`site/en/capabilities/atlas.md` и русский counterpart описывают существующий
native Atlas: назначение, A/B resource identity, reload, выбранные пакеты,
ограничения PNG/manifest loader и команды с pinned source links. Kit/native
поведение не меняется; интерактивный viewer не добавлен.

Для каждого языка опубликованы три настоящих состояния: начальный A
(`B=false`, `reload=0`), переключённый B (`B=true`, `reload=0`) и B после reload
(`B=true`, `reload=1`). Повторная загрузка неизменённых файлов не обязана менять
изображение. Все шесть PNG сняты на clean source
`4da8d7a57bd2453227a4c37df6b0b4d171401681`, 1280×960, scale 1, через проверенную
ISD `f8204c61615406ce5628b15692628e146476a008`; pre-create/create/status подтвердили
`linux-abstract-v1`, собственные runs остановлены. Использован ранее подготовленный
private prefix libpng 1.6.59/zlib 1.4 с проверенной runtime linkage. PNG просмотрены,
public-safe копии pixel-identical и не содержат ancillary metadata.
Media manifest сохраняет отдельные state/locale/resource/image identities;
валидатор дополнительно требует все три состояния Atlas в обоих языках.

На этом кандидате прошли шесть site unit/schema/parity tests, включая negative
missing-reload fixture, build, loopback HTTP (11 маршрутов и media digests),
изолированный Chromium 152 с sandbox: Atlas EN/RU при 360/1280, keyboard,
locale anchors, загруженные изображения, no-JS и reduced motion. Существующие
сценарии сохранены. Все восемь Atlas browser PNG просмотрены исполнителем.
Свежий portable export (630 файлов, сверенных с source revision) и portable-check,
документированная native сборка, 11 loader tests и адресный Atlas reload-failure
test прошли. Дополнительный широкий native app test run остановлен по таймауту
после четырёх тестов, ещё 134 не выполнены; полной квалификации это не доказывает.
Другие браузеры, полная доступность, прочие gallery IDs и deploy не проверены.

Как увидеть локальный кандидат: из `site/` выполнить команды README,
затем `npm run preview -- --port 0`; открыть выданный URL с
`/oui/en/capabilities/atlas` либо `/oui/ru/capabilities/atlas`, или перейти
через соответствующий catalogue. Сравнить A/B и счётчик reload под изображениями.
Это проверено в локальном HTTP/browser, не означает публикацию или Pages deploy.

## Рецепт меню и Lab menu (`oui-3no.20`)

`site/en/recipes/menu.md` и русский counterpart документируют существующий
Basic menu recipe (`consumer/standalone_menu`): прямое замыкание
`ui_base`/`ui_layout`/`ui_interaction`/`ui_style`/`ui_text`/`ui_sdl`/`ui_sdl_text`
плюс транзитивный `unicode_graphemes`, владение моделью/строками/шрифтом,
жизненный цикл publication и фактически выполненные build/test/run команды
с pinned source links на `8bc09cff358aa629410437996520283ff98d77d9`.
Страница явно отличает этот узкий рецепт от более широкого union Integration Lab;
сниппетов кода на странице нет, только выполняемые команды и ссылки на реальные
источники. Recipe-страницы не содержат собственных изображений, как и guide.

`site/en/lab/menu.md` и русский counterpart — первый обзор Lab-экрана:
mock settings flow `lab-menu` (подменю, однострочный editor имени, checkbox,
slider, подтверждение apply/discard), его ограничения из native catalogue
(«Mock settings; process-local» / «Учебные данные; состояние только до
завершения процесса»), прямые семейства экрана и отличие от полного union
showcase с atlas loader. Каталог получил первую запись группы `lab`
(`lab-menu`, coverage 13 IDs) и восемь media records — по четыре состояния
(initial/submenu/settings/confirm) в EN и RU, снятые как настоящие PNG
1280×960, scale 1, на clean source `8bc09cff358aa629410437996520283ff98d77d9`
через проверенную ISD `f8204c61615406ce5628b15692628e146476a008`;
create/status подтвердили `linux-abstract-v1`, собственные runs остановлены
(app/supervisor/Xvfb не живы, owned пуст). Использован отдельный private
prefix libpng 1.6.59/zlib 1.4 (archive digests, upstream tests, ABI/ldd),
собранный по явному разрешению владельца для этой задачи; системные
библиотеки не менялись. Публичные PNG byte-identical приватным capture-копиям,
содержат только IHDR/cHRM/bKGD/IDAT/IEND (без текстовых metadata-чанков);
каждый просмотрен отдельно (визуальная инспекция выполнялась в vision-способном
read-only контексте `explore`, а не моделью основного контекста, который не
принимает изображения): состояния, локали и фокус соответствуют media records,
приватных данных нет. Внешний вид slider в settings-захватах совпадает с уже
опубликованными captures controls. Команды запуска recipe проверены реальными
ISD standalone-menu runs EN/RU 800×600 scale 1 (приватные скриншоты, не commit).

На этом кандидате прошли: свежий portable export (630 файлов, сверенных
с исходной ревизией) и portable-check; documented native сборка и тесты
рецепта (build standalone_menu, 2 model + 4 consumer + 17 ui_sdl + 1 ui_sdl_text
tests, сборка ui_showcase с pinned кодеками); десять site unit/schema/parity
tests, build, loopback HTTP и разрешённая изолированная Chromium browser
приёмка (135 PASS, включая новые lab/recipes страницы в EN/RU на 360/1280,
клавиатуру, locale anchors, no-JS и reduced motion); `check:catalogue:strict`
по-прежнему ожидаемо завершается ошибкой (не все 23 IDs). Kit/native API,
Slyx, extraction inventory и notices не менялись. Полная квалификация,
остальные рецепты/Lab экраны и deploy не заявляются.

Как увидеть локальный кандидат: из `site/` с Node из `.nvmrc` выполнить
`npm ci`, `npm run build`, `npm run check:http`, `npm run preview -- --port 0`;
открыть выданный URL с `/oui/en/recipes/menu`, `/oui/ru/recipes/menu`,
`/oui/en/lab/menu` либо `/oui/ru/lab/menu`, или перейти из catalogue.
Native сценарий — командами со страницы lab/menu (для агентов — только через
wrapper `scripts/ui_isd.py`). Это проверено в локальном HTTP/browser
и native ISD runs; публикация и Pages deploy не выполнялись.

## Рецепт HUD и Lab HUD (`oui-3no.22`)

Кандидат `oui-3no.22`, следующий recipe+Lab срез после опубликованного menu-среза `oui-3no.20`:
библиотека и native consumers не изменены, `kit/`, `consumer/`, `tests/`
и корневые `scripts/` байтово идентичны базовой ревизии; в `docs/` изменён
только этот spec-файл.

- `site/en/recipes/hud.md` и RU-зеркало описывают узкий рецепт HUD: прямые
  выбранные импорты `ui_layers`, `ui_hold`, `ui_hold/sdl` плюс `ui_base`,
  `ui_layout`, `ui_interaction`, `ui_style`, `ui_text`, `ui_sdl`, `ui_sdl_text`,
  транзитивно только Unicode; без controls/editor/collections/gestures/rich/
  custom/transitions/translations/inspect/wire/debug и без atlas loader, поэтому
  сам рецепт не линкует libpng/zlib. Страница документирует владение (приложение
  владеет HP, счётчиком и эффектом), сборку/запуск существующего complete compile
  fixture `tests/ui_recipes/hud/native` (F11 — bounded verification scenario,
  F12 — graceful quit) и проверки, реально выполненные на этом кандидате.
- `site/en/lab/hud.md` и RU-зеркало описывают экран `lab-hud`: учебный HP 60/100
  с clamp −10/+10, восстановление удержанием Space 1000 мс, панель Popup с Close
  и неинтерактивная подсказка Explain; ограничение native catalogue
  «Учебные данные; состояние только до завершения процесса». Различия
  порога (999 мс без эффекта), plain Activate, отмены панелью/потерей фокуса
  и отсутствия повтора восстановления описаны со ссылкой на contract test.
- `catalogue.json` получил запись группы `lab` (`lab-hud`, source
  `consumer/ui_showcase/app/lab_hud.odin`, runnable `consumer/ui_showcase`),
  в интегрированном дереве sample coverage составляет 15 IDs (включая опубликованные `gestures` и `lab-menu`); strict-проверка по-прежнему ожидаемо
  требует полного покрытия 19 gallery + 4 Lab. Site test fixtures
  (`routes.test.js`, `catalogue.test.js`, `catalogue-filter.test.js`) обновлены
  под расширенный sample, а `http-check.js` и `browser-check.js` расширены
  четырьмя маршрутами/страницами рецепта и Lab (включая image-проверки lab-hud,
  no-JS и 360/1280) — та же механика, что в предыдущих site-задачах
  (прецедент `ac0c111`).

Получены восемь настоящих PNG 1280×960, scale 1, на clean source
`8bc09cff358aa629410437996520283ff98d77d9` (зафиксировано в артефактах runs:
`dirty=false`), EN/RU по четыре состояния: initial (HP 60, Idle, count 0),
popup open, hold in progress (683/698 мс, полоса прогресса частично заполнена),
completed (HP 100, count 1). Выбранная ISD
`f8204c61615406ce5628b15692628e146476a008` прошла whole-source verification;
create/status подтвердили `linux-abstract-v1`, явный focus перед вводом,
собственные runs остановлены (`phase=stopped`, `owned=[]`). Private prefix
libpng 1.6.59/zlib 1.4 собран из digest-проверенных archives. Все восемь PNG
просмотрены (автором и отдельным независимым контекстом), содержат только
IHDR/cHRM/bKGD/IDAT/IEND, без приватных путей/имён/метаданных; digests, captions и alt в `media.json` сверены валидатором.

На этом кандидате прошли: `git diff --check`; `npm run check` (9/9, включая
обновлённые fixtures), `npm run build`, `npm run check:http` (включая новые
маршруты `en/ru/recipes/hud.html` и `en/ru/lab/hud.html`), изолированный
sandboxed Chromium `npm run check:browser` (135 PASS; новые страницы рецепта и
Lab проверены в hydrated/no-JS циклах на 360/1280 с клавиатурой, локалью и
image-проверками; собственные артефакты);
native: `odin test tests/ui_recipes/hud/native` (1), `kit/ui_hold` (20),
`kit/ui_hold/sdl` (4), `kit/ui_layers` (24); headless fixture
`tests/ui_recipes/hud` собран и запущен (`recipe-hud effects=1 conflicts=1
live=0`); native recipe запущен через обёртку в обоих локалях (EN и RU:
F11 → вывод `native-hud=ok threshold=999+1 loss=cancel failure=not-ready
recovery=no-replay input=native-synthetic`, F12, `app_exit=0`, runs
остановлены); свежий portable export + `test-ui-kit.py` (5) +
`scripts/test-ui-showcase --portable-check` прошли из export. Static build
по-прежнему не запускает Odin/ISD; native snippet проверки выполнены отдельно
от статической сборки. Независимое review (advanced, read-only) подтвердило
фактуру страниц против исходников, провенанс и неизменность kit/consumer;
его medium-находка о непокрытых маршрутах закрыта расширением http/browser
проверок, low-находки — правкой формулировок и RU-прогоном. После объединения
с опубликованными menu/gestures-задачами повторены site checks на
интегрированном дереве: `npm run check` 11/11, build, `check:http` и
sandboxed Chromium `check:browser` 159 PASS (включая 16 строк HUD-страниц);
native-часть дерева байт-идентична базовой ревизии, поэтому прежние
native/portable доказательства применимы без повтора.

Как увидеть локальный кандидат: команды README из `site/`, затем
`npm run preview -- --port 0`; открыть `/oui/en/recipes/hud`, `/oui/en/lab/hud`
или RU-зеркала, либо перейти из каталога. Native команды страниц выполняются из
подготовленного checkout по документации. Это проверено локально и не означает
публикацию, Pages deploy или полную приёмку: остальные три рецепта/Lab,
полное покрытие IDs, другие браузеры и доступность не проверены.
