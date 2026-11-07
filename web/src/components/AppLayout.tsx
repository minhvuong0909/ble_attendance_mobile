import { BookOpen, Building2, GraduationCap, Menu, Radio, Smartphone, Upload, Users, type LucideIcon } from 'lucide-react'
import { useState, type ReactNode } from 'react'
import { NavLink } from 'react-router-dom'
import type { Role } from '@/api/auth'
import { useAuth } from '@/auth/AuthProvider'
import { Button } from '@/components/ui/button'
import { cn } from '@/lib/utils'
import NotificationBell from './NotificationBell'
import ProfileMenu from './ProfileMenu'

interface NavItem {
  to: string
  label: string
  icon: LucideIcon
}

export const navFor = (role: Role): NavItem[] =>
  role === 'admin'
    ? [
        { to: '/admin/courses', label: 'Môn học', icon: BookOpen },
        { to: '/admin/classes', label: 'Lớp học', icon: Building2 },
        { to: '/admin/teachers', label: 'Giảng viên', icon: Users },
        { to: '/admin/import', label: 'Nhập danh sách', icon: Upload },
        { to: '/admin/device-requests', label: 'Đổi thiết bị', icon: Smartphone },
      ]
    : [
        { to: '/teacher/classes', label: 'Lớp của tôi', icon: GraduationCap },
        { to: '/teacher/live', label: 'Buổi trực tiếp', icon: Radio },
      ]

export default function AppLayout({ children }: { children: ReactNode }) {
  const { user } = useAuth()
  const [open, setOpen] = useState(false)
  const items = navFor(user!.role)
  return (
    <div className="flex min-h-screen">
      <aside
        className={cn(
          'w-56 shrink-0 border-r bg-card p-3 max-md:fixed max-md:inset-y-0 max-md:z-20 max-md:-translate-x-full max-md:transition-transform',
          open && 'max-md:translate-x-0',
        )}
      >
        <div className="mb-4 px-2 text-lg font-semibold">Điểm danh BLE</div>
        <nav className="space-y-1" onClick={() => setOpen(false)}>
          {items.map(({ to, label, icon: Icon }) => (
            <NavLink
              key={to}
              to={to}
              className={({ isActive }) =>
                cn(
                  'flex items-center gap-2 rounded-md px-2 py-2 text-sm hover:bg-accent',
                  isActive && 'bg-accent font-medium',
                )
              }
            >
              <Icon className="size-4" /> {label}
            </NavLink>
          ))}
        </nav>
      </aside>
      <div className="flex min-w-0 flex-1 flex-col">
        <header className="flex items-center justify-between border-b px-4 py-2">
          <Button variant="ghost" size="icon" className="md:hidden" aria-label="Mở menu" onClick={() => setOpen((v) => !v)}>
            <Menu />
          </Button>
          <div className="ml-auto flex items-center gap-2">
            <NotificationBell />
            <ProfileMenu />
          </div>
        </header>
        <main className="mx-auto w-full max-w-6xl flex-1 p-4 md:p-6">{children}</main>
      </div>
    </div>
  )
}
