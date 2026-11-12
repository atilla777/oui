# Статический каталог и изображения сайта

Кандидат `oui-3no.2`, pending integration. Библиотека и native consumers не
изменены; сайт описывает существующий layout, а не реализует его в браузере.

- `site/en/` и `site/ru/` содержат `catalogue` и `capabilities/layout`.
  Страницы объясняют назначение, поведение, ограничения, узкие пакеты и отдельно
  полный showcase, с pinned source links и native build/run command.
- `site/data/catalogue.json` и `media.json` имеют `schemaVersion: 1`.
  Каталог объявляет sample coverage `layout` и `atlas` (Atlas — кандидат
  `oui-3no.7`, pending integration). Native source catalogue
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
