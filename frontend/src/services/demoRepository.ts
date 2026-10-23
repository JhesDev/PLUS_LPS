import {
  createDemoSnapshot,
  refreshTechnicianWorkload,
} from '@/data/demoSeed'
import type {
  Actor,
  DemoScenario,
  OperationsRepository,
} from '@/services/operationsRepository'
import type {
  Assignment,
  AssignmentResult,
  Coordinates,
  Evidence,
  OperationsSnapshot,
  StatusUpdateInput,
  WorkOrderStatus,
} from '@/types/domain'
import { TECHNICIAN_TRANSITIONS, isClosedStatus } from '@/utils/status'

const STATUSES_REQUIRING_REASON: WorkOrderStatus[] = [
  'imposibilitada',
  'cancelada',
]

function nowIso(): string {
  return new Date().toISOString()
}

function newId(prefix: string): string {
  return `${prefix}-${crypto.randomUUID()}`
}

/**
 * URL local de previsualización. Es opcional: algunos entornos (por ejemplo
 * jsdom en pruebas) no implementan `URL.createObjectURL`, y el boceto debe
 * seguir funcionando sin ella.
 */
function safeObjectUrl(file: File): string | undefined {
  if (typeof URL !== 'undefined' && typeof URL.createObjectURL === 'function') {
    return URL.createObjectURL(file)
  }
  return undefined
}

export interface DemoRepositoryOptions {
  /** Multiplicador de la latencia simulada. `0` la desactiva (pruebas). */
  latency?: number
}

function cloneSnapshot(snapshot: OperationsSnapshot): OperationsSnapshot {
  return structuredClone(snapshot)
}

/**
 * Implementación local del puerto de operaciones.
 *
 * No simula respuestas de red ni llama a SAP/backend. Cada mutación devuelve
 * el snapshot actualizado y la UI lo presenta explícitamente como demo.
 */
export class DemoOperationsRepository implements OperationsRepository {
  private snapshot: OperationsSnapshot = createDemoSnapshot()
  private readonly latency: number

  constructor(options: DemoRepositoryOptions = {}) {
    this.latency = options.latency ?? 1
  }

  private wait(ms: number): Promise<void> {
    const delay = Math.round(ms * this.latency)
    if (delay <= 0) return Promise.resolve()
    return new Promise((resolve) => setTimeout(resolve, delay))
  }

  async load(scenario: DemoScenario = 'ready'): Promise<OperationsSnapshot> {
    await this.wait(scenario === 'slow' ? 1600 : 420)

    if (scenario === 'error') {
      throw new Error(
        'No se pudo cargar la jornada demo. Revisa el estado de demostración e inténtalo de nuevo.',
      )
    }

    if (scenario === 'empty') {
      return {
        ...cloneSnapshot(this.snapshot),
        orders: [],
        technicians: [],
        routes: [],
        assignments: [],
        history: [],
        loadedAt: nowIso(),
      }
    }

    return {
      ...cloneSnapshot(this.snapshot),
      loadedAt: nowIso(),
    }
  }

  isClosedStatus(status: WorkOrderStatus): boolean {
    return isClosedStatus(status)
  }

  async assignOrders(input: {
    orderIds: string[]
    technicianId: string
    actor: Actor
    notes?: string
  }): Promise<AssignmentResult> {
    await this.wait(320)

    if (input.actor.role !== 'despachador') {
      throw new Error('Solo un despachador puede asignar órdenes.')
    }

    const technician = this.snapshot.technicians.find(
      (item) => item.id === input.technicianId,
    )
    if (!technician) {
      throw new Error('El técnico seleccionado no existe en la jornada demo.')
    }

    const uniqueIds = [...new Set(input.orderIds)]
    if (!uniqueIds.length) {
      throw new Error('Selecciona al menos una orden para asignar.')
    }

    let assigned = 0
    let reassigned = 0

    for (const orderId of uniqueIds) {
      const order = this.snapshot.orders.find((item) => item.id === orderId)
      if (!order) {
        throw new Error('Una de las órdenes seleccionadas ya no está disponible.')
      }
      if (isClosedStatus(order.status)) {
        throw new Error(
          `La orden ${order.code} está ${order.status} y no admite asignación.`,
        )
      }

      const current = this.snapshot.assignments.find(
        (assignment) =>
          assignment.workOrderId === order.id && !assignment.unassignedAt,
      )

      // La RPC es idempotente si el técnico es el mismo.
      if (current && current.technicianId === technician.id) {
        if (input.notes?.trim()) current.notes = input.notes.trim()
        continue
      }

      if (current) {
        current.unassignedAt = nowIso()
        current.unassignedBy = input.actor.id
        current.endReason = 'reasignada'
        reassigned += 1
      } else {
        assigned += 1
      }

      const assignment: Assignment = {
        id: newId('assignment-demo'),
        workOrderId: order.id,
        technicianId: technician.id,
        technicianName: technician.fullName,
        assignedBy: input.actor.id,
        assignedAt: nowIso(),
        unassignedAt: null,
        unassignedBy: null,
        endReason: null,
        notes: input.notes?.trim() || null,
      }

      this.snapshot.assignments.unshift(assignment)
      order.assignment = assignment
      const fromStatus = order.status
      order.status = 'asignada'
      order.updatedAt = nowIso()
      order.completedAt = null
      order.cancellationReason = null

      this.snapshot.history.unshift({
        id: newId('history-demo'),
        workOrderId: order.id,
        orderCode: order.code,
        fromStatus,
        toStatus: 'asignada',
        changedBy: input.actor.id,
        changedByName: input.actor.name,
        changedAt: nowIso(),
        reason: current ? 'Reasignación demo' : 'Asignación demo',
        location: null,
      })
    }

    this.snapshot.technicians = refreshTechnicianWorkload(
      this.snapshot.orders,
      this.snapshot.technicians,
    )

    return {
      orderIds: uniqueIds,
      technicianId: technician.id,
      technicianName: technician.fullName,
      assigned,
      reassigned,
    }
  }

