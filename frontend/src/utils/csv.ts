function escapeCell(value: unknown): string {
  const text = value == null ? '' : String(value)
  const escaped = text.replace(/"/g, '""')
  return `"${escaped}"`
}

/** Exportación local (sin backend) para el modo lectura/auditoría. */
export function downloadCsv(
  filename: string,
  headers: string[],
  rows: Array<Array<string | number | null | undefined>>,
): void {
  const content = [headers, ...rows]
    .map((row) => row.map(escapeCell).join(','))
    .join('\r\n')

  // BOM para que Excel abra UTF-8 correctamente.
  const blob = new Blob([`\uFEFF${content}`], {
    type: 'text/csv;charset=utf-8;',
  })
  const url = URL.createObjectURL(blob)
  const anchor = document.createElement('a')
  anchor.href = url
  anchor.download = filename
  anchor.click()
  URL.revokeObjectURL(url)
}
