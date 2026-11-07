import { screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { http, HttpResponse } from 'msw'
import { describe, expect, it } from 'vitest'
import { server } from '@/test/server'
import { signInAs, teacherUser, url } from '@/test/handlers'
import { renderApp } from '@/test/render'

const cls = {
  id: 'c1',
  course_id: 'co1',
  course_code: 'PRM393',
  course_name: 'Lập trình di động',
  class_code: 'SE1901',
  semester: 'FA26',
  teacher_user_id: 'u-teacher',
  teacher_name: 'Giảng viên Demo',
  join_code: 'EFC63D',
  max_absence_percent: 20,
  rssi_threshold: -75,
  student_count: 2,
}
const session = (over: Record<string, unknown> = {}) => ({
  id: 's1',
  class_id: 'c1',
  class_code: 'SE1901',
  course_code: 'PRM393',
  course_name: 'Lập trình di động',
  teacher_user_id: 'u-teacher',
  beacon_code: 'abcd1234',
  starts_at: '2026-10-18T03:00:00Z',
  ends_at: '2026-10-18T04:30:00Z',
  is_active: false,
  finalization_open: false,
  rssi_threshold: -75,
  ...over,
})
const students = [
  { id: 's1', student_id: '25CE099', full_name: 'Nguyễn Văn An' },
  { id: 's2', student_id: '25CE100', full_name: 'Lê Thị Bình' },
]

function baseApi() {
  server.use(
    http.get(url('/classes/mine'), () => HttpResponse.json([cls])),
    http.get(url('/classes/c1'), () => HttpResponse.json(cls)),
    http.get(url('/classes/c1/students'), () => HttpResponse.json(students)),
  )
}

describe('my classes', () => {
  it('lists assigned classes linking to their detail', async () => {
    signInAs(teacherUser)
    baseApi()
    renderApp('/teacher/classes')
    const link = await screen.findByRole('link', { name: /SE1901/ })
    expect(link).toHaveAttribute('href', '/teacher/classes/c1')
    expect(screen.getByText(/Lập trình di động/)).toBeInTheDocument()
  })

  it('tells a teacher without classes to contact the admin', async () => {
    signInAs(teacherUser)
    server.use(http.get(url('/classes/mine'), () => HttpResponse.json([])))
    renderApp('/teacher/classes')
    expect(await screen.findByText(/chưa được phân công lớp nào/i)).toBeInTheDocument()
  })
})

describe('class detail tabs', () => {
  it('shows the class header, the student roster by default, and the tab is kept in the URL', async () => {
    signInAs(teacherUser)
    baseApi()
    server.use(http.get(url('/classes/c1/sessions'), () => HttpResponse.json([])))
    renderApp('/teacher/classes/c1')
    expect(await screen.findByRole('heading', { name: /PRM393 · SE1901/ })).toBeInTheDocument()
    expect(screen.queryByText('EFC63D')).not.toBeInTheDocument()
    expect(await screen.findByText('Nguyễn Văn An')).toBeInTheDocument()
    await userEvent.click(screen.getByRole('tab', { name: 'Buổi học' }))
    expect(await screen.findByText('Chưa có buổi học nào')).toBeInTheDocument()
    expect(screen.getByRole('tab', { name: 'Buổi học' })).toHaveAttribute('aria-selected', 'true')
  })

  it('opens directly on the tab named in the URL', async () => {
    signInAs(teacherUser)
    baseApi()
    server.use(http.get(url('/classes/c1/sessions'), () => HttpResponse.json([])))
    renderApp('/teacher/classes/c1?tab=sessions')
    expect(await screen.findByText('Chưa có buổi học nào')).toBeInTheDocument()
  })

  it('an unknown class shows the server message', async () => {
    signInAs(teacherUser)
    server.use(http.get(url('/classes/zzz'), () => HttpResponse.json({ detail: 'Không tìm thấy lớp học', code: 'class_not_found' }, { status: 404 })))
    renderApp('/teacher/classes/zzz')
    expect(await screen.findByText('Không tìm thấy lớp học')).toBeInTheDocument()
  })
})

describe('sessions tab', () => {
  it('lists sessions and links ended ones to their result', async () => {
    signInAs(teacherUser)
    baseApi()
    server.use(
      http.get(url('/classes/c1/sessions'), () =>
        HttpResponse.json([session({ id: 's2', is_active: true, ends_at: null }), session()]),
      ),
    )
    renderApp('/teacher/classes/c1?tab=sessions')
    expect(await screen.findByText('Đang diễn ra')).toBeInTheDocument()
    expect(screen.getByText('Đã kết thúc')).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Xem kết quả' })).toHaveAttribute('href', '/teacher/sessions/s1')
    expect(screen.getByRole('link', { name: 'Mở buổi trực tiếp' })).toHaveAttribute('href', '/teacher/live')
  })

  it('starts a session once and goes to the live page', async () => {
    signInAs(teacherUser)
    baseApi()
    let posts = 0
    server.use(
      http.get(url('/classes/c1/sessions'), () => HttpResponse.json([])),
      http.post(url('/classes/c1/sessions'), () => {
        posts++
        return HttpResponse.json(session({ is_active: true, ends_at: null }), { status: 201 })
      }),
      http.get(url('/sessions/active'), () => HttpResponse.json(session({ is_active: true, ends_at: null }))),
      http.get(url('/sessions/s1/attendance'), () =>
        HttpResponse.json({ session_id: 's1', class_id: 'c1', total_students: 0, present_students: 0, records: [] }),
      ),
    )
    renderApp('/teacher/classes/c1?tab=sessions')
    await userEvent.dblClick(await screen.findByRole('button', { name: 'Bắt đầu buổi học' }))
    expect(await screen.findByText('Mã buổi học:')).toBeInTheDocument()
    expect(posts).toBe(1)
  })

  it('shows the server message and a link when a session is already running', async () => {
    signInAs(teacherUser)
    baseApi()
    server.use(
      http.get(url('/classes/c1/sessions'), () => HttpResponse.json([])),
      http.post(url('/classes/c1/sessions'), () =>
        HttpResponse.json({ detail: 'Bạn đang có một buổi học chưa kết thúc', code: 'session_already_active' }, { status: 409 }),
      ),
    )
    renderApp('/teacher/classes/c1?tab=sessions')
    await userEvent.click(await screen.findByRole('button', { name: 'Bắt đầu buổi học' }))
    expect(await screen.findByText('Bạn đang có một buổi học chưa kết thúc')).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Mở buổi trực tiếp' })).toHaveAttribute('href', '/teacher/live')
  })
})

const reportOut = {
  class_id: 'c1',
  course_code: 'PRM393',
  course_name: 'Lập trình di động',
  class_code: 'SE1901',
  semester: 'FA26',
  sessions: [
    { id: 's1', starts_at: '2026-10-18T03:00:00Z' },
    { id: 's2', starts_at: '2026-10-19T03:00:00Z' },
  ],
  students: [
    { student_user_id: 'u1', student_id: '25CE099', student_name: 'Nguyễn Văn An', cells: ['present', 'absent'], present: 1, absent: 1, excused: 0, attendance_percent: 50, absent_percent: 50, warning: true },
    { student_user_id: 'u2', student_id: '25CE100', student_name: 'Lê Thị Bình', cells: ['present', 'excused'], present: 1, absent: 0, excused: 1, attendance_percent: 100, absent_percent: 0, warning: false },
  ],
  average_attendance_percent: 75,
}

describe('report tab', () => {
  it('shows the matrix, warns students over the absence limit and shows the average', async () => {
    signInAs(teacherUser)
    baseApi()
    server.use(http.get(url('/classes/c1/report'), () => HttpResponse.json(reportOut)))
    renderApp('/teacher/classes/c1?tab=report')
    const row = (await screen.findByText('Nguyễn Văn An')).closest('tr')!
    expect(within(row).getByText('Vắng')).toBeInTheDocument()
    expect(within(row).getByText('50%')).toBeInTheDocument()
    expect(within(row).getByText('Cảnh báo')).toBeInTheDocument()
    const ok = screen.getByText('Lê Thị Bình').closest('tr')!
    expect(within(ok).getByText('Phép')).toBeInTheDocument()
    expect(within(ok).queryByText('Cảnh báo')).not.toBeInTheDocument()
    expect(screen.getByText(/Trung bình lớp: 75%/)).toBeInTheDocument()
  })

  it('says so when no session has ended', async () => {
    signInAs(teacherUser)
    baseApi()
    server.use(http.get(url('/classes/c1/report'), () => HttpResponse.json({ ...reportOut, sessions: [], students: [] })))
    renderApp('/teacher/classes/c1?tab=report')
    expect(await screen.findByText('Chưa có buổi học nào kết thúc')).toBeInTheDocument()
  })

  it('exports Excel with the safe server file name', async () => {
    signInAs(teacherUser)
    baseApi()
    server.use(
      http.get(url('/classes/c1/report'), () => HttpResponse.json(reportOut)),
      http.get(url('/classes/c1/report/export'), () =>
        new HttpResponse('xlsx', { headers: { 'content-disposition': 'attachment; filename="../x/attendance_PRM393.xlsx"' } }),
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
      renderApp('/teacher/classes/c1?tab=report')
      await userEvent.click(await screen.findByRole('button', { name: 'Xuất Excel' }))
      await screen.findByText('Nguyễn Văn An')
      await new Promise((r) => setTimeout(r, 60))
      expect(saved).toBe('attendance_PRM393.xlsx')
    } finally {
      HTMLAnchorElement.prototype.click = original
    }
  })

  it('shows the error when the export fails', async () => {
    signInAs(teacherUser)
    baseApi()
    server.use(
      http.get(url('/classes/c1/report'), () => HttpResponse.json(reportOut)),
      http.get(url('/classes/c1/report/export'), () => HttpResponse.json({ detail: 'Không xuất được báo cáo', code: 'x' }, { status: 500 })),
    )
    renderApp('/teacher/classes/c1?tab=report')
    await userEvent.click(await screen.findByRole('button', { name: 'Xuất Excel' }))
    expect(await screen.findByText('Không xuất được báo cáo')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Xuất Excel' })).toBeEnabled()
  })
})

const leave = (over: Record<string, unknown> = {}) => ({
  id: 4,
  student_user_id: 's1',
  student_id: '25CE099',
  student_name: 'Nguyễn Văn An',
  class_id: 'c1',
  course_code: 'PRM393',
  class_code: 'SE1901',
  date: '2026-10-25',
  reason: 'Đi khám bệnh',
  status: 'pending',
  created_at: '2026-10-20T01:00:00Z',
  reviewed_at: null,
  review_note: null,
  ...over,
})

describe('leave tab', () => {
  it('lists pending requests and approves one once', async () => {
    signInAs(teacherUser)
    baseApi()
    const reviews: unknown[] = []
    server.use(
      http.get(url('/classes/c1/leave-requests'), ({ request }) => {
        expect(new URL(request.url).searchParams.get('status')).toBe('pending')
        return HttpResponse.json([leave()])
      }),
      http.post(url('/leave-requests/4/review'), async ({ request }) => {
        reviews.push(await request.json())
        return HttpResponse.json(leave({ status: 'approved' }))
      }),
    )
    renderApp('/teacher/classes/c1?tab=leave')
    expect(await screen.findByText('Đi khám bệnh')).toBeInTheDocument()
    await userEvent.dblClick(screen.getByRole('button', { name: 'Duyệt' }))
    await screen.findByText('Đã duyệt đơn')
    expect(reviews).toEqual([{ decision: 'approved' }])
  })

  it('rejecting needs a reason, then sends it', async () => {
    signInAs(teacherUser)
    baseApi()
    const reviews: unknown[] = []
    server.use(
      http.get(url('/classes/c1/leave-requests'), () => HttpResponse.json([leave()])),
      http.post(url('/leave-requests/4/review'), async ({ request }) => {
        reviews.push(await request.json())
        return HttpResponse.json(leave({ status: 'rejected' }))
      }),
    )
    renderApp('/teacher/classes/c1?tab=leave')
    const u = userEvent.setup()
    await u.click(await screen.findByRole('button', { name: 'Từ chối' }))
    const dialog = await screen.findByRole('dialog')
    await u.click(within(dialog).getByRole('button', { name: 'Từ chối đơn' }))
    expect(await within(dialog).findByText('Vui lòng nhập lý do (ít nhất 3 ký tự)')).toBeInTheDocument()
    expect(reviews).toEqual([])
    await u.type(within(dialog).getByLabelText('Lý do từ chối'), 'Thiếu giấy tờ')
    await u.dblClick(within(dialog).getByRole('button', { name: 'Từ chối đơn' }))
    await screen.findByText('Đã từ chối đơn')
    expect(reviews).toEqual([{ decision: 'rejected', note: 'Thiếu giấy tờ' }])
  })

  it('an already reviewed request shows the server message and refreshes', async () => {
    signInAs(teacherUser)
    baseApi()
    let listCalls = 0
    server.use(
      http.get(url('/classes/c1/leave-requests'), () => {
        listCalls++
        return HttpResponse.json(listCalls === 1 ? [leave()] : [])
      }),
      http.post(url('/leave-requests/4/review'), () =>
        HttpResponse.json({ detail: 'Đơn này đã được xử lý', code: 'already_reviewed' }, { status: 409 }),
      ),
    )
    renderApp('/teacher/classes/c1?tab=leave')
    await userEvent.click(await screen.findByRole('button', { name: 'Duyệt' }))
    expect(await screen.findByText('Đơn này đã được xử lý')).toBeInTheDocument()
    expect(await screen.findByText('Không có đơn xin phép nào chờ duyệt')).toBeInTheDocument()
  })

  it('has an empty state', async () => {
    signInAs(teacherUser)
    baseApi()
    server.use(http.get(url('/classes/c1/leave-requests'), () => HttpResponse.json([])))
    renderApp('/teacher/classes/c1?tab=leave')
    expect(await screen.findByText('Không có đơn xin phép nào chờ duyệt')).toBeInTheDocument()
  })
})
