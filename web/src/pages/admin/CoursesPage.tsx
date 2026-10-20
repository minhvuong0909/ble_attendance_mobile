import { zodResolver } from '@hookform/resolvers/zod'
import { Pencil, Plus, Trash2 } from 'lucide-react'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { toast } from 'sonner'
import { z } from 'zod'
import { useCourses, useDeleteCourse, useSaveCourse, type Course } from '@/api/admin'
import { ApiError } from '@/api/client'
import ConfirmDialog from '@/components/ConfirmDialog'
import DataTable from '@/components/DataTable'
import QueryBoundary from '@/components/QueryBoundary'
import { Button } from '@/components/ui/button'
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'

const schema = z.object({
  code: z.string().trim().min(2, 'Mã môn từ 2 đến 32 ký tự').max(32, 'Mã môn từ 2 đến 32 ký tự'),
  name: z.string().trim().min(2, 'Tên môn từ 2 đến 120 ký tự').max(120, 'Tên môn từ 2 đến 120 ký tự'),
  credits: z
    .string()
    .trim()
    .refine((v) => v === '' || (/^\d+$/.test(v) && Number(v) <= 30), 'Số tín chỉ từ 0 đến 30'),
})
type Values = z.infer<typeof schema>

function CourseDialog({ course, onClose }: { course: Course | null; onClose: () => void }) {
  const save = useSaveCourse()
  const [error, setError] = useState<string | null>(null)
  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<Values>({
    resolver: zodResolver(schema),
    defaultValues: { code: course?.code ?? '', name: course?.name ?? '', credits: course?.credits?.toString() ?? '' },
  })

  async function onSubmit(values: Values) {
    if (save.isPending) return
    setError(null)
    const credits = values.credits === '' ? undefined : Number(values.credits)
    try {
      if (course) await save.mutateAsync({ id: course.id, data: { name: values.name, credits } })
      else await save.mutateAsync({ data: { code: values.code.toUpperCase(), name: values.name, credits } })
      onClose()
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Đã xảy ra lỗi không mong muốn')
    }
  }

  return (
    <Dialog open onOpenChange={(open) => !open && !save.isPending && onClose()}>
      <DialogContent>
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
          <DialogHeader>
            <DialogTitle>{course ? 'Sửa môn học' : 'Thêm môn học'}</DialogTitle>
          </DialogHeader>
          <div className="space-y-2">
            <Label htmlFor="code">Mã môn</Label>
            <Input id="code" disabled={!!course} {...register('code')} />
            {errors.code && <p className="text-sm text-destructive">{errors.code.message}</p>}
          </div>
          <div className="space-y-2">
            <Label htmlFor="name">Tên môn</Label>
            <Input id="name" {...register('name')} />
            {errors.name && <p className="text-sm text-destructive">{errors.name.message}</p>}
          </div>
          <div className="space-y-2">
            <Label htmlFor="credits">Số tín chỉ</Label>
            <Input id="credits" inputMode="numeric" {...register('credits')} />
            {errors.credits && <p className="text-sm text-destructive">{errors.credits.message}</p>}
          </div>
          {error && (
            <p role="alert" className="text-sm text-destructive">
              {error}
            </p>
          )}
          <DialogFooter>
            <Button type="button" variant="outline" disabled={save.isPending} onClick={onClose}>
              Hủy
            </Button>
            <Button type="submit" disabled={save.isPending}>
              Lưu
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

export default function CoursesPage() {
  const query = useCourses()
  const remove = useDeleteCourse()
  const [editing, setEditing] = useState<Course | 'new' | null>(null)
  const [deleting, setDeleting] = useState<Course | null>(null)

  async function confirmDelete() {
    if (!deleting || remove.isPending) return
    try {
      await remove.mutateAsync(deleting.id)
      setDeleting(null)
    } catch (e) {
      setDeleting(null)
      toast.error(e instanceof ApiError ? e.message : 'Đã xảy ra lỗi không mong muốn')
    }
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Môn học</h1>
        <Button onClick={() => setEditing('new')}>
          <Plus /> Thêm môn
        </Button>
      </div>
      <QueryBoundary query={query} isEmpty={(d) => d.length === 0} emptyText="Chưa có môn học nào">
        {(courses) => (
          <DataTable
            rows={courses}
            rowKey={(c) => c.id}
            columns={[
              { header: 'Mã môn', cell: (c) => c.code },
              { header: 'Tên môn', cell: (c) => c.name },
              { header: 'Tín chỉ', cell: (c) => c.credits ?? '—' },
              {
                header: 'Thao tác',
                className: 'w-28 text-right',
                cell: (c) => (
                  <div className="flex justify-end gap-1">
                    <Button variant="ghost" size="icon" aria-label={`Sửa ${c.code}`} onClick={() => setEditing(c)}>
                      <Pencil />
                    </Button>
                    <Button variant="ghost" size="icon" aria-label={`Xóa ${c.code}`} onClick={() => setDeleting(c)}>
                      <Trash2 />
                    </Button>
                  </div>
                ),
              },
            ]}
          />
        )}
      </QueryBoundary>
      {editing && <CourseDialog course={editing === 'new' ? null : editing} onClose={() => setEditing(null)} />}
      <ConfirmDialog
        open={!!deleting}
        onOpenChange={(open) => !open && setDeleting(null)}
        title="Xóa môn học?"
        description={`Môn ${deleting?.code ?? ''} sẽ bị xóa. Môn đang có lớp không thể xóa.`}
        confirmLabel="Xóa"
        destructive
        busy={remove.isPending}
        onConfirm={() => void confirmDelete()}
      />
    </div>
  )
}
