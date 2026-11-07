import { zodResolver } from '@hookform/resolvers/zod'
import { Plus } from 'lucide-react'
import { useMemo, useState } from 'react'
import { useForm } from 'react-hook-form'
import { Link } from 'react-router-dom'
import { z } from 'zod'
import { useAdminClasses, useCourses, useCreateClass, useTeachers } from '@/api/admin'
import { ApiError } from '@/api/client'
import DataTable from '@/components/DataTable'
import NativeSelect from '@/components/NativeSelect'
import QueryBoundary from '@/components/QueryBoundary'
import { Button } from '@/components/ui/button'
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'

const integer = (min: number, max: number, message: string) =>
  z.string().trim().refine((v) => /^-?\d+$/.test(v) && Number(v) >= min && Number(v) <= max, message)

const schema = z.object({
  course_id: z.string().min(1, 'Vui lòng chọn môn học'),
  class_code: z.string().trim().min(1, 'Mã lớp không được trống').max(32, 'Mã lớp tối đa 32 ký tự'),
  semester: z.string().trim().min(2, 'Học kỳ từ 2 đến 32 ký tự').max(32, 'Học kỳ từ 2 đến 32 ký tự'),
  teacher_user_id: z.string(),
  max_absence_percent: integer(0, 100, 'Tỷ lệ vắng tối đa từ 0 đến 100'),
  rssi_threshold: integer(-100, -30, 'Ngưỡng RSSI từ -100 đến -30'),
})
type Values = z.infer<typeof schema>

function Field({ id, label, error, children }: { id: string; label: string; error?: string; children: React.ReactNode }) {
  return (
    <div className="space-y-2">
      <Label htmlFor={id}>{label}</Label>
      {children}
      {error && <p className="text-sm text-destructive">{error}</p>}
    </div>
  )
}

function CreateClassDialog({ onClose }: { onClose: () => void }) {
  const courses = useCourses()
  const teachers = useTeachers()
  const create = useCreateClass()
  const [error, setError] = useState<string | null>(null)
  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<Values>({
    resolver: zodResolver(schema),
    defaultValues: {
      course_id: '',
      class_code: '',
      semester: '',
      teacher_user_id: '',
      max_absence_percent: '20',
      rssi_threshold: '-75',
    },
  })

  async function onSubmit(v: Values) {
    if (create.isPending) return
    setError(null)
    try {
      await create.mutateAsync({
        course_id: v.course_id,
        class_code: v.class_code.toUpperCase(),
        semester: v.semester,
        teacher_user_id: v.teacher_user_id || undefined,
        max_absence_percent: Number(v.max_absence_percent),
        rssi_threshold: Number(v.rssi_threshold),
      })
      onClose()
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Đã xảy ra lỗi không mong muốn')
    }
  }

  return (
    <Dialog open onOpenChange={(open) => !open && !create.isPending && onClose()}>
      <DialogContent>
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
          <DialogHeader>
            <DialogTitle>Thêm lớp học</DialogTitle>
          </DialogHeader>
          <Field id="course_id" label="Môn học" error={errors.course_id?.message}>
            <NativeSelect id="course_id" {...register('course_id')}>
              <option value="">— Chọn môn —</option>
              {courses.data?.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.code} · {c.name}
                </option>
              ))}
            </NativeSelect>
          </Field>
          <div className="grid grid-cols-2 gap-3">
            <Field id="class_code" label="Mã lớp" error={errors.class_code?.message}>
              <Input id="class_code" {...register('class_code')} />
            </Field>
            <Field id="semester" label="Học kỳ" error={errors.semester?.message}>
              <Input id="semester" placeholder="FA26" {...register('semester')} />
            </Field>
          </div>
          <Field id="teacher_user_id" label="Giảng viên">
            <NativeSelect id="teacher_user_id" {...register('teacher_user_id')}>
              <option value="">— Chưa gán —</option>
              {teachers.data?.map((t) => (
                <option key={t.id} value={t.id}>
                  {t.teacher_id} · {t.full_name}
                </option>
              ))}
            </NativeSelect>
          </Field>
          <div className="grid grid-cols-2 gap-3">
            <Field id="max_absence_percent" label="Vắng tối đa (%)" error={errors.max_absence_percent?.message}>
              <Input id="max_absence_percent" inputMode="numeric" {...register('max_absence_percent')} />
            </Field>
            <Field id="rssi_threshold" label="Ngưỡng RSSI (dBm)" error={errors.rssi_threshold?.message}>
              <Input id="rssi_threshold" inputMode="numeric" {...register('rssi_threshold')} />
            </Field>
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
              Tạo lớp
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

export default function ClassesPage() {
  const query = useAdminClasses()
  const courses = useCourses()
  const [courseId, setCourseId] = useState('')
  const [creating, setCreating] = useState(false)
  const rows = useMemo(() => (query.data ?? []).filter((c) => !courseId || c.course_id === courseId), [query.data, courseId])

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h1 className="text-2xl font-semibold">Lớp học</h1>
        <div className="flex items-center gap-2">
          <div className="w-56">
            <NativeSelect aria-label="Lọc theo môn" value={courseId} onChange={(e) => setCourseId(e.target.value)}>
              <option value="">Tất cả môn</option>
              {courses.data?.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.code}
                </option>
              ))}
            </NativeSelect>
          </div>
          <Button onClick={() => setCreating(true)}>
            <Plus /> Thêm lớp
          </Button>
        </div>
      </div>
      <QueryBoundary query={query} isEmpty={() => rows.length === 0} emptyText="Chưa có lớp học nào">
        {() => (
          <DataTable
            rows={rows}
            rowKey={(c) => c.id}
            columns={[
              {
                header: 'Lớp',
                cell: (c) => (
                  <Link className="font-medium text-primary underline-offset-4 hover:underline" to={`/admin/classes/${c.id}`}>
                    {c.class_code}
                  </Link>
                ),
              },
              { header: 'Môn', cell: (c) => `${c.course_code} · ${c.course_name}` },
              { header: 'Học kỳ', cell: (c) => c.semester },
              { header: 'Giảng viên', cell: (c) => c.teacher_name ?? <span className="text-muted-foreground">Chưa gán</span> },
              { header: 'Sinh viên', cell: (c) => c.student_count, className: 'text-right' },
            ]}
          />
        )}
      </QueryBoundary>
      {creating && <CreateClassDialog onClose={() => setCreating(false)} />}
    </div>
  )
}
