import { Navigate, Outlet } from 'react-router-dom'
import { homePathFor, type Role } from '@/api/auth'
import AppLayout from '@/components/AppLayout'
import { useAuth } from './AuthProvider'
import StudentNoticePage from './StudentNoticePage'

/** [role] bỏ trống: chấp nhận mọi vai trò quản lý (admin, giảng viên). */
export default function RequireRole({ role }: { role?: Role }) {
  const { user, status } = useAuth()
  if (status === 'loading') return <p className="p-8 text-muted-foreground">Đang tải…</p>
  if (!user) return <Navigate to="/login" replace />
  if (user.must_change_password) return <Navigate to="/change-password" replace />
  if (user.role === 'student') return <StudentNoticePage />
  if (role && user.role !== role) return <Navigate to={homePathFor(user.role)} replace />
  return (
    <AppLayout>
      <Outlet />
    </AppLayout>
  )
}
