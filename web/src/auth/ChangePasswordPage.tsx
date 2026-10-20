import { zodResolver } from '@hookform/resolvers/zod'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { Navigate, useNavigate } from 'react-router-dom'
import { z } from 'zod'
import { changePasswordRequest, homePathFor } from '@/api/auth'
import { ApiError } from '@/api/client'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { useAuth } from './AuthProvider'

const schema = z
  .object({
    old: z.string().min(1, 'Vui lòng nhập mật khẩu hiện tại'),
    next: z.string().min(6, 'Mật khẩu phải có ít nhất 6 ký tự'),
    confirm: z.string(),
  })
  .refine((v) => v.next === v.confirm, { path: ['confirm'], message: 'Mật khẩu nhập lại không khớp' })

type Values = z.infer<typeof schema>

export default function ChangePasswordPage() {
  const { user, status, refresh, logout } = useAuth()
  const navigate = useNavigate()
  const [error, setError] = useState<string | null>(null)
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<Values>({ resolver: zodResolver(schema) })

  if (status === 'loading') return <p className="p-8 text-muted-foreground">Đang tải…</p>
  if (!user) return <Navigate to="/login" replace />

  const forced = user.must_change_password

  async function onSubmit(values: Values) {
    setError(null)
    try {
      await changePasswordRequest(values.old, values.next)
      await refresh()
      navigate(homePathFor(user!.role), { replace: true })
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Đã xảy ra lỗi không mong muốn')
    }
  }

  return (
    <main className="flex min-h-screen items-center justify-center p-4">
      <form onSubmit={handleSubmit(onSubmit)} className="w-full max-w-sm space-y-4 rounded-lg border bg-card p-6 shadow-sm">
        <div className="space-y-1">
          <h1 className="text-xl font-semibold">Đổi mật khẩu</h1>
          {forced && <p className="text-sm text-muted-foreground">Bạn cần đổi mật khẩu tạm trước khi tiếp tục.</p>}
        </div>
        <Field id="old" label="Mật khẩu hiện tại" error={errors.old?.message}>
          <Input id="old" type="password" autoComplete="current-password" {...register('old')} />
        </Field>
        <Field id="next" label="Mật khẩu mới" error={errors.next?.message}>
          <Input id="next" type="password" autoComplete="new-password" {...register('next')} />
        </Field>
        <Field id="confirm" label="Nhập lại mật khẩu mới" error={errors.confirm?.message}>
          <Input id="confirm" type="password" autoComplete="new-password" {...register('confirm')} />
        </Field>
        {error && (
          <p role="alert" className="text-sm text-destructive">
            {error}
          </p>
        )}
        <div className="flex gap-2">
          <Button type="submit" disabled={isSubmitting} className="flex-1">
            Đổi mật khẩu
          </Button>
          {forced ? (
            <Button type="button" variant="outline" onClick={logout}>
              Đăng xuất
            </Button>
          ) : (
            <Button type="button" variant="outline" onClick={() => navigate(-1)}>
              Hủy
            </Button>
          )}
        </div>
      </form>
    </main>
  )
}

function Field({ id, label, error, children }: { id: string; label: string; error?: string; children: React.ReactNode }) {
  return (
    <div className="space-y-2">
      <Label htmlFor={id}>{label}</Label>
      {children}
      {error && <p className="text-sm text-destructive">{error}</p>}
    </div>
  )
}
