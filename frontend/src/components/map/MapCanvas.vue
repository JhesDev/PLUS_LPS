<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref, shallowRef, watch } from 'vue'
import maplibregl from 'maplibre-gl'
import type {
  GeoJSONSource,
  Map as MapLibreMap,
  StyleSpecification,
} from 'maplibre-gl'
import type { Coordinates, Technician, WorkOrder } from '@/types/domain'
import type { SelectionMode } from '@/stores/operations'
import { resolveMapProvider } from '@/config/runtime'
import { buildBasemap } from '@/map/basemap'
import {
  buildTechnicianIcon,
  buildTypeIcons,
} from '@/map/icons'
import { STATUS_META } from '@/utils/status'
import type { RouteLine } from '@/map/route'

interface Props {
  orders: WorkOrder[]
  technicians?: Technician[]
  selectedOrderId?: string | null
  highlightedIds?: string[]
  showTechnicians?: boolean
  selectionMode?: SelectionMode
  polygonPoints?: Coordinates[]
  routeLine?: RouteLine | null
}

const props = withDefaults(defineProps<Props>(), {
  technicians: () => [],
  selectedOrderId: null,
  highlightedIds: () => [],
  showTechnicians: false,
  selectionMode: 'none',
  polygonPoints: () => [],
  routeLine: null,
})

const emit = defineEmits<{
  (event: 'select-order', orderId: string | null): void
  (event: 'add-polygon-vertex', point: Coordinates): void
  (event: 'remove-last-polygon-vertex'): void
  (event: 'close-polygon'): void
  (event: 'ready'): void
}>()

const container = ref<HTMLDivElement | null>(null)
const map = shallowRef<MapLibreMap | null>(null)
const isReady = ref(false)
const fatalError = ref<string | null>(null)
/**
 * MapLibre avanza con `requestAnimationFrame`; si la pestaña está oculta o el
 * entorno lo suspende, la carga del estilo no termina. En lugar de dejar un
 * spinner infinito, se avisa y se ofrece reintentar.
 */
const stalled = ref(false)
const STALL_TIMEOUT_MS = 12_000
let stallTimer: ReturnType<typeof setTimeout> | null = null
const warning = ref<string | null>(null)
const supportsLabels = ref(false)

const provider = resolveMapProvider()
const basemap = buildBasemap(provider)

const lastMapClickId = ref<string | null>(null)

/** Ventana para interpretar dos clics seguidos como cierre de polígono. */
const DOUBLE_CLICK_WINDOW_MS = 320
let lastVertexClickAt = 0

const LAYER_ORDERS_CIRCLE = 'orders-circle'
const LAYER_ORDERS_ICON = 'orders-icon'
const LAYER_ORDERS_HIGHLIGHT = 'orders-highlight'
const LAYER_TECHNICIAN = 'technician-marker'

const STATUS_COLOR_EXPRESSION = [
  'match',
  ['get', 'status'],
  'pendiente',
  STATUS_META.pendiente.color,
  'asignada',
  STATUS_META.asignada.color,
  'en_proceso',
  STATUS_META.en_proceso.color,
  'ejecutada',
  STATUS_META.ejecutada.color,
  'imposibilitada',
  STATUS_META.imposibilitada.color,
  'cancelada',
  STATUS_META.cancelada.color,
  '#64748b',
]

function ordersToFeatureCollection(orders: WorkOrder[]) {
  return {
    type: 'FeatureCollection' as const,
    features: orders
      .filter((order) => order.location !== null)
      .map((order) => {
        const location = order.location as Coordinates
        return {
          type: 'Feature' as const,
          id: order.id,
          geometry: {
            type: 'Point' as const,
            coordinates: [location.longitude, location.latitude],
          },
          properties: {
            id: order.id,
            code: order.code,
            status: order.status,
            type: order.type,
            priority: order.priority,
          },
        }
      }),
  }
}

function techniciansToFeatureCollection(technicians: Technician[]) {
  return {
    type: 'FeatureCollection' as const,
    features: technicians
      .filter((technician) => technician.location !== null)
      .map((technician) => {
        const location = technician.location as Coordinates
        return {
          type: 'Feature' as const,
          geometry: {
            type: 'Point' as const,
            coordinates: [location.longitude, location.latitude],
          },
          properties: {
            id: technician.id,
            name: technician.fullName,
            activeOrders: technician.activeOrders,
            initials: technician.fullName
              .split(/\s+/)
              .slice(-2)
              .map((part) => part.charAt(0).toUpperCase())
              .join(''),
          },
        }
      }),
  }
}

