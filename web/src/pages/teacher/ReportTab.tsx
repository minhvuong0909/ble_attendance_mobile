import { downloadClassReport, useClassReport, type ClassReport } from '@/api/classes'
import ExportButton from '@/components/ExportButton'
import QueryBoundary from '@/components/QueryBoundary'
import { Badge } from '@/components/ui/badge'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { formatDate, formatPercentValue } from '@/lib/format'

const CELL: Record<string, string> = { present: 'Có', absent: 'Vắng', excused: 'Phép' }

function Matrix({ report }: { report: ClassReport }) {
  return (
    <div className="space-y-3">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <p className="text-sm font-medium">Trung bình lớp: {formatPercentValue(report.average_attendance_percent)}</p>
        <ExportButton label="Xuất Excel" onExport={() => downloadClassReport(report.class_id)} />
      </div>
      <div className="overflow-x-auto rounded-md border">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>MSSV</TableHead>
              <TableHead>Họ và tên</TableHead>
              {report.sessions.map((s) => (
                <TableHead key={s.id}>{formatDate(s.starts_at)}</TableHead>
              ))}
              <TableHead className="text-right">Có mặt</TableHead>
              <TableHead />
            </TableRow>
          </TableHeader>
          <TableBody>
            {report.students.map((st) => (
              <TableRow key={st.student_user_id} className={st.warning ? 'bg-destructive/5' : undefined}>
                <TableCell>{st.student_id}</TableCell>
                <TableCell>{st.student_name}</TableCell>
                {st.cells.map((cell, i) => (
                  <TableCell key={report.sessions[i]?.id ?? i}>{cell ? CELL[cell] : '—'}</TableCell>
                ))}
                <TableCell className="text-right">{formatPercentValue(st.attendance_percent)}</TableCell>
                <TableCell>{st.warning && <Badge variant="destructive">Cảnh báo</Badge>}</TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </div>
    </div>
  )
}

export default function ReportTab({ classId }: { classId: string }) {
  const query = useClassReport(classId)
  return (
    <QueryBoundary query={query} isEmpty={(d) => d.sessions.length === 0} emptyText="Chưa có buổi học nào kết thúc">
      {(report) => <Matrix report={report} />}
    </QueryBoundary>
  )
}
