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
        nav: [{ text: 'Introduction', link: '/en/' }, { text: 'Using oui', link: '/en/guide/using-oui' }],
        sidebar: [{ text: 'Guide', items: [{ text: 'Introduction', link: '/en/' }, { text: 'Using oui', link: '/en/guide/using-oui' }] }],
        outline: { label: 'On this page' },
        docFooter: { prev: 'Previous page', next: 'Next page' },
        sidebarMenuLabel: 'Menu', returnToTopLabel: 'Return to top'
      }
    },
    ru: {
      lang: 'ru', label: 'Русский',
      themeConfig: {
        nav: [{ text: 'Введение', link: '/ru/' }, { text: 'Использование oui', link: '/ru/guide/using-oui' }],
        sidebar: [{ text: 'Руководство', items: [{ text: 'Введение', link: '/ru/' }, { text: 'Использование oui', link: '/ru/guide/using-oui' }] }],
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
    lightModeSwitchTitle: 'Switch to light theme',
    darkModeSwitchTitle: 'Switch to dark theme',
    notFound: { title: 'Page not found' }
  }
})
