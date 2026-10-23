import type { AppRole } from '@/types/domain'

export interface MapProviderInfo {
  /** Estilo vectorial completo (tiene prioridad si está definido). */
  styleUrl: string | null
  /** Plantilla ráster para el estilo generado por defecto. */
  tilesUrl: string
  attribution: string
  /** Plantilla de glifos para etiquetas de cluster/paradas. */
  glyphsUrl: string | null
  documented: boolean
}

/**
 * Configuración de proveedores del mapa base.
 *
 * Decisión documentada en `frontend/README.md`: el boceto usa tiles ráster de
 * OpenStreetMap y glifos de MapLibre demotiles **solo para desarrollo**. No se
 * integra ningún servicio de geocodificación ni de cálculo de rutas.
 */
export function resolveMapProvider(): MapProviderInfo {
  const env = import.meta.env
  const styleUrl = env.VITE_MAP_STYLE_URL?.trim() || null
  const tilesUrl =
    env.VITE_MAP_TILES_URL?.trim() ||
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
  const attribution =
    env.VITE_MAP_ATTRIBUTION?.trim() || '© OpenStreetMap contributors'
  const glyphsUrl =
    env.VITE_MAP_GLYPHS_URL === undefined
      ? 'https://demotiles.maplibre.org/font/{fontstack}/{range}.pbf'
      : env.VITE_MAP_GLYPHS_URL.trim() || null

  return { styleUrl, tilesUrl, attribution, glyphsUrl, documented: true }
}

export interface RoleNavItem {
  role: AppRole
  label: string
  path: string
  description: string
}

/** Cada rol tiene una única superficie principal en el boceto. */
export const ROLE_NAV: RoleNavItem[] = [
  {
    role: 'coordinador',
    label: 'Coordinación',
    path: '/coordinacion',
    description: 'Mapa, métricas y auditoría en modo lectura.',
  },
  {
    role: 'despachador',
    label: 'Despacho',
    path: '/despacho',
    description: 'Asignación y gestión operativa en el mapa.',
  },
  {
    role: 'tecnico',
    label: 'Mi jornada',
    path: '/tecnico',
    description: 'Hoja de ruta, resultado y evidencias.',
  },
]

export function pathForRole(role: AppRole): string {
  return ROLE_NAV.find((item) => item.role === role)?.path ?? '/'
}
