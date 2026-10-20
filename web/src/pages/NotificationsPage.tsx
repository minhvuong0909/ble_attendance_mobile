import { useMarkAllRead, useMarkRead, useNotifications } from '@/api/notifications'
import QueryBoundary from '@/components/QueryBoundary'
import { Button } from '@/components/ui/button'
import { formatDateTime } from '@/lib/format'
import { cn } from '@/lib/utils'

export default function NotificationsPage() {
  const query = useNotifications()
  const markRead = useMarkRead()
  const markAll = useMarkAllRead()

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Thông báo</h1>
        <Button variant="outline" disabled={markAll.isPending} onClick={() => !markAll.isPending && markAll.mutate()}>
          Đọc tất cả
        </Button>
      </div>
      <QueryBoundary query={query} isEmpty={(d) => d.length === 0} emptyText="Chưa có thông báo nào">
        {(items) => (
          <ul className="space-y-2">
            {items.map((n) => (
              <li key={n.id}>
                <button
                  className={cn('w-full rounded-lg border p-3 text-left hover:bg-accent', !n.is_read && 'border-primary/50 bg-primary/5')}
                  onClick={() => !n.is_read && !markRead.isPending && markRead.mutate(n.id)}
                >
                  <div className="flex items-center justify-between gap-2">
                    <span className={cn('text-sm', !n.is_read && 'font-semibold')}>{n.title}</span>
                    <span className="text-xs text-muted-foreground">{formatDateTime(n.created_at)}</span>
                  </div>
                  <p className="text-sm text-muted-foreground">{n.body}</p>
                </button>
              </li>
            ))}
          </ul>
        )}
      </QueryBoundary>
    </div>
  )
}
