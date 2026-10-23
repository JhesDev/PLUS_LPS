/**
 * Origen de datos del boceto.
 *
 * Mientras no exista contrato de endpoints de órdenes, el frontend trabaja
 * exclusivamente con datos locales de demostración derivados de
 * `database/supabase/seed.sql`. Este flag deja explícito en la UI y en el
 * código que no se está consumiendo la API real.
 */
export const USE_DEMO_DATA = true

export const DEMO_DATA_LABEL = 'Datos de demostración (seed local)'

export const DEMO_DATA_DETAIL =
  'Registros ficticios del seed de desarrollo. No provienen de SAP ni de la API del backend.'
