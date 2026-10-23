<script setup lang="ts">
import type { WorkOrder } from '@/types/domain'
import StatusBadge from '@/components/common/StatusBadge.vue'
import TypeIcon from '@/components/common/TypeIcon.vue'
import PriorityBadge from '@/components/common/PriorityBadge.vue'
import { TYPE_META } from '@/utils/status'
import { formatRange, formatRelative } from '@/utils/format'

defineProps<{
  orders: WorkOrder[]
  selectedOrderId: string | null
  highlightedIds: string[]
}>()

defineEmits<{ (event: 'select', orderId: string): void }>()

function technician(order: WorkOrder): string {
  return order.assignment?.technicianName ?? '—'
}
</script>

<template>
  <div class="table-wrap">
    <table v-if="orders.length" class="data-table">
      <caption class="visually-hidden">
        Órdenes de trabajo con estado, tipo, criticidad y técnico asignado
      </caption>
      <thead>
        <tr>
          <th scope="col">Código</th>
          <th scope="col">Estado</th>
          <th scope="col">Tipo</th>
          <th scope="col">Prio.</th>
          <th scope="col">Cliente</th>
          <th scope="col">Suministro</th>
          <th scope="col">Distrito</th>
          <th scope="col">Ventana</th>
          <th scope="col">Técnico</th>
          <th scope="col">Actualizado</th>
        </tr>
      </thead>
      <tbody>
        <tr
          v-for="order in orders"
          :key="order.id"
          :class="{
            'is-selected':
              order.id === selectedOrderId || highlightedIds.includes(order.id),
          }"
          tabindex="0"
          @click="$emit('select', order.id)"
          @keydown.enter="$emit('select', order.id)"
        >
          <td class="mono strong">
            {{ order.code }}
            <span v-if="!order.location" title="Sin geocodificar">⚠</span>
          </td>
          <td><StatusBadge :status="order.status" /></td>
          <td>
            <span class="row" style="gap: 6px">
              <TypeIcon :type="order.type" :size="14" color="#334155" />
              {{ TYPE_META[order.type].short }}
            </span>
          </td>
          <td><PriorityBadge :priority="order.priority" /></td>
          <td>{{ order.customerName ?? '—' }}</td>
          <td class="mono">{{ order.supplyNumber ?? '—' }}</td>
          <td>{{ order.district ?? '—' }}</td>
          <td>{{ formatRange(order.scheduledAt, order.dueAt) }}</td>
          <td>{{ technician(order) }}</td>
          <td class="muted text-xs">{{ formatRelative(order.updatedAt) }}</td>
        </tr>
      </tbody>
    </table>

    <p v-else class="table-empty">
      No hay órdenes que coincidan con los filtros actuales.
    </p>
  </div>
</template>
