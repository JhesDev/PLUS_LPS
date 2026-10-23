import { SUPABASE_CONFIGURED } from '@/lib/supabase'
import type { DataMode } from '@/types/domain'

/**
 * Origen de datos de la aplicación.
 *
 * - `connected`: hay URL + Publishable key de Supabase; se leen datos reales
 *   (sujetos a RLS) y se escribe por RPC.
 * - `demo`: faltan variables públicas; se usa el conjunto ficticio del seed
 *   local, siempre señalizado en la UI.
 *
 * En ambos casos la UI lo indica de forma explícita: nunca se presentan datos
 * ficticios como si vinieran de la base real.
 */
export type { DataMode }

export const DATA_MODE: DataMode = SUPABASE_CONFIGURED ? 'connected' : 'demo'

export const IS_CONNECTED = DATA_MODE === 'connected'

/** Compatibilidad con el repositorio demo original del frontend. */
export const USE_DEMO_DATA = DATA_MODE === 'demo'

export const DEMO_DATA_LABEL = 'Datos de demostración (seed local)'

export const DEMO_DATA_DETAIL =
  'Registros ficticios del seed de desarrollo. No provienen de Supabase ni de SAP.'

export const CONNECTED_DATA_LABEL = 'Datos conectados a Supabase local'

export const CONNECTED_DATA_DETAIL =
  'Lectura y escritura sujetas a las políticas RLS y a las RPC del proyecto.'
