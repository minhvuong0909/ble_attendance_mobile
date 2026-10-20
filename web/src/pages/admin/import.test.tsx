import { screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { http, HttpResponse } from 'msw'
import { describe, expect, it, vi } from 'vitest'
import { ApiError } from '@/api/client'
import { commitImport, previewImport, validateImportFile, type ImportKind } from '@/api/imports'
import { server } from '@/test/server'
import { adminUser, signInAs, url } from '@/test/handlers'
import { renderApp } from '@/test/render'

// jsdom có FormData riêng, không gửi được multipart qua fetch của Node: thay hai hàm gửi file bằng bản giả,
// các phần còn lại (kiểm tra file, tải mẫu, giao diện) vẫn chạy thật.
vi.mock('@/api/imports', async (original) => {
  const mod = await original<typeof import('@/api/imports')>()
  return { ...mod, previewImport: vi.fn(), commitImport: vi.fn() }
})

const report = (over: Record<string, unknown> = {}) => ({
  kind: 'teachers',
  dry_run: true,
  committed: false,
  total: 2,
  created: 2,
  skipped: 0,
  errors: 0,
  rows: [
    { row: 2, status: 'created', message: 'Tạo tài khoản giảng viên', data: { teacher_id: 'T901', full_name: 'Trần Văn B' } },
    { row: 3, status: 'created', message: 'Tạo tài khoản giảng viên', data: { teacher_id: 'T902', full_name: 'Lê Thị C' } },
  ],
  ...over,
})

const csv = (name = 'gv.csv', body = 'teacher_id,full_name\nT901,A\nT902,B\n') =>
  new File([body], name, { type: 'text/csv' })

type Call = { kind: ImportKind; dry: boolean; file: string; classId?: string }

function importApi(responder: (dry: boolean, kind: ImportKind) => unknown) {
  const calls: Call[] = []
  const handle = (dry: boolean) => async (kind: ImportKind, file: File, classId?: string) => {
    calls.push({ kind, dry, file: file.name, ...(classId ? { classId } : {}) })
    const out = responder(dry, kind)
    if (out instanceof Error) throw out
    return out as never
  }
  vi.mocked(previewImport).mockImplementation(handle(true))
  vi.mocked(commitImport).mockImplementation(handle(false))
  server.use(
    http.get(url('/admin/classes'), () =>
      HttpResponse.json([
        { id: 'c1', course_id: 'co1', course_code: 'PRM393', course_name: 'X', class_code: 'SE1901', semester: 'FA26', teacher_user_id: null, teacher_name: null, join_code: 'A', max_absence_percent: 20, rssi_threshold: -75, student_count: 0 },
      ]),
    ),
  )
  return calls
}

async function pick(file: File) {
  const input = document.querySelector('input[type=file]') as HTMLInputElement
  await userEvent.upload(input, file, { applyAccept: false })
}

describe('validateImportFile', () => {
  it('rejects wrong extension, empty and oversized files', () => {
    expect(validateImportFile(csv('a.txt'))).toBe('Chỉ hỗ trợ file .csv hoặc .xlsx')
    expect(validateImportFile(csv('a.csv', ''))).toBe('File rỗng')
    expect(validateImportFile({ name: 'a.csv', size: 2_000_001 } as File)).toBe('File quá lớn (tối đa 2 MB)')
    expect(validateImportFile({ name: 'a.xlsx', size: 2_000_000 } as File)).toBeNull()
    expect(validateImportFile(csv('A.CSV'))).toBeNull()
  })
})

describe('import page', () => {
  it('explains the columns and downloads the template', async () => {
    signInAs(adminUser)
    importApi(() => report())
    let saved = ''
    server.use(
      http.get(url('/admin/imports/templates/teachers'), () =>
        new HttpResponse('teacher_id,full_name\n', { headers: { 'content-disposition': 'attachment; filename="teachers_template.csv"' } }),
      ),
    )
    URL.createObjectURL = () => 'blob:x'
    URL.revokeObjectURL = () => {}
    const origClick = HTMLAnchorElement.prototype.click
    HTMLAnchorElement.prototype.click = function () {
      saved = this.download
    }
    try {
      renderApp('/admin/import?kind=teachers')
      expect(await screen.findByText(/teacher_id, full_name/)).toBeInTheDocument()
      await userEvent.click(screen.getByRole('button', { name: 'Tải file mẫu' }))
      await screen.findByRole('button', { name: 'Tải file mẫu' })
      await new Promise((r) => setTimeout(r, 50))
      expect(saved).toBe('teachers_template.csv')
    } finally {
      HTMLAnchorElement.prototype.click = origClick
    }
  })

  it('rejects bad files before any upload', async () => {
    signInAs(adminUser)
    const calls = importApi(() => report())
    renderApp('/admin/import?kind=teachers')
    await screen.findByText(/teacher_id/)
    await pick(csv('a.txt'))
    expect(await screen.findByText('Chỉ hỗ trợ file .csv hoặc .xlsx')).toBeInTheDocument()
    expect(calls).toEqual([])
  })

  it('previews with a dry run and allows confirmation; a double click commits once', async () => {
    signInAs(adminUser)
    const calls = importApi((dry) => (dry ? report() : report({ dry_run: false, committed: true })))
    renderApp('/admin/import?kind=teachers')
    await screen.findByText(/teacher_id/)
    await pick(csv())
    expect(await screen.findByText('Sẽ tạo: 2')).toBeInTheDocument()
    expect(screen.getByText('Tổng: 2 dòng')).toBeInTheDocument()
    expect(screen.getAllByText('Tạo tài khoản giảng viên')).toHaveLength(2)
    expect(calls).toEqual([{ kind: 'teachers', dry: true, file: 'gv.csv' }])
    await userEvent.dblClick(screen.getByRole('button', { name: 'Xác nhận nhập' }))
    expect(await screen.findByText('Đã nhập 2 dòng')).toBeInTheDocument()
    expect(calls.filter((c) => !c.dry)).toHaveLength(1)
  })

  it('shows each row\'s file data (teacher, class) next to the result so it can be checked', async () => {
    signInAs(adminUser)
    importApi((_dry, kind) =>
      kind === 'teachers'
        ? report()
        : report({
            kind: 'classes',
            rows: [{ row: 2, status: 'created', message: 'Tạo lớp mới và môn học mới', data: { course_code: 'PRN232', course_name: '.NET', class_code: 'NET01', semester: 'FA26', teacher_id: 'T002' } }],
          }),
    )
    const first = renderApp('/admin/import?kind=teachers')
    await screen.findByText(/teacher_id/)
    await pick(csv())
    const row = (await screen.findByText('T901')).closest('tr')!
    expect(within(row).getByText('Trần Văn B')).toBeInTheDocument()
    expect(screen.getByRole('columnheader', { name: 'Họ và tên' })).toBeInTheDocument()
    first.unmount()
    renderApp('/admin/import?kind=classes')
    await screen.findByText(/course_code/)
    await pick(csv('lop.csv', 'x'))
    const cls = (await screen.findByText('NET01')).closest('tr')!
    for (const value of ['PRN232', '.NET', 'FA26', 'T002']) expect(within(cls).getByText(value)).toBeInTheDocument()
  })

  it('blocks confirmation when the preview has errors', async () => {
    signInAs(adminUser)
    importApi(() =>
      report({ errors: 1, created: 1, rows: [{ row: 2, status: 'created', message: 'ok' }, { row: 3, status: 'error', message: 'Mã giảng viên phải dài từ 3 đến 16 ký tự' }] }),
    )
    renderApp('/admin/import?kind=teachers')
    await screen.findByText(/teacher_id/)
    await pick(csv())
    expect(await screen.findByText('Mã giảng viên phải dài từ 3 đến 16 ký tự')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Xác nhận nhập' })).toBeDisabled()
  })

  it('blocks confirmation when nothing would be created', async () => {
    signInAs(adminUser)
    importApi(() => report({ created: 0, skipped: 2, rows: [{ row: 2, status: 'skipped', message: 'Đã tồn tại' }] }))
    renderApp('/admin/import?kind=teachers')
    await screen.findByText(/teacher_id/)
    await pick(csv())
    await screen.findByText('Bỏ qua: 2')
    expect(screen.getByRole('button', { name: 'Xác nhận nhập' })).toBeDisabled()
  })

  it('a commit the server did not apply is a failure, not a success', async () => {
    signInAs(adminUser)
    importApi(() => report())
    renderApp('/admin/import?kind=teachers')
    await screen.findByText(/teacher_id/)
    await pick(csv())
    await userEvent.click(await screen.findByRole('button', { name: 'Xác nhận nhập' }))
    expect(await screen.findByText(/Dữ liệu chưa được ghi/)).toBeInTheDocument()
    expect(screen.queryByText(/Đã nhập/)).not.toBeInTheDocument()
  })

  it('choosing another file replaces the old preview', async () => {
    signInAs(adminUser)
    let n = 0
    importApi(() => (++n === 1 ? report() : report({ total: 1, created: 1, rows: [{ row: 2, status: 'created', message: 'Dòng mới' }] })))
    renderApp('/admin/import?kind=teachers')
    await screen.findByText(/teacher_id/)
    await pick(csv('một.csv'))
    await screen.findByText('Tổng: 2 dòng')
    await pick(csv('hai.csv'))
    expect(await screen.findByText('Tổng: 1 dòng')).toBeInTheDocument()
    expect(screen.queryByText('Tổng: 2 dòng')).not.toBeInTheDocument()
  })

  it('shows the server message (for example missing columns)', async () => {
    signInAs(adminUser)
    importApi(() => new ApiError('Thiếu cột: teacher_id', 422, 'missing_columns'))
    renderApp('/admin/import?kind=teachers')
    await screen.findByText(/teacher_id/)
    await pick(csv())
    expect(await screen.findByText('Thiếu cột: teacher_id')).toBeInTheDocument()
  })

  it('students import needs a class and posts to that class', async () => {
    signInAs(adminUser)
    const calls = importApi((dry) => report({ kind: 'students', dry_run: dry, committed: !dry }))
    renderApp('/admin/import?kind=students')
    await screen.findByLabelText('Lớp')
    expect(screen.getByText('Hãy chọn lớp trước khi chọn file')).toBeInTheDocument()
    await screen.findByRole('option', { name: /SE1901/ })
    await userEvent.selectOptions(screen.getByLabelText('Lớp'), 'c1')
    await pick(csv('sv.csv', 'student_id,full_name\n25CE001,An\n'))
    await screen.findByText('Tổng: 2 dòng')
    expect(calls).toEqual([{ kind: 'students', dry: true, file: 'sv.csv', classId: 'c1' }])
  })

  it('preselects the class from the URL', async () => {
    signInAs(adminUser)
    importApi(() => report())
    renderApp('/admin/import?kind=students&classId=c1')
    await screen.findByRole('option', { name: /SE1901/ })
    expect(screen.getByLabelText('Lớp')).toHaveValue('c1')
  })

  it('classes import posts to the classes endpoint', async () => {
    signInAs(adminUser)
    const calls = importApi(() => report({ kind: 'classes' }))
    renderApp('/admin/import?kind=classes')
    await screen.findByText(/course_code/)
    await pick(csv('lop.csv', 'course_code,course_name,class_code,semester,teacher_id\n'))
    await screen.findByText('Tổng: 2 dòng')
    expect(calls[0].kind).toBe('classes')
  })
})
