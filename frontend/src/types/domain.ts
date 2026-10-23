/**
 * Contratos de dominio del frontend.
 *
 * Los nombres y valores replican el esquema versionado de
 * `database/supabase/migrations` (0002–0009). No se inventan campos del
 * servicio externo SAP: `externalSource`/`externalId` son solo referencias
 * internas de idempotencia.
 */

export type AppRole = 'coordinador' | 'despachador' | 'tecnico'

export type DataMode = 'connected' | 'demo'

export interface Actor {
  id: string
  name: string
  role: AppRole
}

export type WorkOrderType =
  | 'corte'
  | 'reposicion'
  | 'inspeccion'
  | 'reconexion'
  | 'mantenimiento'
  | 'otro'

export type WorkOrderStatus =
  | 'pendiente'
  | 'asignada'
  | 'en_proceso'
  | 'ejecutada'
  | 'imposibilitada'
  | 'cancelada'

export type RouteStatus = 'planificada' | 'en_curso' | 'completada' | 'cancelada'

export type RouteStopStatus = 'pendiente' | 'en_proceso' | 'completada' | 'omitida'

export type EvidenceKind =
  | 'antes'
  | 'durante'
  | 'despues'
  | 'firma'
  | 'documento'
  | 'otro'

export interface Coordinates {
  latitude: number
  longitude: number
}

export interface Technician {
  id: string
  fullName: string
  phone: string | null
  employeeCode: string | null
  vehicleLabel: string | null
  maxDailyOrders: number
  location: Coordinates | null
  locationUpdatedAt: string | null
  activeOrders: number
  assignedOrders: number
  inProgressOrders: number
}

export interface Assignment {
  id: string
  workOrderId: string
  technicianId: string
  technicianName: string
  assignedBy: string | null
  assignedAt: string
  unassignedAt: string | null
  unassignedBy: string | null
  endReason: string | null
  notes: string | null
}

export interface Evidence {
  id: string
  workOrderId: string
  assignmentId: string | null
  kind: EvidenceKind
  storageBucket: string
  storagePath: string
  mimeType: string | null
  sizeBytes: number | null
  capturedAt: string | null
  uploadedBy: string | null
  metadata: Record<string, unknown>
  /** Solo demo: URL local del archivo elegido, nunca se sube a Storage. */
  localPreviewUrl?: string
}

export interface WorkOrder {
  id: string
  code: string
  externalSource: string | null
  externalId: string | null
  type: WorkOrderType
  status: WorkOrderStatus
  priority: number
  customerName: string | null
  supplyNumber: string | null
  address: string | null
  district: string | null
  zone: string | null
  location: Coordinates | null
  scheduledAt: string | null
  dueAt: string | null
  notes: string | null
  cancellationReason: string | null
  completedAt: string | null
  createdAt: string
  updatedAt: string
  assignment: Assignment | null
  evidence: Evidence[]
}

export interface RouteStop {
  id: string
  routeId: string
  workOrderId: string
  stopOrder: number
  status: RouteStopStatus
  plannedAt: string | null
  arrivedAt: string | null
  completedAt: string | null
  notes: string | null
}

export interface TechnicianRoute {
  id: string
  code: string
  technicianId: string
  routeDate: string
  status: RouteStatus
  startedAt: string | null
  completedAt: string | null
  notes: string | null
  stops: RouteStop[]
}

export interface StatusHistoryEntry {
  id: string
  workOrderId: string
  orderCode: string
  fromStatus: WorkOrderStatus | null
  toStatus: WorkOrderStatus
  changedBy: string | null
  changedByName: string | null
  changedAt: string
  reason: string | null
  location: Coordinates | null
}

export interface OperationsSnapshot {
  orders: WorkOrder[]
  technicians: Technician[]
  routes: TechnicianRoute[]
  assignments: Assignment[]
  history: StatusHistoryEntry[]
  /** Origen explícito para que la UI nunca presente el demo como API real. */
  source: 'demo-seed'
  loadedAt: string
}

export interface OperationsFilters {
  search: string
  status: WorkOrderStatus | 'todos'
  type: WorkOrderType | 'todos'
  district: string
  zone: string
  technicianId: string
  dateFrom: string
  dateTo: string
}

export interface AssignmentResult {
  orderIds: string[]
  technicianId: string
  technicianName: string
  reassigned: number
  assigned: number
}

export interface StatusUpdateInput {
  orderId: string
  status: WorkOrderStatus
  reason?: string
  location?: Coordinates | null
}

export interface EvidenceInput {
  orderId: string
  kind: EvidenceKind
  file: File
}
