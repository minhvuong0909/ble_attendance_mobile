import { zodResolver } from '@hookform/resolvers/zod'
import { useRef, useState } from 'react'
import { useForm } from 'react-hook-form'
import { toast } from 'sonner'
import { z } from 'zod'
import { ApiError } from '@/api/client'
import { useLeaveRequests, useReviewLeave, type LeaveRequest } from '@/api/leave'
import NativeSelect from '@/components/NativeSelect'
import QueryBoundary from '@/components/QueryBoundary'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { formatDate } from '@/lib/format'

const message = (e: unknown) => (e instanceof ApiError ? e.message : 'Đã xảy ra lỗi không mong muốn')
const schema = z.object({ note: z.string().trim().min(3, 'Vui lòng nhập lý do (ít nhất 3 ký tự)').max(255, 'Lý do tối đa 255 ký tự') })
type Values = z.infer<typeof schema>
const STATUS = { pending: 'Chờ duyệt', approved: 'Đã duyệt', rejected: 'Đã từ chối' } as const

function RejectDialog({ leave, onClose, onSubmit, busy }: { leave: LeaveRequest; onClose: () => void; onSubmit: (note: string) => Promise<void>; busy: boolean }) {
  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<Values>({ resolver: zodResolver(schema), defaultValues: { note: '' } })
  return (
    <Dialog open onOpenChange={(open) => !open && !busy && onClose()}>
      <DialogContent>
        <form onSubmit={handleSubmit((v) => onSubmit(v.note))} className="space-y-4">
          <DialogHeader>
            <DialogTitle>Từ chối đơn của {leave.student_name}</DialogTitle>
          </DialogHeader>
          <div className="space-y-2">
            <Label htmlFor="note">Lý do từ chối</Label>
            <Textarea id="note" {...register('note')} />
            {errors.note && <p className="text-sm text-destructive">{errors.note.message}</p>}
          </div>
          <DialogFooter>
            <Button type="button" variant="outline" disabled={busy} onClick={onClose}>
              Hủy
            </Button>
            <Button type="submit" variant="destructive" disabled={busy}>
              Từ chối đơn
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

export default function LeaveTab({ classId }: { classId: string }) {
  const [filter, setFilter] = useState<'pending' | 'all'>('pending')
  const query = useLeaveRequests(classId, filter === 'pending' ? 'pending' : undefined)
  const review = useReviewLeave(classId)
  const [rejecting, setRejecting] = useState<LeaveRequest | null>(null)
  const inflight = useRef(false)

  async function decide(leave: LeaveRequest, decision: 'approved' | 'rejected', note?: string) {
    if (inflight.current) return
    inflight.current = true
    try {
      await review.mutateAsync({ id: leave.id, decision, note })
      toast.success(decision === 'approved' ? 'Đã duyệt đơn' : 'Đã từ chối đơn')
      setRejecting(null)
    } catch (e) {
      setRejecting(null)
      toast.error(message(e))
    } finally {
      inflight.current = false
    }
  }

  return (
    <div className="space-y-4">
      <div className="max-w-48">
        <NativeSelect aria-label="Lọc đơn" value={filter} onChange={(e) => setFilter(e.target.value as 'pending' | 'all')}>
          <option value="pending">Chờ duyệt</option>
          <option value="all">Tất cả</option>
        </NativeSelect>
      </div>
      <QueryBoundary
        query={query}
        isEmpty={(d) => d.length === 0}
        emptyText={filter === 'pending' ? 'Không có đơn xin phép nào chờ duyệt' : 'Chưa có đơn xin phép nào'}
      >
        {(items) => (
          <ul className="space-y-3">
            {items.map((l) => (
              <li key={l.id} className="space-y-2 rounded-lg border p-4">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <div className="font-medium">
                    {l.student_id} · {l.student_name}
                  </div>
                  <Badge variant={l.status === 'pending' ? 'default' : l.status === 'approved' ? 'secondary' : 'destructive'}>{STATUS[l.status]}</Badge>
                </div>
                <div className="text-sm text-muted-foreground">Nghỉ ngày {formatDate(l.date)}</div>
                <p className="text-sm">{l.reason}</p>
                {l.review_note && <p className="text-sm text-muted-foreground">Ghi chú: {l.review_note}</p>}
                {l.status === 'pending' && (
                  <div className="flex gap-2">
                    <Button size="sm" disabled={review.isPending} onClick={() => void decide(l, 'approved')}>
                      Duyệt
                    </Button>
                    <Button size="sm" variant="outline" disabled={review.isPending} onClick={() => setRejecting(l)}>
                      Từ chối
                    </Button>
                  </div>
                )}
              </li>
            ))}
          </ul>
        )}
      </QueryBoundary>
      {rejecting && (
        <RejectDialog leave={rejecting} busy={review.isPending} onClose={() => setRejecting(null)} onSubmit={(note) => decide(rejecting, 'rejected', note)} />
      )}
    </div>
  )
}
