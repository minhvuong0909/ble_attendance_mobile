import { useQueryClient } from '@tanstack/react-query'
import { Bell } from 'lucide-react'
import { useEffect, useRef } from 'react'
import { Link } from 'react-router-dom'
import { useUnreadCount } from '@/api/notifications'
import { buttonVariants } from '@/components/ui/button'
import { cn } from '@/lib/utils'

/** Chuông thông báo; khi số chưa đọc tăng thì làm mới dữ liệu thường đi kèm (đơn xin phép, buổi học...). */
export default function NotificationBell() {
  const qc = useQueryClient()
  const { data } = useUnreadCount()
  const count = data ?? 0
  const previous = useRef<number | null>(null)

  useEffect(() => {
    if (data === undefined) return
    if (previous.current !== null && data > previous.current) {
      for (const key of ['leave-requests', 'active-session', 'class-sessions', 'my-classes', 'class-report', 'session-attendance']) {
        void qc.invalidateQueries({ queryKey: [key] })
      }
    }
    previous.current = data
  }, [data, qc])

  return (
    <Link
      to="/notifications"
      aria-label={count > 0 ? `Thông báo (${count} chưa đọc)` : 'Thông báo'}
      className={cn(buttonVariants({ variant: 'ghost', size: 'icon' }), 'relative')}
    >
      <Bell />
      {count > 0 && (
        <span className="absolute -right-0.5 -top-0.5 flex min-w-4 items-center justify-center rounded-full bg-destructive px-1 text-[10px] text-white">
          {count > 99 ? '99+' : count}
        </span>
      )}
    </Link>
  )
}
