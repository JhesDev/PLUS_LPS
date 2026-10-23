import type { OperationsFilters, WorkOrder } from '@/types/domain'
import { toDateInputValue } from '@/utils/format'

export const UNASSIGNED_FILTER = 'sin-asignar'

export function createDefaultFilters(): OperationsFilters {
  return {
    search: '',
    status: 'todos',
    type: 'todos',
    district: 'todos',
    zone: 'todos',
    technicianId: 'todos',
    dateFrom: '',
    dateTo: '',
  }
}

function normalize(value: string | null | undefined): string {
  return (value ?? '')
    .toLocaleLowerCase('es-PE')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
}

function matchesSearch(order: WorkOrder, search: string): boolean {
  const term = normalize(search.trim())
  if (!term) return true
  return [
    order.code,
    order.supplyNumber,
    order.customerName,
    order.address,
    order.district,
    order.zone,
  ].some((value) => normalize(value).includes(term))
}

function matchesDate(order: WorkOrder, from: string, to: string): boolean {
  if (!from && !to) return true
  if (!order.scheduledAt) return false
  const date = toDateInputValue(new Date(order.scheduledAt))
  if (from && date < from) return false
  if (to && date > to) return false
  return true
}

export function filterOrders(
  orders: WorkOrder[],
  filters: OperationsFilters,
): WorkOrder[] {
  return orders.filter((order) => {
    if (!matchesSearch(order, filters.search)) return false
    if (filters.status !== 'todos' && order.status !== filters.status) return false
    if (filters.type !== 'todos' && order.type !== filters.type) return false
    if (filters.district !== 'todos' && order.district !== filters.district) {
      return false
    }
    if (filters.zone !== 'todos' && order.zone !== filters.zone) return false

    if (filters.technicianId === UNASSIGNED_FILTER) {
      if (order.assignment) return false
    } else if (
      filters.technicianId !== 'todos' &&
      order.assignment?.technicianId !== filters.technicianId
    ) {
      return false
    }

    return matchesDate(order, filters.dateFrom, filters.dateTo)
  })
}

export function hasActiveFilters(filters: OperationsFilters): boolean {
  const defaults = createDefaultFilters()
  return (Object.keys(defaults) as Array<keyof OperationsFilters>).some(
    (key) => filters[key] !== defaults[key],
  )
}

export function uniqueSorted(
  values: Array<string | null | undefined>,
): string[] {
  return [...new Set(values.filter((value): value is string => Boolean(value)))]
    .sort((a, b) => a.localeCompare(b, 'es-PE'))
}

export function sortOrders(orders: WorkOrder[]): WorkOrder[] {
  return [...orders].sort((a, b) => {
    if (a.priority !== b.priority) return a.priority - b.priority
    const aTime = a.scheduledAt ? new Date(a.scheduledAt).getTime() : Infinity
    const bTime = b.scheduledAt ? new Date(b.scheduledAt).getTime() : Infinity
    return aTime - bTime || a.code.localeCompare(b.code)
  })
}
