import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import type { components } from './types'
import { apiFetch } from './client'

export type Session = components['schemas']['SessionOut']

export const useClassSessions = (classId: string) =>
  useQuery({ queryKey: ['class-sessions', classId], queryFn: () => apiFetch<Session[]>(`/classes/${classId}/sessions`) })

export function useStartSession(classId: string) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: () => apiFetch<Session>(`/classes/${classId}/sessions`, { method: 'POST' }),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ['class-sessions', classId] })
      void qc.invalidateQueries({ queryKey: ['active-session'] })
    },
  })
}
