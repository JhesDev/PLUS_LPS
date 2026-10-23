<script setup lang="ts">
import { computed, onMounted, ref, shallowRef } from 'vue'
import type { WorkOrder, WorkOrderStatus } from '@/types/domain'
import { useOperationsStore } from '@/stores/operations'
import { useSessionStore } from '@/stores/session'
import { useToastStore } from '@/stores/toasts'
import MapCanvas from '@/components/map/MapCanvas.vue'
import type { RouteLine } from '@/map/route'
import StatusBadge from '@/components/common/StatusBadge.vue'
import TypeBadge from '@/components/common/TypeBadge.vue'
import PriorityBadge from '@/components/common/PriorityBadge.vue'
import EvidenceUploader from '@/components/orders/EvidenceUploader.vue'
import EvidenceGallery from '@/components/orders/EvidenceGallery.vue'
import StatusUpdateDialog from '@/components/orders/StatusUpdateDialog.vue'
import StatePanel from '@/components/common/StatePanel.vue'
import SourceBadge from '@/components/common/SourceBadge.vue'
import DemoScenarioControls from '@/components/common/DemoScenarioControls.vue'
import { ROUTE_STATUS_META, STOP_STATUS_META } from '@/utils/status'
import { formatRange, formatRelative, initials, toDateInputValue } from '@/utils/format'

const operations = useOperationsStore()
const session = useSessionStore()
const toasts = useToastStore()

const expandedEvidence = ref<string | null>(null)
const statusOrder = shallowRef<WorkOrder | null>(null)
const statusSuggested = ref<WorkOrderStatus | null>(null)

const technicianId = computed(() =>
  session.isTechnician ? session.actorId : null,
)

const technician = computed(() =>
  operations.technicians.find((item) => item.id === technicianId.value) ?? null,
)

const myOrders = computed(() =>
  operations.orders
    .filter((order) => order.assignment?.technicianId === technicianId.value)
    .filter((order) => !['ejecutada', 'imposibilitada', 'cancelada'].includes(order.status)),
)

const todayRoute = computed(() => {
  const today = toDateInputValue(new Date())
  return (
    operations.routes.find(
      (route) => route.technicianId === technicianId.value && route.routeDate === today,
    ) ?? null
  )
})

const orderedStops = computed(() => {
  const route = todayRoute.value
  if (!route) return []
  return [...route.stops]
    .sort((a, b) => a.stopOrder - b.stopOrder)
    .map((stop) => ({
      stop,
      order: operations.orders.find((order) => order.id === stop.workOrderId) ?? null,
    }))
    .filter((item): item is { stop: typeof route.stops[number]; order: WorkOrder } =>
      Boolean(item.order),
    )
})

const routeLine = computed<RouteLine | null>(() => {
  const coordinates = orderedStops.value
    .filter((item) => item.order.location)
    .map((item) => [
      item.order.location!.longitude,
      item.order.location!.latitude,
    ] as [number, number])
  if (coordinates.length < 2) return null
  return {
    coordinates,
    label: `${todayRoute.value?.code ?? 'Ruta'} · ${orderedStops.value.length} paradas`,
  }
})

const stopsNotInRoute = computed(() => {
  const inRoute = new Set(orderedStops.value.map((item) => item.order.id))
  return myOrders.value.filter((order) => !inRoute.has(order.id))
})

onMounted(() => {
  if (!operations.snapshot) void operations.load(session.scenario)
})

function startOrder(order: WorkOrder): void {
  void operations
    .updateStatus({
      orderId: order.id,
      status: 'en_proceso',
      actor: session.actor,
      location: order.location,
    })
    .then(() => toasts.success(`${order.code}: trabajo iniciado.`))
    .catch((error: unknown) =>
      toasts.error(error instanceof Error ? error.message : 'No se pudo iniciar.'),
    )
}

