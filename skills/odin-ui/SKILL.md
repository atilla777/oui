---
name: odin-ui
description: >-
  Implement or inspect a screen with an explicitly selected experimental Odin UI
  kit: layout, basic menu, HUD, settings, inventory or opt-in development tools.
  Use its actual narrow APIs and typed owners. Not for gameplay/design decisions,
  installing skills/dependencies, legacy umbrella hosts, arbitrary family
  combinations, IME/bidi/shaping, full WCAG audits or unowned endpoints.
---

# Использовать автономный Odin UI kit

Входы: явно выбранные kit и target project roots, задача/ограничения, разрешённые
файлы/команды; для live — свой разрешённый run/socket и известное состояние.
Путь skill не выбирает проект и не разрешает запись/запуск. Не требуется tracker,
agent client configuration или история автора. Это source skill, не установка.

1. Прочитайте инструкции целевого проекта и `docs/README.md` выбранного portable
   root, затем нужный recipe в `docs/recipes.md`. Если выбран maintained source,
   docs находятся в `docs/ui-kit/`, packages в `kit/`, consumers в `consumer/`;
   сначала установите форму дерева, не угадывайте пути и не создавайте другой kit.
2. Перед code changes читайте [API](references/api.md). Сверяйте symbols с actual
   selected package source, не копируйте historical umbrella recipes. Выберите
   только нужные family/adapter/resources; исполнитель объединяет code/tests/docs.
3. Перед inspection/CLI/live читайте [tools](references/debug.md). Capabilities
   не permission, endpoint только свой. Unknown outcome → observation, не resend.
4. Перед выбором checks читайте [testing](references/testing.md). Run actual
   commands в выбранной форме дерева; compile/import graph не display evidence.

App owns model/outcome, stable IDs отдельно от translations. Один physical Input,
interaction/focus/Publication, явные family State. Prepare/copy/validate до
infallible commit; reducer один раз до rebuild. Historical frame не разрешает
current action/snapshot. Failure блокирует ready; explicit R строит принятую model
без replay. Owning values move/copy/destroy явно, backend/allocator живут дольше
readers. Не создавайте solver/framework/second focus owner ради удобства.

Недоступная обязательная dependency или shared-contract/design conflict:
остановите зависимую работу, сохраните partial effects, назовите точный пробел
владельцу. Не устанавливайте и не обновляйте ничего автоматически; не принимайте
новое поведение за человека и не маскируйте failure другим API.

Верните bounded result, exact source snapshot/изменённые файлы, criterion→check,
evidence paths, непроверенное/failed и remaining needs. Различайте headless/
software/display, saved/checked/accepted/published. Собственное авторство не
independent approval. Остановитесь на запрошенном результате: без installation,
publication, принятия нового scope или следующего этапа по собственной инициативе.
