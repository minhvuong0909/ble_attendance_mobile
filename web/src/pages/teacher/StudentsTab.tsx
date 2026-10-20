import { useClassStudents } from '@/api/classes'
import DataTable from '@/components/DataTable'
import QueryBoundary from '@/components/QueryBoundary'

export default function StudentsTab({ classId }: { classId: string }) {
  const query = useClassStudents(classId)
  return (
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
  )
}
