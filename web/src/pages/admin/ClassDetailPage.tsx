import { zodResolver } from '@hookform/resolvers/zod'
import { Trash2, Upload } from 'lucide-react'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { toast } from 'sonner'
import { z } from 'zod'
import {
  useAdminClasses,
  useAssignTeacher,
  useDeleteClass,
  useTeachers,
  useUpdateClass,
  type ClassItem,
  type ClassUpdate,
} from '@/api/admin'
import { useClassStudents } from '@/api/classes'
import { ApiError } from '@/api/client'
import ConfirmDialog from '@/components/ConfirmDialog'
import DataTable from '@/components/DataTable'
import NativeSelect from '@/components/NativeSelect'
import QueryBoundary from '@/components/QueryBoundary'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'

const message = (e: unknown) => (e instanceof ApiError ? e.message : 'Đã xảy ra lỗi không mong muốn')

const integer = (min: number, max: number, text: string) =>
  z.string().trim().refine((v) => /^-?\d+$/.test(v) && Number(v) >= min && Number(v) <= max, text)

const schema = z.object({
  class_code: z.string().trim().min(1, 'Mã lớp không được trống').max(32, 'Mã lớp tối đa 32 ký tự'),
  semester: z.string().trim().min(2, 'Học kỳ từ 2 đến 32 ký tự').max(32, 'Học kỳ từ 2 đến 32 ký tự'),
  max_absence_percent: integer(0, 100, 'Tỷ lệ vắng tối đa từ 0 đến 100'),
  rssi_threshold: integer(-100, -30, 'Ngưỡng RSSI từ -100 đến -30'),
})
type Values = z.infer<typeof schema>

const valuesOf = (c: ClassItem): Values => ({
  class_code: c.class_code,
  semester: c.semester,
  max_absence_percent: String(c.max_absence_percent),
  rssi_threshold: String(c.rssi_threshold),
})

function SettingsForm({ cls }: { cls: ClassItem }) {
  const update = useUpdateClass(cls.id)
  const [error, setError] = useState<string | null>(null)
  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isDirty },
  } = useForm<Values>({ resolver: zodResolver(schema), defaultValues: valuesOf(cls) })

  async function onSubmit(v: Values) {
    if (update.isPending) return
    setError(null)
    const patch: ClassUpdate = {}
    if (v.class_code.toUpperCase() !== cls.class_code) patch.class_code = v.class_code.toUpperCase()
    if (v.semester !== cls.semester) patch.semester = v.semester
    if (Number(v.max_absence_percent) !== cls.max_absence_percent) patch.max_absence_percent = Number(v.max_absence_percent)
    if (Number(v.rssi_threshold) !== cls.rssi_threshold) patch.rssi_threshold = Number(v.rssi_threshold)
    if (Object.keys(patch).length === 0) return
    try {
      const saved = await update.mutateAsync(patch)
      reset(valuesOf(saved))
      toast.success('Đã lưu cấu hình')
    } catch (e) {
      setError(message(e))
    }
  }

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-4 rounded-lg border p-4">
      <h2 className="font-semibold">Cấu hình lớp</h2>
      <div className="grid gap-3 sm:grid-cols-2">
        <FieldBox id="class_code" label="Mã lớp" error={errors.class_code?.message}>
          <Input id="class_code" {...register('class_code')} />
        </FieldBox>
        <FieldBox id="semester" label="Học kỳ" error={errors.semester?.message}>
          <Input id="semester" {...register('semester')} />
        </FieldBox>
        <FieldBox id="max_absence_percent" label="Vắng tối đa (%)" error={errors.max_absence_percent?.message}>
          <Input id="max_absence_percent" inputMode="numeric" {...register('max_absence_percent')} />
        </FieldBox>
        <FieldBox id="rssi_threshold" label="Ngưỡng RSSI (dBm)" error={errors.rssi_threshold?.message}>
          <Input id="rssi_threshold" inputMode="numeric" {...register('rssi_threshold')} />
        </FieldBox>
      </div>
      {error && (
        <p role="alert" className="text-sm text-destructive">
          {error}
        </p>
      )}
      <Button type="submit" disabled={!isDirty || update.isPending}>
        Lưu cấu hình
      </Button>
    </form>
  )
}

