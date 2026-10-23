import type { PostgrestError } from '@supabase/supabase-js'

/**
 * Traducción de errores de PostgREST / PostgreSQL a mensajes accionables.
 *
 * No se oculta nada: el mensaje original se conserva en el detalle, pero la
 * UI muestra una explicación comprensible y el usuario sabe si fue permiso,
 * validación o dato inexistente.
 */

const SQLSTATE_MESSAGES: Record<string, string> = {
  '42501': 'No tienes permiso para esta acción (lo aplica la base de datos).',
  '23514': 'La operación no cumple una regla del sistema.',
  '22023': 'Alguno de los datos enviados no es válido.',
  P0002: 'El registro ya no existe o fue eliminado.',
  '42P01': 'Falta un objeto en la base de datos. Avisa al administrador.',
  '23503': 'El registro referenciado no existe.',
  '23505': 'El registro ya existe.',
  PGRST116: 'No se encontró el registro esperado.',
  PGRST301: 'Tu sesión expiró. Vuelve a iniciar sesión.',
}

export class RepositoryError extends Error {
  readonly code: string | null
  readonly action: string
  readonly detail: string | null

  constructor(input: {
    action: string
    code?: string | null
    message: string
    detail?: string | null
  }) {
    super(input.message)
    this.name = 'RepositoryError'
    this.action = input.action
    this.code = input.code ?? null
    this.detail = input.detail ?? null
  }
}

function isPostgrestError(error: unknown): error is PostgrestError {
  return (
    typeof error === 'object' &&
    error !== null &&
    'message' in error &&
    typeof (error as { message: unknown }).message === 'string'
  )
}

export function toRepositoryError(error: unknown, action: string): RepositoryError {
  if (error instanceof RepositoryError) return error

  if (isPostgrestError(error)) {
    const code = error.code ?? null
    const base = code ? SQLSTATE_MESSAGES[code] : undefined
    const detail = [error.details, error.hint].filter(Boolean).join(' · ') || null

    // Los mensajes de las RPC ya son descriptivos en español; se prefieren
    // cuando aportan más contexto que el texto genérico.
    const message =
      base ?? error.message ?? 'La operación no se pudo completar.'

    return new RepositoryError({
      action,
      code,
      message: base && error.message ? `${base} (${error.message})` : message,
      detail,
    })
  }

  if (error instanceof Error) {
    return new RepositoryError({ action, message: error.message })
  }

  return new RepositoryError({
    action,
    message: 'Error desconocido al comunicarse con la base de datos.',
  })
}
