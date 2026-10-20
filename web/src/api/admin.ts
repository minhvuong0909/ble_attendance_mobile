import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import type { components } from './types'
import { apiFetch } from './client'
import type { User } from './auth'

export type Course = components['schemas']['CourseOut']
export type CourseInput = components['schemas']['CourseIn']
export type CourseUpdate = components['schemas']['CourseUpdate']

export const useCourses = () => useQuery({ queryKey: ['courses'], queryFn: () => apiFetch<Course[]>('/admin/courses') })

export function useSaveCourse() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (args: { id?: string; data: CourseInput | CourseUpdate }) =>
      args.id
        ? apiFetch<Course>(`/admin/courses/${args.id}`, { method: 'PATCH', json: args.data })
        : apiFetch<Course>('/admin/courses', { method: 'POST', json: args.data }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['courses'] }),
  })
}

export function useDeleteCourse() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (id: string) => apiFetch<void>(`/admin/courses/${id}`, { method: 'DELETE' }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['courses'] }),
  })
}

export const useTeachers = () => useQuery({ queryKey: ['teachers'], queryFn: () => apiFetch<User[]>('/admin/teachers') })

export function useCreateTeacher() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (data: components['schemas']['TeacherCreate']) =>
      apiFetch<User>('/admin/teachers', { method: 'POST', json: data }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['teachers'] }),
  })
}

export const useResetPassword = () =>
  useMutation({ mutationFn: (userId: string) => apiFetch<{ message: string }>(`/admin/users/${userId}/reset-password`, { method: 'POST' }) })
