import { describe, expect, it } from 'vitest'
import { createDemoSnapshot } from '@/data/demoSeed'
import {
  UNASSIGNED_FILTER,
  createDefaultFilters,
  filterOrders,
  hasActiveFilters,
  sortOrders,
} from '@/utils/filters'
import { buildMetrics } from '@/utils/metrics'
import { pointInPolygon } from '@/utils/geo'
import { allowedTransitions, requiresReason } from '@/utils/status'

const snapshot = createDemoSnapshot(new Date('2026-10-23T12:00:00-05:00'))

describe('filtros de operaciones', () => {
  it('devuelve todas las órdenes sin filtros', () => {
    expect(filterOrders(snapshot.orders, createDefaultFilters())).toHaveLength(
      snapshot.orders.length,
    )
  })

  it('filtra por estado', () => {
    const result = filterOrders(snapshot.orders, {
      ...createDefaultFilters(),
      status: 'pendiente',
    })
    expect(result.length).toBeGreaterThan(0)
    expect(result.every((order) => order.status === 'pendiente')).toBe(true)
  })

  it('busca por suministro ignorando acentos y mayúsculas', () => {
    const result = filterOrders(snapshot.orders, {
      ...createDefaultFilters(),
      search: 'sum-000005',
    })
    expect(result.map((order) => order.code)).toEqual(['WO-2026-0005'])
  })

  it('busca por nombre de cliente', () => {
    const result = filterOrders(snapshot.orders, {
      ...createDefaultFilters(),
      search: 'Cliente Ficticio 09',
    })
    expect(result[0]?.code).toBe('WO-2026-0009')
  })

  it('filtra órdenes sin asignar', () => {
    const result = filterOrders(snapshot.orders, {
      ...createDefaultFilters(),
      technicianId: UNASSIGNED_FILTER,
    })
    expect(result.every((order) => order.assignment === null)).toBe(true)
    expect(result.length).toBeGreaterThan(0)
  })

  it('detecta filtros activos', () => {
    expect(hasActiveFilters(createDefaultFilters())).toBe(false)
    expect(
      hasActiveFilters({ ...createDefaultFilters(), status: 'ejecutada' }),
    ).toBe(true)
  })
})

describe('orden y métricas', () => {
  it('ordena por prioridad ascendente', () => {
    const sorted = sortOrders(snapshot.orders)
    for (let index = 1; index < sorted.length; index += 1) {
      expect(sorted[index - 1].priority).toBeLessThanOrEqual(sorted[index].priority)
    }
  })

  it('cuenta los estados del conjunto demo', () => {
    const metrics = buildMetrics(snapshot.orders)
    expect(metrics.total).toBe(12)
    expect(metrics.pending).toBe(5)
    expect(metrics.assigned).toBe(2)
    expect(metrics.inProgress).toBe(2)
    expect(metrics.executed).toBe(1)
    expect(metrics.impossible).toBe(1)
    expect(metrics.cancelled).toBe(1)
    expect(metrics.enRoute).toBe(metrics.assigned + metrics.inProgress)
  })

  it('detecta órdenes sin geocodificar', () => {
    const metrics = buildMetrics(snapshot.orders)
    expect(metrics.geocoded).toBe(11)
    expect(metrics.total - metrics.geocoded).toBe(1)
  })
})

describe('utilidades geográficas', () => {
  const square: Array<[number, number]> = [
    [-77.05, -12.1],
    [-77.0, -12.1],
    [-77.0, -12.05],
    [-77.05, -12.05],
  ]

  it('detecta un punto dentro del polígono', () => {
    expect(pointInPolygon([-77.03, -12.08], square)).toBe(true)
  })

  it('detecta un punto fuera del polígono', () => {
    expect(pointInPolygon([-76.9, -12.08], square)).toBe(false)
  })

  it('rechaza polígonos degenerados', () => {
    expect(pointInPolygon([-77.03, -12.08], [[0, 0], [1, 1]])).toBe(false)
  })
})

describe('transiciones por rol', () => {
  it('el técnico solo avanza desde en_proceso', () => {
    expect(allowedTransitions('tecnico', 'asignada')).toEqual(['en_proceso'])
    expect(allowedTransitions('tecnico', 'en_proceso')).toEqual([
      'ejecutada',
      'imposibilitada',
    ])
    expect(allowedTransitions('tecnico', 'pendiente')).toEqual([])
  })

  it('el coordinador no tiene transiciones', () => {
    expect(allowedTransitions('coordinador', 'en_proceso')).toEqual([])
  })

  it('exige motivo en imposibilitada y cancelada', () => {
    expect(requiresReason('imposibilitada')).toBe(true)
    expect(requiresReason('cancelada')).toBe(true)
    expect(requiresReason('ejecutada')).toBe(false)
  })
})
