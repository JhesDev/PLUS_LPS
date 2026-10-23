import { defineStore } from 'pinia'
import { computed, ref, shallowRef } from 'vue'
import { DemoOperationsRepository } from '@/services/demoRepository'
import type { Actor, DemoScenario } from '@/services/operationsRepository'
import type {
  Coordinates,
  Evidence,
  EvidenceKind,
  OperationsFilters,
  OperationsSnapshot,
  StatusHistoryEntry,
  Technician,
  TechnicianRoute,
  WorkOrder,
  WorkOrderStatus,
} from '@/types/domain'
import { createDefaultFilters, filterOrders, sortOrders, uniqueSorted } from '@/utils/filters'
import { buildMetrics } from '@/utils/metrics'
import { haversineMeters, pointInPolygon } from '@/utils/geo'
import { USE_DEMO_DATA } from '@/config/dataSource'

export type LoadState = 'idle' | 'loading' | 'ready' | 'empty' | 'error'
export type SelectionMode = 'none' | 'polygon'

/** Único punto de sustitución cuando exista el adaptador HTTP del backend. */
const repository = new DemoOperationsRepository()

/**
 * Normaliza coordenadas a un objeto plano.
 *
 * Importante: los objetos del dominio que pasan por `ref()` reactivos o por
 * props se convierten en Proxy y no son serializables (`structuredClone`
 * falla). La frontera del repositorio exige siempre valores planos.
 */
function toPlainCoordinates(
  value: Coordinates | null | undefined,
): Coordinates | null {
  if (
    !value ||
    typeof value.latitude !== 'number' ||
    typeof value.longitude !== 'number'
  ) {
    return null
  }
  return { latitude: value.latitude, longitude: value.longitude }
}

