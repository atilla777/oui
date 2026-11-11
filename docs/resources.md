# Resources, лицензии, pins и инструменты

`inventory.json` перечисляет **каждый supplied файл**, source locator, SHA-256,
роль и primary license path. `build/` — generated output, не часть поставки.
Все notices сохраняйте вместе с ресурсами даже при embedding. MIT `LICENSE`
охватывает только выбранные собственные code/consumers/tests/helpers/docs/skill,
не игру целиком, не Odin/vendor и не перечисленное third-party содержимое.
Авторство не выводится из actor/ОС пользователя; новая строка copyright не выдумана.
Инвентарь — воспроизводимость/coverage, не юридический аудит неизвестных прав.

## Включённое содержимое

| Files / роль | Источник/version | License/notices и pin |
|---|---|---|
| resources/font.ttf, fallback.ttf; runtime только если явно выбраны | Nerd Fonts v3.5.1, DejaVu2.37; изменённые семейства Slyx UI / Slyx Rich Fallback | DejaVu-LICENSE.txt + Nerd-Fonts-NOTICE.txt + Octicons-LICENSE.txt в resources; embedded license names сохранены |
| primary font | subset по preparation/assets/fonts/source.json, icons.json и scalar-only preparation/assets/text/codepoints.txt | SHA256 `79d18f401240df12bf89a4f49dfaa377d51b36323611b184fd871e533613a3bf` |
| fallback font | explicit U+0020/0301/03B1/03A9/03AC/221E, тот же source | SHA256 `8c829904b3b02b481c55633206576181562355cf20ae7fe73040e44da5c055bf` |
| primary icon oct-play U+F500 | Octicons18.3.0, только этот glyph; не весь Nerd Fonts набор | MIT Octicons-LICENSE + Nerd-Fonts-NOTICE; не общий MIT code scope |
| kit/unicode_graphemes/data и tables_generated.odin; optional tests/preparation, generated tables runtime | Unicode15.1.0, UAX29rev43; https://www.unicode.org/Public/15.1.0/ucd/ | Unicode License v3, полный kit/unicode_graphemes/data/LICENSE.txt; original headers сохранены, tables derived, не MIT |
| resources/atlas/a,b/manifest.json,geometry.png; selected runtime/demo | existing synthetic geometry A/B, manifest1 | полный resources/notices/atlas-LICENSE (CC0-1.0), не relicense fonts/codecs/code |
| preparation/assets/text/codepoints.txt и font metadata; preparation/test | точный прежний scalar set (168 codepoints), без игровых фраз; воспроизводит прежние bytes | MIT; deterministic preparation input, не runtime text catalog |
| preparation/scripts и Unicode generate.py; preparation | existing deterministic scripts, не runtime/build dependency | MIT helpers; Unicode output/data отдельно Unicode-v3 |
| consumer/atlas_catalog/loader; selected showcase build/runtime | существующий consumer loader, не UI core PNG parser | MIT source + внешние libpng/zlib notices ниже |

Atlas A PNG SHA256 `d32d562d851df316106806b1232ab89399e9f08b528a2cf1de0bba8c2ddabe94`,
manifest `994f8243b2e9ba446e42112f844f624f8c10cfe8e0602bb9dc3c73041844ba15`;
B PNG `8242f10d55d97307f2ae362a8bb96bd75c0653b0dd1fb6e582190937e3abf3b8`,
manifest `3f4638eebe4cb59915abbdd8e707aa6ba928c993af44f971df3b787c738e81b4`.

## Внешние зависимости: не включены в собственную MIT поставку

