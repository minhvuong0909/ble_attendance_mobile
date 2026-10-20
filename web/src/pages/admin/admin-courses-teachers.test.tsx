import { screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { http, HttpResponse } from 'msw'
import { describe, expect, it } from 'vitest'
import { server } from '@/test/server'
import { adminUser, signInAs, url } from '@/test/handlers'
import { renderApp } from '@/test/render'

interface Course {
  id: string
  code: string
  name: string
  credits: number | null
}

function courseApi(initial: Course[]) {
  const rows = [...initial]
  const log = { posts: [] as unknown[], patches: [] as unknown[], deletes: [] as string[] }
  server.use(
    http.get(url('/admin/courses'), () => HttpResponse.json(rows)),
    http.post(url('/admin/courses'), async ({ request }) => {
      const body = (await request.json()) as Omit<Course, 'id'>
      log.posts.push(body)
      const row: Course = { ...body, id: `c${rows.length + 1}` }
      rows.push(row)
      return HttpResponse.json(row, { status: 201 })
    }),
    http.patch(url('/admin/courses/:id'), async ({ request, params }) => {
      const body = (await request.json()) as Partial<Course>
      log.patches.push(body)
      const row = rows.find((r) => r.id === params.id)!
      Object.assign(row, body)
      return HttpResponse.json(row)
    }),
    http.delete(url('/admin/courses/:id'), ({ params }) => {
      log.deletes.push(String(params.id))
      rows.splice(rows.findIndex((r) => r.id === params.id), 1)
      return new HttpResponse(null, { status: 204 })
    }),
  )
  return log
}

const prm = { id: 'c1', code: 'PRM393', name: 'Lập trình di động', credits: 3 }

describe('admin courses', () => {
  it('lists courses, with an empty state', async () => {
    signInAs(adminUser)
    courseApi([prm])
    renderApp('/admin/courses')
    expect(await screen.findByText('PRM393')).toBeInTheDocument()
    expect(screen.getByText('Lập trình di động')).toBeInTheDocument()
  })

  it('shows an empty state when there are no courses', async () => {
    signInAs(adminUser)
    courseApi([])
    renderApp('/admin/courses')
    expect(await screen.findByText('Chưa có môn học nào')).toBeInTheDocument()
  })

  it('shows the error with a retry button when loading fails', async () => {
    signInAs(adminUser)
    let fail = true
    server.use(
      http.get(url('/admin/courses'), () =>
        fail ? HttpResponse.json({ detail: 'Máy chủ lỗi', code: 'x' }, { status: 500 }) : HttpResponse.json([prm]),
      ),
    )
    renderApp('/admin/courses')
    expect(await screen.findByText('Máy chủ lỗi')).toBeInTheDocument()
    fail = false
    await userEvent.click(screen.getByRole('button', { name: 'Thử lại' }))
    expect(await screen.findByText('PRM393')).toBeInTheDocument()
  })

  it('creates a course and refreshes the list; double submit sends one request', async () => {
    signInAs(adminUser)
    const log = courseApi([prm])
    renderApp('/admin/courses')
    const u = userEvent.setup()
    await u.click(await screen.findByRole('button', { name: 'Thêm môn' }))
    const dialog = await screen.findByRole('dialog')
    await u.type(within(dialog).getByLabelText('Mã môn'), 'prn232')
    await u.type(within(dialog).getByLabelText('Tên môn'), 'Lập trình .NET')
    await u.type(within(dialog).getByLabelText('Số tín chỉ'), '3')
    await u.dblClick(within(dialog).getByRole('button', { name: 'Lưu' }))
    expect(await screen.findByText('PRN232')).toBeInTheDocument()
    expect(log.posts).toEqual([{ code: 'PRN232', name: 'Lập trình .NET', credits: 3 }])
  })

  it('validates the form without calling the API', async () => {
    signInAs(adminUser)
    const log = courseApi([])
    renderApp('/admin/courses')
    const u = userEvent.setup()
    await u.click(await screen.findByRole('button', { name: 'Thêm môn' }))
    const dialog = await screen.findByRole('dialog')
    await u.click(within(dialog).getByRole('button', { name: 'Lưu' }))
    expect(await within(dialog).findByText('Mã môn từ 2 đến 32 ký tự')).toBeInTheDocument()
    expect(log.posts).toEqual([])
  })

  it('keeps the dialog open and shows the server message on a duplicate code', async () => {
    signInAs(adminUser)
    courseApi([prm])
    server.use(
      http.post(url('/admin/courses'), () =>
        HttpResponse.json({ detail: 'Mã môn học đã tồn tại', code: 'course_exists' }, { status: 409 }),
      ),
    )
    renderApp('/admin/courses')
    const u = userEvent.setup()
    await u.click(await screen.findByRole('button', { name: 'Thêm môn' }))
    const dialog = await screen.findByRole('dialog')
    await u.type(within(dialog).getByLabelText('Mã môn'), 'PRM393')
    await u.type(within(dialog).getByLabelText('Tên môn'), 'Trùng')
    await u.click(within(dialog).getByRole('button', { name: 'Lưu' }))
    expect(await within(dialog).findByText('Mã môn học đã tồn tại')).toBeInTheDocument()
    expect(screen.getByRole('dialog')).toBeInTheDocument()
  })

  it('edits name and credits only (the code is fixed)', async () => {
    signInAs(adminUser)
    const log = courseApi([prm])
    renderApp('/admin/courses')
    const u = userEvent.setup()
    await u.click(await screen.findByRole('button', { name: 'Sửa PRM393' }))
    const dialog = await screen.findByRole('dialog')
    expect(within(dialog).getByLabelText('Mã môn')).toBeDisabled()
    const name = within(dialog).getByLabelText('Tên môn')
    await u.clear(name)
    await u.type(name, 'Lập trình Flutter')
    await u.click(within(dialog).getByRole('button', { name: 'Lưu' }))
    expect(await screen.findByText('Lập trình Flutter')).toBeInTheDocument()
    expect(log.patches).toEqual([{ name: 'Lập trình Flutter', credits: 3 }])
  })

  it('deletes after confirmation; a 409 shows the message and keeps the row', async () => {
    signInAs(adminUser)
    courseApi([prm])
    server.use(
      http.delete(url('/admin/courses/:id'), () =>
        HttpResponse.json({ detail: 'Môn học đang có lớp, không thể xóa', code: 'course_has_classes' }, { status: 409 }),
      ),
    )
    renderApp('/admin/courses')
    const u = userEvent.setup()
    await u.click(await screen.findByRole('button', { name: 'Xóa PRM393' }))
    const dialog = await screen.findByRole('alertdialog')
    await u.click(within(dialog).getByRole('button', { name: 'Xóa' }))
    expect(await screen.findByText('Môn học đang có lớp, không thể xóa')).toBeInTheDocument()
    expect(screen.getByText('PRM393')).toBeInTheDocument()
  })

  it('deletes a course after confirmation', async () => {
    signInAs(adminUser)
    const log = courseApi([prm])
    renderApp('/admin/courses')
    const u = userEvent.setup()
    await u.click(await screen.findByRole('button', { name: 'Xóa PRM393' }))
    const dialog = await screen.findByRole('alertdialog')
    await u.dblClick(within(dialog).getByRole('button', { name: 'Xóa' }))
    expect(await screen.findByText('Chưa có môn học nào')).toBeInTheDocument()
    expect(log.deletes).toEqual(['c1'])
  })
})

const teacher = { id: 'u1', full_name: 'Giảng viên Demo', role: 'teacher', student_id: null, teacher_id: 'T001', must_change_password: false }

function teacherApi(initial = [teacher]) {
  const rows = [...initial]
  const log = { posts: [] as unknown[], resets: [] as string[] }
  server.use(
    http.get(url('/admin/teachers'), () => HttpResponse.json(rows)),
    http.post(url('/admin/teachers'), async ({ request }) => {
      const body = (await request.json()) as { teacher_id: string; full_name: string }
      log.posts.push(body)
      const row = { ...teacher, id: `u${rows.length + 1}`, ...body }
      rows.push(row)
      return HttpResponse.json(row, { status: 201 })
    }),
    http.post(url('/admin/users/:id/reset-password'), ({ params }) => {
      log.resets.push(String(params.id))
      return HttpResponse.json({ message: 'ok' })
    }),
  )
  return log
}

describe('admin teachers', () => {
  it('creates a teacher with a normalised id and shows the temporary password once', async () => {
    signInAs(adminUser)
    const log = teacherApi()
    renderApp('/admin/teachers')
    const u = userEvent.setup()
    await u.click(await screen.findByRole('button', { name: 'Thêm giảng viên' }))
    const dialog = await screen.findByRole('dialog')
    await u.type(within(dialog).getByLabelText('Mã giảng viên'), 't902')
    await u.type(within(dialog).getByLabelText('Họ và tên'), 'Trần Văn B')
    await u.dblClick(within(dialog).getByRole('button', { name: 'Tạo' }))
    const notice = await screen.findByRole('alertdialog')
    expect(within(notice).getByText('T902')).toBeInTheDocument()
    expect(within(notice).getByText(/mật khẩu tạm/i)).toBeInTheDocument()
    expect(log.posts).toEqual([{ teacher_id: 'T902', full_name: 'Trần Văn B' }])
    await u.click(within(notice).getByRole('button', { name: 'Đã ghi nhận' }))
    expect(screen.queryByRole('alertdialog')).not.toBeInTheDocument()
    expect(await screen.findByText('Trần Văn B')).toBeInTheDocument()
    expect(localStorage.getItem('T902')).toBeNull()
  })

  it('blocks short ids and shows duplicates from the server', async () => {
    signInAs(adminUser)
    teacherApi()
    server.use(
      http.post(url('/admin/teachers'), () =>
        HttpResponse.json({ detail: 'Mã giảng viên đã tồn tại', code: 'teacher_exists' }, { status: 409 }),
      ),
    )
    renderApp('/admin/teachers')
    const u = userEvent.setup()
    await u.click(await screen.findByRole('button', { name: 'Thêm giảng viên' }))
    const dialog = await screen.findByRole('dialog')
    await u.type(within(dialog).getByLabelText('Mã giảng viên'), 'T')
    await u.type(within(dialog).getByLabelText('Họ và tên'), 'X Y')
    await u.click(within(dialog).getByRole('button', { name: 'Tạo' }))
    expect(await within(dialog).findByText('Mã giảng viên từ 3 đến 16 ký tự')).toBeInTheDocument()
    await u.type(within(dialog).getByLabelText('Mã giảng viên'), '001')
    await u.click(within(dialog).getByRole('button', { name: 'Tạo' }))
    expect(await within(dialog).findByText('Mã giảng viên đã tồn tại')).toBeInTheDocument()
  })

  it('resets a password after confirmation and reminds about the temporary one', async () => {
    signInAs(adminUser)
    const log = teacherApi()
    renderApp('/admin/teachers')
    const u = userEvent.setup()
    await u.click(await screen.findByRole('button', { name: 'Đặt lại mật khẩu T001' }))
    const confirm = await screen.findByRole('alertdialog')
    await u.dblClick(within(confirm).getByRole('button', { name: 'Đặt lại' }))
    const notice = await screen.findByText(/mật khẩu tạm/i)
    expect(notice).toBeInTheDocument()
    expect(log.resets).toEqual(['u1'])
  })

  it('shows the server message when the reset fails and lets the admin retry', async () => {
    signInAs(adminUser)
    teacherApi()
    server.use(
      http.post(url('/admin/users/:id/reset-password'), () =>
        HttpResponse.json({ detail: 'Không tìm thấy người dùng', code: 'user_not_found' }, { status: 404 }),
      ),
    )
    renderApp('/admin/teachers')
    const u = userEvent.setup()
    await u.click(await screen.findByRole('button', { name: 'Đặt lại mật khẩu T001' }))
    await u.click(within(await screen.findByRole('alertdialog')).getByRole('button', { name: 'Đặt lại' }))
    expect(await screen.findByText('Không tìm thấy người dùng')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Đặt lại mật khẩu T001' })).toBeEnabled()
  })
})
