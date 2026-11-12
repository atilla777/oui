<script setup>
import { computed } from 'vue'
import { useData, withBase } from 'vitepress'
const { page } = useData()
const isRussian = computed(() => page.value.relativePath.startsWith('ru/'))
const isLocalized = computed(() => /^(en|ru)\//.test(page.value.relativePath))
const destination = computed(() => {
  const path = page.value.relativePath.replace(/^(en|ru)\//, '').replace(/\.md$/, '.html').replace(/index\.html$/, '')
  return withBase(`/${isRussian.value ? 'en' : 'ru'}/${path}`)
})
async function switchLanguage(event) {
  if (!location.hash || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
  event.preventDefault()
  let hash = ''
  try {
    const response = await fetch(destination.value)
    if (response.ok) {
      const document = new DOMParser().parseFromString(await response.text(), 'text/html')
      if (document.getElementById(decodeURIComponent(location.hash.slice(1)))) hash = location.hash
    }
  } catch { /* Navigate to the same page without an unverified anchor. */ }
  location.assign(destination.value + hash)
}
</script>
<template>
  <a v-if="isLocalized" class="vp-raw" :href="destination" :lang="isRussian ? 'en' : 'ru'" style="padding: 0 12px" @click="switchLanguage">{{ isRussian ? 'English' : 'Русский' }}</a>
</template>
