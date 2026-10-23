import { defineStore } from 'pinia'
import { computed, ref, watch } from 'vue'
import { DEMO_TECHNICIANS } from '@/data/demoSeed'
import type { Actor, DemoScenario } from '@/services/operationsRepository'
import { DEMO_COORDINATOR_ID, DEMO_DISPATCHER_ID } from '@/data/demoSeed'
import type { AppRole } from '@/types/domain'

const STORAGE_KEY = 'plus-lps.demo.actor'

export interface DemoUser extends Actor {
  employeeCode: string | null
  vehicleLabel: string | null
}

/**
 * Sesión demo.
 *
 * El rol real vive en `public.profiles` y lo verifica el backend; aquí solo se
 * simula para poder recorrer las tres vistas. La UI nunca deduce permisos de
 * esta simulación como mecanismo de autorización.
 */
export const DEMO_USERS: DemoUser[] = [
  {
    id: DEMO_COORDINATOR_ID,
    name: 'Coordinador Demo',
    role: 'coordinador',
    employeeCode: null,
    vehicleLabel: null,
  },
  {
    id: DEMO_DISPATCHER_ID,
    name: 'Despachador Demo',
    role: 'despachador',
    employeeCode: null,
    vehicleLabel: null,
  },
  ...DEMO_TECHNICIANS.map((technician) => ({
    id: technician.id,
    name: technician.fullName,
    role: 'tecnico' as AppRole,
    employeeCode: technician.employeeCode,
    vehicleLabel: technician.vehicleLabel,
  })),
]

function initialActorId(): string {
  const stored = globalThis.localStorage?.getItem(STORAGE_KEY)
  return DEMO_USERS.some((user) => user.id === stored)
    ? (stored as string)
    : DEMO_DISPATCHER_ID
}

export const useSessionStore = defineStore('session', () => {
  const actorId = ref<string>(initialActorId())
  const scenario = ref<DemoScenario>('ready')

  const actor = computed<DemoUser>(
    () => DEMO_USERS.find((user) => user.id === actorId.value) ?? DEMO_USERS[1],
  )
  const role = computed<AppRole>(() => actor.value.role)
  const technicians = computed(() =>
    DEMO_USERS.filter((user) => user.role === 'tecnico'),
  )

  const isCoordinator = computed(() => role.value === 'coordinador')
  const isDispatcher = computed(() => role.value === 'despachador')
  const isTechnician = computed(() => role.value === 'tecnico')

  watch(actorId, (value) => {
    globalThis.localStorage?.setItem(STORAGE_KEY, value)
  })

  function setActor(id: string): void {
    if (DEMO_USERS.some((user) => user.id === id)) actorId.value = id
  }

  function setScenario(next: DemoScenario): void {
    scenario.value = next
  }

  function setRole(next: AppRole): void {
    const user = DEMO_USERS.find((item) => item.role === next)
    if (user) actorId.value = user.id
  }

  return {
    actorId,
    actor,
    role,
    scenario,
    technicians,
    isCoordinator,
    isDispatcher,
    isTechnician,
    setActor,
    setScenario,
    setRole,
  }
})
