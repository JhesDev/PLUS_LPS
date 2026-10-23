import { beforeEach, describe, expect, it } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'
import { reactive } from 'vue'
import { useOperationsStore } from '@/stores/operations'
import type { Actor } from '@/services/operationsRepository'
import { DEMO_TECHNICIANS } from '@/data/demoSeed'

const dispatcher: Actor = {
  id: '22222222-2222-4222-8222-222222222222',
  name: 'Despachador Demo',
  role: 'despachador',
}

beforeEach(() => {
  setActivePinia(createPinia())
})

describe('store de operaciones', () => {
  it('carga el conjunto demo y expone métricas globales', async () => {
    const store = useOperationsStore()
    await store.load('ready')

    expect(store.state).toBe('ready')
    expect(store.orders).toHaveLength(12)
    expect(store.globalMetrics.total).toBe(12)
    expect(store.source).toBe('demo-seed')
  })

  it('marca el estado vacío sin órdenes', async () => {
    const store = useOperationsStore()
    await store.load('empty')
    expect(store.state).toBe('empty')
    expect(store.orders).toHaveLength(0)
  })

  it('expone el mensaje de error del escenario error', async () => {
    const store = useOperationsStore()
    await store.load('error')
    expect(store.state).toBe('error')
    expect(store.errorMessage).toMatch(/jornada demo/)
  })

  it('excluye del mapa las órdenes sin geocodificar', async () => {
    const store = useOperationsStore()
    await store.load('ready')
    expect(store.visibleMapOrders).toHaveLength(11)
    expect(store.ordersWithoutLocation).toHaveLength(1)
  })

  it('selecciona por polígono solo las órdenes dentro del área', async () => {
    const store = useOperationsStore()
    await store.load('ready')

    store.setSelectionMode('polygon')
    // Área que cubre Miraflores y San Isidro (2 órdenes demo).
    store.addPolygonVertex({ latitude: -12.13, longitude: -77.06 })
    store.addPolygonVertex({ latitude: -12.13, longitude: -77.025 })
    store.addPolygonVertex({ latitude: -12.09, longitude: -77.025 })
    store.addPolygonVertex({ latitude: -12.09, longitude: -77.06 })

    expect(store.polygonOrderIds).toHaveLength(2)
    expect(store.polygonSelectedOrders.map((order) => order.code).sort()).toEqual([
      'WO-2026-0001',
      'WO-2026-0002',
    ])
  })

  it('limpia la selección al desactivar el modo polígono', async () => {
    const store = useOperationsStore()
    await store.load('ready')
    store.setSelectionMode('polygon')
    store.addPolygonVertex({ latitude: -12.13, longitude: -77.06 })
    store.addPolygonVertex({ latitude: -12.13, longitude: -77.025 })
    store.addPolygonVertex({ latitude: -12.09, longitude: -77.025 })
    expect(store.polygonPoints.length).toBe(3)

    store.setSelectionMode('none')
    expect(store.polygonPoints).toHaveLength(0)
    expect(store.polygonOrderIds).toHaveLength(0)
  })

  it('asigna por área y refleja el cambio en las órdenes', async () => {
    const store = useOperationsStore()
    await store.load('ready')

    await store.assignOrders({
      orderIds: ['aaaaaaaa-aaaa-4aaa-8aaa-000000000001'],
      technicianId: DEMO_TECHNICIANS[2].id,
      actor: dispatcher,
    })

    const order = store.orders.find(
      (item) => item.id === 'aaaaaaaa-aaaa-4aaa-8aaa-000000000001',
    )
    expect(order?.status).toBe('asignada')
    expect(order?.assignment?.technicianId).toBe(DEMO_TECHNICIANS[2].id)
    expect(store.globalMetrics.assigned).toBe(3)
  })

  it('selecciona por proximidad a la ubicación de la cuadrilla', async () => {    const store = useOperationsStore()
    await store.load('ready')

    store.selectByProximity(DEMO_TECHNICIANS[0].id, 3000)
    expect(store.polygonOrderIds.length).toBeGreaterThan(0)

    const technician = store.technicians.find(
      (item) => item.id === DEMO_TECHNICIANS[0].id,
    )
    // Nunca incluye órdenes ya asignadas a la misma cuadrilla.
    const assignedToSame = store.polygonSelectedOrders.every(
      (order) => order.assignment?.technicianId !== technician?.id,
    )
    expect(assignedToSame).toBe(true)
  })

  it('acepta coordenadas reactivas (Proxy) sin romper la recarga', async () => {
    const store = useOperationsStore()
    await store.load('ready')

    // Un objeto reactivo es un Proxy: no debe filtrarse al repositorio porque
    // no es serializable (structuredClone falla con Proxy).
    const location = reactive({ latitude: -12.0566, longitude: -77.1181 })

    await store.updateStatus({
      orderId: 'aaaaaaaa-aaaa-4aaa-8aaa-000000000005',
      status: 'en_proceso',
      actor: {
        id: DEMO_TECHNICIANS[0].id,
        name: DEMO_TECHNICIANS[0].fullName,
        role: 'tecnico',
      },
      location,
    })

    const order = store.orders.find(
      (item) => item.id === 'aaaaaaaa-aaaa-4aaa-8aaa-000000000005',
    )
    expect(order?.status).toBe('en_proceso')
    expect(store.state).toBe('ready')

    const latest = store.history
      .filter((entry) => entry.workOrderId === 'aaaaaaaa-aaaa-4aaa-8aaa-000000000005')
      .sort((a, b) => new Date(b.changedAt).getTime() - new Date(a.changedAt).getTime())[0]
    expect(latest?.toStatus).toBe('en_proceso')
    expect(latest?.location).toEqual({ latitude: -12.0566, longitude: -77.1181 })
  })
})
