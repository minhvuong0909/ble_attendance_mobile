import { Check, X } from 'lucide-react'
import { useState } from 'react'
import { toast } from 'sonner'
import { useDeviceRequests, useResolveDeviceRequest, type DeviceRequest } from '@/api/admin'
import { ApiError } from '@/api/client'
import ConfirmDialog from '@/components/ConfirmDialog'
import DataTable from '@/components/DataTable'
import QueryBoundary from '@/components/QueryBoundary'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { formatDateTime } from '@/lib/format'

const STATUS = { pending: 'Chờ duyệt', approved: 'Đã duyệt', rejected: 'Đã từ chối' } as const

export default function DeviceRequestsPage() {
  const query = useDeviceRequests()
  const resolve = useResolveDeviceRequest()
  const [target, setTarget] = useState<{ row: DeviceRequest; action: 'approve' | 'reject' } | null>(null)

  async function confirm() {
    if (!target || resolve.isPending) return
    const { row, action } = target
    try {
      await resolve.mutateAsync({ id: row.id, action })
      setTarget(null)
      toast.success(action === 'approve' ? 'Đã duyệt đơn đổi thiết bị' : 'Đã từ chối đơn')
    } catch (e) {
      setTarget(null)
      toast.error(e instanceof ApiError ? e.message : 'Đã xảy ra lỗi không mong muốn')
    }
  }

  const approving = target?.action === 'approve'
  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-semibold">Đơn đổi thiết bị</h1>
      <p className="text-sm text-muted-foreground">
        Mỗi sinh viên chỉ đăng nhập được trên một máy. Duyệt đơn để chuyển tài khoản sang máy mới của sinh viên.
      </p>
      <QueryBoundary query={query} isEmpty={(d) => d.length === 0} emptyText="Chưa có đơn đổi thiết bị nào">
        {(rows) => (
          <DataTable
            rows={rows}
            rowKey={(r) => String(r.id)}
            columns={[
              { header: 'MSSV', cell: (r) => r.student_id },
              { header: 'Họ và tên', cell: (r) => r.student_name },
              { header: 'Lý do', cell: (r) => r.reason },
              { header: 'Gửi lúc', cell: (r) => formatDateTime(r.created_at) },
              {
                header: 'Trạng thái',
                cell: (r) => (
                  <Badge variant={r.status === 'pending' ? 'default' : r.status === 'approved' ? 'secondary' : 'destructive'}>
                    {STATUS[r.status]}
                  </Badge>
                ),
              },
              {
                header: 'Thao tác',
                className: 'w-28 text-right',
                cell: (r) =>
                  r.status === 'pending' ? (
                    <div className="flex justify-end gap-1">
                      <Button variant="ghost" size="icon" aria-label={`Duyệt đơn ${r.student_id}`} onClick={() => setTarget({ row: r, action: 'approve' })}>
                        <Check />
                      </Button>
                      <Button variant="ghost" size="icon" aria-label={`Từ chối đơn ${r.student_id}`} onClick={() => setTarget({ row: r, action: 'reject' })}>
                        <X />
                      </Button>
                    </div>
                  ) : null,
              },
            ]}
          />
        )}
      </QueryBoundary>
      <ConfirmDialog
        open={!!target}
        onOpenChange={(open) => !open && setTarget(null)}
        title={approving ? 'Duyệt đơn đổi thiết bị?' : 'Từ chối đơn đổi thiết bị?'}
        description={
          approving
            ? `Tài khoản ${target?.row.student_id ?? ''} sẽ chuyển sang máy mới; máy cũ không đăng nhập được nữa.`
            : `Tài khoản ${target?.row.student_id ?? ''} vẫn dùng máy cũ.`
        }
        confirmLabel={approving ? 'Duyệt' : 'Từ chối'}
        destructive={!approving}
        busy={resolve.isPending}
        onConfirm={() => void confirm()}
      />
    </div>
  )
}
