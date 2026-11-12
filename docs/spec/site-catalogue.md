# Статический каталог и изображения сайта

Основа `oui-3no.2`; расширение кандидата `oui-3no.11` pending integration.
Библиотека и native consumers не изменены; сайт описывает существующие
возможности, а не реализует их в браузере.

- `site/en/` и `site/ru/` содержат `catalogue` и `capabilities/layout`,
  `capabilities/layers`, `capabilities/hud`.
  Страницы объясняют назначение, поведение, ограничения, узкие пакеты и отдельно
  полный showcase, с pinned source links и native build/run command.
- `site/data/catalogue.json` и `media.json` имеют `schemaVersion: 1`.
  Каталог объявляет sample coverage `layout`, `layers`, `hud`. Native source catalogue
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
Все 36 итоговых browser PNG просмотрены исполнителем; собственные браузеры и
preview остановлены в `finally`. Изображения на мобильном экране уменьшены;
viewer/zoom и полная квалификация остальных IDs не входят в этот результат.
Публикация и deployment не выполнены.
После сборки открыть `/oui/en/capabilities/layers` или `/oui/en/capabilities/hud`
(либо соответствующие `/ru/` страницы); ожидаются текст и два настоящих
изображения на каждой странице. HTTP и браузерное представление проверены.
Браузерные проверки воспроизводятся командой `npm run check:browser` из `site/`
в разрешённой sandboxed Chromium-среде; другие браузеры и полный аудит доступности
не проверены.
