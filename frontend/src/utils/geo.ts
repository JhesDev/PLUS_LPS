import type { Coordinates } from '@/types/domain'

const EARTH_RADIUS_METERS = 6_371_000

export function haversineMeters(a: Coordinates, b: Coordinates): number {
  const toRad = (value: number) => (value * Math.PI) / 180
  const dLat = toRad(b.latitude - a.latitude)
  const dLon = toRad(b.longitude - a.longitude)
  const lat1 = toRad(a.latitude)
  const lat2 = toRad(b.latitude)

  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) ** 2

  return 2 * EARTH_RADIUS_METERS * Math.asin(Math.min(1, Math.sqrt(h)))
}

export function formatDistance(meters: number): string {
  if (!Number.isFinite(meters)) return '—'
  if (meters < 1000) return `${Math.round(meters)} m`
  return `${(meters / 1000).toFixed(1)} km`
}

/**
 * Ray casting sobre coordenadas [lng, lat]. El polígono se cierra
 * implícitamente. Un punto en el borde puede quedar dentro o fuera.
 */
export function pointInPolygon(
  point: [number, number],
  polygon: Array<[number, number]>,
): boolean {
  if (polygon.length < 3) return false

  const [x, y] = point
  let inside = false

  for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    const [xi, yi] = polygon[i]
    const [xj, yj] = polygon[j]
    const intersects =
      yi > y !== yj > y &&
      x < ((xj - xi) * (y - yi)) / (yj - yi || Number.EPSILON) + xi
    if (intersects) inside = !inside
  }

  return inside
}

export function pointsToLngLat(points: Coordinates[]): Array<[number, number]> {
  return points.map((point) => [point.longitude, point.latitude])
}

export function centroid(points: Coordinates[]): Coordinates | null {
  if (!points.length) return null
  const total = points.reduce(
    (acc, point) => ({
      latitude: acc.latitude + point.latitude,
      longitude: acc.longitude + point.longitude,
    }),
    { latitude: 0, longitude: 0 },
  )
  return {
    latitude: total.latitude / points.length,
    longitude: total.longitude / points.length,
  }
}

export function groupBy<T, K extends string>(
  items: T[],
  key: (item: T) => K | null,
): Record<K, T[]> {
  return items.reduce(
    (acc, item) => {
      const k = key(item)
      if (k) {
        acc[k] = acc[k] ?? []
        acc[k].push(item)
      }
      return acc
    },
    {} as Record<K, T[]>,
  )
}
