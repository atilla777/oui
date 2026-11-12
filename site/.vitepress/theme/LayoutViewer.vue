<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, ref } from 'vue'
import { withBase } from 'vitepress'
import catalogue from '../../data/catalogue.json'
import media from '../../data/media.json'

const props = defineProps({ locale: { type: String, required: true } })
const labels = {
  en: { open: 'Open image viewer', title: 'Layout image viewer', close: 'Close viewer', state: 'Viewport state', large: '1280 × 960 initial', small: '960 × 720 initial' },
  ru: { open: 'Открыть просмотр изображений', title: 'Просмотр изображений компоновки', close: 'Закрыть просмотр', state: 'Состояние окна', large: '1280 × 960 начальное', small: '960 × 720 начальное' }
}
const t = computed(() => labels[props.locale])
const states = catalogue.records.find(record => record.id === 'layout').viewerStates
const selected = ref('large')
const image = computed(() => {
  const state = states.find(item => item.id === selected.value)
  return media.records.find(item => item.id === state.media[props.locale])
})
const mounted = ref(false)
const dialog = ref(null)
const opener = ref(null)
const closeButton = ref(null)
let returnFocus = null
function open() {
  returnFocus = document.activeElement
  dialog.value.showModal()
  nextTick(() => closeButton.value?.focus())
}
function close() { dialog.value.close() }
function restore() { if (returnFocus?.isConnected) returnFocus.focus(); returnFocus = null }
function contain(event) {
  if (!dialog.value?.open || event.key !== 'Tab') return
  const items = [...dialog.value.querySelectorAll('button:not([disabled]), select:not([disabled]), a[href], [tabindex="0"]')].filter(el => el.getClientRects().length)
  if (!items.length) { event.preventDefault(); dialog.value.focus(); return }
  const index = items.indexOf(document.activeElement)
  if (index < 0 || (!event.shiftKey && index === items.length - 1)) { event.preventDefault(); items[0].focus() }
  else if (event.shiftKey && index === 0) { event.preventDefault(); items[items.length - 1].focus() }
}
function guardFocus(event) {
  if (dialog.value?.open && !dialog.value.contains(event.target)) closeButton.value?.focus()
}
onMounted(() => { mounted.value = true; document.addEventListener('focusin', guardFocus) })
onBeforeUnmount(() => { document.removeEventListener('focusin', guardFocus); if (dialog.value?.open) dialog.value.close(); restore() })
</script>

<template>
  <div v-if="mounted" class="layout-viewer">
    <button ref="opener" type="button" class="viewer-open" @click="open">{{ t.open }}</button>
    <dialog ref="dialog" aria-labelledby="layout-viewer-title" @close="restore" @keydown="contain">
      <div class="viewer-header">
        <h2 id="layout-viewer-title">{{ t.title }}</h2>
        <button ref="closeButton" type="button" @click="close">{{ t.close }}</button>
      </div>
      <label for="layout-viewer-state">{{ t.state }}</label>
      <select id="layout-viewer-state" v-model="selected">
        <option v-for="state in states" :key="state.id" :value="state.id">{{ t[state.id] }}</option>
      </select>
      <figure>
        <img :src="withBase('/' + image.path)" :alt="image.alt[locale]" :width="image.drawable.width" :height="image.drawable.height">
        <figcaption>{{ image.caption[locale] }}</figcaption>
      </figure>
    </dialog>
  </div>
</template>
