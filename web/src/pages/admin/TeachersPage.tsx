import { zodResolver } from '@hookform/resolvers/zod'
import { KeyRound, UserPlus } from 'lucide-react'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { toast } from 'sonner'
import { z } from 'zod'
import { useCreateTeacher, useResetPassword, useTeachers } from '@/api/admin'
import type { User } from '@/api/auth'
import { ApiError } from '@/api/client'
import ConfirmDialog from '@/components/ConfirmDialog'
import DataTable from '@/components/DataTable'
import QueryBoundary from '@/components/QueryBoundary'
import TempPasswordDialog from '@/components/TempPasswordDialog'
import { Button } from '@/components/ui/button'
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'

const schema = z.object({
  teacher_id: z.string().trim().min(3, 'Mã giảng viên từ 3 đến 16 ký tự').max(16, 'Mã giảng viên từ 3 đến 16 ký tự'),
  full_name: z.string().trim().min(2, 'Họ tên từ 2 đến 120 ký tự').max(120, 'Họ tên từ 2 đến 120 ký tự'),
})
type Values = z.infer<typeof schema>

function TeacherDialog({ onClose, onCreated }: { onClose: () => void; onCreated: (user: User) => void }) {
  const create = useCreateTeacher()
  const [error, setError] = useState<string | null>(null)
  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<Values>({ resolver: zodResolver(schema), defaultValues: { teacher_id: '', full_name: '' } })

  async function onSubmit(values: Values) {
    if (create.isPending) return
    setError(null)
    try {
      const user = await create.mutateAsync({ teacher_id: values.teacher_id.toUpperCase(), full_name: values.full_name })
      onCreated(user)
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Đã xảy ra lỗi không mong muốn')
    }
  }

  return (
    <Dialog open onOpenChange={(open) => !open && !create.isPending && onClose()}>
      <DialogContent>
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
          <DialogHeader>
            <DialogTitle>Thêm giảng viên</DialogTitle>
          </DialogHeader>
          <div className="space-y-2">
            <Label htmlFor="teacher_id">Mã giảng viên</Label>
            <Input id="teacher_id" placeholder="Ví dụ T002" {...register('teacher_id')} />
            {errors.teacher_id && <p className="text-sm text-destructive">{errors.teacher_id.message}</p>}
          </div>
          <div className="space-y-2">
            <Label htmlFor="full_name">Họ và tên</Label>
            <Input id="full_name" {...register('full_name')} />
            {errors.full_name && <p className="text-sm text-destructive">{errors.full_name.message}</p>}
          </div>
          {error && (
            <p role="alert" className="text-sm text-destructive">
              {error}
            </p>
          )}
          <DialogFooter>
            <Button type="button" variant="outline" disabled={create.isPending} onClick={onClose}>
              Hủy
            </Button>
            <Button type="submit" disabled={create.isPending}>
              Tạo
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

export default function TeachersPage() {
  const query = useTeachers()
  const reset = useResetPassword()
  const [creating, setCreating] = useState(false)
  const [resetting, setResetting] = useState<User | null>(null)
  const [notice, setNotice] = useState<{ loginId: string; name: string } | null>(null)

  async function confirmReset() {
    if (!resetting || reset.isPending) return
    const target = resetting
    try {
      await reset.mutateAsync(target.id)
      setResetting(null)
      setNotice({ loginId: target.teacher_id ?? '', name: target.full_name })
    } catch (e) {
      setResetting(null)
      toast.error(e instanceof ApiError ? e.message : 'Đã xảy ra lỗi không mong muốn')
    }
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Giảng viên</h1>
        <Button onClick={() => setCreating(true)}>
          <UserPlus /> Thêm giảng viên
        </Button>
      </div>
      <QueryBoundary query={query} isEmpty={(d) => d.length === 0} emptyText="Chưa có giảng viên nào">
        {(teachers) => (
          <DataTable
            rows={teachers}
            rowKey={(t) => t.id}
            columns={[
              { header: 'Mã', cell: (t) => t.teacher_id },
              { header: 'Họ và tên', cell: (t) => t.full_name },
              {
                header: 'Thao tác',
                className: 'w-24 text-right',
                cell: (t) => (
                  <Button variant="ghost" size="icon" aria-label={`Đặt lại mật khẩu ${t.teacher_id}`} onClick={() => setResetting(t)}>
                    <KeyRound />
                  </Button>
                ),
              },
            ]}
          />
        )}
      </QueryBoundary>
      {creating && (
        <TeacherDialog
          onClose={() => setCreating(false)}
          onCreated={(user) => {
            setCreating(false)
            setNotice({ loginId: user.teacher_id ?? '', name: user.full_name })
          }}
        />
      )}
      <ConfirmDialog
        open={!!resetting}
        onOpenChange={(open) => !open && setResetting(null)}
        title="Đặt lại mật khẩu?"
        description={`Mật khẩu của ${resetting?.full_name ?? ''} sẽ trở về mã đăng nhập và họ phải đổi khi đăng nhập.`}
        confirmLabel="Đặt lại"
        busy={reset.isPending}
        onConfirm={() => void confirmReset()}
      />
      <TempPasswordDialog open={!!notice} loginId={notice?.loginId ?? ''} name={notice?.name ?? ''} onClose={() => setNotice(null)} />
    </div>
  )
}
