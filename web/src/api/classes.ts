import { useQuery } from '@tanstack/react-query'
import type { components } from './types'
import { apiFetch } from './client'

export type Student = components['schemas']['StudentOut']

export const useClassStudents = (classId: string) =>
  useQuery({ queryKey: ['class-students', classId], queryFn: () => apiFetch<Student[]>(`/classes/${classId}/students`) })
