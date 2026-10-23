import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import { DEMO_DISPATCHER_ID, DEMO_TECHNICIANS } from '@/data/demoSeed'
import { DATA_MODE } from '@/config/dataSource'
import { SUPABASE_CONFIG_ERROR, supabase } from '@/lib/supabase'
import { RepositoryError, toRepositoryError } from '@/services/supabase/errors'
import type { Actor, AppRole, DataMode } from '@/types/domain'

const STORAGE_KEY = 'plus-lps.demo.actor'

export interface DemoUser extends Actor {
  employeeCode: string | null
  vehicleLabel: string | null
}

export type SessionStatus =
  | 'loading'
  | 'anonymous'
  | 'authenticated'
  | 'error'
  | 'demo'

/**
 * Usuarios ficticios disponibles **solo** en modo demo.
 *
 * El rol nunca se toma de aquí cuando hay Supabase configurado: se lee de
 * `public.profiles`, que es la fuente de verdad.
 */
export const DEMO_USERS: DemoUser[] = [
  {
    id: '11111111-1111-4111-8111-111111111111',
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

const KNOWN_ROLES: AppRole[] = ['coordinador', 'despachador', 'tecnico']
const EMPTY_ACTOR: Actor = { id: '', name: 'Sin sesión', role: 'tecnico' }

function initialDemoUserId(): string {
  try {
    const stored = globalThis.localStorage?.getItem(STORAGE_KEY)
    return DEMO_USERS.some((user) => user.id === stored)
      ? (stored as string)
      : DEMO_DISPATCHER_ID
  } catch {
    return DEMO_DISPATCHER_ID
  }
}

interface ProfileRow {
  id: string
  role: string
  full_name: string
  is_active: boolean
}

export const useSessionStore = defineStore('session', () => {
  const mode = ref<DataMode>(DATA_MODE)
  const status = ref<SessionStatus>('loading')
  const actor = ref<Actor>(EMPTY_ACTOR)
  const email = ref<string | null>(null)
  const errorMessage = ref<string | null>(null)
  const demoUserId = ref<string>(initialDemoUserId())
  const scenario = ref<'ready' | 'empty' | 'error' | 'slow'>('ready')

  const isConnected = computed(() => mode.value === 'connected')
  const isDemo = computed(() => mode.value === 'demo')
  const role = computed<AppRole | null>(() =>
    status.value === 'authenticated' || status.value === 'demo'
      ? actor.value.role
      : null,
  )
  const actorId = computed(() =>
    status.value === 'authenticated' || status.value === 'demo'
      ? actor.value.id
      : null,
  )
  const isReady = computed(
    () => status.value === 'authenticated' || status.value === 'demo',
  )
  const isCoordinator = computed(() => role.value === 'coordinador')
  const isDispatcher = computed(() => role.value === 'despachador')
  const isTechnician = computed(() => role.value === 'tecnico')
  const technicians = computed(() =>
    DEMO_USERS.filter((user) => user.role === 'tecnico'),
  )

  /** Lectura del usuario demo activo (solo aplica en modo demo). */
  const demoUser = computed<DemoUser>(
    () =>
      DEMO_USERS.find((user) => user.id === demoUserId.value) ?? DEMO_USERS[1],
  )

  /**
   * Actor garantizado por el guard de rutas. Si se usa sin sesión, es un error
   * de programación y se hace visible en lugar de degradar silenciosamente.
   */
  function requireActor(): Actor {
    return actor.value
  }

  function applyDemoSession(): void {
    actor.value = {
      id: demoUser.value.id,
      name: demoUser.value.name,
      role: demoUser.value.role,
    }
    email.value = null
    status.value = 'demo'
  }

  function setScenario(next: 'ready' | 'empty' | 'error' | 'slow'): void {
    scenario.value = next
  }

  function setMode(next: DataMode): void {
    mode.value = next
  }

  /** Cambia el usuario simulado. Solo tiene efecto en modo demo. */
  function setActor(id: string): void {
    if (!isDemo.value) return
    if (!DEMO_USERS.some((user) => user.id === id)) return
    demoUserId.value = id
    try {
      globalThis.localStorage?.setItem(STORAGE_KEY, id)
    } catch {
      // Preferencia local opcional.
    }
    applyDemoSession()
  }

  function setRole(next: AppRole): void {
    if (!isDemo.value) return
    const user = DEMO_USERS.find((item) => item.role === next)
    if (user) setActor(user.id)
  }

  async function loadProfile(
    userId: string,
    userEmail: string | null,
  ): Promise<boolean> {
    if (!supabase) {
      status.value = 'error'
      errorMessage.value =
        SUPABASE_CONFIG_ERROR ?? 'Supabase no está configurado.'
      return false
    }

    const { data, error } = await supabase
      .from('profiles')
      .select('id,role,full_name,is_active')
      .eq('id', userId)
      .maybeSingle<ProfileRow>()

    if (error) {
      status.value = 'error'
      errorMessage.value = toRepositoryError(error, 'leer el perfil').message
      return false
    }

    if (!data) {
      status.value = 'error'
      errorMessage.value =
        'Tu usuario no tiene perfil en la aplicación. Pide a un administrador que lo cree.'
      return false
    }

    if (!data.is_active) {
      status.value = 'error'
      errorMessage.value = 'Tu perfil está inactivo. Contacta al administrador.'
      return false
    }

    if (!KNOWN_ROLES.includes(data.role as AppRole)) {
      status.value = 'error'
      errorMessage.value = `El perfil tiene un rol no reconocido (${data.role}).`
      return false
    }

    actor.value = {
      id: data.id,
      name: data.full_name,
      role: data.role as AppRole,
    }
    email.value = userEmail
    errorMessage.value = null
    status.value = 'authenticated'
    return true
  }

  /**
   * Inicializa la sesión: en modo conectado restaura la sesión de Supabase y
   * carga el perfil; en modo demo activa el usuario simulado.
   */
  async function init(): Promise<void> {
    if (isDemo.value) {
      applyDemoSession()
      return
    }

    if (!supabase) {
      status.value = 'error'
      errorMessage.value =
        SUPABASE_CONFIG_ERROR ??
        'Falta configurar VITE_SUPABASE_URL y VITE_SUPABASE_PUBLISHABLE_KEY.'
      return
    }

    status.value = 'loading'
    const { data, error } = await supabase.auth.getSession()

    if (error) {
      status.value = 'error'
      errorMessage.value = error.message
      return
    }

    const session = data.session
    if (!session?.user) {
      actor.value = EMPTY_ACTOR
      status.value = 'anonymous'
      return
    }

    await loadProfile(session.user.id, session.user.email ?? null)
  }

  /** Escucha cambios de sesión (login, logout, refresco de token). */
  function subscribe(): void {
    if (!supabase || isDemo.value) return
    supabase.auth.onAuthStateChange((event, session) => {
      if (event === 'SIGNED_OUT' || !session?.user) {
        actor.value = EMPTY_ACTOR
        email.value = null
        status.value = 'anonymous'
        return
      }
      if (event === 'TOKEN_REFRESHED') return
      void loadProfile(session.user.id, session.user.email ?? null)
    })
  }

  async function signIn(input: {
    email: string
    password: string
  }): Promise<void> {
    if (!supabase) {
      throw new RepositoryError({
        action: 'iniciar sesión',
        message:
          SUPABASE_CONFIG_ERROR ??
          'Supabase no está configurado en este entorno.',
      })
    }

    errorMessage.value = null
    status.value = 'loading'

    const { data, error } = await supabase.auth.signInWithPassword({
      email: input.email.trim(),
      password: input.password,
    })

    if (error) {
      status.value = 'anonymous'
      const message = /invalid login credentials/i.test(error.message)
        ? 'Correo o contraseña incorrectos.'
        : /email not confirmed/i.test(error.message)
          ? 'El correo aún no está confirmado en el stack local.'
          : error.message
      throw new RepositoryError({ action: 'iniciar sesión', message })
    }

    if (!data.user) {
      status.value = 'anonymous'
      throw new RepositoryError({
        action: 'iniciar sesión',
        message: 'No se recibió el usuario autenticado.',
      })
    }

    await loadProfile(data.user.id, data.user.email ?? null).then(async (ok) => {
      if (ok) return
      // El perfil no es válido: se cierra la sesión para no dejar estado a medias.
      await supabase?.auth.signOut()
      throw new RepositoryError({
        action: 'iniciar sesión',
        message: errorMessage.value ?? 'El perfil no es válido.',
      })
    })
  }

  async function signOut(): Promise<void> {
    if (isDemo.value) {
      return
    }
    if (!supabase) return
    const { error } = await supabase.auth.signOut()
    if (error) {
      throw new RepositoryError({
        action: 'cerrar sesión',
        message: error.message,
      })
    }
    actor.value = EMPTY_ACTOR
    email.value = null
    status.value = 'anonymous'
  }

  function leaveDemo(): void {
    if (!isDemo.value) return
    actor.value = EMPTY_ACTOR
    email.value = null
    status.value = 'anonymous'
  }

  function fail(message: string): void {
    status.value = 'error'
    errorMessage.value = message
  }

  return {
    mode,
    status,
    actor,
    email,
    errorMessage,
    demoUserId,
    scenario,
    demoUser,
    isConnected,
    isDemo,
    isReady,
    isCoordinator,
    isDispatcher,
    isTechnician,
    technicians,
    role,
    actorId,
    requireActor,
    setMode,
    setActor,
    setRole,
    setScenario,
    init,
    subscribe,
    signIn,
    signOut,
    leaveDemo,
    fail,
  }
})
