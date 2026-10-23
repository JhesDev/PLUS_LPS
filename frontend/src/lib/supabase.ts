import { createClient, type SupabaseClient } from '@supabase/supabase-js'

/**
 * Cliente Supabase del navegador.
 *
 * Reglas de seguridad (ver `AGENTS.md` y el plan alpha):
 * - Solo se acepta una **Publishable / anon key**. Es pública y viaja en el
 *   bundle.
 * - Nunca `service_role`, `sb_secret_*` ni un DSN de PostgreSQL.
 * - La autorización real la resuelven RLS y las RPC; esta clave no autoriza por
 *   sí sola ni sustituye a la sesión del usuario.
 */

export interface SupabaseConfig {
  url: string
  publishableKey: string
}

const FORBIDDEN_KEY_PREFIXES = ['sb_secret_', 'sbp_secret_']
const FORBIDDEN_JWT_ROLES = new Set(['service_role', 'supabase_admin'])

function readConfig(): SupabaseConfig | null {
  const url = import.meta.env.VITE_SUPABASE_URL?.trim()
  const key = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY?.trim()
  if (!url || !key) return null
  return { url, publishableKey: key }
}

/**
 * Comprueba que la clave configurada es publicable. Devuelve un mensaje de
 * error legible cuando no lo es, para no arrancar el modo conectado con una
 * credencial elevada.
 */
export function validatePublishableKey(key: string): string | null {
  const normalized = key.trim()
  if (!normalized) return 'Falta la clave publicable de Supabase.'

  if (FORBIDDEN_KEY_PREFIXES.some((prefix) => normalized.startsWith(prefix))) {
    return 'La clave configurada es secreta. Usa solo la Publishable/anon key en el navegador.'
  }

  if (normalized.startsWith('sb_publishable_')) return null

  const segments = normalized.split('.')
  if (segments.length === 3) {
    try {
      const payload = JSON.parse(
        atob(segments[1].replace(/-/g, '+').replace(/_/g, '/')),
      ) as { role?: string }
      if (payload.role && FORBIDDEN_JWT_ROLES.has(payload.role)) {
        return `La clave configurada usa el rol "${payload.role}". El navegador solo admite Publishable/anon.`
      }
      return null
    } catch {
      return 'No se pudo leer la clave de Supabase (JWT inválido).'
    }
  }

  return null
}

const config = readConfig()
const keyError = config ? validatePublishableKey(config.publishableKey) : null

/** El modo conectado solo se activa con URL + clave publicable válidas. */
export const SUPABASE_CONFIGURED = Boolean(config) && !keyError

/** Motivo por el que el modo conectado está desactivado (diagnóstico interno). */
export const SUPABASE_CONFIG_ERROR: string | null = keyError

export const supabase: SupabaseClient | null =
  SUPABASE_CONFIGURED && config
    ? createClient(config.url, config.publishableKey, {
        auth: {
          persistSession: true,
          autoRefreshToken: true,
          detectSessionInUrl: true,
        },
      })
    : null

export function requireSupabase(): SupabaseClient {
  if (!supabase) {
    throw new Error(
      SUPABASE_CONFIG_ERROR ??
        'Supabase no está configurado. Revisa VITE_SUPABASE_URL y VITE_SUPABASE_PUBLISHABLE_KEY.',
    )
  }
  return supabase
}
