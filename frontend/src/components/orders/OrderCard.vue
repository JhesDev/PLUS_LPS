<script setup lang="ts">
import { computed } from 'vue'
import type { WorkOrder } from '@/types/domain'
import StatusBadge from '@/components/common/StatusBadge.vue'
import TypeBadge from '@/components/common/TypeBadge.vue'
import PriorityBadge from '@/components/common/PriorityBadge.vue'
import { formatRange } from '@/utils/format'

const props = withDefaults(
  defineProps<{
    order: WorkOrder
    selected?: boolean
    highlighted?: boolean
  }>(),
  { selected: false, highlighted: false },
)

defineEmits<{ (event: 'select', orderId: string): void }>()

const technicianName = computed(
  () => props.order.assignment?.technicianName ?? 'Sin asignar',
)
</script>

<template>
  <button
    type="button"
    class="order-card"
    :class="{ 'is-selected': selected || highlighted }"
    @click="$emit('select', order.id)"
  >
    <div class="order-card__head">
      <span class="order-card__code">{{ order.code }}</span>
      <StatusBadge :status="order.status" />
    </div>

    <span class="order-card__title">
      {{ order.customerName ?? 'Cliente sin nombre' }}
    </span>

    <div class="order-card__meta">
      <span>{{ order.supplyNumber ?? 'Sin suministro' }}</span>
      <span>{{ order.district ?? 'Sin distrito' }}</span>
      <span>{{ formatRange(order.scheduledAt, order.dueAt) }}</span>
    </div>

    <div class="order-card__tags">
      <TypeBadge :type="order.type" />
      <PriorityBadge :priority="order.priority" />
      <span class="tag" style="background: #eef2f6; color: #334155">
        {{ technicianName }}
      </span>
    </div>

    <p v-if="!order.location" class="text-xs order-card__no-geo">
      ⚠ Sin geocodificar: no aparece en el mapa
    </p>
  </button>
</template>
