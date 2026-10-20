import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { NOTIFICATION_POLL_MS } from '@/lib/constants'
import type { components } from './types'
import { apiFetch } from './client'

export type AppNotification = components['schemas']['NotificationOut']

export const useUnreadCount = () =>
  useQuery({
    queryKey: ['unread-count'],
    queryFn: async () => (await apiFetch<{ count: number }>('/notifications/unread-count')).count,
    refetchInterval: NOTIFICATION_POLL_MS,
  })

export const useNotifications = () =>
  useQuery({ queryKey: ['notifications'], queryFn: () => apiFetch<AppNotification[]>('/notifications') })

function useRefreshNotifications() {
  const qc = useQueryClient()
  return () => {
    void qc.invalidateQueries({ queryKey: ['notifications'] })
    void qc.invalidateQueries({ queryKey: ['unread-count'] })
  }
}

export function useMarkRead() {
  const refresh = useRefreshNotifications()
  return useMutation({
    mutationFn: (id: number) => apiFetch<unknown>(`/notifications/${id}/read`, { method: 'POST' }),
    onSuccess: refresh,
  })
}

export function useMarkAllRead() {
  const refresh = useRefreshNotifications()
  return useMutation({
    mutationFn: () => apiFetch<unknown>('/notifications/read-all', { method: 'POST' }),
    onSuccess: refresh,
  })
}
