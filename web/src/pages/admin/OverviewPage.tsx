import { BookOpen, Building2, UserX, Users, type LucideIcon } from 'lucide-react'
import { Link } from 'react-router-dom'
import { useAdminClasses, useCourses, useTeachers } from '@/api/admin'
import { useAuth } from '@/auth/AuthProvider'
import { Skeleton } from '@/components/ui/skeleton'

function Stat({ to, icon: Icon, label, value }: { to: string; icon: LucideIcon; label: string; value?: number }) {
  return (
    <Link
      to={to}
      className="flex items-center gap-4 rounded-xl bg-card p-4 shadow-[0_1px_2px_rgb(0_0_0/0.04)] ring-1 ring-foreground/10 transition hover:-translate-y-0.5 hover:ring-primary/40 hover:shadow-md"
    >
      <div className="flex size-11 items-center justify-center rounded-lg bg-accent text-accent-foreground">
        <Icon className="size-5" />
      </div>
      <div>
        {value === undefined ? <Skeleton className="h-7 w-10" /> : <div className="text-2xl font-semibold leading-none">{value}</div>}
        <div className="mt-1 text-sm text-muted-foreground">{label}</div>
      </div>
    </Link>
  )
}

export default function OverviewPage() {
  const { user } = useAuth()
  const courses = useCourses()
  const classes = useAdminClasses()
  const teachers = useTeachers()
  const unassigned = classes.data?.filter((c) => !c.teacher_name) ?? []
  const students = classes.data?.reduce((sum, c) => sum + c.student_count, 0)

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">Tổng quan</h1>
        <p className="text-sm text-muted-foreground">Xin chào {user?.full_name}, đây là tình hình dữ liệu hiện tại của hệ thống.</p>
      </div>
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <Stat to="/admin/courses" icon={BookOpen} label="Môn học" value={courses.data?.length} />
        <Stat to="/admin/classes" icon={Building2} label="Lớp học" value={classes.data?.length} />
        <Stat to="/admin/teachers" icon={Users} label="Giảng viên" value={teachers.data?.length} />
        <Stat to="/admin/classes" icon={UserX} label="Lớp chưa có giảng viên" value={classes.data ? unassigned.length : undefined} />
      </div>
      {students !== undefined && (
        <p className="text-sm text-muted-foreground">Tổng số lượt đăng ký học: {students} sinh viên trên {classes.data?.length} lớp.</p>
      )}
      {unassigned.length > 0 && (
        <div className="rounded-xl bg-card p-4 ring-1 ring-foreground/10">
          <h2 className="mb-2 font-medium">Cần phân công giảng viên</h2>
          <ul className="space-y-1 text-sm">
            {unassigned.slice(0, 5).map((c) => (
              <li key={c.id}>
                <Link className="text-primary hover:underline" to={`/admin/classes/${c.id}`}>
                  {c.course_code} · {c.class_code}
                </Link>{' '}
                <span className="text-muted-foreground">({c.semester})</span>
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  )
}
