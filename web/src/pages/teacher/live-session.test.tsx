import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { http, HttpResponse } from 'msw'
import { describe, expect, it, vi } from 'vitest'
import { server } from '@/test/server'
import { signInAs, teacherUser, url } from '@/test/handlers'
import { renderApp } from '@/test/render'

vi.mock('@/lib/constants', () => ({ POLL_MS: 40, NOTIFICATION_POLL_MS: 60000 }))

const session = (over: Record<string, unknown> = {}) => ({
  id: 's1',
  class_id: 'c1',
  class_code: 'SE1901',
  course_code: 'PRM393',
  course_name: 'Lập trình di động',
  teacher_user_id: 'u-teacher',
  beacon_code: 'abcd1234',
  starts_at: '2026-10-18T03:00:00Z',
  ends_at: null,
  is_active: true,
  finalization_open: false,
  rssi_threshold: -75,
  ...over,
})
const record = (over: Record<string, unknown> = {}) => ({
  student_user_id: 'u1',
  student_id: '25CE099',
  student_name: 'Nguyễn Văn An',
  detection_count: 12,
  presence_ratio: 0.8,
  status: 'present',
  finalized: true,
  first_seen_at: '2026-10-18T03:05:00Z',
  overridden: false,
  override_reason: null,
  ...over,
})
const attendance = (records = [record(), record({ student_user_id: 'u2', student_id: '25CE100', student_name: 'Lê Thị Bình', status: 'absent', presence_ratio: 0, finalized: false, first_seen_at: null, detection_count: 0 })]) => ({
  session_id: 's1',
  class_id: 'c1',
  total_students: records.length,
  present_students: records.filter((r) => r.status === 'present').length,
  records,
})

function liveApi(opts: { open?: boolean } = {}) {
  const state = { open: opts.open ?? false, ended: false, opens: 0, ends: 0, overrides: [] as unknown[] }
  server.use(
    http.get(url('/sessions/active'), () =>
      state.ended
        ? HttpResponse.json({ detail: 'Hiện không có buổi học nào đang diễn ra', code: 'no_active_session' }, { status: 404 })
        : HttpResponse.json(session({ finalization_open: state.open })),
    ),
    http.get(url('/sessions/s1/attendance'), () => HttpResponse.json(attendance())),
    http.post(url('/sessions/s1/open-finalization'), () => {
      state.opens++
      state.open = true
      return HttpResponse.json(session({ finalization_open: true }))
    }),
    http.post(url('/sessions/s1/end'), () => {
      state.ends++
      state.ended = true
      return HttpResponse.json(session({ is_active: false, ends_at: '2026-10-18T04:30:00Z', finalization_open: state.open }))
    }),
    http.get(url('/classes/c1/sessions'), () =>
      HttpResponse.json([session({ is_active: false, ends_at: '2026-10-18T04:30:00Z' })]),
    ),
    http.post(url('/sessions/s1/attendance/override'), async ({ request }) => {
      state.overrides.push(await request.json())
      return HttpResponse.json({ student_user_id: 'u2', status: 'present', overridden_by: 'x', overridden_at: '2026-10-18T05:00:00Z', override_reason: 'r' })
    }),
  )
  return state
}

