import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { http, HttpResponse } from 'msw'
import { describe, expect, it, vi } from 'vitest'
import { initTheme } from '@/lib/theme'
import { server } from '@/test/server'
import { signInAs, teacherUser, url } from '@/test/handlers'
import { renderApp } from '@/test/render'

vi.mock('@/lib/constants', () => ({ POLL_MS: 40, NOTIFICATION_POLL_MS: 40 }))

const note = (over: Record<string, unknown> = {}) => ({
  id: 1,
  type: 'leave_request',
  title: 'Đơn xin phép mới',
  body: 'Nguyễn Văn An xin nghỉ ngày 25/10',
  ref_id: '4',
  is_read: false,
  created_at: '2026-10-20T01:00:00Z',
  ...over,
})

function api(count: number | (() => number), list = [note()]) {
  const log = { read: [] as string[], readAll: 0 }
  server.use(
    http.get(url('/notifications/unread-count'), () => HttpResponse.json({ count: typeof count === 'function' ? count() : count })),
    http.get(url('/notifications'), () => HttpResponse.json(list)),
    http.post(url('/notifications/:id/read'), ({ params }) => {
      log.read.push(String(params.id))
      return HttpResponse.json({ message: 'ok' })
    }),
    http.post(url('/notifications/read-all'), () => {
      log.readAll++
      return HttpResponse.json({ message: 'ok' })
    }),
    http.get(url('/classes/mine'), () => HttpResponse.json([])),
  )
  return log
}

describe('notification bell', () => {
  it('shows the unread count, 99+ when large, and nothing at zero', async () => {
    signInAs(teacherUser)
    api(3)
    const first = renderApp('/teacher/classes')
    expect(await screen.findByLabelText('Thông báo (3 chưa đọc)')).toBeInTheDocument()
    first.unmount()
    api(250)
    const second = renderApp('/teacher/classes')
    expect(await screen.findByText('99+')).toBeInTheDocument()
    second.unmount()
    api(0)
    renderApp('/teacher/classes')
    expect(await screen.findByLabelText('Thông báo')).toBeInTheDocument()
    expect(screen.queryByText('0')).not.toBeInTheDocument()
  })

  it('refreshes leave requests when the unread count goes up', async () => {
    signInAs(teacherUser)
    let count = 0
    api(() => count)
    let leaveCalls = 0
    server.use(
      http.get(url('/classes/c1'), () =>
        HttpResponse.json({ id: 'c1', course_id: 'x', course_code: 'PRM393', course_name: 'X', class_code: 'SE1901', semester: 'FA26', teacher_user_id: 'u', teacher_name: 'T', join_code: 'A', max_absence_percent: 20, rssi_threshold: -75, student_count: 0 }),
      ),
      http.get(url('/classes/c1/leave-requests'), () => {
        leaveCalls++
        return HttpResponse.json([])
      }),
    )
    renderApp('/teacher/classes/c1?tab=leave')
    await screen.findByText('Không có đơn xin phép nào chờ duyệt')
    const before = leaveCalls
    count = 1
    await waitFor(() => expect(leaveCalls).toBeGreaterThan(before))
  })
})

describe('notifications page', () => {
  it('lists notifications; opening one marks it read once', async () => {
    signInAs(teacherUser)
    const log = api(1)
    renderApp('/notifications')
    expect(await screen.findByText('Đơn xin phép mới')).toBeInTheDocument()
    await userEvent.dblClick(screen.getByRole('button', { name: /Đơn xin phép mới/ }))
    await waitFor(() => expect(log.read).toEqual(['1']))
  })

  it('marks everything read with one request', async () => {
    signInAs(teacherUser)
    const log = api(2, [note(), note({ id: 2, title: 'Buổi học kết thúc' })])
    renderApp('/notifications')
    await screen.findByText('Buổi học kết thúc')
    await userEvent.dblClick(screen.getByRole('button', { name: 'Đọc tất cả' }))
    await waitFor(() => expect(log.readAll).toBe(1))
  })

  it('has empty and error states', async () => {
    signInAs(teacherUser)
    api(0, [])
    renderApp('/notifications')
    expect(await screen.findByText('Chưa có thông báo nào')).toBeInTheDocument()
  })

  it('shows the error with retry when loading fails', async () => {
    signInAs(teacherUser)
    api(0)
    server.use(http.get(url('/notifications'), () => HttpResponse.json({ detail: 'Máy chủ lỗi', code: 'x' }, { status: 500 })))
    renderApp('/notifications')
    expect(await screen.findByText('Máy chủ lỗi')).toBeInTheDocument()
  })
})

describe('theme', () => {
  it('follows the system colour scheme', () => {
    let listener: (() => void) | null = null
    let dark = true
    window.matchMedia = ((query: string) => ({
      get matches() {
        return dark && query.includes('dark')
      },
      media: query,
      addEventListener: (_: string, l: () => void) => {
        listener = l
      },
      removeEventListener: () => {},
    })) as unknown as typeof window.matchMedia
    initTheme()
    expect(document.documentElement.classList.contains('dark')).toBe(true)
    dark = false
    listener!()
    expect(document.documentElement.classList.contains('dark')).toBe(false)
  })
})
