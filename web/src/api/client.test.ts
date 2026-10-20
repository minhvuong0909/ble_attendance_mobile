import { http, HttpResponse } from 'msw'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { server } from '@/test/server'
import { safeFilename } from '@/lib/download'
import {
  ApiError,
  apiDownload,
  apiFetch,
  clearToken,
  getToken,
  setToken,
  setUnauthorizedHandler,
} from './client'

const failure = (p: Promise<unknown>) =>
  p.then(
    () => {
      throw new Error('expected the request to fail')
    },
    (e: unknown) => e as ApiError,
  )

const url = (p: string) => `${window.location.origin}${p}`

describe('apiFetch', () => {
  beforeEach(() => {
    clearToken()
    setUnauthorizedHandler(null)
  })

  it('sends the bearer token and JSON body, returns parsed JSON', async () => {
    setToken('abc')
    let seen: { auth: string | null; body: unknown } | null = null
    server.use(
      http.post(url('/x'), async ({ request }) => {
        seen = { auth: request.headers.get('authorization'), body: await request.json() }
        return HttpResponse.json({ ok: 1 })
      }),
    )
    const out = await apiFetch<{ ok: number }>('/x', { method: 'POST', json: { a: 1 } })
    expect(out).toEqual({ ok: 1 })
    expect(seen).toEqual({ auth: 'Bearer abc', body: { a: 1 } })
  })

  it('serialises query parameters and skips undefined', async () => {
    let search = ''
    server.use(
      http.get(url('/q'), ({ request }) => {
        search = new URL(request.url).search
        return HttpResponse.json([])
      }),
    )
    await apiFetch('/q', { query: { a: 1, b: undefined, dry_run: true } })
    expect(search).toBe('?a=1&dry_run=true')
  })

  it('turns {detail, code} into ApiError using detail as the message', async () => {
    server.use(
      http.get(url('/e'), () => HttpResponse.json({ detail: 'Mã trùng', code: 'course_exists' }, { status: 409 })),
    )
    const err = await failure(apiFetch('/e'))
    expect(err).toBeInstanceOf(ApiError)
    expect(err.message).toBe('Mã trùng')
    expect(err.code).toBe('course_exists')
    expect(err.status).toBe(409)
  })

  it('maps validation errors (detail as a list) to a readable message', async () => {
    server.use(
      http.post(url('/v'), () =>
        HttpResponse.json({ detail: [{ loc: ['body', 'x'], msg: 'Field required' }] }, { status: 422 }),
      ),
    )
    const err = await failure(apiFetch('/v', { method: 'POST', json: {} }))
    expect(err.status).toBe(422)
    expect(err.message).toContain('Field required')
  })

  it('maps network failure to a Vietnamese ApiError', async () => {
    server.use(http.get(url('/n'), () => HttpResponse.error()))
    const err = await failure(apiFetch('/n'))
    expect(err).toBeInstanceOf(ApiError)
    expect(err.code).toBe('network')
    expect(err.message).toMatch(/kết nối/i)
  })

  it('returns undefined for 204', async () => {
    server.use(http.delete(url('/d'), () => new HttpResponse(null, { status: 204 })))
    expect(await apiFetch('/d', { method: 'DELETE' })).toBeUndefined()
  })

  it('on 401 clears the current token and calls the handler exactly once', async () => {
    setToken('t1')
    const handler = vi.fn()
    setUnauthorizedHandler(handler)
    server.use(http.get(url('/u'), () => HttpResponse.json({ detail: 'x', code: 'unauthorized' }, { status: 401 })))
    await Promise.all([apiFetch('/u').catch(() => {}), apiFetch('/u').catch(() => {})])
    expect(getToken()).toBeNull()
    expect(handler).toHaveBeenCalledTimes(1)
  })

  it('a late 401 for an old token does not log out the new session', async () => {
    setToken('old')
    const handler = vi.fn()
    setUnauthorizedHandler(handler)
    server.use(
      http.get(url('/late'), async () => {
        setToken('new') // đăng nhập lại trong lúc request cũ còn bay
        return HttpResponse.json({ detail: 'x' }, { status: 401 })
      }),
    )
    await apiFetch('/late').catch(() => {})
    expect(getToken()).toBe('new')
    expect(handler).not.toHaveBeenCalled()
  })

  it('a 401 without a token (bad login) is just an error, no handler', async () => {
    const handler = vi.fn()
    setUnauthorizedHandler(handler)
    server.use(
      http.post(url('/auth/login'), () =>
        HttpResponse.json({ detail: 'Sai mã đăng nhập hoặc mật khẩu', code: 'invalid_credentials' }, { status: 401 }),
      ),
    )
    const err = await failure(apiFetch('/auth/login', { method: 'POST', json: {} }))
    expect(err.code).toBe('invalid_credentials')
    expect(handler).not.toHaveBeenCalled()
  })
})

describe('apiDownload and safeFilename', () => {
  it('returns the blob with a safe filename from Content-Disposition', async () => {
    setToken('abc')
    server.use(
      http.get(url('/f'), () =>
        new HttpResponse('data', { headers: { 'content-disposition': 'attachment; filename="../../a b.xlsx"' } }),
      ),
    )
    const out = await apiDownload('/f', 'fallback.xlsx')
    expect(out.filename).toBe('a b.xlsx')
    expect(await out.blob.text()).toBe('data')
  })

  it('never returns a path or dot names', () => {
    expect(safeFilename('attachment; filename="C:\\tmp\\b.xlsx"', 'x')).toBe('b.xlsx')
    expect(safeFilename('attachment; filename=".."', 'fb.xlsx')).toBe('fb.xlsx')
    expect(safeFilename(null, 'fb.xlsx')).toBe('fb.xlsx')
    expect(safeFilename('attachment; filename=plain.xlsx; size=3', 'x')).toBe('plain.xlsx')
  })
})
