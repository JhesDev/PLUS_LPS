<script setup lang="ts">
import { computed } from 'vue'
import type { Evidence, StatusHistoryEntry, WorkOrder, WorkOrderStatus } from '@/types/domain'
import type { Actor } from '@/services/operationsRepository'
import StatusBadge from '@/components/common/StatusBadge.vue'
import TypeBadge from '@/components/common/TypeBadge.vue'
import PriorityBadge from '@/components/common/PriorityBadge.vue'
import HistoryTimeline from './HistoryTimeline.vue'
import EvidenceGallery from './EvidenceGallery.vue'
import EvidenceUploader from './EvidenceUploader.vue'
import { allowedTransitions, STATUS_META } from '@/utils/status'
import { formatDateTime, formatRange } from '@/utils/format'

const props = defineProps<{
  order: WorkOrder
  history: StatusHistoryEntry[]
  actor: Actor
  canOperate: boolean
}>()

const emit = defineEmits<{
  (event: 'close'): void
  (event: 'assign', orderId: string): void
  (event: 'unassign', orderId: string): void
  (event: 'change-status', payload: { orderId: string; status: WorkOrderStatus }): void
  (event: 'preview-evidence', item: Evidence): void
  (event: 'focus-map', orderId: string): void
}>()

const transitions = computed(() =>
  allowedTransitions(props.actor.role, props.order.status),
)

const technicianName = computed(
  () => props.order.assignment?.technicianName ?? 'Sin asignar',
)

/**
 * El bucket y la política RLS permiten INSERT tanto al despachador como al
 * técnico con la orden asignada. La UI respeta esa misma capacidad.
 */
const canUpload = computed(
  () =>
    props.actor.role === 'despachador' ||
    (props.actor.role === 'tecnico' &&
      props.order.assignment?.technicianId === props.actor.id),
)
</script>

<template>
  <aside class="detail-drawer" aria-label="Detalle de la orden">
    <div class="drawer__head">
      <div>
        <p class="text-xs muted strong">
          {{ order.externalSource ? `Origen ${order.externalSource} · ` : '' }}
          {{ order.externalId ?? 'sin referencia externa' }}
        </p>
        <h2 class="drawer__title mono">{{ order.code }}</h2>
        <p class="text-sm muted">
          {{ order.customerName ?? 'Cliente sin nombre' }}
        </p>
      </div>
      <button type="button" class="btn btn--sm btn--ghost" @click="emit('close')">
        ✕
      </button>
    </div>

    <div class="drawer__body">
      <div class="row row--wrap" style="gap: 6px">
        <StatusBadge :status="order.status" />
        <TypeBadge :type="order.type" />
        <PriorityBadge :priority="order.priority" />
        <span v-if="!order.location" class="tag" style="background: var(--warning-soft); color: #7c4a03">
          Sin geocodificar
        </span>
      </div>

      <div class="drawer__section">
        <p class="drawer__section-title">Datos del suministro</p>
        <dl class="def-list">
          <dt>Suministro</dt>
          <dd class="mono">{{ order.supplyNumber ?? '—' }}</dd>
          <dt>Dirección</dt>
          <dd>{{ order.address ?? '—' }}</dd>
          <dt>Distrito</dt>
          <dd>{{ order.district ?? '—' }}</dd>
          <dt>Zona</dt>
          <dd>{{ order.zone ?? '—' }}</dd>
          <dt>Ventana</dt>
          <dd>{{ formatRange(order.scheduledAt, order.dueAt) }}</dd>
          <dt>Vence</dt>
          <dd>{{ formatDateTime(order.dueAt) }}</dd>
          <dt>Coordenadas</dt>
          <dd class="mono">
            <template v-if="order.location">
              {{ order.location.latitude.toFixed(5) }},
              {{ order.location.longitude.toFixed(5) }}
            </template>
            <template v-else>—</template>
          </dd>
          <dt>Notas</dt>
          <dd>{{ order.notes ?? '—' }}</dd>
          <dt v-if="order.cancellationReason">Motivo cancelación</dt>
          <dd v-if="order.cancellationReason">{{ order.cancellationReason }}</dd>
        </dl>
      </div>

      <div class="drawer__section">
        <p class="drawer__section-title">Asignación vigente</p>
        <div v-if="order.assignment" class="card" style="padding: 10px">
          <p class="strong">{{ technicianName }}</p>
          <p class="text-xs muted">
            Asignada {{ formatDateTime(order.assignment.assignedAt) }}
          </p>
          <p v-if="order.assignment.notes" class="text-sm">
            {{ order.assignment.notes }}
          </p>
        </div>
        <p v-else class="text-sm muted">La orden no tiene técnico asignado.</p>
      </div>

      <div class="drawer__section">
        <p class="drawer__section-title">Evidencias</p>
        <EvidenceGallery
          :evidence="order.evidence"
          :read-only="!canUpload"
          @preview="emit('preview-evidence', $event)"
        />
        <EvidenceUploader
          v-if="canUpload"
          :order-id="order.id"
          :actor="actor"
        />
      </div>

      <div class="drawer__section">
        <p class="drawer__section-title">Historial y auditoría</p>
        <HistoryTimeline :entries="history" />
      </div>
    </div>

    <div class="drawer__footer">
      <button
        v-if="order.location"
        type="button"
        class="btn btn--sm btn--ghost"
        @click="emit('focus-map', order.id)"
      >
        ⌖ Centrar en mapa
      </button>

      <template v-if="canOperate">
        <button
          type="button"
          class="btn btn--sm btn--navy"
          @click="emit('assign', order.id)"
        >
          {{ order.assignment ? 'Reasignar' : 'Asignar' }}
        </button>

        <button
          v-if="order.assignment"
          type="button"
          class="btn btn--sm btn--ghost"
          @click="emit('unassign', order.id)"
        >
          Desasignar
        </button>

        <button
          v-for="status in transitions"
          :key="status"
          type="button"
          class="btn btn--sm"
          :class="status === 'cancelada' || status === 'imposibilitada' ? 'btn--ghost' : 'btn--primary'"
          @click="emit('change-status', { orderId: order.id, status })"
        >
          {{ STATUS_META[status].label }}
        </button>
      </template>

      <p v-else class="text-xs muted">
        Modo lectura: el rol {{ actor.role }} no modifica órdenes ni asignaciones.
      </p>
    </div>
  </aside>
</template>
