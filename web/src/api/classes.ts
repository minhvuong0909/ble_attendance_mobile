import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import type { components } from './types'
import { apiDownload, apiFetch } from './client'

export type Student = components['schemas']['StudentOut']

export const useClassStudents = (classId: string) =>
  useQuery({ queryKey: ['class-students', classId], queryFn: () => apiFetch<Student[]>(`/classes/${classId}/students`) })

export type ClassItem = components['schemas']['ClassOut']

export const useMyClasses = () => useQuery({ queryKey: ['my-classes'], queryFn: () => apiFetch<ClassItem[]>('/classes/mine') })

export const useClass = (classId: string) =>
  useQuery({ queryKey: ['class', classId], queryFn: () => apiFetch<ClassItem>(`/classes/${classId}`) })

export type ClassReport = components['schemas']['ClassReportOut']

export const useClassReport = (classId: string) =>
  useQuery({ queryKey: ['class-report', classId], queryFn: () => apiFetch<ClassReport>(`/classes/${classId}/report`) })

export const downloadClassReport = (classId: string) =>
  apiDownload(`/classes/${classId}/report/export`, 'bao_cao_lop.xlsx')

export function useUpdateRssi(classId: string) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (rssi_threshold: number) =>
      apiFetch<ClassItem>(`/classes/${classId}/rssi`, { method: 'PATCH', json: { rssi_threshold } }),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ['class', classId] })
      void qc.invalidateQueries({ queryKey: ['my-classes'] })
    },
  })
}
