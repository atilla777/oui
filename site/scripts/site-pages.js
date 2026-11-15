// Shared route and media expectations for the local preview check and the live
// read-back check. Keeping one table prevents the two checks from drifting.
export const pages = [
  ['', 'en', 'experimental Odin UI kit', '/oui/ru/'],
  ['en/', 'en', 'Introducing oui', '/oui/ru/'],
  ['ru/', 'ru', 'Знакомство с oui', '/oui/en/'],
  ['en/guide/using-oui.html', 'en', 'Using oui', '/oui/ru/guide/using-oui.html'],
  ['ru/guide/using-oui.html', 'ru', 'Использование oui', '/oui/en/guide/using-oui.html'],
  ['en/catalogue.html', 'en', 'Capability catalogue', '/oui/ru/catalogue.html'],
  ['ru/catalogue.html', 'ru', 'Каталог возможностей', '/oui/en/catalogue.html'],
  ['en/capabilities/accessibility.html', 'en', 'Accessibility assessment', '/oui/ru/capabilities/accessibility.html'],
  ['ru/capabilities/accessibility.html', 'ru', 'Оценка доступности', '/oui/en/capabilities/accessibility.html'],
  ['en/capabilities/layout.html', 'en', 'Layout', '/oui/ru/capabilities/layout.html'],
  ['ru/capabilities/layout.html', 'ru', 'Компоновка', '/oui/en/capabilities/layout.html'],
  ['en/capabilities/text.html', 'en', 'Text', '/oui/ru/capabilities/text.html'],
  ['ru/capabilities/text.html', 'ru', 'Текст', '/oui/en/capabilities/text.html'],
  ['en/capabilities/rich-text.html', 'en', 'Rich text', '/oui/ru/capabilities/rich-text.html'],
  ['ru/capabilities/rich-text.html', 'ru', 'Форматированный текст', '/oui/en/capabilities/rich-text.html'],
  ['en/capabilities/scroll-table.html', 'en', 'Scroll and table', '/oui/ru/capabilities/scroll-table.html'],
  ['ru/capabilities/scroll-table.html', 'ru', 'Прокрутка и таблица', '/oui/en/capabilities/scroll-table.html'],
  ['en/capabilities/collections.html', 'en', 'Virtual collections', '/oui/ru/capabilities/collections.html'],
  ['ru/capabilities/collections.html', 'ru', 'Виртуальные коллекции', '/oui/en/capabilities/collections.html'],
  ['en/capabilities/layers.html', 'en', 'Layers', '/oui/ru/capabilities/layers.html'],
  ['ru/capabilities/layers.html', 'ru', 'Слои', '/oui/en/capabilities/layers.html'],
  ['en/capabilities/hud.html', 'en', 'HUD hold', '/oui/ru/capabilities/hud.html'],
  ['ru/capabilities/hud.html', 'ru', 'HUD и удержание', '/oui/en/capabilities/hud.html'],
  ['en/capabilities/transitions.html', 'en', 'State transitions', '/oui/ru/capabilities/transitions.html'],
  ['ru/capabilities/transitions.html', 'ru', 'Переходы состояния', '/oui/en/capabilities/transitions.html'],
  ['en/capabilities/atlas.html', 'en', 'Atlas', '/oui/ru/capabilities/atlas.html'],
  ['ru/capabilities/atlas.html', 'ru', 'Атлас', '/oui/en/capabilities/atlas.html'],
  ['en/capabilities/composition.html', 'en', 'Nested composition', '/oui/ru/capabilities/composition.html'],
  ['ru/capabilities/composition.html', 'ru', 'Вложенная композиция', '/oui/en/capabilities/composition.html'],
  ['en/capabilities/custom.html', 'en', 'Custom primitives', '/oui/ru/capabilities/custom.html'],
  ['ru/capabilities/custom.html', 'ru', 'Свои примитивы', '/oui/en/capabilities/custom.html'],
  ['en/capabilities/gestures.html', 'en', 'Gestures', '/oui/ru/capabilities/gestures.html'],
  ['ru/capabilities/gestures.html', 'ru', 'Жесты', '/oui/en/capabilities/gestures.html'],
  ['en/capabilities/text-input.html', 'en', 'Text input', '/oui/ru/capabilities/text-input.html'],
  ['ru/capabilities/text-input.html', 'ru', 'Ввод текста', '/oui/en/capabilities/text-input.html'],
  ['en/capabilities/controls.html', 'en', 'Controls', '/oui/ru/capabilities/controls.html'],
  ['ru/capabilities/controls.html', 'ru', 'Элементы управления', '/oui/en/capabilities/controls.html'],
  ['en/capabilities/styling.html', 'en', 'Styling', '/oui/ru/capabilities/styling.html'],
  ['ru/capabilities/styling.html', 'ru', 'Оформление', '/oui/en/capabilities/styling.html'],
  ['en/capabilities/profiles.html', 'en', 'Profiles', '/oui/ru/capabilities/profiles.html'],
  ['ru/capabilities/profiles.html', 'ru', 'Профили', '/oui/en/capabilities/profiles.html'],
  ['en/labs/settings.html', 'en', 'Lab settings', '/oui/ru/labs/settings.html'],
  ['ru/labs/settings.html', 'ru', 'Лаборатория: настройки', '/oui/en/labs/settings.html'],
  ['en/recipes/settings.html', 'en', 'Settings recipe', '/oui/ru/recipes/settings.html'],
  ['ru/recipes/settings.html', 'ru', 'Рецепт: настройки', '/oui/en/recipes/settings.html'],
  ['en/recipes/menu.html', 'en', 'Basic menu recipe', '/oui/ru/recipes/menu.html'],
  ['ru/recipes/menu.html', 'ru', 'Рецепт меню', '/oui/en/recipes/menu.html'],
  ['en/lab/menu.html', 'en', 'Lab menu', '/oui/ru/lab/menu.html'],
  ['ru/lab/menu.html', 'ru', 'Меню лаборатории', '/oui/en/lab/menu.html'],
  ['en/recipes/hud.html', 'en', 'HUD recipe', '/oui/ru/recipes/hud.html'],
  ['ru/recipes/hud.html', 'ru', 'Рецепт HUD', '/oui/en/recipes/hud.html'],
  ['en/lab/hud.html', 'en', 'Lab HUD', '/oui/ru/lab/hud.html'],
  ['ru/lab/hud.html', 'ru', 'Лаборатория HUD', '/oui/en/lab/hud.html'],
  ['en/recipes/inventory.html', 'en', 'Inventory recipe', '/oui/ru/recipes/inventory.html'],
  ['ru/recipes/inventory.html', 'ru', 'Рецепт инвентаря', '/oui/en/recipes/inventory.html'],
  ['en/lab/inventory.html', 'en', 'Lab inventory', '/oui/ru/lab/inventory.html'],
  ['ru/lab/inventory.html', 'ru', 'Инвентарь лаборатории', '/oui/en/lab/inventory.html'],
  ['en/capabilities/diagnostics-performance.html', 'en', 'Diagnostics and performance', '/oui/ru/capabilities/diagnostics-performance.html'],
  ['ru/capabilities/diagnostics-performance.html', 'ru', 'Диагностика и производительность', '/oui/en/capabilities/diagnostics-performance.html'],
  ['en/capabilities/world.html', 'en', 'World anchors', '/oui/ru/capabilities/world.html'],
  ['ru/capabilities/world.html', 'ru', 'Якоря мира', '/oui/en/capabilities/world.html']
]

