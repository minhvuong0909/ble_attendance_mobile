import { Pencil } from 'lucide-react'
import { useState } from 'react'
import { useSessionAttendance, type AttendanceRecord, type AttendanceStatus } from '@/api/sessions'
import DataTable from '@/components/DataTable'
import QueryBoundary from '@/components/QueryBoundary'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { formatDateTime, formatPercent } from '@/lib/format'
import OverrideDialog from './OverrideDialog'

export const STATUS_LABEL: Record<AttendanceStatus, string> = { present: 'Có mặt', absent: 'Vắng', excused: 'Có phép' }

export default function AttendanceTable({ sessionId, live }: { sessionId: string; live: boolean }) {
  const query = useSessionAttendance(sessionId, live)
  const [editing, setEditing] = useState<AttendanceRecord | null>(null)

  return (
    <div className="space-y-3">
      <QueryBoundary query={query} isEmpty={(d) => d.records.length === 0} emptyText="Lớp chưa có sinh viên">
        {(data) => (
          <>
            <p className="text-sm font-medium">
              Có mặt: {data.present_students}/{data.total_students}
            </p>
            <DataTable
              rows={data.records}
              rowKey={(r) => r.student_user_id}
              columns={[
                { header: 'MSSV', cell: (r) => r.student_id },
                { header: 'Họ và tên', cell: (r) => r.student_name },
                {
                  header: 'Trạng thái',
                  cell: (r) => <Badge variant={r.status === 'present' ? 'default' : r.status === 'excused' ? 'secondary' : 'destructive'}>{STATUS_LABEL[r.status]}</Badge>,
                },
                { header: 'Hiện diện', cell: (r) => formatPercent(r.presence_ratio) },
                { header: 'Giờ đến', cell: (r) => formatDateTime(r.first_seen_at) },
                {
                  header: 'Ghi chú',
                  cell: (r) => (
                    <div className="space-y-0.5 text-xs">
                      {r.finalized && <div>Đã chốt</div>}
                      {r.overridden && (
                        <div>
                          <span className="font-medium">Đã chỉnh tay</span>
                          {r.override_reason && <span className="text-muted-foreground"> — {r.override_reason}</span>}
                        </div>
                      )}
                    </div>
                  ),
                },
                {
                  header: '',
                  className: 'w-12',
                  cell: (r) => (
                    <Button variant="ghost" size="icon" aria-label={`Chỉnh tay ${r.student_name}`} onClick={() => setEditing(r)}>
                      <Pencil />
                    </Button>
                  ),
                },
              ]}
            />
          </>
        )}
      </QueryBoundary>
      {editing && <OverrideDialog sessionId={sessionId} record={editing} onClose={() => setEditing(null)} />}
    </div>
  )
}