  async unassignOrder(input: {
    orderId: string
    actor: Actor
    reason?: string
  }): Promise<void> {
    await this.wait(280)

    if (input.actor.role !== 'despachador') {
      throw new Error('Solo un despachador puede desasignar órdenes.')
    }

    const order = this.snapshot.orders.find((item) => item.id === input.orderId)
    if (!order) throw new Error('La orden no existe en la jornada demo.')
    if (isClosedStatus(order.status)) {
      throw new Error(`La orden ${order.code} está cerrada y no admite cambios.`)
    }

    const current = this.snapshot.assignments.find(
      (assignment) =>
        assignment.workOrderId === order.id && !assignment.unassignedAt,
    )
    if (!current) {
      throw new Error(`La orden ${order.code} no tiene una asignación vigente.`)
    }

    const reason = input.reason?.trim() || 'desasignada'
    current.unassignedAt = nowIso()
    current.unassignedBy = input.actor.id
    current.endReason = reason
    order.assignment = null
    order.status = 'pendiente'
    order.updatedAt = nowIso()

    this.snapshot.history.unshift({
      id: newId('history-demo'),
      workOrderId: order.id,
      orderCode: order.code,
      fromStatus: 'asignada',
      toStatus: 'pendiente',
      changedBy: input.actor.id,
      changedByName: input.actor.name,
      changedAt: nowIso(),
      reason: `Desasignada: ${reason}`,
      location: null,
    })

    this.snapshot.technicians = refreshTechnicianWorkload(
      this.snapshot.orders,
      this.snapshot.technicians,
    )
  }

  async updateStatus(input: {
    update: StatusUpdateInput
    actor: Actor
    location?: Coordinates | null
  }): Promise<void> {
    await this.wait(300)

    const { update, actor, location } = input
    const order = this.snapshot.orders.find(
      (item) => item.id === update.orderId,
    )
    if (!order) throw new Error('La orden no existe en la jornada demo.')

    if (actor.role === 'coordinador') {
      throw new Error('El coordinador solo tiene acceso de lectura/auditoría.')
    }

    if (order.status === update.status) {
      throw new Error(`La orden ${order.code} ya está en estado ${update.status}.`)
    }

    if (actor.role === 'tecnico') {
      const ownsOrder = order.assignment?.technicianId === actor.id
      if (!ownsOrder) {
        throw new Error('El técnico no tiene esta orden asignada de forma vigente.')
      }
      const allowed = TECHNICIAN_TRANSITIONS[order.status] ?? []
      if (!allowed.includes(update.status)) {
        throw new Error(
          `Transición no permitida para técnico: ${order.status} → ${update.status}.`,
        )
      }
    }

    if (
      actor.role === 'despachador' &&
      ![
        'en_proceso',
        'ejecutada',
        'imposibilitada',
        'cancelada',
        'pendiente',
      ].includes(update.status)
    ) {
      throw new Error('El despachador no puede aplicar ese estado.')
    }

    const reason = update.reason?.trim() || null
    if (STATUSES_REQUIRING_REASON.includes(update.status) && !reason) {
      throw new Error(`El estado ${update.status} requiere un motivo.`)
    }

    const fromStatus = order.status
    order.status = update.status
    order.updatedAt = nowIso()
    order.cancellationReason =
      update.status === 'cancelada' ? reason : null
    order.completedAt = ['ejecutada', 'imposibilitada'].includes(update.status)
      ? nowIso()
      : null

    this.snapshot.history.unshift({
      id: newId('history-demo'),
      workOrderId: order.id,
      orderCode: order.code,
      fromStatus,
      toStatus: update.status,
      changedBy: actor.id,
      changedByName: actor.name,
      changedAt: nowIso(),
      reason:
        reason ??
        `Cambio demo de estado: ${fromStatus} → ${update.status}`,
      location: location ?? null,
    })

    this.snapshot.technicians = refreshTechnicianWorkload(
      this.snapshot.orders,
      this.snapshot.technicians,
    )
  }

  async addEvidence(input: {
    orderId: string
    kind: Evidence['kind']
    file: File
    actor: Actor
  }): Promise<void> {
    await this.wait(220)

    const order = this.snapshot.orders.find((item) => item.id === input.orderId)
    if (!order) throw new Error('La orden no existe en la jornada demo.')

    if (input.actor.role === 'tecnico') {
      if (order.assignment?.technicianId !== input.actor.id) {
        throw new Error('El técnico no tiene esta orden asignada de forma vigente.')
      }
    }

    if (input.file.size > 10 * 1024 * 1024) {
      throw new Error('La evidencia supera el límite de 10 MiB del bucket.')
    }

    const safeName = input.file.name.replace(/[^a-zA-Z0-9._-]/g, '-')
    const evidence: Evidence = {
      id: newId('evidence-demo'),
      workOrderId: order.id,
      assignmentId: order.assignment?.id ?? null,
      kind: input.kind,
      storageBucket: 'work-order-evidence',
      storagePath: `${order.id}/${safeName}`,
      mimeType: input.file.type || null,
      sizeBytes: input.file.size,
      capturedAt: nowIso(),
      uploadedBy: input.actor.id,
      metadata: { demo: true, uploaded: false },
      localPreviewUrl: safeObjectUrl(input.file),
    }

    order.evidence = [evidence, ...order.evidence]
    order.updatedAt = nowIso()
  }
}
