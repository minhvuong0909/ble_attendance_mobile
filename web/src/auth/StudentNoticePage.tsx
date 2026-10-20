import { Smartphone } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { useAuth } from './AuthProvider'

export default function StudentNoticePage() {
  const { user, logout } = useAuth()
  return (
    <main className="mx-auto flex min-h-screen max-w-md flex-col items-center justify-center gap-4 p-6 text-center">
      <Smartphone className="size-10 text-muted-foreground" />
      <h1 className="text-xl font-semibold">Xin chào {user?.full_name}</h1>
      <p className="text-muted-foreground">
        Sinh viên điểm danh và xem thống kê bằng ứng dụng Android. Trang web này dành cho admin và giảng viên.
      </p>
      <Button variant="outline" onClick={logout}>
        Đăng xuất
      </Button>
    </main>
  )
}
