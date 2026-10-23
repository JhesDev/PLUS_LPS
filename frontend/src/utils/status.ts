import type {
  EvidenceKind,
  RouteStatus,
  RouteStopStatus,
  WorkOrderStatus,
  WorkOrderType,
} from '@/types/domain'

export interface StatusMeta {
  label: string
  color: string
  soft: string
  description: string
}

export const STATUS_META: Record<WorkOrderStatus, StatusMeta> = {
  pendiente: {
    label: 'Pendiente',
    color: '#d99a06',
    soft: '#fef3c7',
    description: 'Sin asignar o devuelta a la cola.',
  },
  asignada: {
    label: 'Asignada',
    color: '#2563eb',
    soft: '#dbeafe',
    description: 'Tiene una asignación vigente.',
  },
  en_proceso: {
    label: 'En proceso',
    color: '#ea580c',
    soft: '#ffedd5',
    description: 'El técnico inició el trabajo.',
  },
  ejecutada: {
    label: 'Ejecutada',
    color: '#16803c',
    soft: '#dcfce7',
    description: 'Resultado exitoso registrado.',
  },
  imposibilitada: {
    label: 'Imposibilitada',
    color: '#dc2626',
    soft: '#fee2e2',
    description: 'No se pudo ejecutar; requiere motivo.',
  },
  cancelada: {
    label: 'Cancelada',
    color: '#64748b',
    soft: '#e2e8f0',
    description: 'Cerrada sin ejecución.',
  },
}

export const STATUS_ORDER: WorkOrderStatus[] = [
  'pendiente',
  'asignada',
  'en_proceso',
  'ejecutada',
  'imposibilitada',
  'cancelada',
]

export const OPEN_STATUSES: WorkOrderStatus[] = [
  'pendiente',
  'asignada',
  'en_proceso',
]

export interface TypeMeta {
  label: string
  icon: string
  short: string
}

export const TYPE_META: Record<WorkOrderType, TypeMeta> = {
  corte: { label: 'Corte', icon: 'scissors', short: 'Corte' },
  reposicion: { label: 'Reposición', icon: 'bolt', short: 'Repos.' },
  inspeccion: { label: 'Inspección', icon: 'inspect', short: 'Insp.' },
  reconexion: { label: 'Reconexión', icon: 'link', short: 'Recon.' },
  mantenimiento: { label: 'Mantenimiento', icon: 'wrench', short: 'Mant.' },
  otro: { label: 'Otro', icon: 'tool', short: 'Otro' },
}

export const TYPE_ORDER: WorkOrderType[] = [
  'corte',
  'reposicion',
  'inspeccion',
  'reconexion',
  'mantenimiento',
  'otro',
]

export const PRIORITY_META: Record<number, { label: string; color: string }> = {
  1: { label: 'P1 · Crítica', color: '#dc2626' },
  2: { label: 'P2 · Alta', color: '#ea580c' },
  3: { label: 'P3 · Media', color: '#ca8a04' },
  4: { label: 'P4 · Baja', color: '#2563eb' },
  5: { label: 'P5 · Mínima', color: '#64748b' },
}

export const ROUTE_STATUS_META: Record<RouteStatus, { label: string; color: string }> = {
  planificada: { label: 'Planificada', color: '#2563eb' },
  en_curso: { label: 'En curso', color: '#ea580c' },
  completada: { label: 'Completada', color: '#16803c' },
  cancelada: { label: 'Cancelada', color: '#64748b' },
}

export const STOP_STATUS_META: Record<RouteStopStatus, { label: string; color: string }> = {
  pendiente: { label: 'Pendiente', color: '#d99a06' },
  en_proceso: { label: 'En proceso', color: '#ea580c' },
  completada: { label: 'Completada', color: '#16803c' },
  omitida: { label: 'Omitida', color: '#64748b' },
}

export const EVIDENCE_KIND_META: Record<EvidenceKind, string> = {
  antes: 'Antes',
  durante: 'Durante',
  despues: 'Después',
  firma: 'Firma',
  documento: 'Documento',
  otro: 'Otro',
}

/** Transiciones que la RPC `update_work_order_status` permite al técnico. */
export const TECHNICIAN_TRANSITIONS: Partial<
  Record<WorkOrderStatus, WorkOrderStatus[]>
> = {
  asignada: ['en_proceso'],
  en_proceso: ['ejecutada', 'imposibilitada'],
}

/** Transiciones que la RPC permite al despachador (según migración 0007). */
export const DISPATCHER_TRANSITIONS: Partial<
  Record<WorkOrderStatus, WorkOrderStatus[]>
> = {
  pendiente: ['cancelada'],
  asignada: ['en_proceso', 'cancelada'],
  en_proceso: ['ejecutada', 'imposibilitada', 'cancelada'],
  imposibilitada: ['pendiente'],
}

/**
 * Estados destino permitidos por rol. Replica la matriz de la RPC para que la
 * UI no ofrezca transiciones que el servidor rechazará.
 */
export function allowedTransitions(
  role: 'coordinador' | 'despachador' | 'tecnico',
  status: WorkOrderStatus,
): WorkOrderStatus[] {
  if (role === 'despachador') return DISPATCHER_TRANSITIONS[status] ?? []
  if (role === 'tecnico') return TECHNICIAN_TRANSITIONS[status] ?? []
  return []
}

export function requiresReason(status: WorkOrderStatus): boolean {
  return status === 'imposibilitada' || status === 'cancelada'
}

export function isClosedStatus(status: WorkOrderStatus): boolean {
  return ['ejecutada', 'imposibilitada', 'cancelada'].includes(status)
}
