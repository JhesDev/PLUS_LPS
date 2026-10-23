<script setup lang="ts">
import type { OperationMetrics } from '@/utils/metrics'

const props = defineProps<{ metrics: OperationMetrics }>()

const items = () => [
  { label: 'Total', value: props.metrics.total, accent: false },
  { label: 'Pendientes', value: props.metrics.pending, accent: false },
  { label: 'En ruta', value: props.metrics.enRoute, accent: true },
  { label: 'Ejecutadas', value: props.metrics.executed, accent: false },
  { label: 'Imposib.', value: props.metrics.impossible, accent: false },
]
</script>

<template>
  <div class="kpi-strip" role="group" aria-label="Indicadores del día">
    <div
      v-for="item in items()"
      :key="item.label"
      class="kpi"
      :class="{ 'kpi--accent': item.accent }"
    >
      <span class="kpi__value">{{ item.value }}</span>
      <span class="kpi__label">{{ item.label }}</span>
    </div>
  </div>
</template>