describe('live session', () => {
  it('has an empty state with a way to start a session', async () => {
    signInAs(teacherUser)
    liveApi()
    server.use(
      http.get(url('/sessions/active'), () =>
        HttpResponse.json({ detail: 'Hiện không có buổi học nào đang diễn ra', code: 'no_active_session' }, { status: 404 }),
      ),
    )
    renderApp('/teacher/live')
    expect(await screen.findByText(/không có buổi học nào đang diễn ra/i)).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Chọn lớp để bắt đầu' })).toHaveAttribute('href', '/teacher/classes')
  })

  it('shows a real error (not a blank page) when the session cannot be loaded', async () => {
    signInAs(teacherUser)
    server.use(http.get(url('/sessions/active'), () => HttpResponse.json({ detail: 'Máy chủ lỗi', code: 'x' }, { status: 500 })))
    renderApp('/teacher/live')
    expect(await screen.findByText('Máy chủ lỗi')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Thử lại' })).toBeInTheDocument()
  })

  it('shows the session and the attendance table', async () => {
    signInAs(teacherUser)
    liveApi()
    renderApp('/teacher/live')
    expect(await screen.findByRole('heading', { name: /PRM393 · SE1901/ })).toBeInTheDocument()
    expect(screen.getByText('abcd1234')).toBeInTheDocument()
    expect(await screen.findByText('Nguyễn Văn An')).toBeInTheDocument()
    const row = screen.getByText('Lê Thị Bình').closest('tr')!
    expect(within(row).getByText('Vắng')).toBeInTheDocument()
    expect(screen.getByText('Có mặt: 1/2')).toBeInTheDocument()
  })

  it('opens finalization once, then shows it as open', async () => {
    signInAs(teacherUser)
    const state = liveApi()
    renderApp('/teacher/live')
    await userEvent.dblClick(await screen.findByRole('button', { name: 'Mở chốt điểm danh' }))
    expect(await screen.findByText('Đã mở chốt')).toBeInTheDocument()
    expect(state.opens).toBe(1)
    expect(screen.queryByRole('button', { name: 'Mở chốt điểm danh' })).not.toBeInTheDocument()
  })

  it('ending asks for confirmation (with a warning if finalization is closed), then ends once and shows the result', async () => {
    signInAs(teacherUser)
    const state = liveApi()
    renderApp('/teacher/live')
    const u = userEvent.setup()
    await u.click(await screen.findByRole('button', { name: 'Kết thúc buổi' }))
    const dialog = await screen.findByRole('alertdialog')
    expect(within(dialog).getByText(/chưa mở chốt/i)).toBeInTheDocument()
    await u.dblClick(within(dialog).getByRole('button', { name: 'Kết thúc' }))
    expect(await screen.findByRole('heading', { name: 'Kết quả buổi học' })).toBeInTheDocument()
    expect(state.ends).toBe(1)
  })

  it('ending after opening finalization uses the normal wording', async () => {
    signInAs(teacherUser)
    liveApi({ open: true })
    renderApp('/teacher/live')
    await userEvent.click(await screen.findByRole('button', { name: 'Kết thúc buổi' }))
    const dialog = await screen.findByRole('alertdialog')
    expect(within(dialog).getByText(/không thể hoàn tác/i)).toBeInTheDocument()
    expect(within(dialog).queryByText(/chưa mở chốt/i)).not.toBeInTheDocument()
  })

  it('refreshes the table by polling and keeps old data with a warning when a poll fails', async () => {
    signInAs(teacherUser)
    liveApi()
    let calls = 0
    server.use(
      http.get(url('/sessions/s1/attendance'), () => {
        calls++
        if (calls === 1) return HttpResponse.json(attendance())
        if (calls === 2) return HttpResponse.json(attendance([record({ student_name: 'Nguyễn Văn Ân Mới' })]))
        return HttpResponse.json({ detail: 'Mất kết nối', code: 'x' }, { status: 500 })
      }),
    )
    renderApp('/teacher/live')
    expect(await screen.findByText('Nguyễn Văn An')).toBeInTheDocument()
    expect(await screen.findByText('Nguyễn Văn Ân Mới')).toBeInTheDocument()
    expect(await screen.findByText(/Không cập nhật được/)).toBeInTheDocument()
    expect(screen.getByText('Nguyễn Văn Ân Mới')).toBeInTheDocument()
  })
})

describe('override dialog', () => {
  async function openOverride() {
    const u = userEvent.setup()
    await u.click(await screen.findByRole('button', { name: 'Chỉnh tay Lê Thị Bình' }))
    return { u, dialog: await screen.findByRole('dialog') }
  }

  it('requires a reason, then sends status and reason once', async () => {
    signInAs(teacherUser)
    const state = liveApi()
    renderApp('/teacher/live')
    const { u, dialog } = await openOverride()
    await u.click(within(dialog).getByRole('button', { name: 'Lưu' }))
    expect(await within(dialog).findByText('Lý do cần ít nhất 3 ký tự')).toBeInTheDocument()
    expect(state.overrides).toEqual([])
    await u.selectOptions(within(dialog).getByLabelText('Trạng thái'), 'present')
    await u.type(within(dialog).getByLabelText('Lý do'), 'Quên mang điện thoại')
    await u.dblClick(within(dialog).getByRole('button', { name: 'Lưu' }))
    await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument())
    expect(state.overrides).toEqual([{ student_user_id: 'u2', status: 'present', reason: 'Quên mang điện thoại' }])
  })

  it('shows a server error inside the dialog and keeps it open', async () => {
    signInAs(teacherUser)
    liveApi()
    server.use(
      http.post(url('/sessions/s1/attendance/override'), () =>
        HttpResponse.json({ detail: 'Buổi học đã kết thúc từ lâu', code: 'x' }, { status: 409 }),
      ),
    )
    renderApp('/teacher/live')
    const { u, dialog } = await openOverride()
    await u.type(within(dialog).getByLabelText('Lý do'), 'Lý do hợp lệ')
    await u.click(within(dialog).getByRole('button', { name: 'Lưu' }))
    expect(await within(dialog).findByText('Buổi học đã kết thúc từ lâu')).toBeInTheDocument()
    expect(screen.getByRole('dialog')).toBeInTheDocument()
    expect(within(dialog).getByRole('button', { name: 'Lưu' })).toBeEnabled()
  })

  it('marks overridden rows with their reason', async () => {
    signInAs(teacherUser)
    liveApi()
    server.use(
      http.get(url('/sessions/s1/attendance'), () =>
        HttpResponse.json(attendance([record({ overridden: true, override_reason: 'Có giấy xác nhận', status: 'excused' })])),
      ),
    )
    renderApp('/teacher/live')
    expect(await screen.findByText('Đã chỉnh tay')).toBeInTheDocument()
    expect(screen.getByText(/Có giấy xác nhận/)).toBeInTheDocument()
  })
})