function polygonFeatureCollection(points: Coordinates[]) {
  if (points.length < 3) {
    return { type: 'FeatureCollection' as const, features: [] }
  }
  const ring = points.map((point) => [point.longitude, point.latitude])
  ring.push(ring[0])
  return {
    type: 'FeatureCollection' as const,
    features: [
      {
        type: 'Feature' as const,
        geometry: { type: 'Polygon' as const, coordinates: [ring] },
        properties: {},
      },
    ],
  }
}

function polygonPathCollection(points: Coordinates[]) {
  if (points.length < 2) {
    return { type: 'FeatureCollection' as const, features: [] }
  }
  return {
    type: 'FeatureCollection' as const,
    features: [
      {
        type: 'Feature' as const,
        geometry: {
          type: 'LineString' as const,
          coordinates: points.map((point) => [point.longitude, point.latitude]),
        },
        properties: {},
      },
    ],
  }
}

function polygonVertexCollection(points: Coordinates[]) {
  return {
    type: 'FeatureCollection' as const,
    features: points.map((point, index) => ({
      type: 'Feature' as const,
      geometry: {
        type: 'Point' as const,
        coordinates: [point.longitude, point.latitude],
      },
      properties: { index },
    })),
  }
}

function routeLineCollection(route: RouteLine | null) {
  if (!route || route.coordinates.length < 2) {
    return { type: 'FeatureCollection' as const, features: [] }
  }
  return {
    type: 'FeatureCollection' as const,
    features: [
      {
        type: 'Feature' as const,
        geometry: {
          type: 'LineString' as const,
          coordinates: route.coordinates,
        },
        properties: {},
      },
    ],
  }
}

function setSourceData(sourceId: string, data: unknown): void {
  const instance = map.value
  if (!instance) return
  const source = instance.getSource(sourceId) as GeoJSONSource | undefined
  source?.setData(data as never)
}

function syncOrderData(): void {
  setSourceData('orders', ordersToFeatureCollection(props.orders))
}

function syncHighlight(): void {
  const instance = map.value
  if (!instance || !instance.getLayer(LAYER_ORDERS_HIGHLIGHT)) return
  const ids = props.highlightedIds
  instance.setFilter(
    LAYER_ORDERS_HIGHLIGHT,
    ids.length ? ['in', ['get', 'id'], ['literal', ids]] : ['==', ['get', 'id'], '__none__'],
  )
}

function syncSelected(): void {
  const instance = map.value
  if (!instance || !instance.getLayer(LAYER_ORDERS_CIRCLE)) return
  const id = props.selectedOrderId ?? '__none__'
  instance.setFilter(LAYER_ORDERS_CIRCLE, [
    'all',
    ['!', ['has', 'point_count']],
  ])
  instance.setPaintProperty(LAYER_ORDERS_CIRCLE, 'circle-stroke-width', [
    'case',
    ['==', ['get', 'id'], id],
    4,
    2,
  ])
  instance.setPaintProperty(LAYER_ORDERS_CIRCLE, 'circle-stroke-color', [
    'case',
    ['==', ['get', 'id'], id],
    '#0a2540',
    '#ffffff',
  ])
}

function syncTechnicians(): void {
  setSourceData('technicians', techniciansToFeatureCollection(props.technicians))
  const instance = map.value
  if (!instance) return
  const visibility = props.showTechnicians ? 'visible' : 'none'
  if (instance.getLayer(LAYER_TECHNICIAN)) {
    instance.setLayoutProperty(LAYER_TECHNICIAN, 'visibility', visibility)
  }
}

function syncPolygon(): void {
  setSourceData('polygon-fill', polygonFeatureCollection(props.polygonPoints))
  setSourceData('polygon-path', polygonPathCollection(props.polygonPoints))
  setSourceData('polygon-vertices', polygonVertexCollection(props.polygonPoints))
}

function syncRoute(): void {
  setSourceData('route-line', routeLineCollection(props.routeLine))
}

