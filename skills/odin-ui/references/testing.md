# Проверки: прочитать перед выбором checks

Portable `docs/quickstart.md` и `docs/resources.md` содержат actual build/test/
preparation команды. В source form они в `docs/ui-kit/`; export-form commands
не выполняются в source root. Используйте core:testing/@(test), existing proof
scripts, check/vet и fresh linked build; не новый runner/framework.

Из portable root: `bash scripts/test-ui-showcase --portable-check`.
Restricted closures/snippets/import graphs всех шести recipes проверяйте отдельно
от большого showcase union. Layout-only/menu не должны получать optional пакеты.
Не называйте package presence достаточным доказательством composed lifecycle.

Для affected поведения проверьте accepted/rejected/boundaries, guards/duplicate
ownership/regions, lifetime/copy/destroy/partial-init, failed publication/render,
historical/current и R/no-replay, compile/runtime tools gates и unknown outcome.
Для layout/resources сохраняйте exact dimensions/scale/fonts/data/hash.
TDD применяйте если требует проект/запрос: meaningful expected RED до production,
GREEN после; setup/compile failure сам по себе не RED. Text-only не требует
искусственного RED или live-agent experiment.

SDL logic tests serial/dummy не display/hardware evidence. Для visual изменений
нужен own isolated ru/en run, explicit focus, finally stop, сохранённые logs/PNG
и осмотр каждого PNG (читаемость/focus/clip). Недоступный display/check — unverified,
не PASS. Не переносите прежние measurements/C08 assessment в FPS/WCAG/platform
qualification. Full matrix не подменяется bounded smoke; source skill static
checks не доказывают agent routing/reliability/cost.
