<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import AppHeader from '@/components/layout/AppHeader.vue'
import ToastHost from '@/components/common/ToastHost.vue'
import { useOperationsStore } from '@/stores/operations'

const route = useRoute()
const operations = useOperationsStore()

/**
 * KPIs del día solo en las superficies de datos (despacho y coordinación).
 * La vista del técnico prioriza la hoja de ruta.
 */
const showMetrics = computed(
  () => route.name === 'despacho' || route.name === 'coordinacion',
)

const metrics = computed(() =>
  showMetrics.value && operations.orders.length ? operations.globalMetrics : null,
)
</script>

<template>
  <div class="app-shell">
    <AppHeader :metrics="metrics" />
    <main class="app-main">
      <RouterView />
    </main>
    <ToastHost />
  </div>
</template>
