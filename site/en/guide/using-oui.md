# Using oui

## Choose a boundary {#choose-a-boundary}

Start with the interface your application needs. Headless layout can be selected separately; interaction, text, component families and the SDL3 backend are opt-in. Select the packages and their dependencies according to the actual integration rather than assuming the whole repository is required.

## Ownership and resources {#ownership-and-resources}

The consumer owns the application model and meaningful values. Follow the library's lifecycle and error contracts when preparing, using and recovering resources. Fonts, Unicode data and native codecs have their own dependencies and notices; the kit's MIT license does not relicense them.

The [quickstart](https://github.com/atilla777/oui/blob/main/docs/quickstart.md), [recipes](https://github.com/atilla777/oui/blob/main/docs/recipes.md) and [resource guide](https://github.com/atilla777/oui/blob/main/docs/resources.md) are the authoritative starting points for commands and prerequisites. Native consumers do not need this website's Node tooling.

## Prerequisites {#prerequisites}

The first checked environment is Linux x86_64 with Odin `dev-2026-10-nightly:84bc3fc`, SDL3 `3.4.16` and SDL3_ttf `3.2.2`. Install or select these separately; they are not supplied by the kit. The native linker and loader must find their shared libraries. If they are outside system paths, set `LIBRARY_PATH` and `LD_LIBRARY_PATH` to your own absolute library directories. Bash and Git are needed for the acquisition commands below; Python 3 is needed for the export helper. No Node is needed for the native example. Other configurations are not established by this guide.

## Source and portable tree {#source-and-portable}

The [published GitHub repository](https://github.com/atilla777/oui) is the maintained source repository, **not** a portable dependency repository. To inspect it and produce a local portable tree, choose an exact full source commit and a new destination:

```sh
set -euo pipefail
SOURCE_COMMIT='<full-maintained-source-commit>'
git clone --no-checkout https://github.com/atilla777/oui.git oui-source
git -C oui-source checkout --detach "$SOURCE_COMMIT"
test "$(git -C oui-source rev-parse HEAD)" = "$SOURCE_COMMIT"
python3 -B oui-source/scripts/export-ui-kit.py ./oui-portable
```

Replace the placeholder before running; `oui-source` and `oui-portable` must not already exist. The exporter copies the allowlisted files and inventory, without Git history. It does not publish a repository. To use the Git acquisition methods below, obtain an owner-published **portable tree** repository and choose its full commit, or create your own Git repository from the exported tree and commit it. No public portable repository URL is promised here. The portable commit is distinct from the maintained source commit; record their relationship yourself. Preserve `LICENSE`, inventory and all relevant resource notices.

## Pin and acquire {#acquire}

In your consumer repository, choose one method. Replace both placeholders with the portable repository URL and its exact full commit; neither `main` nor a tag is a pin. Use a fresh `vendor/odin-ui` destination. These commands require Bash and stop on errors.

### Vendor copy {#vendor}

```sh
set -euo pipefail
UI_REPOSITORY_URL='<portable-repository-url>'
UI_COMMIT='<full-portable-commit>'
test "$UI_REPOSITORY_URL" != '<portable-repository-url>'
test "$UI_COMMIT" != '<full-portable-commit>'
git clone --no-checkout "$UI_REPOSITORY_URL" ui-source
git -C ui-source checkout --detach "$UI_COMMIT"
test "$(git -C ui-source rev-parse HEAD)" = "$UI_COMMIT"
test ! -e vendor/odin-ui
mkdir -p vendor/odin-ui
git -C ui-source archive "$UI_COMMIT" | tar -x -C vendor/odin-ui
printf '%s\n' "$UI_COMMIT" > vendor/odin-ui/SOURCE_COMMIT
```

Use a fresh `ui-source` name; if you already used that name for the maintained clone, choose another. `SOURCE_COMMIT` records the selected commit, not the integrity of later edits. Commit the copied files in your consumer as appropriate.

### Submodule {#submodule}

```sh
set -euo pipefail
UI_REPOSITORY_URL='<portable-repository-url>'
UI_COMMIT='<full-portable-commit>'
test "$UI_REPOSITORY_URL" != '<portable-repository-url>'
test "$UI_COMMIT" != '<full-portable-commit>'
git submodule add "$UI_REPOSITORY_URL" vendor/odin-ui
git -C vendor/odin-ui checkout --detach "$UI_COMMIT"
test "$(git -C vendor/odin-ui rev-parse HEAD)" = "$UI_COMMIT"
git add .gitmodules vendor/odin-ui
git ls-files --stage vendor/odin-ui
```

Check that the staged entry has mode `160000` and the chosen commit, then commit the gitlink and `.gitmodules` in your consumer. On a fresh consumer checkout, `git submodule update --init -- vendor/odin-ui` obtains that recorded commit; do not use `--remote` for a pinned checkout.

## Build and run the menu {#build-and-run}

From the acquired portable root, build the existing standalone example and supply its included font explicitly:

```sh
cd vendor/odin-ui
mkdir -p build
odin build consumer/standalone_menu -collection:ui=kit -vet -vet-style -vet-tabs -vet-semicolon -show-import-graph -out:build/menu
build/menu --font resources/font.ttf --locale en --size 800x600 --scale 1
# Or, for Russian:
build/menu --font resources/font.ttf --locale ru --size 800x600 --scale 1
```

Run one command at a time on a suitable graphical session. Tab/Shift-Tab and Return/Space or the pointer operate the menu. The example supplies its own strings; applications supply their own strings and fonts. The included font has separate notices under `resources/`; retain them when distributing it. For package closures, other resources, and native dependency details see the authoritative links above. A successful build alone does not establish graphical operation or qualify other platforms.

These interactive commands are for ordinary users. Agents must not use the main display; they need a separately supplied, verified ISD through the project's wrapper, with their own run, explicit focus and cleanup.
