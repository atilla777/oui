import DefaultTheme from 'vitepress/theme'
import { h } from 'vue'
import LanguageLink from './LanguageLink.vue'
import CatalogueFilter from './CatalogueFilter.vue'
import './style.css'

export default {
  extends: DefaultTheme,
  enhanceApp({ app }) { app.component('CatalogueFilter', CatalogueFilter) },
  Layout() {
    return h(DefaultTheme.Layout, null, { 'doc-before': () => h(LanguageLink) })
  }
}
