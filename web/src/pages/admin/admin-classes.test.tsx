import { screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { http, HttpResponse } from 'msw'
import { describe, expect, it } from 'vitest'
import { server } from '@/test/server'
import { adminUser, signInAs, url } from '@/test/handlers'
import { renderApp } from '@/test/render'

const courses = [
  { id: 'co1', code: 'PRM393', name: 'Lập trình di động', credits: 3 },
  { id: 'co2', code: 'PRN232', name: '.NET', credits: 3 },
]
const teachers = [
  { id: 'u1', full_name: 'Giảng viên Demo', role: 'teacher', student_id: null, teacher_id: 'T001', must_change_password: false },
  { id: 'u2', full_name: 'Trần Văn B', role: 'teacher', student_id: null, teacher_id: 'T002', must_change_password: false },
]
const cls = (over: Record<string, unknown> = {}) => ({
  id: 'c1',
  course_id: 'co1',
  course_code: 'PRM393',
  course_name: 'Lập trình di động',
  class_code: 'SE1901',
  semester: 'FA26',
  teacher_user_id: 'u1',
  teacher_name: 'Giảng viên Demo',
  join_code: 'EFC63D',
  max_absence_percent: 20,
  rssi_threshold: -75,
  student_count: 2,
  ...over,
})
const students = [
  { id: 's1', student_id: '25CE099', full_name: 'Nguyễn Văn An' },
  { id: 's2', student_id: '25CE100', full_name: 'Lê Thị Bình' },
]

function api(list = [cls(), cls({ id: 'c2', course_id: 'co2', course_code: 'PRN232', class_code: 'NET01', join_code: 'ZZZ111', teacher_user_id: null, teacher_name: null })]) {
  const log = { posts: [] as unknown[], patches: [] as unknown[], assigns: [] as unknown[], deletes: [] as string[] }
  server.use(
    http.get(url('/admin/courses'), () => HttpResponse.json(courses)),
    http.get(url('/admin/teachers'), () => HttpResponse.json(teachers)),
    http.get(url('/admin/classes'), () => HttpResponse.json(list)),
    http.get(url('/classes/:id/students'), () => HttpResponse.json(students)),
    http.post(url('/admin/classes'), async ({ request }) => {
      const body = await request.json()
      log.posts.push(body)
      return HttpResponse.json(cls({ id: 'c9', class_code: 'NEW1' }), { status: 201 })
    }),
    http.patch(url('/admin/classes/:id'), async ({ request }) => {
      const body = (await request.json()) as Record<string, unknown>
      log.patches.push(body)
      Object.assign(list[0], body)
      return HttpResponse.json(list[0])
    }),
    http.post(url('/admin/classes/:id/assign-teacher'), async ({ request }) => {
      const body = (await request.json()) as { teacher_user_id: string }
      log.assigns.push(body)
      Object.assign(list[0], { teacher_user_id: body.teacher_user_id, teacher_name: 'Trần Văn B' })
      return HttpResponse.json(list[0])
    }),
    http.delete(url('/admin/classes/:id'), ({ params }) => {
      log.deletes.push(String(params.id))
      return new HttpResponse(null, { status: 204 })
    }),
  )
  return log
}

describe('admin classes list', () => {
  it('lists classes with teacher and student count, and filters by course', async () => {
    signInAs(adminUser)
    api()
    renderApp('/admin/classes')
    expect(await screen.findByText('SE1901')).toBeInTheDocument()
    expect(screen.getByText('NET01')).toBeInTheDocument()
    expect(screen.queryByText('EFC63D')).not.toBeInTheDocument()
    expect(screen.getByText('Chưa gán')).toBeInTheDocument()
    await userEvent.selectOptions(screen.getByLabelText('Lọc theo môn'), 'co2')
    expect(screen.queryByText('SE1901')).not.toBeInTheDocument()
    expect(screen.getByText('NET01')).toBeInTheDocument()
  })

  it('shows an empty state', async () => {
    signInAs(adminUser)
    api([])
    renderApp('/admin/classes')
    expect(await screen.findByText('Chưa có lớp học nào')).toBeInTheDocument()
  })

  it('creates a class with defaults; double submit sends one request', async () => {
    signInAs(adminUser)
    const log = api()
    renderApp('/admin/classes')
    const u = userEvent.setup()
    await u.click(await screen.findByRole('button', { name: 'Thêm lớp' }))
    const dialog = await screen.findByRole('dialog')
    await u.selectOptions(within(dialog).getByLabelText('Môn học'), 'co1')
    await u.type(within(dialog).getByLabelText('Mã lớp'), 'se1902')
    await u.type(within(dialog).getByLabelText('Học kỳ'), 'FA26')
    await u.selectOptions(within(dialog).getByLabelText('Giảng viên'), 'u2')
    await u.dblClick(within(dialog).getByRole('button', { name: 'Tạo lớp' }))
    await screen.findByText('SE1901')
    expect(log.posts).toEqual([
      { course_id: 'co1', class_code: 'SE1902', semester: 'FA26', teacher_user_id: 'u2', max_absence_percent: 20, rssi_threshold: -75 },
    ])
  })

  it('validates required fields and ranges without calling the API', async () => {
    signInAs(adminUser)
    const log = api()
    renderApp('/admin/classes')
    const u = userEvent.setup()
    await u.click(await screen.findByRole('button', { name: 'Thêm lớp' }))
    const dialog = await screen.findByRole('dialog')
    await u.click(within(dialog).getByRole('button', { name: 'Tạo lớp' }))
    expect(await within(dialog).findByText('Vui lòng chọn môn học')).toBeInTheDocument()
    expect(within(dialog).getByText('Mã lớp không được trống')).toBeInTheDocument()
    const rssi = within(dialog).getByLabelText('Ngưỡng RSSI (dBm)')
    await u.clear(rssi)
    await u.type(rssi, '-10')
    await u.click(within(dialog).getByRole('button', { name: 'Tạo lớp' }))
    expect(await within(dialog).findByText('Ngưỡng RSSI từ -100 đến -30')).toBeInTheDocument()
    expect(log.posts).toEqual([])
  })

  it('keeps the dialog open on a duplicate class (409)', async () => {
    signInAs(adminUser)
    api()
    server.use(
      http.post(url('/admin/classes'), () =>
        HttpResponse.json({ detail: 'Lớp này đã tồn tại trong học kỳ', code: 'class_exists' }, { status: 409 }),
      ),
    )
    renderApp('/admin/classes')
    const u = userEvent.setup()
    await u.click(await screen.findByRole('button', { name: 'Thêm lớp' }))
    const dialog = await screen.findByRole('dialog')
    await u.selectOptions(within(dialog).getByLabelText('Môn học'), 'co1')
    await u.type(within(dialog).getByLabelText('Mã lớp'), 'SE1901')
    await u.type(within(dialog).getByLabelText('Học kỳ'), 'FA26')
    await u.click(within(dialog).getByRole('button', { name: 'Tạo lớp' }))
    expect(await within(dialog).findByText('Lớp này đã tồn tại trong học kỳ')).toBeInTheDocument()
  })
})

describe('admin class detail', () => {
  it('shows the class, its teacher and students', async () => {
    signInAs(adminUser)
    api()
    renderApp('/admin/classes/c1')
    expect(await screen.findByRole('heading', { name: /PRM393 · SE1901/ })).toBeInTheDocument()
    expect(screen.queryByText('EFC63D')).not.toBeInTheDocument()
    expect(await screen.findByText('Nguyễn Văn An')).toBeInTheDocument()
    expect(screen.getByText('25CE100')).toBeInTheDocument()
  })

  it('shows a message for an unknown class', async () => {
    signInAs(adminUser)
    api()
    renderApp('/admin/classes/zzz')
    expect(await screen.findByText('Không tìm thấy lớp học')).toBeInTheDocument()
  })

  it('an empty roster offers the import link', async () => {
    signInAs(adminUser)
    api()
    server.use(http.get(url('/classes/:id/students'), () => HttpResponse.json([])))
    renderApp('/admin/classes/c1')
    expect(await screen.findByText('Lớp chưa có sinh viên')).toBeInTheDocument()
    const link = screen.getByRole('link', { name: 'Nhập danh sách sinh viên' })
    expect(link).toHaveAttribute('href', '/admin/import?kind=students&classId=c1')
  })

  it('saves only the changed settings', async () => {
    signInAs(adminUser)
    const log = api()
    renderApp('/admin/classes/c1')
    const u = userEvent.setup()
    const save = await screen.findByRole('button', { name: 'Lưu cấu hình' })
    expect(save).toBeDisabled()
    const rssi = screen.getByLabelText('Ngưỡng RSSI (dBm)')
    await u.clear(rssi)
    await u.type(rssi, '-70')
    await u.dblClick(screen.getByRole('button', { name: 'Lưu cấu hình' }))
    expect(await screen.findByText('Đã lưu cấu hình')).toBeInTheDocument()
    expect(log.patches).toEqual([{ rssi_threshold: -70 }])
  })

  it('shows the server message when renaming collides with another class', async () => {
    signInAs(adminUser)
    api()
    server.use(
      http.patch(url('/admin/classes/:id'), () =>
        HttpResponse.json({ detail: 'Lớp này đã tồn tại trong học kỳ', code: 'class_exists' }, { status: 409 }),
      ),
    )
    renderApp('/admin/classes/c1')
    const u = userEvent.setup()
    const code = await screen.findByLabelText('Mã lớp')
    await u.clear(code)
    await u.type(code, 'se1902')
    await u.click(screen.getByRole('button', { name: 'Lưu cấu hình' }))
    expect(await screen.findByText('Lớp này đã tồn tại trong học kỳ')).toBeInTheDocument()
  })

  it('assigns another teacher; a 409 from an active session is shown', async () => {
    signInAs(adminUser)
    const log = api()
    renderApp('/admin/classes/c1')
    const u = userEvent.setup()
    await screen.findByRole('option', { name: /T002/ })
    await u.selectOptions(await screen.findByLabelText('Giảng viên phụ trách'), 'u2')
    await u.click(screen.getByRole('button', { name: 'Gán giảng viên' }))
    expect(await screen.findByText('Đã gán giảng viên')).toBeInTheDocument()
    expect(log.assigns).toEqual([{ teacher_user_id: 'u2' }])

    server.use(
      http.post(url('/admin/classes/:id/assign-teacher'), () =>
        HttpResponse.json({ detail: 'Lớp đang có buổi học, chưa thể đổi giảng viên', code: 'class_has_active_session' }, { status: 409 }),
      ),
    )
    await u.selectOptions(screen.getByLabelText('Giảng viên phụ trách'), 'u1')
    await u.click(screen.getByRole('button', { name: 'Gán giảng viên' }))
    expect(await screen.findByText('Lớp đang có buổi học, chưa thể đổi giảng viên')).toBeInTheDocument()
  })

  it('deletes after confirmation and returns to the list', async () => {
    signInAs(adminUser)
    const log = api()
    renderApp('/admin/classes/c1')
    const u = userEvent.setup()
    await u.click(await screen.findByRole('button', { name: 'Xóa lớp' }))
    await u.dblClick(within(await screen.findByRole('alertdialog')).getByRole('button', { name: 'Xóa' }))
    expect(await screen.findByRole('heading', { name: 'Lớp học' })).toBeInTheDocument()
    expect(log.deletes).toEqual(['c1'])
  })

  it('a non-empty class cannot be deleted: message shown, page stays', async () => {
    signInAs(adminUser)
    api()
    server.use(
      http.delete(url('/admin/classes/:id'), () =>
        HttpResponse.json({ detail: 'Lớp đã có sinh viên hoặc buổi học, không thể xóa', code: 'class_not_empty' }, { status: 409 }),
      ),
    )
    renderApp('/admin/classes/c1')
    const u = userEvent.setup()
    await u.click(await screen.findByRole('button', { name: 'Xóa lớp' }))
    await u.click(within(await screen.findByRole('alertdialog')).getByRole('button', { name: 'Xóa' }))
    expect(await screen.findByText('Lớp đã có sinh viên hoặc buổi học, không thể xóa')).toBeInTheDocument()
    expect(screen.getByRole('heading', { name: /PRM393 · SE1901/ })).toBeInTheDocument()
  })
})
