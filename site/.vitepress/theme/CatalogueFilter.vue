<script setup>
import { computed, ref } from 'vue'
import catalogue from '../../data/catalogue.json'
import { matchesRecord } from './catalogue-filter.js'

const props = defineProps({ locale: { type: String, required: true } })
const query = ref('')
const category = ref('')
const record = catalogue.records.find(item => item.id === 'layout')
const categories = [...new Set(catalogue.records.flatMap(item => item.categories))].sort()
const categoryLabels = { en: { layout: 'Layout', geometry: 'Geometry' }, ru: { layout: 'Компоновка', geometry: 'Геометрия' } }
const visible = computed(() => matchesRecord(record, props.locale, query.value, category.value))
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
    <p v-if="!visible" role="status">{{ labels.empty }}</p>
    <div v-show="visible"><slot /></div>
  </div>
</template>