const mediaSections = /capabilities\/(layout|layers|hud|transitions|text-input|scroll-table|collections|text|rich-text|gestures|diagnostics-performance|world)\.html/

// Section detection and expected counts mirror the local preview check exactly.
// Pages it does not map are either covered by `mediaStates` below or are outside
// this manifest set; neither check invents additional expectations.
export const mediaSection = path => path.endsWith('labs/settings.html')
  ? 'lab-settings'
  : path.match(mediaSections)?.[1] ?? (path.endsWith('lab/menu.html') ? 'lab-menu'
    : path.endsWith('lab/inventory.html') ? 'lab-inventory'
      : path.endsWith('lab/hud.html') ? 'lab-hud' : undefined)

export const expectedMediaCount = section =>
  ['profiles', 'atlas', 'gestures'].includes(section) ? 3
    : ['text-input', 'scroll-table', 'collections'].includes(section) ? 1
      : ['lab-menu', 'lab-hud', 'lab-settings'].includes(section) ? 4
        : section === 'lab-inventory' ? 5 : 2

export const mediaStates = [
  ['atlas', ['initial', 'alternate', 'reload']],
  ['profiles', ['initial', 'dialog', 'applied']],
  ['controls', ['initial', 'changed']],
  ['styling', ['initial', 'changed']],
  ['gestures', ['initial', 'proposal', 'applied']],
  ['diagnostics-performance', ['initial', 'diagnostic']]
]