describe('session result', () => {
  it('shows the ended session with the table and exports Excel with a safe name', async () => {
    signInAs(teacherUser)
    liveApi()
    server.use(
      http.get(url('/sessions/s1/export'), () =>
        new HttpResponse('x', { headers: { 'content-disposition': 'attachment; filename="..\\evil\\buoi.xlsx"' } }),
      ),
    )
    let saved = ''
    URL.createObjectURL = () => 'blob:x'
    URL.revokeObjectURL = () => {}
    const original = HTMLAnchorElement.prototype.click
    HTMLAnchorElement.prototype.click = function () {
      saved = this.download
    }
    try {
      renderApp('/teacher/sessions/s1')
      expect(await screen.findByRole('heading', { name: 'Kết quả buổi học' })).toBeInTheDocument()
      expect(await screen.findByText('PRM393 · SE1901')).toBeInTheDocument()
      expect(await screen.findByText('Nguyễn Văn An')).toBeInTheDocument()
      await userEvent.click(screen.getByRole('button', { name: 'Xuất Excel buổi này' }))
      await waitFor(() => expect(saved).toBe('buoi.xlsx'))
    } finally {
      HTMLAnchorElement.prototype.click = original
    }
  })

  it('shows the server message for a session that is not theirs', async () => {
    signInAs(teacherUser)
    server.use(
      http.get(url('/sessions/zzz/attendance'), () =>
        HttpResponse.json({ detail: 'Không tìm thấy buổi học', code: 'session_not_found' }, { status: 404 }),
      ),
    )
    renderApp('/teacher/sessions/zzz')
    expect(await screen.findByText('Không tìm thấy buổi học')).toBeInTheDocument()
  })
})
