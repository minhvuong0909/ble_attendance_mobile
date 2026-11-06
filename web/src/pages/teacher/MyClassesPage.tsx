import { Link } from 'react-router-dom'
import { useMyClasses } from '@/api/classes'
import { useAuth } from '@/auth/AuthProvider'
import QueryBoundary from '@/components/QueryBoundary'

export default function MyClassesPage() {
  const query = useMyClasses()
  const { user } = useAuth()
  const firstName = user?.full_name.trim().split(' ').pop()
  return (
    <div className="space-y-4">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">Lớp của tôi</h1>
        {firstName && <p className="text-sm text-muted-foreground">Chào thầy/cô {firstName}, đây là các lớp bạn đang phụ trách.</p>}
      </div>
      <QueryBoundary query={query} isEmpty={(d) => d.length === 0} emptyText="Bạn chưa được phân công lớp nào. Hãy liên hệ admin.">
        {(classes) => (
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {classes.map((c) => (
              <Link key={c.id} to={`/teacher/classes/${c.id}`} className="rounded-xl bg-card p-4 shadow-[0_1px_2px_rgb(0_0_0/0.04)] ring-1 ring-foreground/10 transition hover:-translate-y-0.5 hover:ring-primary/40 hover:shadow-md">
                <div className="font-semibold">
                  {c.course_code} · {c.class_code}
                </div>
                <div className="text-sm text-muted-foreground">{c.course_name}</div>
                <div className="mt-2 text-sm">
                  {c.semester} · {c.student_count} sinh viên
                </div>
              </Link>
            ))}
          </div>
        )}
      </QueryBoundary>
    </div>
  )
}
