import { useState, type FormEvent } from 'react'
import { Navigate, useNavigate } from 'react-router-dom'
import { homePathFor } from '@/api/auth'
import { ApiError } from '@/api/client'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { useAuth } from './AuthProvider'

export default function LoginPage() {
  const { user, login } = useAuth()
  const navigate = useNavigate()
  const [identifier, setIdentifier] = useState('')
  const [password, setPassword] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  if (user) {
    return <Navigate to={user.must_change_password ? '/change-password' : homePathFor(user.role)} replace />
  }

  async function submit(event: FormEvent) {
    event.preventDefault()
    if (busy) return
    if (!identifier.trim() || !password) {
      setError('Vui lòng nhập mã đăng nhập và mật khẩu')
      return
    }
    setBusy(true)
    setError(null)
    try {
      const me = await login(identifier.trim().toUpperCase(), password)
      navigate(me.must_change_password ? '/change-password' : homePathFor(me.role), { replace: true })
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Đã xảy ra lỗi không mong muốn')
    } finally {
      setBusy(false)
    }
  }

  return (
    <main className="flex min-h-screen items-center justify-center p-4">
      <form onSubmit={submit} className="w-full max-w-sm space-y-4 rounded-lg border bg-card p-6 shadow-sm">
        <div className="space-y-1">
          <h1 className="text-xl font-semibold">Điểm danh BLE</h1>
          <p className="text-sm text-muted-foreground">Đăng nhập dành cho admin và giảng viên</p>
        </div>
        <div className="space-y-2">
          <Label htmlFor="identifier">Mã đăng nhập</Label>
          <Input id="identifier" autoComplete="username" value={identifier} onChange={(e) => setIdentifier(e.target.value)} />
        </div>
        <div className="space-y-2">
          <Label htmlFor="password">Mật khẩu</Label>
          <Input id="password" type="password" autoComplete="current-password" value={password} onChange={(e) => setPassword(e.target.value)} />
        </div>
        {error && (
          <p role="alert" className="text-sm text-destructive">
            {error}
          </p>
        )}
        <Button type="submit" className="w-full" disabled={busy}>
          Đăng nhập
        </Button>
      </form>
    </main>
  )
}
