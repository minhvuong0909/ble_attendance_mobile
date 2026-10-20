import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import type { components } from './types'
import { apiFetch } from './client'

export type LeaveRequest = components['schemas']['LeaveOut']

export const useLeaveRequests = (classId: string, status: 'pending' | undefined) =>
  useQuery({
    queryKey: ['leave-requests', classId, status ?? 'all'],
    queryFn: () => apiFetch<LeaveRequest[]>(`/classes/${classId}/leave-requests`, { query: { status } }),
  })

export function useReviewLeave(classId: string) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (args: { id: number; decision: 'approved' | 'rejected'; note?: string }) =>
      apiFetch<LeaveRequest>(`/leave-requests/${args.id}/review`, {
        method: 'POST',
        json: args.note ? { decision: args.decision, note: args.note } : { decision: args.decision },
      }),
    onSettled: () => qc.invalidateQueries({ queryKey: ['leave-requests', classId] }),
  })
}
