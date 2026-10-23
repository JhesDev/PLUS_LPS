import type {
  Assignment,
  Coordinates,
  Evidence,
  OperationsSnapshot,
  StatusHistoryEntry,
  Technician,
  TechnicianRoute,
  WorkOrder,
  WorkOrderStatus,
  WorkOrderType,
} from '@/types/domain'

/**
 * Datos demo derivados de `database/supabase/seed.sql`.
 *
 * - Son ficticios y viven solo en memoria.
 * - No representan una respuesta de la API real ni del servicio SAP.
 * - Las fechas se recalculan respecto del día actual para que el boceto
 *   siempre muestre una jornada operativa "de hoy".
 */

export const DEMO_COORDINATOR_ID = '11111111-1111-4111-8111-111111111111'
export const DEMO_DISPATCHER_ID = '22222222-2222-4222-8222-222222222222'

export interface DemoUserOption {
  id: string
  fullName: string
  employeeCode: string | null
  vehicleLabel: string | null
}

export const DEMO_TECHNICIANS: DemoUserOption[] = [
  {
    id: '33333333-3333-4333-8333-333333333331',
    fullName: 'Técnico Demo Uno',
    employeeCode: 'TEC-001',
    vehicleLabel: 'Moto Demo A',
  },
  {
    id: '33333333-3333-4333-8333-333333333332',
    fullName: 'Técnico Demo Dos',
    employeeCode: 'TEC-002',
    vehicleLabel: 'Camioneta Demo B',
  },
  {
    id: '33333333-3333-4333-8333-333333333333',
    fullName: 'Técnico Demo Tres',
    employeeCode: 'TEC-003',
    vehicleLabel: 'Moto Demo C',
  },
]

export const DEMO_STAFF = {
  coordinador: {
    id: DEMO_COORDINATOR_ID,
    fullName: 'Coordinador Demo',
  },
  despachador: {
    id: DEMO_DISPATCHER_ID,
    fullName: 'Despachador Demo',
  },
} as const

interface TechnicianSeed extends DemoUserOption {
  phone: string
  maxDailyOrders: number
  location: Coordinates
  locationMinutesAgo: number
}

const TECHNICIAN_SEED: TechnicianSeed[] = [
  {
    ...DEMO_TECHNICIANS[0],
    phone: '+51 900 000 011',
    maxDailyOrders: 12,
    location: { latitude: -12.12, longitude: -77.03 },
    locationMinutesAgo: 10,
  },
  {
    ...DEMO_TECHNICIANS[1],
    phone: '+51 900 000 012',
    maxDailyOrders: 8,
    location: { latitude: -12.09, longitude: -77.04 },
    locationMinutesAgo: 25,
  },
  {
    ...DEMO_TECHNICIANS[2],
    phone: '+51 900 000 013',
    maxDailyOrders: 10,
    location: { latitude: -12.145, longitude: -77.02 },
    locationMinutesAgo: 24 * 60,
  },
]

function startOfToday(now: Date): Date {
  const date = new Date(now)
  date.setHours(0, 0, 0, 0)
  return date
}

/** Fecha local en formato YYYY-MM-DD (sin desfase por zona horaria). */
function localDate(date: Date): string {
  const year = date.getFullYear()
  const month = `${date.getMonth() + 1}`.padStart(2, '0')
  const day = `${date.getDate()}`.padStart(2, '0')
  return `${year}-${month}-${day}`
}

function localDateDaysAgo(now: Date, days: number): string {
  const date = startOfToday(now)
  date.setDate(date.getDate() - days)
  return localDate(date)
}

function todayAt(now: Date, hour: number, minute = 0): string {
  const date = startOfToday(now)
  date.setHours(hour, minute, 0, 0)
  return date.toISOString()
}

function daysAgo(now: Date, days: number, hour = 0, minute = 0): string {
  const date = startOfToday(now)
  date.setDate(date.getDate() - days)
  date.setHours(hour, minute, 0, 0)
  return date.toISOString()
}

function minutesAgo(now: Date, minutes: number): string {
  return new Date(now.getTime() - minutes * 60_000).toISOString()
}

interface OrderSeed {
  id: string
  code: string
  externalSource?: string | null
  externalId?: string | null
  type: WorkOrderType
  status: WorkOrderStatus
  priority: number
  customerName: string
  supplyNumber: string
  address: string
  district: string
  zone: string
  location: Coordinates | null
  scheduledAt: string | null
  dueAt: string | null
  notes?: string | null
  cancellationReason?: string | null
  completedAt?: string | null
  createdAt: string
  updatedAt: string
  assignment?: Assignment | null
  evidence?: Evidence[]
}

