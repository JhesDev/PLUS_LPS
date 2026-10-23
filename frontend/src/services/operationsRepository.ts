import type {
  AppRole,
  AssignmentResult,
  Coordinates,
  EvidenceKind,
  OperationsSnapshot,
  StatusUpdateInput,
  WorkOrderStatus,
} from '@/types/domain'

export type DemoScenario = 'ready' | 'empty' | 'error' | 'slow'

export interface Actor {
  id: string
  name: string
  role: AppRole
}

/**
 * Puerto de acceso a datos de operaciones.
 *
 * Hoy solo existe la implementación demo (`demoRepository`). Cuando el
 * backend publique los endpoints de lectura/escritura, se agregará un
 * adaptador que los consuma sin cambiar las vistas ni los stores.
 *
 * Las escrituras respetan la semántica de las RPC de PostgreSQL:
 * asignaciones vigentes únicas, transiciones válidas y motivo obligatorio
 * para `imposibilitada`/`cancelada`.
 */
export interface OperationsRepository {
  load(scenario?: DemoScenario): Promise<OperationsSnapshot>
  assignOrders(input: {
    orderIds: string[]
    technicianId: string
    actor: Actor
    notes?: string
  }): Promise<AssignmentResult>
  unassignOrder(input: {
    orderId: string
    actor: Actor
    reason?: string
  }): Promise<void>
  updateStatus(input: {
    update: StatusUpdateInput
    actor: Actor
    location?: Coordinates | null
  }): Promise<void>
  addEvidence(input: {
    orderId: string
    kind: EvidenceKind
    file: File
    actor: Actor
  }): Promise<void>
  /** Expuesto para que la UI pueda mapear estados de error sin acoplarse. */
  isClosedStatus(status: WorkOrderStatus): boolean
}
