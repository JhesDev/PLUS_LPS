import { describe, expect, it } from 'vitest'
import { DemoOperationsRepository } from '@/services/demoRepository'
import type { Actor } from '@/services/operationsRepository'
import { DEMO_TECHNICIANS } from '@/data/demoSeed'

const dispatcher: Actor = {
  id: '22222222-2222-4222-8222-222222222222',
  name: 'Despachador Demo',
  role: 'despachador',
}

const coordinator: Actor = {
  id: '11111111-1111-4111-8111-111111111111',
  name: 'Coordinador Demo',
  role: 'coordinador',
}

const technician: Actor = {
  id: DEMO_TECHNICIANS[0].id,
  name: DEMO_TECHNICIANS[0].fullName,
  role: 'tecnico',
}

const PENDING_ORDER = 'aaaaaaaa-aaaa-4aaa-8aaa-000000000001'
const ASSIGNED_ORDER = 'aaaaaaaa-aaaa-4aaa-8aaa-000000000005'
const EXECUTED_ORDER = 'aaaaaaaa-aaaa-4aaa-8aaa-000000000009'
const IN_PROGRESS_ORDER = 'aaaaaaaa-aaaa-4aaa-8aaa-000000000007'

async function freshRepository(): Promise<DemoOperationsRepository> {
  // Sin latencia simulada para que las pruebas sean rápidas.
  const repository = new DemoOperationsRepository({ latency: 0 })
  await repository.load('ready')
  return repository
}

describe('repositorio demo · asignaciones', () => {
  it('asigna una orden pendiente y la deja asignada', async () => {
    const repository = await freshRepository()
    const result = await repository.assignOrders({
      orderIds: [PENDING_ORDER],
      technicianId: DEMO_TECHNICIANS[1].id,
      actor: dispatcher,
    })

    expect(result.assigned).toBe(1)
    expect(result.reassigned).toBe(0)

    const snapshot = await repository.load('ready')
    const order = snapshot.orders.find((item) => item.id === PENDING_ORDER)
    expect(order?.status).toBe('asignada')
    expect(order?.assignment?.technicianId).toBe(DEMO_TECHNICIANS[1].id)

    const active = snapshot.assignments.filter(
      (assignment) => assignment.workOrderId === PENDING_ORDER && !assignment.unassignedAt,
    )
    expect(active).toHaveLength(1)
  })

  it('reasigna cerrando la asignación vigente anterior', async () => {
    const repository = await freshRepository()
    const result = await repository.assignOrders({
      orderIds: [ASSIGNED_ORDER],
      technicianId: DEMO_TECHNICIANS[2].id,
      actor: dispatcher,
    })

    expect(result.reassigned).toBe(1)

    const snapshot = await repository.load('ready')
    const previous = snapshot.assignments.find(
      (assignment) =>
        assignment.workOrderId === ASSIGNED_ORDER &&
        assignment.technicianId === DEMO_TECHNICIANS[0].id,
    )
    expect(previous?.unassignedAt).not.toBeNull()
    expect(previous?.endReason).toBe('reasignada')

    const active = snapshot.assignments.filter(
      (assignment) => assignment.workOrderId === ASSIGNED_ORDER && !assignment.unassignedAt,
    )
    expect(active).toHaveLength(1)
    expect(active[0].technicianId).toBe(DEMO_TECHNICIANS[2].id)
  })

  it('es idempotente si el técnico destino es el mismo', async () => {
    const repository = await freshRepository()
    const result = await repository.assignOrders({
      orderIds: [ASSIGNED_ORDER],
      technicianId: DEMO_TECHNICIANS[0].id,
      actor: dispatcher,
      notes: 'nota demo',
    })

    expect(result.assigned).toBe(0)
    expect(result.reassigned).toBe(0)

    const snapshot = await repository.load('ready')
    const active = snapshot.assignments.filter(
      (assignment) => assignment.workOrderId === ASSIGNED_ORDER && !assignment.unassignedAt,
    )
    expect(active).toHaveLength(1)
    expect(active[0].notes).toBe('nota demo')
  })

  it('rechaza asignar a una orden cerrada', async () => {
    const repository = await freshRepository()
    await expect(
      repository.assignOrders({
        orderIds: [EXECUTED_ORDER],
        technicianId: DEMO_TECHNICIANS[1].id,
        actor: dispatcher,
      }),
    ).rejects.toThrow(/no admite asignación/)
  })

  it('rechaza asignar sin rol despachador', async () => {
    const repository = await freshRepository()
    await expect(
      repository.assignOrders({
        orderIds: [PENDING_ORDER],
        technicianId: DEMO_TECHNICIANS[0].id,
        actor: coordinator,
      }),
    ).rejects.toThrow(/Solo un despachador/)
  })

  it('rechaza una lista vacía', async () => {
    const repository = await freshRepository()
    await expect(
      repository.assignOrders({
        orderIds: [],
        technicianId: DEMO_TECHNICIANS[0].id,
        actor: dispatcher,
      }),
    ).rejects.toThrow(/al menos una orden/)
  })
})

