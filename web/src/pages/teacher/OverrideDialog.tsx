import { zodResolver } from '@hookform/resolvers/zod'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { toast } from 'sonner'
import { z } from 'zod'
import { ApiError } from '@/api/client'
import { useOverrideAttendance, type AttendanceRecord } from '@/api/sessions'
import NativeSelect from '@/components/NativeSelect'
import { Button } from '@/components/ui/button'
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'

const schema = z.object({
  status: z.enum(['present', 'absent', 'excused']),
  reason: z.string().trim().min(3, 'Lý do cần ít nhất 3 ký tự').max(255, 'Lý do tối đa 255 ký tự'),
})
type Values = z.infer<typeof schema>

export default function OverrideDialog({ sessionId, record, onClose }: { sessionId: string; record: AttendanceRecord; onClose: () => void }) {
  const override = useOverrideAttendance(sessionId)
  const [error, setError] = useState<string | null>(null)
  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<Values>({ resolver: zodResolver(schema), defaultValues: { status: record.status, reason: '' } })

  async function onSubmit(values: Values) {
    if (override.isPending) return
    setError(null)
    try {
      await override.mutateAsync({ student_user_id: record.student_user_id, status: values.status, reason: values.reason })
      toast.success('Đã lưu chỉnh tay')
      onClose()
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Đã xảy ra lỗi không mong muốn')
    }
  }

  return (
    <Dialog open onOpenChange={(open) => !open && !override.isPending && onClose()}>
      <DialogContent>
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
          <DialogHeader>
            <DialogTitle>Chỉnh tay điểm danh</DialogTitle>
            <DialogDescription>
              {record.student_id} · {record.student_name}
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-2">
            <Label htmlFor="status">Trạng thái</Label>
            <NativeSelect id="status" {...register('status')}>
              <option value="present">Có mặt</option>
              <option value="absent">Vắng</option>
              <option value="excused">Có phép</option>
            </NativeSelect>
          </div>
          <div className="space-y-2">
            <Label htmlFor="reason">Lý do</Label>
            <Textarea id="reason" {...register('reason')} />
            {errors.reason && <p className="text-sm text-destructive">{errors.reason.message}</p>}
          </div>
          {error && (
            <p role="alert" className="text-sm text-destructive">
              {error}
            </p>
          )}
          <DialogFooter>
            <Button type="button" variant="outline" disabled={override.isPending} onClick={onClose}>
              Hủy
            </Button>
            <Button type="submit" disabled={override.isPending}>
              Lưu
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
