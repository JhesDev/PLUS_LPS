<script setup lang="ts">
import type { WorkOrderType } from '@/types/domain'
import { TYPE_META } from '@/utils/status'

const props = withDefaults(
  defineProps<{
    type: WorkOrderType
    size?: number
    color?: string
    title?: string
  }>(),
  {
    size: 16,
    color: 'currentColor',
    title: '',
  },
)

const label = () => props.title || TYPE_META[props.type].label
</script>

<template>
  <svg
    :width="size"
    :height="size"
    viewBox="0 0 24 24"
    fill="none"
    :stroke="color"
    stroke-width="2"
    stroke-linecap="round"
    stroke-linejoin="round"
    role="img"
    :aria-label="label()"
  >
    <title>{{ label() }}</title>

    <template v-if="props.type === 'corte'">
      <line x1="6" y1="4" x2="18" y2="16" />
      <line x1="18" y1="4" x2="6" y2="16" />
      <circle cx="6" cy="19" r="2.4" />
      <circle cx="18" cy="19" r="2.4" />
    </template>

    <template v-else-if="props.type === 'reposicion'">
      <path d="M13 2 L6 13 H11 L10 22 L18 10 H12.5 Z" :fill="color" stroke="none" />
    </template>

    <template v-else-if="props.type === 'inspeccion'">
      <circle cx="11" cy="11" r="6" />
      <line x1="15.5" y1="15.5" x2="21" y2="21" />
    </template>

    <template v-else-if="props.type === 'reconexion'">
      <circle cx="9" cy="12" r="4" />
      <circle cx="15" cy="12" r="4" />
    </template>

    <template v-else-if="props.type === 'mantenimiento'">
      <circle cx="8.5" cy="15.5" r="3.4" />
      <line x1="11" y1="13" x2="19" y2="5" />
      <line x1="17.5" y1="3.5" x2="20.5" y2="6.5" />
    </template>

    <template v-else>
      <circle cx="12" cy="12" r="3.6" :fill="color" stroke="none" />
    </template>
  </svg>
</template>
