<script setup>
import { computed, provide, ref } from 'vue'
import catalogue from '../../data/catalogue.json'
import { matchesRecord } from './catalogue-filter.js'

const props = defineProps({ locale: { type: String, required: true } })
const query = ref('')
const category = ref('')
const categories = [...new Set(catalogue.records.flatMap(item => item.categories))].sort()
const categoryLabels = { en: { layout: 'Layout', geometry: 'Geometry', controls: 'Controls', styling: 'Styling', state: 'State', text: 'Text', input: 'Input', typography: 'Typography' }, ru: { layout: 'Компоновка', geometry: 'Геометрия', controls: 'Элементы управления', styling: 'Оформление', state: 'Состояние', text: 'Текст', input: 'Ввод', typography: 'Типографика' } }
const visible = computed(() => new Set(catalogue.records.filter(record => matchesRecord(record, props.locale, query.value, category.value)).map(record => record.id)))
provide('catalogueVisible', visible)
const labels = computed(() => props.locale === 'ru'
  ? { query: 'Поиск в каталоге', category: 'Категория', all: 'Все категории', reset: 'Сбросить фильтры', empty: 'Ничего не найдено.' }
  : { query: 'Search catalogue', category: 'Category', all: 'All categories', reset: 'Reset filters', empty: 'No results found.' })
function reset() { query.value = ''; category.value = '' }
</script>

<template>
  <div class="catalogue-filter">
    <div class="catalogue-controls">
      <label>{{ labels.query }} <input v-model="query" type="search"></label>
      <label>{{ labels.category }} <select v-model="category"><option value="">{{ labels.all }}</option><option v-for="item in categories" :key="item" :value="item">{{ categoryLabels[locale]?.[item] || item }}</option></select></label>
      <button type="button" @click="reset">{{ labels.reset }}</button>
    </div>
    <p v-if="!visible.size" role="status">{{ labels.empty }}</p>
    <slot />
  </div>
</template>