| Зависимость | Version/source и роль | License/portable notice locator |
|---|---|---|
| Odin core/vendor | dev-2026-10-nightly:84bc3fc; https://github.com/odin-lang/Odin/commit/84bc3fc, build | BSD-3-Clause и individual vendor notices из выбранной compiler distribution; сохранить их при redistribution compiler/vendor |
| SDL3 | 3.4.16; https://github.com/libsdl-org/SDL/tree/release-3.4.16; selected runtime/link | zlib license, upstream LICENSE.txt выбранного source release |
| SDL3_ttf | 3.2.2; https://github.com/libsdl-org/SDL_ttf/tree/release-3.2.2; selected text runtime/link | zlib license, upstream LICENSE.txt; native transitive FreeType/HarfBuzz/прочие linked components по своей actual distribution |
| libpng | 1.6.59; https://www.libpng.org/pub/png/libpng.html, https://github.com/pnggroup/libpng/tree/v1.6.59; atlas runtime/link | resources/notices/libpng-LICENSE.txt, upstream LICENSE source release |
| zlib | 1.4; https://zlib.net/; atlas runtime/link | resources/notices/zlib-LICENSE.txt, source README/license |
| FontTools | 4.67.0; exact wheel URL/hash в preparation/assets/fonts/fonttools-requirements.txt; preparation only | MIT; полный license входит в выбранный wheel (*.dist-info/licenses/LICENSE), не runtime шрифта |
| Python3 / venv | preparation/std-library checks/client only; https://www.python.org/ | PSF license выбранной distribution, не поставляется |
| Bash/Git/pkg-config | check shell/acquisition/link flag discovery only | выбранные external distributions, не поставляются; GPL-3+/GPL-2/LGPL respectively, не лицензия kit |

Не используйте `/usr/share/licenses` как portable source locator. Maintained
export helper может получить notices из проверенной локальной distribution;
в другом окружении явно передайте `LIBPNG_LICENSE=/chosen/full/upstream/LICENSE`
и `ZLIB_LICENSE=/chosen/full/upstream/README`. Проверенная пара notice hashes:
libpng `bdb0a645ea18c60507d0368379b1ac5474b92255fcc2d115e07486a7672ba526`,
zlib1.4 README `5ba0fa00469b780503932c2967d34b857a15ba2354f4f86d6c747bc6646acb65`.
Проверяйте соответствие своей exact source version, а не только имя файла.

Security check 2026-11-10, только доступные publisher pages:
https://github.com/libsdl-org/SDL/security/advisories и SDL_ttf/security/advisories
показали отсутствие опубликованных advisories; это не доказательство отсутствия
уязвимостей SDL либо native transitive dependencies. FontTools/security/advisories
перечисляет GHSA-768j-98cg-p3fv (varLib XML/file write) и GHSA-6673-4983-2vx5 (XXE);
здесь используются только pinned trusted TTF/subset inputs, не произвольный XML.