function addSourcesAndLayers(instance: MapLibreMap): void {
  instance.addSource('orders', {
    type: 'geojson',
    data: ordersToFeatureCollection(props.orders) as never,
    cluster: true,
    clusterMaxZoom: 14,
    clusterRadius: 48,
  })

  instance.addSource('technicians', {
    type: 'geojson',
    data: techniciansToFeatureCollection(props.technicians) as never,
  })

  instance.addSource('route-line', {
    type: 'geojson',
    data: routeLineCollection(props.routeLine) as never,
  })

  instance.addSource('polygon-fill', {
    type: 'geojson',
    data: polygonFeatureCollection(props.polygonPoints) as never,
  })

  instance.addSource('polygon-path', {
    type: 'geojson',
    data: polygonPathCollection(props.polygonPoints) as never,
  })

  instance.addSource('polygon-vertices', {
    type: 'geojson',
    data: polygonVertexCollection(props.polygonPoints) as never,
  })

  instance.addLayer({
    id: 'clusters',
    type: 'circle',
    source: 'orders',
    filter: ['has', 'point_count'],
    paint: {
      'circle-color': '#0a2540',
      'circle-opacity': 0.86,
      'circle-stroke-width': 2,
      'circle-stroke-color': '#ffffff',
      'circle-radius': [
        'step',
        ['get', 'point_count'],
        15,
        5,
        19,
        15,
        24,
        40,
        30,
      ],
    },
  })

  if (supportsLabels.value) {
    instance.addLayer({
      id: 'cluster-count',
      type: 'symbol',
      source: 'orders',
      filter: ['has', 'point_count'],
      layout: {
        'text-field': ['get', 'point_count_abbreviated'],
        'text-font': ['Open Sans Semibold'],
        'text-size': 12,
      },
      paint: { 'text-color': '#ffffff' },
    })
  }

  instance.addLayer({
    id: LAYER_ORDERS_HIGHLIGHT,
    type: 'circle',
    source: 'orders',
    filter: ['==', ['get', 'id'], '__none__'],
    paint: {
      'circle-color': 'rgba(20, 163, 163, 0.22)',
      'circle-radius': 18,
      'circle-stroke-width': 2,
      'circle-stroke-color': '#0f8f8f',
    },
  })

  instance.addLayer({
    id: LAYER_ORDERS_CIRCLE,
    type: 'circle',
    source: 'orders',
    filter: ['!', ['has', 'point_count']],
    paint: {
      'circle-color': STATUS_COLOR_EXPRESSION as never,
      'circle-radius': 10,
      'circle-stroke-width': 2,
      'circle-stroke-color': '#ffffff',
    },
  })

  instance.addLayer({
    id: LAYER_ORDERS_ICON,
    type: 'symbol',
    source: 'orders',
    filter: ['!', ['has', 'point_count']],
    layout: {
      'icon-image': ['concat', 'type-icon-', ['get', 'type']],
      'icon-size': 0.5,
      'icon-allow-overlap': true,
    },
  })

  if (props.routeLine) {
    instance.addLayer({
      id: 'route-line',
      type: 'line',
      source: 'route-line',
      paint: {
        'line-color': '#0f8f8f',
        'line-width': 3,
        'line-dasharray': [2, 1.4],
        'line-opacity': 0.9,
      },
    })
  }

  instance.addLayer({
    id: LAYER_TECHNICIAN,
    type: 'symbol',
    source: 'technicians',
    layout: {
      'icon-image': 'technician-marker',
      'icon-size': 0.62,
      'icon-allow-overlap': true,
      'visibility': props.showTechnicians ? 'visible' : 'none',
    },
  })

  instance.addLayer({
    id: 'polygon-fill',
    type: 'fill',
    source: 'polygon-fill',
    paint: { 'fill-color': '#0f8f8f', 'fill-opacity': 0.16 },
  })

  instance.addLayer({
    id: 'polygon-path',
    type: 'line',
    source: 'polygon-path',
    paint: {
      'line-color': '#0f8f8f',
      'line-width': 2,
      'line-dasharray': [1.5, 1],
    },
  })

  instance.addLayer({
    id: 'polygon-vertices',
    type: 'circle',
    source: 'polygon-vertices',
    paint: {
      'circle-color': '#0f8f8f',
      'circle-radius': 5,
      'circle-stroke-width': 2,
      'circle-stroke-color': '#ffffff',
    },
  })
}

function fitToOrders(): void {
  const instance = map.value
  if (!instance) return
  const withLocation = props.orders.filter((order) => order.location)
  if (!withLocation.length) return

  if (withLocation.length === 1) {
    const only = withLocation[0].location as Coordinates
    instance.easeTo({
      center: [only.longitude, only.latitude],
      zoom: 13,
    })
    return
  }

  const bounds = new maplibregl.LngLatBounds()
  for (const order of withLocation) {
    const location = order.location as Coordinates
    bounds.extend([location.longitude, location.latitude])
  }
  instance.fitBounds(bounds, { padding: 72, maxZoom: 14, duration: 0 })
}

