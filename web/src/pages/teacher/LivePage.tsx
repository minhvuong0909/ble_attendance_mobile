import { LockOpen, Square } from 'lucide-react'
import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { toast } from 'sonner'
import { ApiError } from '@/api/client'
import { downloadSessionExport, useActiveSession, useEndSession, useOpenFinalization, type Session } from '@/api/sessions'
import ConfirmDialog from '@/components/ConfirmDialog'
import ExportButton from '@/components/ExportButton'
import QueryBoundary from '@/components/QueryBoundary'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { formatDateTime } from '@/lib/format'
import AttendanceTable from './AttendanceTable'

const message = (e: unknown) => (e instanceof ApiError ? e.message : 'Đã xảy ra lỗi không mong muốn')

function LiveSession({ session }: { session: Session }) {
  const navigate = useNavigate()
  const open = useOpenFinalization(session.id)
  const end = useEndSession(session.id)
  const [confirming, setConfirming] = useState(false)

  async function openFinalization() {
    if (open.isPending) return
    try {
      await open.mutateAsync()
      toast.success('Đã mở chốt điểm danh')
    } catch (e) {
      toast.error(message(e))
    }
  }

  async function endSession() {
    if (end.isPending) return
    try {
      const ended = await end.mutateAsync()
      setConfirming(false)
      navigate(`/teacher/sessions/${ended.id}`)
    } catch (e) {
      setConfirming(false)
      toast.error(message(e))
    }
  }

  return (
    <div className="space-y-4">
      <div className="space-y-3 rounded-lg border p-4">
        <Badge>Đang diễn ra</Badge>
        <h1 className="text-2xl font-semibold">
          {session.course_code} · {session.class_code}
        </h1>
        <p className="text-sm text-muted-foreground">
          {session.course_name} · bắt đầu lúc {formatDateTime(session.starts_at)}
        </p>
        <p className="text-sm">
          Mã buổi học: <code className="rounded bg-muted px-1">{session.beacon_code}</code>
        </p>
        <div className="flex flex-wrap items-center gap-2">
          {session.finalization_open ? (
            <Badge variant="secondary">Đã mở chốt</Badge>
          ) : (
            <Button disabled={open.isPending} onClick={() => void openFinalization()}>
              <LockOpen /> Mở chốt điểm danh
            </Button>
          )}
          <Button variant="destructive" disabled={end.isPending} onClick={() => setConfirming(true)}>
            <Square /> Kết thúc buổi
          </Button>
          <ExportButton label="Xuất Excel buổi này" onExport={() => downloadSessionExport(session.id)} />
        </div>
      </div>
      <AttendanceTable sessionId={session.id} live />
      <ConfirmDialog
        open={confirming}
        onOpenChange={setConfirming}
        title="Kết thúc buổi học?"
        description={
          session.finalization_open
            ? 'Hệ thống sẽ chốt kết quả điểm danh cả lớp. Không thể hoàn tác.'
            : 'Bạn chưa mở chốt điểm danh nên sinh viên chưa xác nhận được: mọi sinh viên không có đơn xin phép sẽ bị tính vắng. Hãy mở chốt trước khi kết thúc, hoặc chỉnh tay kết quả sau đó.'
        }
        confirmLabel="Kết thúc"
        destructive
        busy={end.isPending}
        onConfirm={() => void endSession()}
      />
    </div>
  )
}

export default function LivePage() {
  const query = useActiveSession()
  return (
    <QueryBoundary query={query}>
      {(session) =>
        session ? (
          <LiveSession session={session} />
        ) : (
          <div className="space-y-3">
            <h1 className="text-2xl font-semibold">Buổi trực tiếp</h1>
            <p className="rounded-md border border-dashed p-8 text-center text-muted-foreground">
              Hiện không có buổi học nào đang diễn ra.
            </p>
            <Button render={<Link to="/teacher/classes" />}>Chọn lớp để bắt đầu</Button>
          </div>
        )
      }
    </QueryBoundary>
  )
}
