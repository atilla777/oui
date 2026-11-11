# Tools/live: прочитать перед обращением к endpoint

Прочитайте tools recipe в `docs/recipes.md` выбранного portable root (в source
`docs/ui-kit/recipes.md`). Единственный текущий showcase profile — showcase-v19;
это отдельный `consumer/ui_showcase_tools`, не historical hosts/protocol10–18.
Ordinary/menu не имеют socket stack. Compile selection не разрешение; требуются
debug либо UI_DEMO_TEST gate и runtime --ui-debug + --ui-profile showcase-v19.
Test-time требует отдельный compile test gate; RPC не включает его.

Используйте `scripts/ui-showcase-cli.py --socket "$OWN_SOCKET" --profile
showcase-v19 ...`; поля/operations смотрите в --help, не придумывайте setters.
Endpoint только из своего run/record, никаких discovery чужих sockets. Capabilities
не permissions. Find даёт все exact matches, mutation только по проверенному ID.
Проверяйте dispatch/application.status/observations/effects, не только ok.

CLI exit0 success,1 refusal,2 unknown outcome. Request_id коррелирует, не dedup.
Lost reply → read-only observation, **никогда blind resend mutation**. Historical
queries не разрешают current actions/snapshots. Ready/resource mismatch/IO failure
не лечатся query/resize/input. Explicit native host R перестраивает current model
без повторения уже принятого effect. Plain Activate не completes hold.

Snapshot удерживает frozen owning reader и matched generations, проходит real
render/readback/present/restoration/association, atomic no-replace output. JSON/BMP
одного кадра отдельно от external display PNG. Incomplete output не success.

Агентская графика только через явно supplied verified isolation wrapper, не
прямой main-display run. До create проверьте полную выбранную копию supervisor
и allocation policy по её инструкции. Только свой run/input/screenshot,
explicit focus, stop в finally после start, включая failures; PNG/логи сохранить
и каждый PNG осмотреть. При isolation error никакого desktop fallback.
ISD — optional verification dependency, не production/install requirement skill.
