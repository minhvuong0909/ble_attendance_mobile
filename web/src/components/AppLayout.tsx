import { BookOpen, Building2, LayoutDashboard, GraduationCap, Menu, Radio, Smartphone, Upload, Users, type LucideIcon } from 'lucide-react'
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
  end?: boolean
}

export const navFor = (role: Role): NavItem[] =>
  role === 'admin'
    ? [
        { to: '/admin', label: 'Tổng quan', icon: LayoutDashboard, end: true },
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

const ROLE_LABEL: Record<Role, string> = { admin: 'Quản trị viên', teacher: 'Giảng viên', student: 'Sinh viên' }

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
        <div className="mb-5 flex items-center gap-2.5 px-2 pt-1">
          <img src={`${import.meta.env.BASE_URL}logo.svg`} alt="" className="size-9 rounded-lg" />
          <div className="leading-tight">
            <div className="text-base font-semibold">Điểm danh BLE</div>
            <div className="text-xs text-muted-foreground">{ROLE_LABEL[user!.role]}</div>
          </div>
        </div>
        <nav className="space-y-1" onClick={() => setOpen(false)}>
          {items.map(({ to, label, icon: Icon, end }) => (
            <NavLink
              key={to}
              to={to}
              end={end}
              className={({ isActive }) =>
                cn(
                  'flex items-center gap-2.5 rounded-lg px-3 py-2 text-sm text-muted-foreground transition-colors hover:bg-accent hover:text-foreground',
                  isActive && 'bg-accent font-semibold text-accent-foreground',
                )
              }
            >
              <Icon className="size-[18px]" /> {label}
            </NavLink>
          ))}
        </nav>
      </aside>
      <div className="flex min-w-0 flex-1 flex-col">
        <header className="sticky top-0 z-10 flex items-center justify-between border-b bg-background/80 px-4 py-2 backdrop-blur">
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
