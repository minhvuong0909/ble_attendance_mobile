import { Play } from 'lucide-react'
import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { ApiError } from '@/api/client'
import { useClassSessions, useStartSession } from '@/api/sessions'
import DataTable from '@/components/DataTable'
import QueryBoundary from '@/components/QueryBoundary'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { formatDateTime } from '@/lib/format'

export default function SessionsTab({ classId }: { classId: string }) {
  const query = useClassSessions(classId)
  const start = useStartSession(classId)
  const navigate = useNavigate()
  const [error, setError] = useState<ApiError | null>(null)

  async function begin() {
    if (start.isPending) return
    setError(null)
    try {
      await start.mutateAsync()
      navigate('/teacher/live')
    } catch (e) {
      setError(e instanceof ApiError ? e : new ApiError('Đã xảy ra lỗi không mong muốn', 0, 'unknown'))
    }
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-3">
        <Button disabled={start.isPending} onClick={() => void begin()}>
          <Play /> Bắt đầu buổi học
        </Button>
      </div>
      {error && (
        <div role="alert" className="flex flex-wrap items-center gap-3 rounded-md border border-destructive/40 p-3 text-sm">
          <span className="text-destructive">{error.message}</span>
          {error.code === 'session_already_active' && (
            <Link className="text-primary underline" to="/teacher/live">
              Mở buổi trực tiếp
            </Link>
          )}
        </div>
      )}
      <QueryBoundary query={query} isEmpty={(d) => d.length === 0} emptyText="Chưa có buổi học nào">
        {(sessions) => (
          <DataTable
            rows={sessions}
            rowKey={(s) => s.id}
            columns={[
              { header: 'Bắt đầu', cell: (s) => formatDateTime(s.starts_at) },
              { header: 'Kết thúc', cell: (s) => formatDateTime(s.ends_at) },
              {
                header: 'Trạng thái',
                cell: (s) => (s.is_active ? <Badge>Đang diễn ra</Badge> : <Badge variant="secondary">Đã kết thúc</Badge>),
              },
              {
                header: 'Thao tác',
                className: 'text-right',
                cell: (s) =>
                  s.is_active ? (
                    <Link className="text-primary underline" to="/teacher/live">
                      Mở buổi trực tiếp
                    </Link>
                  ) : (
                    <Link className="text-primary underline" to={`/teacher/sessions/${s.id}`}>
                      Xem kết quả
                    </Link>
                  ),
              },
            ]}
          />
        )}
      </QueryBoundary>
    </div>
  )
}