function focusOrder(orderId: string): void {
  const instance = map.value
  const order = props.orders.find((item) => item.id === orderId)
  if (!instance || !order?.location) return
  instance.easeTo({
    center: [order.location.longitude, order.location.latitude],
    zoom: Math.max(instance.getZoom(), 14),
    duration: 600,
  })
}

function fitRoute(): void {
  const instance = map.value
  const route = props.routeLine
  if (!instance || !route || route.coordinates.length < 2) return
  const bounds = new maplibregl.LngLatBounds()
  for (const coordinate of route.coordinates) bounds.extend(coordinate)
  instance.fitBounds(bounds, { padding: 64, maxZoom: 15, duration: 600 })
}

function zoomIn(): void {
  map.value?.zoomIn()
}

function zoomOut(): void {
  map.value?.zoomOut()
}

function attachInteractions(instance: MapLibreMap): void {
  instance.on('click', 'clusters', (event) => {
    const feature = event.features?.[0]
    const clusterId = feature?.properties?.cluster_id as number | undefined
    if (clusterId === undefined) return
    const source = instance.getSource('orders') as GeoJSONSource | undefined
    if (!source) return

    void source
      .getClusterExpansionZoom(clusterId)
      .then((zoom) => {
        const coordinates = (feature?.geometry as GeoJSON.Point).coordinates as [
          number,
          number,
        ]
        instance.easeTo({ center: coordinates, zoom: zoom + 0.2 })
      })
      .catch(() => {
        // Si el cluster ya no existe, se ignora sin romper la interacción.
      })
  })

  instance.on('mouseenter', 'clusters', () => {
    if (props.selectionMode === 'none') instance.getCanvas().style.cursor = 'pointer'
  })

  instance.on('mouseleave', 'clusters', () => {
    instance.getCanvas().style.cursor =
      props.selectionMode === 'polygon' ? 'crosshair' : ''
  })

  instance.on('click', LAYER_ORDERS_CIRCLE, (event) => {
    if (props.selectionMode === 'polygon') return
    const feature = event.features?.[0]
    const id = feature?.properties?.id as string | undefined
    if (!id) return
    lastMapClickId.value = id
    emit('select-order', id)
  })

  instance.on('mouseenter', LAYER_ORDERS_CIRCLE, () => {
    if (props.selectionMode === 'none') {
      instance.getCanvas().style.cursor = 'pointer'
    }
  })

  instance.on('mouseleave', LAYER_ORDERS_CIRCLE, () => {
    instance.getCanvas().style.cursor =
      props.selectionMode === 'polygon' ? 'crosshair' : ''
  })

  instance.on('click', (event) => {
    if (props.selectionMode !== 'polygon') return

    // Un doble clic produce dos clics seguidos: el segundo vértice se
    // revierte y el área se cierra, en lugar de dejar un punto duplicado.
    const now = Date.now()
    if (now - lastVertexClickAt < DOUBLE_CLICK_WINDOW_MS) {
      lastVertexClickAt = 0
      emit('remove-last-polygon-vertex')
      emit('close-polygon')
      return
    }

    lastVertexClickAt = now
    emit('add-polygon-vertex', {
      latitude: event.lngLat.lat,
      longitude: event.lngLat.lng,
    })
  })

  instance.on('error', (event) => {
    const message =
      event && 'error' in event && event.error instanceof Error
        ? event.error.message
        : 'Recurso del mapa no disponible.'
    warning.value = message
  })
}

function initMap(): void {
  if (!container.value) return

  supportsLabels.value = basemap.supportsLabels

  try {
    const instance = new maplibregl.Map({
      container: container.value,
      style: basemap.style as StyleSpecification | string,
      center: [-77.03, -12.09],
      zoom: 11,
      attributionControl: { compact: true },
      doubleClickZoom: true,
    })
    map.value = instance

    instance.addControl(
      new maplibregl.NavigationControl({ showCompass: false }),
      'bottom-right',
    )

    if (stallTimer) clearTimeout(stallTimer)
    stallTimer = setTimeout(() => {
      if (!isReady.value) stalled.value = true
    }, STALL_TIMEOUT_MS)

    instance.on('load', () => {
      for (const icon of [...buildTypeIcons(), buildTechnicianIcon()]) {
        if (!instance.hasImage(icon.id)) {
          instance.addImage(
            icon.id,
            {
              width: icon.width,
              height: icon.height,
              data: icon.data,
            },
            { pixelRatio: icon.pixelRatio },
          )
        }
      }
      addSourcesAndLayers(instance)
      attachInteractions(instance)
      if (stallTimer) clearTimeout(stallTimer)
      stallTimer = null
      stalled.value = false
      isReady.value = true
      fitToOrders()
      emit('ready')
    })
  } catch (error) {
    fatalError.value =
      error instanceof Error
        ? error.message
        : 'No se pudo inicializar MapLibre GL JS.'
  }
}