interface AssignmentSeed {
  id: string
  workOrderId: string
  technicianId: string
  assignedAt: string
  unassignedAt?: string | null
  endReason?: string | null
  notes?: string | null
}

export function createDemoSnapshot(now: Date = new Date()): OperationsSnapshot {
  const assignmentSeeds: AssignmentSeed[] = [
    {
      id: 'cccccccc-cccc-4ccc-8ccc-000000000005',
      workOrderId: 'aaaaaaaa-aaaa-4aaa-8aaa-000000000005',
      technicianId: DEMO_TECHNICIANS[0].id,
      assignedAt: minutesAgo(now, 180),
      notes: 'Asignación ficticia vigente',
    },
    {
      id: 'cccccccc-cccc-4ccc-8ccc-000000000006',
      workOrderId: 'aaaaaaaa-aaaa-4aaa-8aaa-000000000006',
      technicianId: DEMO_TECHNICIANS[1].id,
      assignedAt: minutesAgo(now, 180),
      notes: 'Asignación ficticia vigente',
    },
    {
      id: 'cccccccc-cccc-4ccc-8ccc-000000000007',
      workOrderId: 'aaaaaaaa-aaaa-4aaa-8aaa-000000000007',
      technicianId: DEMO_TECHNICIANS[0].id,
      assignedAt: minutesAgo(now, 300),
      notes: 'Asignación ficticia vigente',
    },
    {
      id: 'cccccccc-cccc-4ccc-8ccc-000000000008',
      workOrderId: 'aaaaaaaa-aaaa-4aaa-8aaa-000000000008',
      technicianId: DEMO_TECHNICIANS[1].id,
      assignedAt: minutesAgo(now, 240),
      notes: 'Asignación ficticia vigente',
    },
    {
      id: 'cccccccc-cccc-4ccc-8ccc-000000000009',
      workOrderId: 'aaaaaaaa-aaaa-4aaa-8aaa-000000000009',
      technicianId: DEMO_TECHNICIANS[2].id,
      assignedAt: daysAgo(now, 2, 8),
      unassignedAt: daysAgo(now, 1, 16),
      endReason: 'completada',
      notes: 'Asignación ficticia cerrada',
    },
    {
      id: 'cccccccc-cccc-4ccc-8ccc-000000000010',
      workOrderId: 'aaaaaaaa-aaaa-4aaa-8aaa-000000000010',
      technicianId: DEMO_TECHNICIANS[2].id,
      assignedAt: daysAgo(now, 2, 8),
      unassignedAt: daysAgo(now, 1, 16),
      endReason: 'imposibilitada',
      notes: 'Asignación ficticia cerrada',
    },
  ]

  const techById = new Map(
    TECHNICIAN_SEED.map((tech) => [tech.id, tech] as const),
  )

  const assignments: Assignment[] = assignmentSeeds.map((seed) => ({
    id: seed.id,
    workOrderId: seed.workOrderId,
    technicianId: seed.technicianId,
    technicianName: techById.get(seed.technicianId)?.fullName ?? 'Técnico demo',
    assignedBy: DEMO_DISPATCHER_ID,
    assignedAt: seed.assignedAt,
    unassignedAt: seed.unassignedAt ?? null,
    unassignedBy: seed.unassignedAt ? DEMO_DISPATCHER_ID : null,
    endReason: seed.endReason ?? null,
    notes: seed.notes ?? null,
  }))

  const activeAssignmentByOrder = new Map(
    assignments
      .filter((assignment) => !assignment.unassignedAt)
      .map((assignment) => [assignment.workOrderId, assignment] as const),
  )

  const evidence: Evidence[] = [
    {
      id: 'ffffffff-ffff-4fff-8fff-000000000001',
      workOrderId: 'aaaaaaaa-aaaa-4aaa-8aaa-000000000009',
      assignmentId: 'cccccccc-cccc-4ccc-8ccc-000000000009',
      kind: 'despues',
      storageBucket: 'work-order-evidence',
      storagePath:
        'aaaaaaaa-aaaa-4aaa-8aaa-000000000009/despues-1.jpg',
      mimeType: 'image/jpeg',
      sizeBytes: 204_800,
      capturedAt: daysAgo(now, 1, 15),
      uploadedBy: DEMO_TECHNICIANS[2].id,
      metadata: { demo: true },
    },
    {
      id: 'ffffffff-ffff-4fff-8fff-000000000002',
      workOrderId: 'aaaaaaaa-aaaa-4aaa-8aaa-000000000009',
      assignmentId: 'cccccccc-cccc-4ccc-8ccc-000000000009',
      kind: 'firma',
      storageBucket: 'work-order-evidence',
      storagePath: 'aaaaaaaa-aaaa-4aaa-8aaa-000000000009/firma.png',
      mimeType: 'image/png',
      sizeBytes: 51_200,
      capturedAt: daysAgo(now, 1, 15),
      uploadedBy: DEMO_TECHNICIANS[2].id,
      metadata: { demo: true },
    },
    {
      id: 'ffffffff-ffff-4fff-8fff-000000000003',
      workOrderId: 'aaaaaaaa-aaaa-4aaa-8aaa-000000000010',
      assignmentId: 'cccccccc-cccc-4ccc-8ccc-000000000010',
      kind: 'antes',
      storageBucket: 'work-order-evidence',
      storagePath: 'aaaaaaaa-aaaa-4aaa-8aaa-000000000010/antes-1.jpg',
      mimeType: 'image/jpeg',
      sizeBytes: 102_400,
      capturedAt: daysAgo(now, 1, 12),
      uploadedBy: DEMO_TECHNICIANS[2].id,
      metadata: { demo: true },
    },
  ]

  const evidenceByOrder = new Map<string, Evidence[]>()
  for (const item of evidence) {
    evidenceByOrder.set(item.workOrderId, [
      ...(evidenceByOrder.get(item.workOrderId) ?? []),
      item,
    ])
  }

  const orderSeeds: OrderSeed[] = [
    {
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-000000000001',
      code: 'WO-2026-0001',
      externalSource: 'sap',
      externalId: 'DEMO-EXT-0001',
      type: 'corte',
      status: 'pendiente',
      priority: 2,
      customerName: 'Cliente Ficticio 01',
      supplyNumber: 'SUM-000001',
      address: 'Av. Demo 100, Miraflores',
      district: 'Miraflores',
      zone: 'Zona Costa Verde',
      location: { latitude: -12.1219, longitude: -77.0297 },
      scheduledAt: todayAt(now, 9),
      dueAt: todayAt(now, 18),
      notes: 'Orden ficticia para pruebas de mapa.',
      createdAt: daysAgo(now, 2, 8),
      updatedAt: minutesAgo(now, 90),
    },
    {
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-000000000002',
      code: 'WO-2026-0002',
      type: 'reposicion',
      status: 'pendiente',
      priority: 3,
      customerName: 'Cliente Ficticio 02',
      supplyNumber: 'SUM-000002',
      address: 'Calle Demo 201, San Isidro',
      district: 'San Isidro',
      zone: 'Zona Centro',
      location: { latitude: -12.0972, longitude: -77.0365 },
      scheduledAt: todayAt(now, 10),
      dueAt: todayAt(now, 19),
      notes: 'Orden ficticia para pruebas de asignación.',
      createdAt: daysAgo(now, 2, 8),
      updatedAt: minutesAgo(now, 80),
    },
    {
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-000000000003',
      code: 'WO-2026-0003',
      type: 'inspeccion',
      status: 'pendiente',
      priority: 4,
      customerName: 'Cliente Ficticio 03',
      supplyNumber: 'SUM-000003',
      address: 'Av. Demo 302, Santiago de Surco',
      district: 'Santiago de Surco',
      zone: 'Zona Sur',
      location: { latitude: -12.145, longitude: -76.995 },
      scheduledAt: todayAt(now, 11),
      dueAt: todayAt(now, 20),
      notes: 'Inspección ficticia.',
      createdAt: daysAgo(now, 2, 8),
      updatedAt: minutesAgo(now, 70),
    },
    {
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-000000000004',
      code: 'WO-2026-0004',
      type: 'reconexion',
      status: 'pendiente',
      priority: 5,
      customerName: 'Cliente Ficticio 04',
      supplyNumber: 'SUM-000004',
      address: 'Jr. Demo 403, La Victoria',
      district: 'La Victoria',
      zone: 'Zona Centro',
      location: { latitude: -12.065, longitude: -77.025 },
      scheduledAt: todayAt(now, 12),
      dueAt: todayAt(now, 21),
      notes: 'Reconexión ficticia.',
      createdAt: daysAgo(now, 2, 8),
      updatedAt: minutesAgo(now, 60),
    },
    {
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-000000000005',
      code: 'WO-2026-0005',
      type: 'corte',
      status: 'asignada',
      priority: 1,
      customerName: 'Cliente Ficticio 05',
      supplyNumber: 'SUM-000005',
      address: 'Av. Demo 504, Callao',
      district: 'Callao',
      zone: 'Zona Callao',
      location: { latitude: -12.0566, longitude: -77.1181 },
      scheduledAt: todayAt(now, 8),
      dueAt: todayAt(now, 14),
      notes: 'Corte ficticio prioritario.',
      createdAt: daysAgo(now, 2, 8),
      updatedAt: minutesAgo(now, 180),
    },
    {
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-000000000006',
      code: 'WO-2026-0006',
      type: 'mantenimiento',
      status: 'asignada',
      priority: 3,
      customerName: 'Cliente Ficticio 06',
      supplyNumber: 'SUM-000006',
      address: 'Calle Demo 605, San Miguel',
      district: 'San Miguel',
      zone: 'Zona Costa Verde',
      location: { latitude: -12.077, longitude: -77.083 },
      scheduledAt: todayAt(now, 13),
      dueAt: todayAt(now, 20),
      notes: 'Mantenimiento ficticio.',
      createdAt: daysAgo(now, 2, 8),
      updatedAt: minutesAgo(now, 180),
    },
    {
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-000000000007',
      code: 'WO-2026-0007',
      type: 'reposicion',
      status: 'en_proceso',
      priority: 2,
      customerName: 'Cliente Ficticio 07',
      supplyNumber: 'SUM-000007',
      address: 'Av. Demo 706, Jesús María',
      district: 'Jesús María',
      zone: 'Zona Centro',
      location: { latitude: -12.074, longitude: -77.045 },
      scheduledAt: todayAt(now, 8),
      dueAt: todayAt(now, 16),
      notes: 'Reposición ficticia en curso.',
      createdAt: daysAgo(now, 2, 8),
      updatedAt: minutesAgo(now, 60),
    },
    {
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-000000000008',
      code: 'WO-2026-0008',
      type: 'corte',
      status: 'en_proceso',
      priority: 1,
      customerName: 'Cliente Ficticio 08',
      supplyNumber: 'SUM-000008',
      address: 'Jr. Demo 808, Lince',
      district: 'Lince',
      zone: 'Zona Centro',
      location: { latitude: -12.085, longitude: -77.035 },
      scheduledAt: todayAt(now, 9),
      dueAt: todayAt(now, 17),
      notes: 'Corte ficticio en curso.',
      createdAt: daysAgo(now, 2, 8),
      updatedAt: minutesAgo(now, 50),
    },
    {
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-000000000009',
      code: 'WO-2026-0009',
      type: 'inspeccion',
      status: 'ejecutada',
      priority: 3,
      customerName: 'Cliente Ficticio 09',
      supplyNumber: 'SUM-000009',
      address: 'Av. Demo 909, Barranco',
      district: 'Barranco',
      zone: 'Zona Sur',
      location: { latitude: -12.147, longitude: -77.02 },
      scheduledAt: daysAgo(now, 1, 8),
      dueAt: daysAgo(now, 1, 14),
      notes: 'Inspección ficticia finalizada.',
      completedAt: daysAgo(now, 1, 15),
      createdAt: daysAgo(now, 3, 8),
      updatedAt: daysAgo(now, 1, 15),
    },
    {
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-000000000010',
      code: 'WO-2026-0010',
      type: 'reconexion',
      status: 'imposibilitada',
      priority: 4,
      customerName: 'Cliente Ficticio 10',
      supplyNumber: 'SUM-000010',
      address: 'Calle Demo 1010, Ate',
      district: 'Ate',
      zone: 'Zona Este',
      location: { latitude: -12.026, longitude: -76.92 },
      scheduledAt: daysAgo(now, 1, 8),
      dueAt: daysAgo(now, 1, 16),
      notes: 'Reconexión ficticia imposibilitada.',
      completedAt: daysAgo(now, 1, 16),
      createdAt: daysAgo(now, 3, 8),
      updatedAt: daysAgo(now, 1, 16),
    },
    {
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-000000000011',
      code: 'WO-2026-0011',
      type: 'corte',
      status: 'cancelada',
      priority: 5,
      customerName: 'Cliente Ficticio 11',
      supplyNumber: 'SUM-000011',
      address: 'Av. Demo 1111, Surquillo',
      district: 'Surquillo',
      zone: 'Zona Sur',
      location: { latitude: -12.113, longitude: -77.02 },
      scheduledAt: todayAt(now, 15),
      dueAt: todayAt(now, 23),
      notes: 'Orden ficticia cancelada.',
      cancellationReason: 'Duplicado de demostración',
      createdAt: daysAgo(now, 2, 8),
      updatedAt: minutesAgo(now, 360),
    },
    {
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-000000000012',
      code: 'WO-2026-0012',
      type: 'mantenimiento',
      status: 'pendiente',
      priority: 3,
      customerName: 'Cliente Ficticio 12',
      supplyNumber: 'SUM-000012',
      address: 'Calle Demo 1212, Pueblo Libre',
      district: 'Pueblo Libre',
      zone: 'Zona Centro',
      location: null,
      scheduledAt: todayAt(now, 16),
      dueAt: todayAt(now, 23),
      notes: 'Orden ficticia SIN geocodificar (location NULL).',
      createdAt: daysAgo(now, 2, 8),
      updatedAt: minutesAgo(now, 30),
    },
  ]

  const orders: WorkOrder[] = orderSeeds.map((seed) => ({
    id: seed.id,
    code: seed.code,
    externalSource: seed.externalSource ?? null,
    externalId: seed.externalId ?? null,
    type: seed.type,
    status: seed.status,
    priority: seed.priority,
    customerName: seed.customerName,
    supplyNumber: seed.supplyNumber,
    address: seed.address,
    district: seed.district,
    zone: seed.zone,
    location: seed.location,
    scheduledAt: seed.scheduledAt,
    dueAt: seed.dueAt,
    notes: seed.notes ?? null,
    cancellationReason: seed.cancellationReason ?? null,
    completedAt: seed.completedAt ?? null,
    createdAt: seed.createdAt,
    updatedAt: seed.updatedAt,
    assignment: activeAssignmentByOrder.get(seed.id) ?? null,
    evidence: evidenceByOrder.get(seed.id) ?? [],
  }))

  const routes: TechnicianRoute[] = [
    {
      id: 'bbbbbbbb-bbbb-4bbb-8bbb-000000000001',
      code: 'RUTA-2026-0001',
      technicianId: DEMO_TECHNICIANS[0].id,
      routeDate: localDate(startOfToday(now)),
      status: 'en_curso',
      startedAt: minutesAgo(now, 60),
      completedAt: null,
      notes: 'Ruta ficticia en curso',
      stops: [
        {
          id: 'dddddddd-dddd-4ddd-8ddd-000000000001',
          routeId: 'bbbbbbbb-bbbb-4bbb-8bbb-000000000001',
          workOrderId: 'aaaaaaaa-aaaa-4aaa-8aaa-000000000005',
          stopOrder: 1,
          status: 'pendiente',
          plannedAt: todayAt(now, 9),
          arrivedAt: null,
          completedAt: null,
          notes: 'Parada ficticia 1',
        },
        {
          id: 'dddddddd-dddd-4ddd-8ddd-000000000002',
          routeId: 'bbbbbbbb-bbbb-4bbb-8bbb-000000000001',
          workOrderId: 'aaaaaaaa-aaaa-4aaa-8aaa-000000000007',
          stopOrder: 2,
          status: 'en_proceso',
          plannedAt: todayAt(now, 11),
          arrivedAt: minutesAgo(now, 30),
          completedAt: null,
          notes: 'Parada ficticia 2',
        },
      ],
    },
    {
      id: 'bbbbbbbb-bbbb-4bbb-8bbb-000000000002',
      code: 'RUTA-2026-0002',
      technicianId: DEMO_TECHNICIANS[1].id,
      routeDate: localDate(startOfToday(now)),
      status: 'planificada',
      startedAt: null,
      completedAt: null,
      notes: 'Ruta ficticia planificada',
      stops: [
        {
          id: 'dddddddd-dddd-4ddd-8ddd-000000000003',
          routeId: 'bbbbbbbb-bbbb-4bbb-8bbb-000000000002',
          workOrderId: 'aaaaaaaa-aaaa-4aaa-8aaa-000000000006',
          stopOrder: 1,
          status: 'pendiente',
          plannedAt: todayAt(now, 13),
          arrivedAt: null,
          completedAt: null,
          notes: 'Parada ficticia 3',
        },
        {
          id: 'dddddddd-dddd-4ddd-8ddd-000000000004',
          routeId: 'bbbbbbbb-bbbb-4bbb-8bbb-000000000002',
          workOrderId: 'aaaaaaaa-aaaa-4aaa-8aaa-000000000008',
          stopOrder: 2,
          status: 'pendiente',
          plannedAt: todayAt(now, 15),
          arrivedAt: null,
          completedAt: null,
          notes: 'Parada ficticia 4',
        },
      ],
    },
    {
      id: 'bbbbbbbb-bbbb-4bbb-8bbb-000000000003',
      code: 'RUTA-2026-0003',
      technicianId: DEMO_TECHNICIANS[2].id,
      routeDate: localDateDaysAgo(now, 1),
      status: 'completada',
      startedAt: daysAgo(now, 1, 8),
      completedAt: daysAgo(now, 1, 17),
      notes: 'Ruta ficticia histórica',
      stops: [
        {
          id: 'dddddddd-dddd-4ddd-8ddd-000000000005',
          routeId: 'bbbbbbbb-bbbb-4bbb-8bbb-000000000003',
          workOrderId: 'aaaaaaaa-aaaa-4aaa-8aaa-000000000009',
          stopOrder: 1,
          status: 'completada',
          plannedAt: daysAgo(now, 1, 8),
          arrivedAt: daysAgo(now, 1, 9),
          completedAt: daysAgo(now, 1, 10),
          notes: 'Parada ficticia 5',
        },
        {
          id: 'dddddddd-dddd-4ddd-8ddd-000000000006',
          routeId: 'bbbbbbbb-bbbb-4bbb-8bbb-000000000003',
          workOrderId: 'aaaaaaaa-aaaa-4aaa-8aaa-000000000010',
          stopOrder: 2,
          status: 'omitida',
          plannedAt: daysAgo(now, 1, 10),
          arrivedAt: daysAgo(now, 1, 11),
          completedAt: daysAgo(now, 1, 11),
          notes: 'Parada ficticia 6',
        },
      ],
    },
  ]

  const history: StatusHistoryEntry[] = [
    historyEntry(1, now, 'aaaaaaaa-aaaa-4aaa-8aaa-000000000005', 'WO-2026-0005', null, 'pendiente', DEMO_DISPATCHER_ID, 'Despachador Demo', 3, 0, 'Alta ficticia'),
    historyEntry(2, now, 'aaaaaaaa-aaaa-4aaa-8aaa-000000000005', 'WO-2026-0005', 'pendiente', 'asignada', DEMO_DISPATCHER_ID, 'Despachador Demo', 3, 0, 'Asignación ficticia'),
    historyEntry(3, now, 'aaaaaaaa-aaaa-4aaa-8aaa-000000000007', 'WO-2026-0007', null, 'pendiente', DEMO_DISPATCHER_ID, 'Despachador Demo', 5, 0, 'Alta ficticia'),
    historyEntry(4, now, 'aaaaaaaa-aaaa-4aaa-8aaa-000000000007', 'WO-2026-0007', 'pendiente', 'asignada', DEMO_DISPATCHER_ID, 'Despachador Demo', 5, 0, 'Asignación ficticia'),
    historyEntry(5, now, 'aaaaaaaa-aaaa-4aaa-8aaa-000000000007', 'WO-2026-0007', 'asignada', 'en_proceso', DEMO_TECHNICIANS[0].id, DEMO_TECHNICIANS[0].fullName, 1, 0, 'Inicio ficticio de trabajo'),
    historyEntry(6, now, 'aaaaaaaa-aaaa-4aaa-8aaa-000000000009', 'WO-2026-0009', null, 'pendiente', DEMO_DISPATCHER_ID, 'Despachador Demo', 48, 0, 'Alta ficticia'),
    historyEntry(7, now, 'aaaaaaaa-aaaa-4aaa-8aaa-000000000009', 'WO-2026-0009', 'pendiente', 'asignada', DEMO_DISPATCHER_ID, 'Despachador Demo', 48, 0, 'Asignación ficticia'),
    historyEntry(8, now, 'aaaaaaaa-aaaa-4aaa-8aaa-000000000009', 'WO-2026-0009', 'asignada', 'en_proceso', DEMO_TECHNICIANS[2].id, DEMO_TECHNICIANS[2].fullName, 28, 0, 'Inicio ficticio'),
    historyEntry(9, now, 'aaaaaaaa-aaaa-4aaa-8aaa-000000000009', 'WO-2026-0009', 'en_proceso', 'ejecutada', DEMO_TECHNICIANS[2].id, DEMO_TECHNICIANS[2].fullName, 24, 0, 'Trabajo ficticio ejecutado'),
    historyEntry(10, now, 'aaaaaaaa-aaaa-4aaa-8aaa-000000000010', 'WO-2026-0010', null, 'pendiente', DEMO_DISPATCHER_ID, 'Despachador Demo', 48, 0, 'Alta ficticia'),
    historyEntry(11, now, 'aaaaaaaa-aaaa-4aaa-8aaa-000000000010', 'WO-2026-0010', 'pendiente', 'asignada', DEMO_DISPATCHER_ID, 'Despachador Demo', 48, 0, 'Asignación ficticia'),
    historyEntry(12, now, 'aaaaaaaa-aaaa-4aaa-8aaa-000000000010', 'WO-2026-0010', 'asignada', 'en_proceso', DEMO_TECHNICIANS[2].id, DEMO_TECHNICIANS[2].fullName, 28, 0, 'Inicio ficticio'),
    historyEntry(13, now, 'aaaaaaaa-aaaa-4aaa-8aaa-000000000010', 'WO-2026-0010', 'en_proceso', 'imposibilitada', DEMO_TECHNICIANS[2].id, DEMO_TECHNICIANS[2].fullName, 24, 0, 'Acceso ficticio bloqueado'),
    historyEntry(14, now, 'aaaaaaaa-aaaa-4aaa-8aaa-000000000011', 'WO-2026-0011', 'pendiente', 'cancelada', DEMO_DISPATCHER_ID, 'Despachador Demo', 6, 0, 'Duplicado ficticio'),
  ]

  const technicians = buildTechnicians(orders, now)

  return {
    orders,
    technicians,
    routes,
    assignments,
    history,
    source: 'demo-seed',
    loadedAt: now.toISOString(),
  }
}

