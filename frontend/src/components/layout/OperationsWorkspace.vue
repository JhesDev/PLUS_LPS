<script setup lang="ts">
import { computed, onMounted, ref, shallowRef, watch } from 'vue'
import type { Evidence, WorkOrder, WorkOrderStatus } from '@/types/domain'
import type { DemoScenario } from '@/services/operationsRepository'
import { useOperationsStore } from '@/stores/operations'
import { useSessionStore } from '@/stores/session'
import MapCanvas from '@/components/map/MapCanvas.vue'
import type { RouteLine } from '@/map/route'
import MapToolbar from '@/components/map/MapToolbar.vue'
import MapLegend from '@/components/map/MapLegend.vue'
import OrderFilters from '@/components/orders/OrderFilters.vue'
import OrderListPanel from '@/components/orders/OrderListPanel.vue'
import OrderTable from '@/components/orders/OrderTable.vue'
import OrderDetailDrawer from '@/components/orders/OrderDetailDrawer.vue'
import AssignDialog from '@/components/orders/AssignDialog.vue'
import StatusUpdateDialog from '@/components/orders/StatusUpdateDialog.vue'
import TechnicianList from '@/components/technicians/TechnicianList.vue'
import StatePanel from '@/components/common/StatePanel.vue'
import MetricCard from '@/components/common/MetricCard.vue'
import SourceBadge from '@/components/common/SourceBadge.vue'
import DemoScenarioControls from '@/components/common/DemoScenarioControls.vue'
import { useToastStore } from '@/stores/toasts'
import { hasActiveFilters } from '@/utils/filters'
import { downloadCsv } from '@/utils/csv'
import { STATUS_META } from '@/utils/status'
import { formatDateTime, formatRelative, toDateInputValue } from '@/utils/format'

const props = withDefaults(defineProps<{ mode?: 'despacho' | 'auditoria' }>(), {
  mode: 'despacho',
})

const operations = useOperationsStore()
const session = useSessionStore()
const toasts = useToastStore()

const canOperate = computed(() => session.isDispatcher && props.mode === 'despacho')
const isAudit = computed(() => props.mode === 'auditoria')

type SidebarTab = 'orders' | 'technicians' | 'audit' | 'table'
const sidebarTab = ref<SidebarTab>('orders')
const mapRef = ref<InstanceType<typeof MapCanvas> | null>(null)
const proximityTechnicianId = ref('')
const selectedTechnicianId = ref<string | null>(null)

const assignOpen = ref(false)
const assignTechnicianPreselect = ref<string | null>(null)
const assignOrders = ref<WorkOrder[]>([])

const statusOpen = ref(false)
const statusOrder = shallowRef<WorkOrder | null>(null)
const statusSuggested = ref<WorkOrderStatus | null>(null)

const previewEvidence = ref<Evidence | null>(null)

const activeRoute = computed(() => {
  const technicianId =
    selectedTechnicianId.value ?? operations.selectedOrder?.assignment?.technicianId
  if (!technicianId) return null
  const today = toDateInputValue(new Date())
  return (
    operations.routes.find(
      (route) => route.technicianId === technicianId && route.routeDate === today,
    ) ??
    operations.routes.find((route) => route.technicianId === technicianId) ??
    null
  )
})

const routeLine = computed<RouteLine | null>(() => {
  const route = activeRoute.value
  if (!route) return null
  const coordinates = [...route.stops]
    .sort((a, b) => a.stopOrder - b.stopOrder)
    .map((stop) => operations.orders.find((order) => order.id === stop.workOrderId))
    .filter((order): order is WorkOrder => Boolean(order?.location))
    .map((order) => [order.location!.longitude, order.location!.latitude] as [number, number])

  if (coordinates.length < 2) return null
  return {
    coordinates,
    label: `${route.code} · ${route.stops.length} paradas (secuencia, sin vialidad)`,
  }
})

const filteredHasFilters = computed(() => hasActiveFilters(operations.filters))

const metrics = computed(() => operations.metrics)

onMounted(() => {
  void operations.load(session.scenario)
})

watch(
  () => session.scenario,
  (scenario) => {
    void operations.load(scenario)
  },
)

watch(
  () => operations.polygonOrderIds,
  (ids) => {
    if (ids.length && canOperate.value) toasts.info(`${ids.length} órdenes seleccionadas por área.`)
  },
)

function selectOrder(orderId: string): void {
  operations.selectOrder(orderId)
}

function openAssign(technicianId: string | null = null): void {
  const batch = operations.polygonSelectedOrders.length
    ? operations.polygonSelectedOrders
    : operations.selectedOrder
      ? [operations.selectedOrder]
      : []
  assignOrders.value = batch
  assignTechnicianPreselect.value = technicianId
  assignOpen.value = true
}

