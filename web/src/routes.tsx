import { Navigate, Route, Routes } from 'react-router-dom'
import { homePathFor } from '@/api/auth'
import ChangePasswordPage from '@/auth/ChangePasswordPage'
import { useAuth } from '@/auth/AuthProvider'
import LoginPage from '@/auth/LoginPage'
import RequireRole from '@/auth/RequireRole'
import StudentNoticePage from '@/auth/StudentNoticePage'
import NotFoundPage from '@/pages/NotFoundPage'
import CoursesPage from '@/pages/admin/CoursesPage'
import TeachersPage from '@/pages/admin/TeachersPage'
import Placeholder from '@/pages/Placeholder'

function Home() {
  const { user, status } = useAuth()
  if (status === 'loading') return <p className="p-8 text-muted-foreground">Đang tải…</p>
  if (!user) return <Navigate to="/login" replace />
  return <Navigate to={user.must_change_password ? '/change-password' : homePathFor(user.role)} replace />
}

export function AppRoutes() {
  return (
    <Routes>
      <Route path="/" element={<Home />} />
      <Route path="/login" element={<LoginPage />} />
      <Route path="/change-password" element={<ChangePasswordPage />} />
      <Route path="/student" element={<StudentNoticePage />} />
      <Route path="/admin" element={<RequireRole role="admin" />}>
        <Route index element={<Navigate to="courses" replace />} />
        <Route path="courses" element={<CoursesPage />} />
        <Route path="teachers" element={<TeachersPage />} />
      </Route>
      <Route path="/teacher" element={<RequireRole role="teacher" />}>
        <Route index element={<Navigate to="classes" replace />} />
        <Route path="classes" element={<Placeholder title="Lớp của tôi" />} />
      </Route>
      <Route path="*" element={<NotFoundPage />} />
    </Routes>
  )
}
