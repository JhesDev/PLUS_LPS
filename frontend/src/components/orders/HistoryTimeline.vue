<script setup lang="ts">
import type { StatusHistoryEntry } from '@/types/domain'
import { STATUS_META } from '@/utils/status'
import { formatDateTime } from '@/utils/format'

defineProps<{ entries: StatusHistoryEntry[] }>()
</script>

<template>
  <div v-if="entries.length" class="timeline">
    <div v-for="entry in entries" :key="entry.id" class="timeline__item">
      <span
        class="timeline__dot"
        :style="{ background: STATUS_META[entry.toStatus].color }"
        aria-hidden="true"
      />
      <p class="timeline__line">
        <span v-if="entry.fromStatus" class="muted">
          {{ STATUS_META[entry.fromStatus].label }} →
        </span>
        <span class="strong">{{ STATUS_META[entry.toStatus].label }}</span>
      </p>
      <p class="timeline__meta">
        {{ formatDateTime(entry.changedAt) }} ·
        {{ entry.changedByName ?? 'Sistema' }}
      </p>
      <p v-if="entry.reason" class="timeline__reason">{{ entry.reason }}</p>
    </div>
  </div>

  <p v-else class="text-sm muted">
    Sin movimientos registrados para esta orden.
  </p>
</template>
