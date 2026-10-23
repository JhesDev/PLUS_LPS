import type { WorkOrder, WorkOrderStatus, WorkOrderType } from '@/types/domain'

export interface OperationMetrics {
  total: number
  pending: number
  assigned: number
  inProgress: number
  enRoute: number
  executed: number
  impossible: number
  cancelled: number
  unassigned: number
  geocoded: number
  byStatus: Record<WorkOrderStatus, number>
  byType: Record<WorkOrderType, number>
}

const EMPTY_STATUS: Record<WorkOrderStatus, number> = {
  pendiente: 0,
  asignada: 0,
  en_proceso: 0,
  ejecutada: 0,
  imposibilitada: 0,
  cancelada: 0,
}

const EMPTY_TYPE: Record<WorkOrderType, number> = {
  corte: 0,
  reposicion: 0,
  inspeccion: 0,
  reconexion: 0,
  mantenimiento: 0,
  otro: 0,
}

export function buildMetrics(orders: WorkOrder[]): OperationMetrics {
  const byStatus = { ...EMPTY_STATUS }
  const byType = { ...EMPTY_TYPE }

  for (const order of orders) {
    byStatus[order.status] += 1
    byType[order.type] += 1
  }

  return {
    total: orders.length,
    pending: byStatus.pendiente,
    assigned: byStatus.asignada,
    inProgress: byStatus.en_proceso,
    enRoute: byStatus.asignada + byStatus.en_proceso,
    executed: byStatus.ejecutada,
    impossible: byStatus.imposibilitada,
    cancelled: byStatus.cancelada,
    unassigned: orders.filter((order) => !order.assignment).length,
    geocoded: orders.filter((order) => order.location).length,
    byStatus,
    byType,
  }
}