function openStatus(order: WorkOrder, suggested: WorkOrderStatus | null = null): void {
  statusOrder.value = order
  statusSuggested.value = suggested
  statusOpen.value = true
}

async function unassign(orderId: string): Promise<void> {
  try {
    await operations.unassignOrder({
      orderId,
      actor: session.actor,
      reason: 'desasignada desde el panel',
    })
    toasts.success('Orden devuelta a pendiente.')
  } catch (caught) {
    toasts.error(caught instanceof Error ? caught.message : 'No se pudo desasignar.')
  }
}

function togglePolygon(): void {
  operations.setSelectionMode(
    operations.selectionMode === 'polygon' ? 'none' : 'polygon',
  )
  if (operations.selectionMode === 'polygon') {
    toasts.info('Haz clic en el mapa para dibujar el área. Doble clic o “Cerrar” para terminar.')
  }
}

function useProximity(technicianId: string): void {
  operations.selectByProximity(technicianId, 3000)
  toasts.info('Órdenes a menos de 3 km de la cuadrilla marcadas (sin cálculo de rutas).')
}

function loadScenario(scenario: DemoScenario): void {
  session.setScenario(scenario)
}

function exportAudit(): void {
  downloadCsv(
    `plus-lps-auditoria-${new Date().toISOString().slice(0, 10)}.csv`,
    [
      'codigo',
      'estado',
      'tipo',
      'prioridad',
      'cliente',
      'suministro',
      'distrito',
      'zona',
      'tecnico',
      'programada',
      'vence',
      'actualizada',
    ],
    operations.filteredOrders.map((order) => [
      order.code,
      STATUS_META[order.status].label,
      order.type,
      order.priority,
      order.customerName,
      order.supplyNumber,
      order.district,
      order.zone,
      order.assignment?.technicianName ?? 'sin asignar',
      order.scheduledAt,
      order.dueAt,
      order.updatedAt,
    ]),
  )
  toasts.success('Exportación demo generada localmente (CSV).')
}

function exportHistory(): void {
  downloadCsv(
    `plus-lps-historial-${new Date().toISOString().slice(0, 10)}.csv`,
    ['orden', 'desde', 'hacia', 'actor', 'fecha', 'motivo'],
    operations.history.map((entry) => [
      entry.orderCode,
      entry.fromStatus,
      entry.toStatus,
      entry.changedByName ?? 'sistema',
      entry.changedAt,
      entry.reason,
    ]),
  )
  toasts.success('Historial exportado como CSV (demo local).')
}
</script>

