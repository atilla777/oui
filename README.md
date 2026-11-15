# Odin UI kit — experimental

Выборочные Odin packages для UI небольших игр: headless layout, отдельное
interaction/text, opt-in families и SDL3 backend. Это experimental API, не
совместимый facade старого umbrella `ui` и не обещание произвольной композиции.

Начните с [quickstart](docs/quickstart.md), затем выберите один из
[шести рецептов](docs/recipes.md). [API](docs/api.md) и [lifecycle](docs/lifecycle.md) объясняют
owners/errors/recovery; [compatibility](docs/compatibility.md) — границы поддержки;
[resources](docs/resources.md) — ресурсы, инструменты подготовки и полные notices.
[Provenance](docs/provenance.md) — необязательная история, не шаг сборки.

Planned bilingual visual documentation / План двуязычной визуальной документации:
[feature #1](https://github.com/atilla777/oui/issues/1),
[requirements](docs/specs/1/spec.md), [design](docs/specs/1/design.md),
[delivery plan](docs/specs/1/plan.md). This is preparation, not a deployed website.

Maintained portable root: `kit/`, `consumer/`, `resources/`, `docs/`, `skills/`, `tests/`, `scripts/`, `preparation/`. Production build/run не требует Slyx checkout, истории проекта, трекера, Python, генераторов, agent client или сети. Full relocated qualification ещё не завершена.

Собственный выбранный code/consumers/tests/helpers/docs/skill — MIT, полный текст
в `LICENSE` export. Unicode tables/data, fonts, atlas и внешние codecs/toolchain
**не** перелицензируются: см. resources. MIT не распространяется автоматически
на игру, всё `kit/`, чужие инструменты или весь исходный репозиторий.

Нет автоматической установки/обновления skill или зависимости. Выберите kit и
целевой проект явно. Поставка сама не создаёт отдельный remote или release.
