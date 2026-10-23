<script setup lang="ts">
withDefaults(
  defineProps<{
    label: string
    value: number | string
    hint?: string
    accent?: string
  }>(),
  { hint: '', accent: '' },
)
</script>

<template>
  <div class="card metric-card" :style="accent ? { borderLeft: `3px solid ${accent}` } : {}">
    <span class="metric-card__value">{{ value }}</span>
    <span class="metric-card__label">{{ label }}</span>
    <span v-if="hint" class="metric-card__hint">{{ hint }}</span>
  </div>
</template>
