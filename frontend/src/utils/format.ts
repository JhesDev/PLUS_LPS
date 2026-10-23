const DATE_TIME = new Intl.DateTimeFormat('es-PE', {
  day: '2-digit',
  month: 'short',
  year: 'numeric',
  hour: '2-digit',
  minute: '2-digit',
})

const DATE_ONLY = new Intl.DateTimeFormat('es-PE', {
  day: '2-digit',
  month: 'short',
  year: 'numeric',
})

const TIME_ONLY = new Intl.DateTimeFormat('es-PE', {
  hour: '2-digit',
  minute: '2-digit',
})

const DAY_LABEL = new Intl.DateTimeFormat('es-PE', {
  weekday: 'long',
  day: '2-digit',
  month: 'long',
})

function parse(value: string | null | undefined): Date | null {
  if (!value) return null
  const date = new Date(value)
  return Number.isNaN(date.getTime()) ? null : date
}

export function formatDateTime(value: string | null | undefined): string {
  const date = parse(value)
  return date ? DATE_TIME.format(date) : '—'
}

export function formatDate(value: string | null | undefined): string {
  const date = parse(value)
  return date ? DATE_ONLY.format(date) : '—'
}

export function formatTime(value: string | null | undefined): string {
  const date = parse(value)
  return date ? TIME_ONLY.format(date) : '—'
}

export function formatLongDay(value: Date = new Date()): string {
  const label = DAY_LABEL.format(value)
  return label.charAt(0).toUpperCase() + label.slice(1)
}

export function formatRelative(value: string | null | undefined): string {
  const date = parse(value)
  if (!date) return '—'

  const diffMs = Date.now() - date.getTime()
  const diffMinutes = Math.round(diffMs / 60000)
  const formatter = new Intl.RelativeTimeFormat('es-PE', { numeric: 'auto' })

  if (Math.abs(diffMinutes) < 60) return formatter.format(-diffMinutes, 'minute')
  const diffHours = Math.round(diffMinutes / 60)
  if (Math.abs(diffHours) < 48) return formatter.format(-diffHours, 'hour')
  return formatter.format(-Math.round(diffHours / 24), 'day')
}

export function formatRange(
  from: string | null | undefined,
  to: string | null | undefined,
): string {
  if (!from && !to) return 'Sin ventana horaria'
  const start = from ? formatTime(from) : '—'
  const end = to ? formatTime(to) : '—'
  return `${start} – ${end}`
}

export function formatBytes(bytes: number | null | undefined): string {
  if (!bytes) return '—'
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(0)} KB`
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
}

export function initials(name: string | null | undefined): string {
  if (!name) return '—'
  return name
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map((part) => part.charAt(0).toUpperCase())
    .join('')
}

export function formatNumber(value: number): string {
  return new Intl.NumberFormat('es-PE').format(value)
}

export function toDateInputValue(date: Date): string {
  const year = date.getFullYear()
  const month = `${date.getMonth() + 1}`.padStart(2, '0')
  const day = `${date.getDate()}`.padStart(2, '0')
  return `${year}-${month}-${day}`
}
