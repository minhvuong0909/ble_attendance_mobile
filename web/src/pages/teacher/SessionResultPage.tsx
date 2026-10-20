import { Link, useParams } from 'react-router-dom'
import { downloadSessionExport, useClassSessions, useSessionAttendance } from '@/api/sessions'
import ExportButton from '@/components/ExportButton'
import { formatDateTime } from '@/lib/format'
import AttendanceTable from './AttendanceTable'

export default function SessionResultPage() {
  const { sessionId = '' } = useParams()
  const attendance = useSessionAttendance(sessionId, false)
  const classId = attendance.data?.class_id
  const sessions = useClassSessions(classId)
  const session = sessions.data?.find((s) => s.id === sessionId)

  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-semibold">Kết quả buổi học</h1>
      {session && (
        <div className="flex flex-wrap items-center justify-between gap-2">
          <div>
            <p className="font-medium">
              {session.course_code} · {session.class_code}
            </p>
            <p className="text-sm text-muted-foreground">
              {formatDateTime(session.starts_at)} → {formatDateTime(session.ends_at)}
            </p>
          </div>
          <div className="flex gap-2">
            <ExportButton label="Xuất Excel buổi này" onExport={() => downloadSessionExport(sessionId)} />
            <Link className="self-center text-sm text-primary underline" to={`/teacher/classes/${session.class_id}?tab=sessions`}>
              Về lớp học
            </Link>
          </div>
        </div>
      )}
      <AttendanceTable sessionId={sessionId} live={false} />
    </div>
  )
}