<template>
  <div class="workspace-root">
    <div class="demo-banner">
    <SourceBadge compact />
    <span class="demo-banner__text">
      {{ operations.source === 'demo-seed' ? 'Datos ficticios del seed local.' : '' }}
      Sin conexión a SAP ni a los endpoints de órdenes del backend.
    </span>
    <span class="grow" />
    <DemoScenarioControls />
    <span v-if="operations.loadedAt" class="text-xs">
      Cargado {{ formatRelative(operations.loadedAt) }}
    </span>
  </div>

  <StatePanel
    v-if="operations.state === 'loading'"
    kind="loading"
    title="Cargando jornada operativa"
    message="Leyendo el conjunto de demostración."
  />

  <StatePanel
    v-else-if="operations.state === 'error'"
    kind="error"
    title="No se pudieron cargar las órdenes"
    :message="operations.errorMessage ?? ''"
    hint="Puedes reintentar o cambiar el estado de demostración en la barra lateral."
    action-label="Reintentar"
    @action="operations.load(session.scenario)"
  />

  <StatePanel
    v-else-if="operations.state === 'empty'"
    kind="empty"
    title="Sin órdenes en la jornada"
    message="El conjunto demo está vacío para este estado."
    action-label="Volver a datos de demostración"
    @action="loadScenario('ready')"
  />

  <div
    v-else
    class="workspace"
    :class="{ 'workspace--with-detail': Boolean(operations.selectedOrder) }"
  >
    <div class="sidebar">
      <div class="sidebar__tabs" role="tablist">
        <button
          type="button"
          class="sidebar__tab"
          :class="{ 'is-active': sidebarTab === 'orders' }"
          role="tab"
          @click="sidebarTab = 'orders'"
        >
          Órdenes ({{ operations.filteredOrders.length }})
        </button>
        <button
          type="button"
          class="sidebar__tab"
          :class="{ 'is-active': sidebarTab === 'technicians' }"
          role="tab"
          @click="sidebarTab = 'technicians'"
        >
          Cuadrillas ({{ operations.technicians.length }})
        </button>
        <button
          v-if="isAudit"
          type="button"
          class="sidebar__tab"
          :class="{ 'is-active': sidebarTab === 'audit' }"
          role="tab"
          @click="sidebarTab = 'audit'"
        >
          Auditoría
        </button>
        <button
          type="button"
          class="sidebar__tab"
          :class="{ 'is-active': sidebarTab === 'table' }"
          role="tab"
          @click="sidebarTab = 'table'"
        >
          Tabla
        </button>
      </div>

      <div class="sidebar__body">
        <div v-if="sidebarTab === 'orders'" class="sidebar__section">
          <div class="sidebar__section-title">
            <span>Filtros</span>
            <span v-if="metrics.geocoded < metrics.total" class="text-xs muted">
              {{ metrics.total - metrics.geocoded }} sin geocodificar
            </span>
          </div>
          <OrderFilters
            :filters="operations.filters"
            :districts="operations.districts"
            :zones="operations.zones"
            :technicians="operations.technicians"
            :has-filters="filteredHasFilters"
            @update="operations.setFilters"
            @reset="operations.resetFilters"
          />
        </div>

        <div v-if="sidebarTab === 'orders'">
          <OrderListPanel
            :orders="operations.filteredOrders"
            :selected-order-id="operations.selectedOrderId"
            :highlighted-ids="operations.polygonOrderIds"
            :has-filters="filteredHasFilters"
            @select="selectOrder"
            @clear-filters="operations.resetFilters"
          />
        </div>

        <div v-else-if="sidebarTab === 'technicians'" class="sidebar__section">
          <p class="sidebar__section-title">Cuadrillas activas</p>
          <p class="text-xs muted">
            La carga se calcula sobre las asignaciones vigentes (asignada / en
            proceso).
          </p>
          <TechnicianList
            :technicians="operations.technicians"
            :selected-technician-id="selectedTechnicianId"
            @select="
              (id) => {
                selectedTechnicianId = id
                if (canOperate) openAssign(id)
              }
            "
            @select-proximity="
              (id) => {
                selectedTechnicianId = id
                useProximity(id)
              }
            "
          />
        </div>

        <div v-else-if="sidebarTab === 'audit'" class="sidebar__section">
          <p class="sidebar__section-title">Indicadores</p>
          <div class="kpi-grid">
            <MetricCard label="Total" :value="metrics.total" />
            <MetricCard label="Pendientes" :value="metrics.pending" accent="#d99a06" />
            <MetricCard label="Asignadas" :value="metrics.assigned" accent="#2563eb" />
            <MetricCard label="En proceso" :value="metrics.inProgress" accent="#ea580c" />
            <MetricCard label="Ejecutadas" :value="metrics.executed" accent="#16803c" />
            <MetricCard label="Imposibilitadas" :value="metrics.impossible" accent="#dc2626" />
            <MetricCard label="Canceladas" :value="metrics.cancelled" accent="#64748b" />
            <MetricCard
              label="Sin asignar"
              :value="metrics.unassigned"
              accent="#0f8f8f"
            />
          </div>

          <p class="sidebar__section-title" style="margin-top: 6px">Exportar</p>
          <button type="button" class="btn btn--sm btn--ghost btn--block" @click="exportAudit">
            ⤓ Órdenes filtradas (CSV)
          </button>
          <button type="button" class="btn btn--sm btn--ghost btn--block" @click="exportHistory">
            ⤓ Historial de estados (CSV)
          </button>
          <p class="text-xs muted">
            Exportación local del boceto (Excel/CSV). Los reportes PDF quedan
            pendientes de definir su plantilla.
          </p>
        </div>

        <div v-else-if="sidebarTab === 'table'">
          <OrderTable
            :orders="operations.filteredOrders"
            :selected-order-id="operations.selectedOrderId"
            :highlighted-ids="operations.polygonOrderIds"
            @select="selectOrder"
          />
        </div>
      </div>

      <div v-if="isAudit && sidebarTab !== 'audit'" class="sidebar__section">
        <button type="button" class="btn btn--sm btn--ghost btn--block" @click="sidebarTab = 'audit'">
          Ver métricas, auditoría y exportación
        </button>
      </div>
    </div>

    <div class="map-pane">
      <MapCanvas
        ref="mapRef"
        :orders="operations.visibleMapOrders"
        :technicians="operations.technicians"
        :selected-order-id="operations.selectedOrderId"
        :highlighted-ids="operations.polygonOrderIds"
        :show-technicians="operations.showTechnicianLayer"
        :selection-mode="operations.selectionMode"
        :polygon-points="operations.polygonPoints"
        :route-line="routeLine"
        @select-order="operations.selectOrder"
        @add-polygon-vertex="operations.addPolygonVertex"
        @remove-last-polygon-vertex="operations.removeLastPolygonVertex"
        @close-polygon="operations.closePolygon"
      />

      <MapToolbar
        :selection-mode="operations.selectionMode"
        :selection-count="operations.polygonOrderIds.length"
        :show-technicians="operations.showTechnicianLayer"
        :route-available="Boolean(routeLine)"
        :can-dispatch="canOperate"
        v-model:proximity-technician-id="proximityTechnicianId"
        :technicians="operations.technicians"
        @toggle-polygon="togglePolygon"
        @close-polygon="operations.closePolygon"
        @clear-selection="operations.clearPolygon"
        @toggle-technicians="operations.showTechnicianLayer = !operations.showTechnicianLayer"
        @fit-all="mapRef?.fitToOrders()"
        @fit-route="mapRef?.fitRoute()"
        @zoom-in="mapRef?.zoomIn()"
        @zoom-out="mapRef?.zoomOut()"
        @proximity="useProximity"
      />

      <MapLegend
        :show-technicians="operations.showTechnicianLayer"
        :route-label="routeLine?.label ?? null"
      />

      <div v-if="operations.polygonOrderIds.length && canOperate" class="selection-bar">
        <p class="text-sm">
          <span class="selection-bar__count">{{ operations.polygonOrderIds.length }}</span>
          órdenes dentro del área.
        </p>
        <div class="row" style="gap: 6px">
          <button type="button" class="btn btn--sm btn--primary grow" @click="openAssign(selectedTechnicianId)">
            Asignar selección
          </button>
          <button type="button" class="btn btn--sm btn--ghost" @click="operations.clearPolygon()">
            Limpiar
          </button>
        </div>
      </div>

      <div
        v-if="operations.selectionMode === 'polygon'"
        class="map-hint"
        role="status"
      >
        Dibujando área: {{ operations.polygonPoints.length }} vértices
        <button type="button" class="btn btn--sm btn--primary" @click="operations.closePolygon()">
          Cerrar área
        </button>
      </div>
    </div>

    <OrderDetailDrawer
      v-if="operations.selectedOrder"
      :order="operations.selectedOrder"
      :history="operations.selectedOrderHistory"
      :actor="session.actor"
      :can-operate="canOperate"
      @close="operations.selectOrder(null)"
      @assign="openAssign"
      @unassign="unassign"
      @change-status="
        ({ orderId, status }) => {
          const order = operations.orders.find((item) => item.id === orderId)
          if (order) openStatus(order, status)
        }
      "
      @preview-evidence="previewEvidence = $event"
      @focus-map="mapRef?.focusOrder($event)"
    />
  </div>

  <AssignDialog
    :open="assignOpen"
    :orders="assignOrders"
    :actor="session.actor"
    :preselected-technician-id="assignTechnicianPreselect"
    @close="assignOpen = false"
    @assigned="operations.clearPolygon()"
  />

  <StatusUpdateDialog
    v-if="statusOrder"
    :open="statusOpen"
    :order="statusOrder"
    :actor="session.actor"
    :suggested-status="statusSuggested"
    @close="
      () => {
        statusOpen = false
        statusOrder = null
      }
    "
  />

  <div v-if="previewEvidence" class="modal-backdrop" @click.self="previewEvidence = null">
    <div class="modal" role="dialog" aria-modal="true" aria-label="Vista de evidencia">
      <div class="modal__head">
        <h2 class="modal__title">Evidencia</h2>
        <button type="button" class="btn btn--sm btn--ghost" @click="previewEvidence = null">
          Cerrar
        </button>
      </div>
      <div class="modal__body">
        <img
          v-if="previewEvidence.localPreviewUrl"
          :src="previewEvidence.localPreviewUrl"
          alt="Previsualización local de la evidencia"
          style="max-width: 100%; border-radius: 8px"
        />
        <dl class="def-list">
          <dt>Tipo</dt>
          <dd>{{ previewEvidence.kind }}</dd>
          <dt>Bucket</dt>
          <dd class="mono">{{ previewEvidence.storageBucket }}</dd>
          <dt>Ruta</dt>
          <dd class="mono">{{ previewEvidence.storagePath }}</dd>
          <dt>Capturada</dt>
          <dd>{{ formatDateTime(previewEvidence.capturedAt) }}</dd>
        </dl>
        <p class="alert alert--warning">
          El seed solo guarda metadatos: el binario no existe en Storage, por eso
          se muestra únicamente la referencia lógica.
        </p>
      </div>
    </div>
  </div>
  </div>
</template>
