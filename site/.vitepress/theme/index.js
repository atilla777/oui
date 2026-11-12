import DefaultTheme from 'vitepress/theme'
import { h } from 'vue'
import LanguageLink from './LanguageLink.vue'
import LayoutViewer from './LayoutViewer.vue'
import CatalogueFilter from './CatalogueFilter.vue'
import CatalogueItem from './CatalogueItem.vue'
import './style.css'

export default {
  extends: DefaultTheme,
  enhanceApp({ app }) { app.component('LayoutViewer', LayoutViewer); app.component('CatalogueFilter', CatalogueFilter); app.component('CatalogueItem', CatalogueItem) },
  Layout() {
    return h(DefaultTheme.Layout, null, { 'doc-before': () => h(LanguageLink) })
  }
}
