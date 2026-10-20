const dateTime = new Intl.DateTimeFormat('vi-VN', { dateStyle: 'short', timeStyle: 'short' })

export function formatDateTime(iso: string | null | undefined): string {
  if (!iso) return '—'
  const date = new Date(iso)
  return Number.isNaN(date.getTime()) ? '—' : dateTime.format(date)
}

export function formatPercent(value: number | null | undefined): string {
  return value == null ? '—' : `${Math.round(value * 100)}%`
}

const dateOnly = new Intl.DateTimeFormat('vi-VN', { dateStyle: 'short' })

export function formatDate(iso: string | null | undefined): string {
  if (!iso) return '—'
  const date = new Date(iso)
  return Number.isNaN(date.getTime()) ? '—' : dateOnly.format(date)
}

/** Phần trăm đã ở thang 0–100 (báo cáo của server). */
export function formatPercentValue(value: number | null | undefined): string {
  return value == null ? '—' : `${Math.round(value)}%`
}
