import { http, HttpResponse } from 'msw'
import { server } from './server'

export const url = (path: string) => `${window.location.origin}${path}`

export interface TestUser {
  id: string
  full_name: string
  role: 'admin' | 'teacher' | 'student'
  student_id: string | null
  teacher_id: string | null
  must_change_password: boolean
}

export const adminUser: TestUser = {
  id: 'u-admin',
  full_name: 'Quản trị viên',
  role: 'admin',
  student_id: null,
  teacher_id: 'A001',
  must_change_password: false,
}
export const teacherUser: TestUser = {
  id: 'u-teacher',
  full_name: 'Giảng viên Demo',
  role: 'teacher',
  student_id: null,
  teacher_id: 'T001',
  must_change_password: false,
}
export const studentUser: TestUser = {
  id: 'u-student',
  full_name: 'Sinh viên A',
  role: 'student',
  student_id: '25CE099',
  teacher_id: null,
  must_change_password: false,
}

/** Đặt sẵn phiên đăng nhập và trả về người dùng cho GET /auth/me. */
export function signInAs(user: TestUser) {
  localStorage.setItem('token', `token-${user.id}`)
  server.use(http.get(url('/auth/me'), () => HttpResponse.json(user)))
}

/** Đăng nhập thành công bằng mật khẩu bất kỳ; /auth/me trả về [user] sau khi có token. */
export function loginAs(user: TestUser) {
  server.use(
    http.post(url('/auth/login'), () =>
      HttpResponse.json({
        access_token: `token-${user.id}`,
        token_type: 'bearer',
        must_change_password: user.must_change_password,
      }),
    ),
    http.get(url('/auth/me'), () => HttpResponse.json(user)),
  )
}
