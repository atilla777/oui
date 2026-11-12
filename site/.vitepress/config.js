import { defineConfig } from 'vitepress'

export default defineConfig({
  base: '/oui/',
  title: 'oui',
  description: 'Experimental Odin UI kit',
  locales: {
    root: { lang: 'en', label: 'English' },
    en: {
      lang: 'en', label: 'English',
      themeConfig: {
        nav: [{ text: 'Introduction', link: '/en/' }, { text: 'Using oui', link: '/en/guide/using-oui' }, { text: 'Catalogue', link: '/en/catalogue' }],
        sidebar: [{ text: 'Guide', items: [{ text: 'Introduction', link: '/en/' }, { text: 'Using oui', link: '/en/guide/using-oui' }, { text: 'Catalogue', link: '/en/catalogue' }, { text: 'Layout', link: '/en/capabilities/layout' }, { text: 'Controls', link: '/en/capabilities/controls' }, { text: 'Styling', link: '/en/capabilities/styling' }] }],
        outline: { label: 'On this page' },
        docFooter: { prev: 'Previous page', next: 'Next page' },
        sidebarMenuLabel: 'Menu', returnToTopLabel: 'Return to top'
      }
    },
    ru: {
      lang: 'ru', label: 'Русский',
      themeConfig: {
        nav: [{ text: 'Введение', link: '/ru/' }, { text: 'Использование oui', link: '/ru/guide/using-oui' }, { text: 'Каталог', link: '/ru/catalogue' }],
        sidebar: [{ text: 'Руководство', items: [{ text: 'Введение', link: '/ru/' }, { text: 'Использование oui', link: '/ru/guide/using-oui' }, { text: 'Каталог', link: '/ru/catalogue' }, { text: 'Компоновка', link: '/ru/capabilities/layout' }, { text: 'Элементы управления', link: '/ru/capabilities/controls' }, { text: 'Оформление', link: '/ru/capabilities/styling' }] }],
        outline: { label: 'На этой странице' },
        docFooter: { prev: 'Предыдущая страница', next: 'Следующая страница' },
        sidebarMenuLabel: 'Меню', returnToTopLabel: 'Наверх',
        langMenuLabel: 'Сменить язык', skipToContentLabel: 'Перейти к содержимому',
        darkModeSwitchLabel: 'Оформление', lightModeSwitchTitle: 'Включить светлую тему',
        darkModeSwitchTitle: 'Включить тёмную тему'
      }
    }
  },
  themeConfig: {
    search: {
      provider: 'local',
      options: {
        locales: {
          ru: { translations: {
            button: { buttonText: 'Поиск', buttonAriaLabel: 'Поиск по сайту' },
            modal: {
              displayDetails: 'Показать подробный список', resetButtonTitle: 'Очистить поиск',
              backButtonTitle: 'Закрыть поиск', noResultsText: 'Нет результатов для',
              footer: { selectText: 'выбрать', selectKeyAriaLabel: 'ввод', navigateText: 'навигация', navigateUpKeyAriaLabel: 'стрелка вверх', navigateDownKeyAriaLabel: 'стрелка вниз', closeText: 'закрыть', closeKeyAriaLabel: 'escape' }
            }
          } }
        }
      }
    },
    lightModeSwitchTitle: 'Switch to light theme',
    darkModeSwitchTitle: 'Switch to dark theme',
    notFound: { title: 'Page not found' }
  }
})