function destroyMap(): void {
  map.value?.remove()
  map.value = null
  isReady.value = false
}

/** Reintenta la inicialización del mapa (p. ej. tras un entorno suspendido). */
function retryMap(): void {
  stalled.value = false
  fatalError.value = null
  warning.value = null
  destroyMap()
  initMap()
}

/** Si la pestaña vuelve a primer plano, se reintenta el mapa automáticamente. */
function onVisibilityChange(): void {
  if (
    document.visibilityState === 'visible' &&
    stalled.value &&
    !isReady.value &&
    !fatalError.value
  ) {
    retryMap()
  }
}

onMounted(() => {
  document.addEventListener('visibilitychange', onVisibilityChange)
  initMap()
})

onBeforeUnmount(() => {
  document.removeEventListener('visibilitychange', onVisibilityChange)
  if (stallTimer) clearTimeout(stallTimer)
  stallTimer = null
  destroyMap()
})

watch(
  () => props.orders,
  () => {
    if (!isReady.value) return
    syncOrderData()
    syncHighlight()
    syncSelected()
  },
)

watch(
  () => props.highlightedIds,
  () => syncHighlight(),
  { deep: true },
)

watch(
  () => props.selectedOrderId,
  (id) => {
    if (!isReady.value) return
    syncSelected()
    // Sincronización tabla → mapa: solo si el cambio no vino del propio mapa.
    if (id && id !== lastMapClickId.value) focusOrder(id)
    lastMapClickId.value = null
  },
)

watch(
  () => props.technicians,
  () => {
    if (isReady.value) syncTechnicians()
  },
  { deep: true },
)

watch(
  () => props.showTechnicians,
  () => {
    if (isReady.value) syncTechnicians()
  },
)

watch(
  () => props.polygonPoints,
  () => {
    if (isReady.value) syncPolygon()
  },
  { deep: true },
)

watch(
  () => props.routeLine,
  () => {
    if (!isReady.value) return
    syncRoute()
    fitRoute()
  },
  { deep: true },
)

watch(
  () => props.selectionMode,
  (mode) => {
    const instance = map.value
    if (!instance) return
    instance.getCanvas().style.cursor = mode === 'polygon' ? 'crosshair' : ''
    if (mode === 'polygon') {
      instance.doubleClickZoom.disable()
    } else {
      instance.doubleClickZoom.enable()
    }
  },
)

defineExpose({ focusOrder, fitToOrders, fitRoute, zoomIn, zoomOut })
</script>

<template>
  <div class="map-canvas-wrap">
    <div ref="container" class="map-canvas" />

    <div v-if="!isReady && !fatalError && !stalled" class="map-loading-overlay">
      <div class="state-panel__box">
        <div class="spinner" />
        <p class="state-panel__title">Cargando mapa</p>
        <p class="text-sm muted">Inicializando MapLibre GL JS…</p>
      </div>
    </div>

    <div
      v-if="stalled && !isReady && !fatalError"
      class="map-error-overlay"
      role="alert"
    >
      <div class="state-panel__box">
        <p class="state-panel__title">El mapa no respondió</p>
        <p class="text-sm">
          La carga del mapa base no terminó en
          {{ Math.round(STALL_TIMEOUT_MS / 1000) }} s. Puede ocurrir si la
          pestaña está en segundo plano o el proveedor de tiles no responde.
        </p>
        <p class="state-panel__hint">
          Las órdenes siguen disponibles en la lista y la tabla; al volver a
          esta pestaña el mapa suele continuar.
        </p>
        <button type="button" class="btn btn--primary" @click="retryMap">
          Reintentar mapa
        </button>
      </div>
    </div>

    <div v-if="fatalError" class="map-error-overlay" role="alert">
      <div class="state-panel__box">
        <p class="state-panel__title">No se pudo inicializar el mapa</p>
        <p class="text-sm">{{ fatalError }}</p>
        <p class="state-panel__hint">
          Las órdenes siguen disponibles en la tabla y la lista lateral.
        </p>
      </div>
    </div>

    <p v-if="warning && isReady" class="map-attribution-note">
      Aviso del mapa: {{ warning }}
    </p>

    <slot />
  </div>
</template>

<style scoped>
.map-canvas-wrap {
  position: absolute;
  inset: 0;
}
</style>