function FieldBox({ id, label, error, children }: { id: string; label: string; error?: string; children: React.ReactNode }) {
  return (
    <div className="space-y-2">
      <Label htmlFor={id}>{label}</Label>
      {children}
      {error && <p className="text-sm text-destructive">{error}</p>}
    </div>
  )
}

function AssignTeacher({ cls }: { cls: ClassItem }) {
  const teachers = useTeachers()
  const assign = useAssignTeacher(cls.id)
  const [teacherId, setTeacherId] = useState(cls.teacher_user_id ?? '')

  async function submit() {
    if (!teacherId || assign.isPending) return
    try {
      await assign.mutateAsync(teacherId)
      toast.success('Đã gán giảng viên')
    } catch (e) {
      toast.error(message(e))
    }
  }

  return (
    <div className="space-y-3 rounded-lg border p-4">
      <h2 className="font-semibold">Giảng viên</h2>
      <p className="text-sm text-muted-foreground">Hiện tại: {cls.teacher_name ?? 'Chưa gán'}</p>
      <div className="flex gap-2">
        <div className="flex-1 space-y-2">
          <Label htmlFor="assign">Giảng viên phụ trách</Label>
          <NativeSelect id="assign" value={teacherId} onChange={(e) => setTeacherId(e.target.value)}>
            <option value="">— Chọn giảng viên —</option>
            {teachers.data?.map((t) => (
              <option key={t.id} value={t.id}>
                {t.teacher_id} · {t.full_name}
              </option>
            ))}
          </NativeSelect>
        </div>
        <Button className="self-end" disabled={!teacherId || assign.isPending} onClick={() => void submit()}>
          Gán giảng viên
        </Button>
      </div>
    </div>
  )
}

function Roster({ classId }: { classId: string }) {
  const query = useClassStudents(classId)
  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <h2 className="font-semibold">Sinh viên</h2>
        <Button variant="outline" size="sm" render={<Link to={`/admin/import?kind=students&classId=${classId}`} />}>
          <Upload /> Nhập danh sách sinh viên
        </Button>
      </div>
      <QueryBoundary query={query} isEmpty={(d) => d.length === 0} emptyText="Lớp chưa có sinh viên">
        {(rows) => (
          <DataTable
            rows={rows}
            rowKey={(s) => s.id}
            columns={[
              { header: 'MSSV', cell: (s) => s.student_id },
              { header: 'Họ và tên', cell: (s) => s.full_name },
            ]}
          />
        )}
      </QueryBoundary>
    </div>
  )
}

function ClassDetail({ cls }: { cls: ClassItem }) {
  const navigate = useNavigate()
  const remove = useDeleteClass(cls.id)
  const [confirming, setConfirming] = useState(false)

  async function confirmDelete() {
    if (remove.isPending) return
    try {
      await remove.mutateAsync()
      navigate('/admin/classes', { replace: true })
    } catch (e) {
      setConfirming(false)
      toast.error(message(e))
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div>
          <h1 className="text-2xl font-semibold">
            {cls.course_code} · {cls.class_code}
          </h1>
          <p className="text-sm text-muted-foreground">
            {cls.course_name} · {cls.semester} · {cls.student_count} sinh viên
          </p>
        </div>
        <Button variant="destructive" onClick={() => setConfirming(true)}>
          <Trash2 /> Xóa lớp
        </Button>
      </div>
      <div className="grid gap-4 lg:grid-cols-2">
        <SettingsForm key={`${cls.class_code}-${cls.semester}-${cls.max_absence_percent}-${cls.rssi_threshold}`} cls={cls} />
        <AssignTeacher key={cls.teacher_user_id ?? 'none'} cls={cls} />
      </div>
      <Roster classId={cls.id} />
      <ConfirmDialog
        open={confirming}
        onOpenChange={setConfirming}
        title="Xóa lớp học?"
        description="Chỉ xóa được lớp chưa có sinh viên hoặc buổi học."
        confirmLabel="Xóa"
        destructive
        busy={remove.isPending}
        onConfirm={() => void confirmDelete()}
      />
    </div>
  )
}

export default function AdminClassDetailPage() {
  const { classId } = useParams()
  const query = useAdminClasses()
  return (
    <QueryBoundary query={query}>
      {(classes) => {
        const cls = classes.find((c) => c.id === classId)
        return cls ? <ClassDetail cls={cls} /> : <p className="text-muted-foreground">Không tìm thấy lớp học</p>
      }}
    </QueryBoundary>
  )
}
