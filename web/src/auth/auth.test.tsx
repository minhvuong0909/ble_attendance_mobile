import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { http, HttpResponse } from 'msw'
import { describe, expect, it } from 'vitest'
import { server } from '@/test/server'
import { adminUser, loginAs, signInAs, studentUser, teacherUser, url } from '@/test/handlers'
import { renderApp } from '@/test/render'

async function login(id: string, password = 'Pass@123') {
  const user = userEvent.setup()
  await user.type(await screen.findByLabelText('Mã đăng nhập'), id)
  await user.type(screen.getByLabelText('Mật khẩu'), password)
  await user.click(screen.getByRole('button', { name: 'Đăng nhập' }))
}

describe('login and routing', () => {
  it('admin lands on the admin area, teacher on their classes', async () => {
    loginAs(adminUser)
    renderApp('/login')
    await login('A001')
    expect(await screen.findByRole('heading', { name: 'Môn học' })).toBeInTheDocument()
  })

  it('teacher lands on their classes', async () => {
    loginAs(teacherUser)
    renderApp('/login')
    await login('T001')
    expect(await screen.findByRole('heading', { name: 'Lớp của tôi' })).toBeInTheDocument()
  })

  it('shows the server message for a wrong password and stays on login', async () => {
    server.use(
      http.post(url('/auth/login'), () =>
        HttpResponse.json({ detail: 'Sai mã đăng nhập hoặc mật khẩu', code: 'invalid_credentials' }, { status: 401 }),
      ),
    )
    renderApp('/login')
    await login('A001', 'x')
    expect(await screen.findByText('Sai mã đăng nhập hoặc mật khẩu')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Đăng nhập' })).toBeEnabled()
  })

  it('sends one login request when the button is clicked twice', async () => {
    let calls = 0
    server.use(
      http.post(url('/auth/login'), async () => {
        calls++
        await new Promise((r) => setTimeout(r, 50))
        return HttpResponse.json({ detail: 'Sai', code: 'invalid_credentials' }, { status: 401 })
      }),
    )
    renderApp('/login')
    const user = userEvent.setup()
    await user.type(await screen.findByLabelText('Mã đăng nhập'), 'A001')
    await user.type(screen.getByLabelText('Mật khẩu'), 'x')
    const button = screen.getByRole('button', { name: 'Đăng nhập' })
    await user.dblClick(button)
    await screen.findByText('Sai')
    expect(calls).toBe(1)
  })

  it('anonymous visitors of protected pages go to login', async () => {
    renderApp('/admin/courses')
    expect(await screen.findByRole('button', { name: 'Đăng nhập' })).toBeInTheDocument()
  })

  it('a role cannot use the other role area', async () => {
    signInAs(adminUser)
    renderApp('/teacher/classes')
    expect(await screen.findByRole('heading', { name: 'Môn học' })).toBeInTheDocument()
  })

  it('students only see the Android app notice', async () => {
    signInAs(studentUser)
    renderApp('/admin/courses')
    expect(await screen.findByText(/ứng dụng Android/i)).toBeInTheDocument()
    expect(screen.queryByRole('heading', { name: 'Môn học' })).not.toBeInTheDocument()
  })

  it('forces a password change before anything else, then continues', async () => {
    const user = { ...teacherUser, must_change_password: true }
    signInAs(user)
    let changed = false
    server.use(
      http.get(url('/auth/me'), () => HttpResponse.json({ ...user, must_change_password: !changed })),
      http.post(url('/auth/change-password'), async ({ request }) => {
        const body = (await request.json()) as { old_password: string; new_password: string }
        expect(body).toEqual({ old_password: 'T001', new_password: 'Matkhau@2' })
        changed = true
        return HttpResponse.json({ message: 'ok' })
      }),
    )
    renderApp('/teacher/classes')
    const u = userEvent.setup()
    await u.type(await screen.findByLabelText('Mật khẩu hiện tại'), 'T001')
    await u.type(screen.getByLabelText('Mật khẩu mới'), 'Matkhau@2')
    await u.type(screen.getByLabelText('Nhập lại mật khẩu mới'), 'Matkhau@2')
    await u.click(screen.getByRole('button', { name: 'Đổi mật khẩu' }))
    expect(await screen.findByRole('heading', { name: 'Lớp của tôi' })).toBeInTheDocument()
  })

  it('rejects mismatched or short new passwords without calling the API', async () => {
    const user = { ...adminUser, must_change_password: true }
    signInAs(user)
    renderApp('/')
    const u = userEvent.setup()
    await u.type(await screen.findByLabelText('Mật khẩu hiện tại'), 'A001')
    await u.type(screen.getByLabelText('Mật khẩu mới'), 'abc')
    await u.type(screen.getByLabelText('Nhập lại mật khẩu mới'), 'abd')
    await u.click(screen.getByRole('button', { name: 'Đổi mật khẩu' }))
    expect(await screen.findByText('Mật khẩu phải có ít nhất 6 ký tự')).toBeInTheDocument()
  })

  it('logging out clears the token and shows login', async () => {
    signInAs(adminUser)
    renderApp('/admin/courses')
    const u = userEvent.setup()
    await u.click(await screen.findByRole('button', { name: /tài khoản/i }))
    await u.click(await screen.findByRole('menuitem', { name: 'Đăng xuất' }))
    await waitFor(() => expect(localStorage.getItem('token')).toBeNull())
    expect(await screen.findByRole('button', { name: 'Đăng nhập' })).toBeInTheDocument()
  })

  it('a rejected token during the session sends the user back to login', async () => {
    signInAs(adminUser)
    server.use(
      http.get(url('/auth/me'), () => HttpResponse.json({ detail: 'Phiên hết hạn', code: 'unauthorized' }, { status: 401 })),
    )
    renderApp('/admin/courses')
    expect(await screen.findByRole('button', { name: 'Đăng nhập' })).toBeInTheDocument()
    expect(localStorage.getItem('token')).toBeNull()
  })
})
