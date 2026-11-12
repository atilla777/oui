# Статический каталог и изображения сайта

Основа `oui-3no.2`; расширение `oui-3no.6` — локальный кандидат, pending integration.
Библиотека и native consumers не изменены; сайт описывает существующие
layout и profiles, а не реализует их в браузере.

- `site/en/` и `site/ru/` содержат `catalogue`, `capabilities/layout` и
  `capabilities/profiles`.
  Страницы объясняют назначение, поведение, ограничения, узкие пакеты и отдельно
  полный showcase, с pinned source links и native build/run command.
- `site/data/catalogue.json` и `media.json` имеют `schemaVersion: 1`.
  Каталог объявляет sample coverage только `layout` и `profiles`. Native source catalogue
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
