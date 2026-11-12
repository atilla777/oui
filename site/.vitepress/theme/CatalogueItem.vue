<script setup>
import { inject } from 'vue'
defineProps({ id: { type: String, required: true } })
const visible = inject('catalogueVisible')
</script>

<template><div v-show="visible.has(id)"><slot /></div></template>