function openResult(order: WorkOrder, status: WorkOrderStatus): void {
  statusOrder.value = order
  statusSuggested.value = status
}
</script>

<template>
  <div class="tech-shell">
    <div class="demo-banner">
      <SourceBadge compact />
      <span class="demo-banner__text">
        Hoja de ruta demo del seed local. Sin conexión a la API real.
      </span>
      <span class="grow" />
      <DemoScenarioControls />
      <span v-if="operations.loadedAt" class="text-xs">
        {{ formatRelative(operations.loadedAt) }}
      </span>
    </div>

    <div v-if="!technicianId" class="tech-body">
      <div class="alert alert--warning">
        El rol activo es <strong>{{ session.role }}</strong>. Cambia a un usuario
        técnico en el selector superior para ver la hoja de ruta móvil.
      </div>
    </div>

    <StatePanel
      v-else-if="operations.state === 'loading'"
      kind="loading"
      title="Cargando tu jornada"
    />

    <StatePanel
      v-else-if="operations.state === 'error'"
      kind="error"
      title="No se pudo cargar la jornada"
      :message="operations.errorMessage ?? ''"
      action-label="Reintentar"
      @action="operations.load(session.scenario)"
    />

    <div v-else class="tech-body">
      <div class="card" style="padding: 12px">
        <div class="row" style="gap: 10px">
          <span class="avatar" aria-hidden="true">
            {{ initials(session.actor.name) }}
          </span>
          <div class="grow">
            <p class="strong">{{ session.actor.name }}</p>
            <p class="text-xs muted">
              {{ technician?.employeeCode ?? 'Sin código' }} ·
              {{ technician?.vehicleLabel ?? 'Sin vehículo' }}
            </p>
          </div>
        </div>
        <div class="row row--between text-sm" style="margin-top: 8px">
          <span class="muted">Órdenes activas</span>
          <span class="strong">{{ myOrders.length }}</span>
        </div>
        <div v-if="todayRoute" class="row row--between text-sm">
          <span class="muted">Ruta {{ todayRoute.code }}</span>
          <span
            class="tag"
            :style="{ background: '#eef2f6', color: ROUTE_STATUS_META[todayRoute.status].color }"
          >
            {{ ROUTE_STATUS_META[todayRoute.status].label }}
          </span>
        </div>
      </div>

      <div v-if="routeLine || myOrders.some((order) => order.location)" class="tech-map">
        <MapCanvas
          :orders="myOrders"
          :selected-order-id="null"
          :route-line="routeLine"
          :show-technicians="false"
          selection-mode="none"
        />
      </div>

      <div>
        <p class="sidebar__section-title" style="margin-bottom: 8px">
          Secuencia de paradas
        </p>
        <p class="text-xs muted" style="margin-bottom: 8px">
          Orden sugerido de visita. La línea del mapa une las paradas con rectas:
          no es geometría vial.
        </p>

        <div v-if="orderedStops.length" class="tech-order-list">
          <article
            v-for="(item, index) in orderedStops"
            :key="item.stop.id"
            class="stop-card"
          >
            <div class="stop-card__head">
              <span class="stop-index" aria-hidden="true">{{ index + 1 }}</span>
              <div class="grow">
                <span class="mono strong">{{ item.order.code }}</span>
                <span
                  class="tag"
                  :style="{
                    background: '#eef2f6',
                    color: STOP_STATUS_META[item.stop.status].color,
                    marginLeft: '8px',
                  }"
                >
                  {{ STOP_STATUS_META[item.stop.status].label }}
                </span>
                <p class="text-xs muted">{{ item.stop.notes ?? '' }}</p>
              </div>
            </div>

            <p class="strong">{{ item.order.customerName ?? 'Cliente sin nombre' }}</p>
            <p class="text-sm">{{ item.order.address ?? 'Sin dirección' }}</p>
            <div class="order-card__tags">
              <StatusBadge :status="item.order.status" />
              <TypeBadge :type="item.order.type" />
              <PriorityBadge :priority="item.order.priority" />
            </div>
            <p class="text-xs muted">
              Suministro {{ item.order.supplyNumber ?? '—' }} ·
              {{ formatRange(item.order.scheduledAt, item.order.dueAt) }}
            </p>

            <div class="action-bar">
              <button
                v-if="item.order.status === 'asignada'"
                type="button"
                class="btn btn--sm btn--primary"
                :disabled="operations.busy"
                @click="startOrder(item.order)"
              >
                ▶ Iniciar trabajo
              </button>
              <template v-if="item.order.status === 'en_proceso'">
                <button
                  type="button"
                  class="btn btn--sm btn--primary"
                  :disabled="operations.busy"
                  @click="openResult(item.order, 'ejecutada')"
                >
                  ✓ Completar
                </button>
                <button
                  type="button"
                  class="btn btn--sm btn--ghost"
                  :disabled="operations.busy"
                  @click="openResult(item.order, 'imposibilitada')"
                >
                  ⚠ Imposible
                </button>
              </template>
              <button
                type="button"
                class="btn btn--sm btn--ghost"
                @click="
                  expandedEvidence = expandedEvidence === item.order.id ? null : item.order.id
                "
              >
                📷 Evidencia
              </button>
            </div>

            <div v-if="expandedEvidence === item.order.id" class="stack stack--tight">
              <EvidenceGallery :evidence="item.order.evidence" />
              <EvidenceUploader :order-id="item.order.id" :actor="session.actor" />
            </div>
          </article>
        </div>

        <p v-else class="text-sm muted">
          No tienes paradas en la ruta de hoy.
        </p>
      </div>

      <div v-if="stopsNotInRoute.length">
        <p class="sidebar__section-title" style="margin-bottom: 8px">
          Otras órdenes asignadas
        </p>
        <div class="tech-order-list">
          <article v-for="order in stopsNotInRoute" :key="order.id" class="stop-card">
            <div class="row row--wrap" style="gap: 6px">
              <span class="mono strong">{{ order.code }}</span>
              <StatusBadge :status="order.status" />
              <TypeBadge :type="order.type" />
            </div>
            <p class="strong">{{ order.customerName ?? 'Cliente sin nombre' }}</p>
            <p class="text-sm">{{ order.address ?? 'Sin dirección' }}</p>
            <div class="action-bar">
              <button
                v-if="order.status === 'asignada'"
                type="button"
                class="btn btn--sm btn--primary"
                :disabled="operations.busy"
                @click="startOrder(order)"
              >
                ▶ Iniciar trabajo
              </button>
              <button
                v-else-if="order.status === 'en_proceso'"
                type="button"
                class="btn btn--sm btn--primary"
                :disabled="operations.busy"
                @click="openResult(order, 'ejecutada')"
              >
                ✓ Completar
              </button>
              <button
                type="button"
                class="btn btn--sm btn--ghost"
                @click="expandedEvidence = expandedEvidence === order.id ? null : order.id"
              >
                📷 Evidencia
              </button>
            </div>
            <div v-if="expandedEvidence === order.id" class="stack stack--tight">
              <EvidenceGallery :evidence="order.evidence" />
              <EvidenceUploader :order-id="order.id" :actor="session.actor" />
            </div>
          </article>
        </div>
      </div>

      <p class="alert alert--info">
        El estado de la jornada (iniciar/cerrar ruta) se cambia con la RPC
        <code class="mono">set_route_status</code>, pendiente de integrar en el
        frontend.
      </p>
    </div>

    <StatusUpdateDialog
      v-if="statusOrder"
      :open="Boolean(statusOrder)"
      :order="statusOrder"
      :actor="session.actor"
      :suggested-status="statusSuggested"
      @close="
        () => {
          statusOrder = null
        }
      "
    />
  </div>
</template>

<style scoped>
.tech-shell {
  background: var(--canvas);
}
</style>
