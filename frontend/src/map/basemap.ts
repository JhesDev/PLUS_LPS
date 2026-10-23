import type { StyleSpecification } from 'maplibre-gl'
import type { MapProviderInfo } from '@/config/runtime'

export interface Basemap {
  style: StyleSpecification | string
  /** True cuando el estilo declara `glyphs` y se pueden usar etiquetas. */
  supportsLabels: boolean
  /** Nota de atribución a mostrar en la UI. */
  attribution: string
}

/**
 * Construye el estilo base del mapa.
 *
 * - Si existe `VITE_MAP_STYLE_URL`, se usa ese estilo vectorial y se respeta
 *   su propia configuración de glifos.
 * - Si no, se genera un estilo ráster mínimo con los tiles configurados.
 *
 * No se añaden capas de tráfico, geocodificación ni ruteo.
 */
export function buildBasemap(provider: MapProviderInfo): Basemap {
  if (provider.styleUrl) {
    return {
      style: provider.styleUrl,
      supportsLabels: true,
      attribution: provider.attribution,
    }
  }

  const style: StyleSpecification = {
    version: 8,
    sources: {
      basemap: {
        type: 'raster',
        tiles: [provider.tilesUrl],
        tileSize: 256,
        maxzoom: 19,
        attribution: provider.attribution,
      },
    },
    layers: [
      {
        id: 'basemap',
        type: 'raster',
        source: 'basemap',
        paint: { 'raster-opacity': 1 },
      },
    ],
  }

  if (provider.glyphsUrl) {
    style.glyphs = provider.glyphsUrl
  }

  return {
    style,
    supportsLabels: Boolean(provider.glyphsUrl),
    attribution: provider.attribution,
  }
}
