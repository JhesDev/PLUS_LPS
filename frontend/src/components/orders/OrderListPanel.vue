<script setup lang="ts">
import { computed } from 'vue'
import type { WorkOrder } from '@/types/domain'
import OrderCard from './OrderCard.vue'

const props = defineProps<{
  orders: WorkOrder[]
  selectedOrderId: string | null
  highlightedIds: string[]
  hasFilters: boolean
}>()

defineEmits<{
  (event: 'select', orderId: string): void
  (event: 'clear-filters'): void
}>()

const title = computed(() =>
  props.orders.length === 1
    ? '1 orden visible'
    : `${props.orders.length} órdenes visibles`,
)
</script>

<template>
  <div>
    <div class="order-list__header">
      <span class="text-xs muted strong">{{ title }}</span>
    </div>

    <div v-if="orders.length" class="order-list">
      <OrderCard
        v-for="order in orders"
        :key="order.id"
        :order="order"
        :selected="order.id === selectedOrderId"
        :highlighted="highlightedIds.includes(order.id)"
        @select="$emit('select', $event)"
      />
    </div>

    <div v-else class="order-list__empty">
      <p class="strong">Sin órdenes para los filtros actuales</p>
      <p class="text-sm muted">
        Ajusta los filtros o la búsqueda para ver más resultados.
      </p>
      <button
        v-if="hasFilters"
        type="button"
        class="btn btn--sm btn--ghost"
        style="margin-top: 10px"
        @click="$emit('clear-filters')"
      >
        Limpiar filtros
      </button>
    </div>
  </div>
</template>

<style scoped>
.order-list__header {
  padding: 8px 12px;
  border-bottom: 1px solid var(--ink-100);
}
</style>
