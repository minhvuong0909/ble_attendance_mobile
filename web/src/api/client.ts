import { safeFilename } from '@/lib/download'

const TOKEN_KEY = 'token'

export class ApiError extends Error {
  status: number
  code: string

  constructor(message: string, status: number, code: string) {
    super(message)
    this.name = 'ApiError'
    this.status = status
    this.code = code
  }
}

export function getToken(): string | null {
  try {
    return localStorage.getItem(TOKEN_KEY)
  } catch {
    return null
  }
}

export function setToken(token: string): void {
  localStorage.setItem(TOKEN_KEY, token)
}

export function clearToken(): void {
  try {
    localStorage.removeItem(TOKEN_KEY)
  } catch {
    // bỏ qua: trình duyệt chặn lưu trữ
  }
}

let unauthorizedHandler: (() => void) | null = null

/** Gọi khi token hiện tại bị server từ chối (hết hạn/thu hồi). */
export function setUnauthorizedHandler(handler: (() => void) | null): void {
  unauthorizedHandler = handler
}

export type Query = Record<string, string | number | boolean | undefined>

export interface RequestInit2 {
  method?: string
  json?: unknown
  body?: FormData
  query?: Query
}

function buildUrl(path: string, query?: Query): string {
  const url = new URL(path, window.location.origin)
  for (const [key, value] of Object.entries(query ?? {})) {
    if (value !== undefined) url.searchParams.set(key, String(value))
  }
  return url.toString()
}

function messageFromDetail(detail: unknown, fallback: string): string {
  if (typeof detail === 'string') return detail
  if (Array.isArray(detail)) {
    const parts = detail
      .map((item) => (item && typeof item === 'object' && 'msg' in item ? String((item as { msg: unknown }).msg) : ''))
      .filter(Boolean)
    if (parts.length > 0) return parts.join('; ')
  }
  return fallback
}

async function request(path: string, init: RequestInit2): Promise<Response> {
  const sentToken = getToken()
  const headers: Record<string, string> = {}
  if (sentToken) headers.Authorization = `Bearer ${sentToken}`
  let body: BodyInit | undefined
  if (init.json !== undefined) {
    headers['Content-Type'] = 'application/json'
    body = JSON.stringify(init.json)
  } else if (init.body) {
    body = init.body
  }

  let response: Response
  try {
    response = await fetch(buildUrl(path, init.query), { method: init.method ?? 'GET', headers, body })
  } catch {
    throw new ApiError('Không kết nối được máy chủ. Hãy kiểm tra mạng rồi thử lại.', 0, 'network')
  }

  if (response.ok) return response

  let detail: unknown
  let code = 'http_error'
  try {
    const data = (await response.json()) as { detail?: unknown; code?: string }
    detail = data.detail
    if (data.code) code = data.code
  } catch {
    // thân phản hồi không phải JSON
  }
  if (response.status === 401 && sentToken && getToken() === sentToken) {
    clearToken()
    unauthorizedHandler?.()
  }
  throw new ApiError(messageFromDetail(detail, `Máy chủ trả về lỗi (${response.status}).`), response.status, code)
}

export async function apiFetch<T>(path: string, init: RequestInit2 = {}): Promise<T> {
  const response = await request(path, init)
  if (response.status === 204) return undefined as T
  return (await response.json()) as T
}

export async function apiDownload(
  path: string,
  fallbackName: string,
  query?: Query,
): Promise<{ blob: Blob; filename: string }> {
  const response = await request(path, { query })
  return { blob: await response.blob(), filename: safeFilename(response.headers.get('content-disposition'), fallbackName) }
}