describe('repositorio demo · desasignación', () => {
  it('desasigna y devuelve la orden a pendiente', async () => {
    const repository = await freshRepository()
    await repository.unassignOrder({
      orderId: ASSIGNED_ORDER,
      actor: dispatcher,
      reason: 'avería',
    })

    const snapshot = await repository.load('ready')
    const order = snapshot.orders.find((item) => item.id === ASSIGNED_ORDER)
    expect(order?.status).toBe('pendiente')
    expect(order?.assignment).toBeNull()
  })

  it('rechaza desasignar una orden sin asignación vigente', async () => {
    const repository = await freshRepository()
    await expect(
      repository.unassignOrder({ orderId: PENDING_ORDER, actor: dispatcher }),
    ).rejects.toThrow(/no tiene una asignación vigente/)
  })
})

describe('repositorio demo · estados', () => {
  it('permite al técnico pasar de asignada a en_proceso', async () => {
    const repository = await freshRepository()
    await repository.updateStatus({
      update: { orderId: ASSIGNED_ORDER, status: 'en_proceso' },
      actor: technician,
    })
    const snapshot = await repository.load('ready')
    expect(snapshot.orders.find((item) => item.id === ASSIGNED_ORDER)?.status).toBe(
      'en_proceso',
    )
  })

  it('bloquea transiciones no permitidas al técnico', async () => {
    const repository = await freshRepository()
    await expect(
      repository.updateStatus({
        update: { orderId: ASSIGNED_ORDER, status: 'ejecutada' },
        actor: technician,
      }),
    ).rejects.toThrow(/Transición no permitida/)
  })

  it('exige motivo para imposibilitada', async () => {
    const repository = await freshRepository()
    await expect(
      repository.updateStatus({
        update: { orderId: IN_PROGRESS_ORDER, status: 'imposibilitada' },
        actor: technician,
      }),
    ).rejects.toThrow(/requiere un motivo/)
  })

  it('registra el historial al cambiar de estado', async () => {
    const repository = await freshRepository()
    await repository.updateStatus({
      update: { orderId: IN_PROGRESS_ORDER, status: 'ejecutada' },
      actor: technician,
    })
    const snapshot = await repository.load('ready')
    const latest = snapshot.history
      .filter((entry) => entry.workOrderId === IN_PROGRESS_ORDER)
      .sort(
        (a, b) => new Date(b.changedAt).getTime() - new Date(a.changedAt).getTime(),
      )[0]
    expect(latest?.toStatus).toBe('ejecutada')
    expect(latest?.changedBy).toBe(technician.id)
  })

  it('rechaza al coordinador cualquier cambio de estado', async () => {
    const repository = await freshRepository()
    await expect(
      repository.updateStatus({
        update: { orderId: IN_PROGRESS_ORDER, status: 'ejecutada' },
        actor: coordinator,
      }),
    ).rejects.toThrow(/solo tiene acceso de lectura/)
  })
})

describe('repositorio demo · evidencias', () => {
  it('registra la evidencia como demo local, sin subirla', async () => {
    const repository = await freshRepository()
    const file = new File([new Uint8Array([1, 2, 3])], 'foto prueba.jpg', {
      type: 'image/jpeg',
    })

    await repository.addEvidence({
      orderId: ASSIGNED_ORDER,
      kind: 'antes',
      file,
      actor: technician,
    })

    const snapshot = await repository.load('ready')
    const order = snapshot.orders.find((item) => item.id === ASSIGNED_ORDER)
    const evidence = order?.evidence[0]
    expect(evidence?.kind).toBe('antes')
    expect(evidence?.storageBucket).toBe('work-order-evidence')
    expect(evidence?.storagePath.startsWith(`${ASSIGNED_ORDER}/`)).toBe(true)
    expect(evidence?.metadata.uploaded).toBe(false)
  })

  it('rechaza archivos que superan el límite del bucket', async () => {
    const repository = await freshRepository()
    const big = new File([new Uint8Array(10 * 1024 * 1024 + 1)], 'grande.jpg', {
      type: 'image/jpeg',
    })

    await expect(
      repository.addEvidence({
        orderId: ASSIGNED_ORDER,
        kind: 'durante',
        file: big,
        actor: technician,
      }),
    ).rejects.toThrow(/10 MiB/)
  })
})

describe('repositorio demo · escenarios', () => {
  it('devuelve un conjunto vacío en el escenario empty', async () => {
    const repository = await freshRepository()
    const snapshot = await repository.load('empty')
    expect(snapshot.orders).toHaveLength(0)
  })

  it('falla con mensaje claro en el escenario error', async () => {
    const repository = await freshRepository()
    await expect(repository.load('error')).rejects.toThrow(/jornada demo/)
  })
})
