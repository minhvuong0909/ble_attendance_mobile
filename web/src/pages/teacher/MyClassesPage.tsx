import { Link } from 'react-router-dom'
import { useMyClasses } from '@/api/classes'
import QueryBoundary from '@/components/QueryBoundary'

export default function MyClassesPage() {
  const query = useMyClasses()
  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-semibold">Lớp của tôi</h1>
      <QueryBoundary query={query} isEmpty={(d) => d.length === 0} emptyText="Bạn chưa được phân công lớp nào. Hãy liên hệ admin.">
        {(classes) => (
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {classes.map((c) => (
              <Link key={c.id} to={`/teacher/classes/${c.id}`} className="rounded-lg border p-4 hover:bg-accent">
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