/** Recalcula la carga de los técnicos tras un cambio local (demo). */
export function refreshTechnicianWorkload(
  orders: WorkOrder[],
  technicians: Technician[],
): Technician[] {
  return technicians.map((technician) => {
    const active = orders.filter(
      (order) =>
        order.assignment?.technicianId === technician.id &&
        ['asignada', 'en_proceso'].includes(order.status),
    )
    return {
      ...technician,
      activeOrders: active.length,
      assignedOrders: active.filter((order) => order.status === 'asignada')
        .length,
      inProgressOrders: active.filter((order) => order.status === 'en_proceso')
        .length,
    }
  })
}

function historyEntry(
  index: number,
  now: Date,
  workOrderId: string,
  orderCode: string,
  fromStatus: WorkOrderStatus | null,
  toStatus: WorkOrderStatus,
  changedBy: string | null,
  changedByName: string | null,
  hoursAgo: number,
  minutesAgoValue: number,
  reason: string,
): StatusHistoryEntry {
  return {
    id: `history-demo-${index}`,
    workOrderId,
    orderCode,
    fromStatus,
    toStatus,
    changedBy,
    changedByName,
    changedAt: new Date(
      now.getTime() - hoursAgo * 3_600_000 - minutesAgoValue * 60_000,
    ).toISOString(),
    reason,
    location: null,
  }
}

function buildTechnicians(orders: WorkOrder[], now: Date): Technician[] {
  return TECHNICIAN_SEED.map((seed) => {
    const active = orders.filter(
      (order) =>
        order.assignment?.technicianId === seed.id &&
        ['asignada', 'en_proceso'].includes(order.status),
    )
    const assigned = active.filter((order) => order.status === 'asignada').length
    const inProgress = active.filter((order) => order.status === 'en_proceso').length

    return {
      id: seed.id,
      fullName: seed.fullName,
      phone: seed.phone,
      employeeCode: seed.employeeCode,
      vehicleLabel: seed.vehicleLabel,
      maxDailyOrders: seed.maxDailyOrders,
      location: seed.location,
      locationUpdatedAt: minutesAgo(now, seed.locationMinutesAgo),
      activeOrders: active.length,
      assignedOrders: assigned,
      inProgressOrders: inProgress,
    }
  })
}
