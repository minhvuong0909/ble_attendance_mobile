import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import type { components } from './types'
import { POLL_MS } from '@/lib/constants'
import { ApiError, apiDownload, apiFetch } from './client'

export type Session = components['schemas']['SessionOut']

export const useClassSessions = (classId: string | undefined) =>
  useQuery({
    queryKey: ['class-sessions', classId],
    queryFn: () => apiFetch<Session[]>(`/classes/${classId}/sessions`),
    enabled: !!classId,
  })

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

export type SessionAttendance = components['schemas']['SessionAttendanceOut']
export type AttendanceRecord = components['schemas']['AttendanceRecordOut']
export type AttendanceStatus = components['schemas']['AttendanceStatus']

/** Buổi đang diễn ra của giảng viên (null nếu không có); tự làm mới. */
export const useActiveSession = () =>
  useQuery({
    queryKey: ['active-session'],
    queryFn: async () => {
      try {
        return await apiFetch<Session>('/sessions/active')
      } catch (e) {
        if (e instanceof ApiError && e.code === 'no_active_session') return null
        throw e
      }
    },
    refetchInterval: POLL_MS,
  })

export const useSessionAttendance = (sessionId: string, live: boolean) =>
  useQuery({
    queryKey: ['session-attendance', sessionId],
    queryFn: () => apiFetch<SessionAttendance>(`/sessions/${sessionId}/attendance`),
    refetchInterval: live ? POLL_MS : false,
  })

export function useOpenFinalization(sessionId: string) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: () => apiFetch<Session>(`/sessions/${sessionId}/open-finalization`, { method: 'POST' }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['active-session'] }),
  })
}

export function useEndSession(sessionId: string) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: () => apiFetch<Session>(`/sessions/${sessionId}/end`, { method: 'POST' }),
    onSuccess: (ended) => {
      qc.setQueryData(['active-session'], null)
      void qc.invalidateQueries({ queryKey: ['class-sessions', ended.class_id] })
      void qc.invalidateQueries({ queryKey: ['session-attendance', sessionId] })
      void qc.invalidateQueries({ queryKey: ['class-report', ended.class_id] })
    },
  })
}

export function useOverrideAttendance(sessionId: string) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (data: components['schemas']['OverrideIn']) =>
      apiFetch<components['schemas']['OverrideOut']>(`/sessions/${sessionId}/attendance/override`, { method: 'POST', json: data }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['session-attendance', sessionId] }),
  })
}

export const downloadSessionExport = (sessionId: string) =>
  apiDownload(`/sessions/${sessionId}/export`, 'buoi_hoc.xlsx')