export const useOperationsStore = defineStore('operations', () => {
  const snapshot = shallowRef<OperationsSnapshot | null>(null)
  const state = ref<LoadState>('idle')
  const errorMessage = ref<string | null>(null)
  const filters = ref<OperationsFilters>(createDefaultFilters())
  const selectedOrderId = ref<string | null>(null)
  const hoveredOrderId = ref<string | null>(null)
  const selectionMode = ref<SelectionMode>('none')
  const polygonPoints = ref<Coordinates[]>([])
  const polygonOrderIds = ref<string[]>([])
  const showTechnicianLayer = ref(true)
  const busy = ref(false)

  const orders = computed<WorkOrder[]>(() => snapshot.value?.orders ?? [])
  const technicians = computed<Technician[]>(
    () => snapshot.value?.technicians ?? [],
  )
  const routes = computed<TechnicianRoute[]>(() => snapshot.value?.routes ?? [])
  const history = computed<StatusHistoryEntry[]>(
    () => snapshot.value?.history ?? [],
  )
  const source = computed(() => snapshot.value?.source ?? 'demo-seed')
  const loadedAt = computed(() => snapshot.value?.loadedAt ?? null)

  const filteredOrders = computed(() =>
    sortOrders(filterOrders(orders.value, filters.value)),
  )
  const metrics = computed(() => buildMetrics(filteredOrders.value))
  const globalMetrics = computed(() => buildMetrics(orders.value))

  const selectedOrder = computed<WorkOrder | null>(
    () =>
      orders.value.find((order) => order.id === selectedOrderId.value) ?? null,
  )

  const selectedOrderHistory = computed<StatusHistoryEntry[]>(() =>
    selectedOrderId.value
      ? history.value
          .filter((entry) => entry.workOrderId === selectedOrderId.value)
          .sort(
            (a, b) =>
              new Date(b.changedAt).getTime() - new Date(a.changedAt).getTime(),
          )
      : [],
  )

  const polygonSelectedOrders = computed<WorkOrder[]>(() =>
    orders.value.filter((order) => polygonOrderIds.value.includes(order.id)),
  )

  const districts = computed(() =>
    uniqueSorted(orders.value.map((order) => order.district)),
  )
  const zones = computed(() => uniqueSorted(orders.value.map((order) => order.zone)))

  const visibleMapOrders = computed(() =>
    filteredOrders.value.filter((order) => order.location !== null),
  )
  const ordersWithoutLocation = computed(() =>
    filteredOrders.value.filter((order) => order.location === null),
  )

  async function load(scenario: DemoScenario = 'ready'): Promise<void> {
    state.value = 'loading'
    errorMessage.value = null
    try {
      const data = await repository.load(scenario)
      snapshot.value = data
      state.value = data.orders.length ? 'ready' : 'empty'
      if (selectedOrderId.value && !data.orders.some((o) => o.id === selectedOrderId.value)) {
        selectedOrderId.value = null
      }
    } catch (error) {
      state.value = 'error'
      errorMessage.value =
        error instanceof Error
          ? error.message
          : 'Error desconocido al cargar la jornada.'
    }
  }

  function setFilters(partial: Partial<OperationsFilters>): void {
    filters.value = { ...filters.value, ...partial }
  }

  function resetFilters(): void {
    filters.value = createDefaultFilters()
  }

  function selectOrder(id: string | null): void {
    selectedOrderId.value = id
  }

  function setSelectionMode(mode: SelectionMode): void {
    selectionMode.value = mode
    if (mode === 'none') {
      polygonPoints.value = []
      polygonOrderIds.value = []
    }
  }

  function addPolygonVertex(point: Coordinates): void {
    polygonPoints.value = [...polygonPoints.value, point]
    recomputePolygonSelection()
  }

  function closePolygon(): void {
    if (polygonPoints.value.length >= 3) recomputePolygonSelection()
    selectionMode.value = 'none'
  }

  /**
   * El doble clic en el mapa emite dos clics seguidos; el segundo revierte el
   * vértice duplicado y cierra el área.
   */
  function removeLastPolygonVertex(): void {
    polygonPoints.value = polygonPoints.value.slice(0, -1)
    recomputePolygonSelection()
  }

  function clearPolygon(): void {
    polygonPoints.value = []
    polygonOrderIds.value = []
  }

  function recomputePolygonSelection(): void {
    const polygon = polygonPoints.value
    if (polygon.length < 3) {
      polygonOrderIds.value = []
      return
    }
    const ring: Array<[number, number]> = polygon.map((point) => [
      point.longitude,
      point.latitude,
    ])
    polygonOrderIds.value = visibleMapOrders.value
      .filter((order) => order.location)
      .filter((order) => {
        const location = order.location as Coordinates
        return pointInPolygon([location.longitude, location.latitude], ring)
      })
      .map((order) => order.id)
  }

  /**
   * Selección por proximidad al GPS de una cuadrilla (capa opcional).
   * No calcula rutas: solo marca las órdenes dentro del radio.
   */
  function selectByProximity(technicianId: string, radiusMeters: number): void {
    const technician = technicians.value.find(
      (item) => item.id === technicianId,
    )
    if (!technician?.location) return

    polygonPoints.value = []
    polygonOrderIds.value = visibleMapOrders.value
      .filter((order) => order.location)
      .filter((order) => !order.assignment || order.assignment.technicianId !== technicianId)
      .filter((order) => {
        const distance = haversineMeters(
          technician.location as Coordinates,
          order.location as Coordinates,
        )
        return distance <= radiusMeters
      })
      .map((order) => order.id)
  }

  async function assignOrders(input: {
    orderIds: string[]
    technicianId: string
    actor: Actor
    notes?: string
  }): Promise<{ assigned: number; reassigned: number; technicianName: string }> {
    busy.value = true
    try {
      const result = await repository.assignOrders(input)
      await reloadLocal()
      const target = result.orderIds[0] ?? null
      if (target) selectedOrderId.value = target
      return {
        assigned: result.assigned,
        reassigned: result.reassigned,
        technicianName: result.technicianName,
      }
    } finally {
      busy.value = false
    }
  }

  async function unassignOrder(input: {
    orderId: string
    actor: Actor
    reason?: string
  }): Promise<void> {
    busy.value = true
    try {
      await repository.unassignOrder(input)
      await reloadLocal()
    } finally {
      busy.value = false
    }
  }

  async function updateStatus(input: {
    orderId: string
    status: WorkOrderStatus
    actor: Actor
    reason?: string
    location?: Coordinates | null
  }): Promise<void> {
    busy.value = true
    const location = toPlainCoordinates(input.location)
    try {
      await repository.updateStatus({
        update: {
          orderId: input.orderId,
          status: input.status,
          reason: input.reason,
          location,
        },
        actor: input.actor,
        location,
      })
      await reloadLocal()
    } finally {
      busy.value = false
    }
  }

  async function addEvidence(input: {
    orderId: string
    kind: EvidenceKind
    file: File
    actor: Actor
  }): Promise<Evidence | undefined> {
    busy.value = true
    try {
      await repository.addEvidence(input)
      const order = orders.value.find((item) => item.id === input.orderId)
      return order?.evidence[0]
    } finally {
      busy.value = false
    }
  }

  /**
   * El repositorio demo muta su snapshot interno; el store lo vuelve a leer
   * para mantener una única fuente de verdad durante el boceto.
   */
  async function reloadLocal(): Promise<void> {
    const data = await repository.load('ready')
    snapshot.value = {
      ...data,
      orders: [...data.orders],
      assignments: [...data.assignments],
      history: [...data.history],
      technicians: [...data.technicians],
    }
  }

  return {
    demoMode: USE_DEMO_DATA,
    snapshot,
    state,
    errorMessage,
    filters,
    selectedOrderId,
    hoveredOrderId,
    selectionMode,
    polygonPoints,
    polygonOrderIds,
    showTechnicianLayer,
    busy,
    orders,
    technicians,
    routes,
    history,
    source,
    loadedAt,
    filteredOrders,
    metrics,
    globalMetrics,
    selectedOrder,
    selectedOrderHistory,
    polygonSelectedOrders,
    districts,
    zones,
    visibleMapOrders,
    ordersWithoutLocation,
    load,
    setFilters,
    resetFilters,
    selectOrder,
    setSelectionMode,
    addPolygonVertex,
    closePolygon,
    removeLastPolygonVertex,
    clearPolygon,
    selectByProximity,
    assignOrders,
    unassignOrder,
    updateStatus,
    addEvidence,
  }
})