**Codec update candidate, pending F8 integration:** pins отдельно приняты и
обновлены до libpng1.6.59/zlib1.4; historical F7 qualification остаётся на
1.6.58/1.3.2 и не доказывает прохождения нового дерева. Publisher pages повторно
прочитаны 2026-11-11. libpng исправляет CVE-2026-46675 в 1.6.59;
[advisory](https://github.com/pnggroup/libpng/security/advisories/GHSA-qvg3-h654-xq3j)
явно исключает simplified API из affected surface. Это ограниченное утверждение
поставщика, не общий security clearance. Zlib1.4 перечисляет исправления
CVE-2026-85091/non-blocking gzwrite, inflateGetDictionary/Sync/Prime,
deflatePrime и других API; reachability каждого из них не квалифицирована.
Strict RGB8/RGBA8 envelope/CRC и успешные regressions не означают устранения
всех native decoder defects. Полного CVE/OS/transitive аудита нет.

Официальные archives: `https://download.sourceforge.net/libpng/libpng-1.6.59.tar.xz`
SHA256 `d80dd2a38a37f803cb9b6ac7b14bd6e74ddc3b654780a8380bdf93523fdb4389`;
`https://zlib.net/zlib-1.4.tar.xz`
SHA256 `4f11c512053d7bab8d9e9b89bde3575add3e4c50a383b42ef6cb837035fc5a7c`.
Digests опубликованы соответственно libpng.org и zlib.net и проверены по
скачанным bytes. Подготовка — отдельный сознательный шаг, не hidden download
при build. Сначала собрать zlib1.4 в выбранный private prefix, затем libpng1.6.59
с `CPPFLAGS=-I<prefix>/include`, `LDFLAGS='-L<prefix>/lib -Wl,-rpath,<prefix>/lib'`
и scoped `PKG_CONFIG_PATH=<prefix>/lib/pkgconfig`. Перед проверками использовать
scoped `LD_LIBRARY_PATH=<prefix>/lib`, подтвердить C ABI и фактические `ldd`
пути executable **и libpng transitive zlib**, а не только версию pkg-config.
Не смешивать system headers/config/libraries с private парой. Системные пакеты,
SDL/Odin/fonts и persistent environment автоматически не менять. Все F8
integration/display/performance checks на перенесённом дереве ещё обязательны;
прежний performance PASS не переносится автоматически.

## Font preparation/check: только сознательно выбранный шаг

Выберите **свой** новый workspace/venv и archive. Никаких author-specific /tmp
путей. Из portable root (обычная сборка использует saved fonts и всё это пропускает):

```sh
FONT_WORK=/your/chosen/new/font-work
mkdir -p "$FONT_WORK"
python3 -m venv "$FONT_WORK/venv"
"$FONT_WORK/venv/bin/python" -m pip install --require-hashes --no-deps -r preparation/assets/fonts/fonttools-requirements.txt
curl --fail --location --output "$FONT_WORK/DejaVuSansMono.tar.xz" https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/DejaVuSansMono.tar.xz
printf '%s  %s\n' 9d3f2d60faa790b101903c2984b89c11397fc63b9ce43f2dcd25ffed4fb44e5f "$FONT_WORK/DejaVuSansMono.tar.xz" | sha256sum -c -
"$FONT_WORK/venv/bin/python" -B preparation/scripts/prepare-font.py --check --archive "$FONT_WORK/DejaVuSansMono.tar.xz"
"$FONT_WORK/venv/bin/python" -B preparation/scripts/prepare-rich-font.py --check --archive "$FONT_WORK/DejaVuSansMono.tar.xz"
"$FONT_WORK/venv/bin/python" -B preparation/scripts/test-prepare-font.py
"$FONT_WORK/venv/bin/python" -B preparation/scripts/test-prepare-rich-font.py "$FONT_WORK/DejaVuSansMono.tar.xz"
```

Archive SHA256 выше проверяется скриптом повторно; member
DejaVuSansMNerdFontMono-Regular.ttf SHA256
`9b55ade625f2d3f2a273ed16d9db2d924ad6236222920f9fd1324941cdc3c712`.
FontTools wheel SHA256
`4304f03ed7f4ba000a8dcc941ad854bfa52e2f3b6112b8f099b6f431cf98e701`.
Для явного regeneration опустите `--check`; output —
`resources/font.ttf`/`resources/fallback.ttf` в выбранной authoring-копии
kit. Это явная замена runtime resources, не дополнительная maintained TTF copy;
просмотрите diff/notices. Ни check,
ни build не делает download/retry/upgrade/rebuild font автоматически.

## Unicode regeneration/conformance

```sh
python3 -B kit/unicode_graphemes/generate.py --check
odin test kit/unicode_graphemes -vet -vet-style -vet-tabs -vet-semicolon -out:build/unicode-tests
```

Data hashes заданы в generate.py: GCB `a7e52eee647e52dc210b8719b4d7037276f4b353810293d69377fc46374cec3f`,
GraphemeBreakTest `ed9c5e92fd0911ccbeeb63c97cb19c519ea272ff1112ce843abd991582dd848f`,
emoji-data `d7aef489c8fe4c14f09ea5695200277c6b93ac82ac60845cdd2161b0d6835cc1`,
DerivedCoreProperties `f55d0db69123431a7317868725b1fcbf1eab6b265d756d1bd7f0f6d9f9ee108b`.
Generator без --check явно пишет tables в выбранной kit copy; tests используют
полный pinned1187-case corpus, не generator как oracle. Network не нужен.
Нет автоматической смены Unicode/font/codec версии и нового test runner.
