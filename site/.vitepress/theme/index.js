import DefaultTheme from 'vitepress/theme'
import { h } from 'vue'
import LanguageLink from './LanguageLink.vue'
import './style.css'

export default {
  extends: DefaultTheme,
  Layout() {
    return h(DefaultTheme.Layout, null, { 'doc-before': () => h(LanguageLink) })
  }
}
