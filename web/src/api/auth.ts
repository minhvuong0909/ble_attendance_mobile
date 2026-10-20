import type { components } from './types'
import { apiFetch } from './client'

export type User = components['schemas']['UserOut']
export type Role = User['role']

export const loginRequest = (identifier: string, password: string) =>
  apiFetch<components['schemas']['TokenResponse']>('/auth/login', { method: 'POST', json: { identifier, password } })

export const fetchMe = () => apiFetch<User>('/auth/me')

export const changePasswordRequest = (oldPassword: string, newPassword: string) =>
  apiFetch<unknown>('/auth/change-password', {
    method: 'POST',
    json: { old_password: oldPassword, new_password: newPassword },
  })

export const homePathFor = (role: Role): string =>
  role === 'admin' ? '/admin/courses' : role === 'teacher' ? '/teacher/classes' : '/student'
