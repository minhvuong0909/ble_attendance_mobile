/** Lấy tên tệp từ Content-Disposition; chỉ giữ phần tên cuối, bỏ mọi đường dẫn. */
export function safeFilename(header: string | null, fallback: string): string {
  const raw = header?.match(/filename="?([^";]+)"?/)?.[1]?.trim()
  const name = raw?.split(/[\\/]/).pop()?.trim()
  return !name || name === '.' || name === '..' ? fallback : name
}

/** Lưu blob xuống máy bằng thẻ <a download>. */
export function saveBlob(blob: Blob, filename: string): void {
  const url = URL.createObjectURL(blob)
  const anchor = document.createElement('a')
  anchor.href = url
  anchor.download = filename
  document.body.appendChild(anchor)
  anchor.click()
  anchor.remove()
  URL.revokeObjectURL(url)
}
