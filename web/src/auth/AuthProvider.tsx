import { useQueryClient } from '@tanstack/react-query'
import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'
import { fetchMe, loginRequest, type User } from '@/api/auth'
import { ApiError, clearToken, getToken, setToken, setUnauthorizedHandler } from '@/api/client'

type Status = 'loading' | 'anon' | 'authed'

interface AuthValue {
  user: User | null
  status: Status
  login: (identifier: string, password: string) => Promise<User>
  logout: () => void
  refresh: () => Promise<void>
}

const AuthContext = createContext<AuthValue | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const queryClient = useQueryClient()
  const [user, setUser] = useState<User | null>(null)
  const [status, setStatus] = useState<Status>(getToken() ? 'loading' : 'anon')

  const signOut = useCallback(() => {
    clearToken()
    setUser(null)
    setStatus('anon')
    queryClient.clear()
  }, [queryClient])

  useEffect(() => {
    setUnauthorizedHandler(signOut)
    return () => setUnauthorizedHandler(null)
  }, [signOut])

  useEffect(() => {
    if (!getToken()) return
    let cancelled = false
    fetchMe()
      .then((me) => {
        if (cancelled) return
        setUser(me)
        setStatus('authed')
      })
      .catch((error) => {
        if (cancelled) return
        // 401 đã được client xử lý; lỗi khác (mạng, 5xx) cũng đưa về đăng nhập, không treo màn hình tải.
        if (!(error instanceof ApiError) || error.status !== 401) clearToken()
        setUser(null)
        setStatus('anon')
      })
    return () => {
      cancelled = true
    }
  }, [])

  const login = useCallback(async (identifier: string, password: string) => {
    const token = await loginRequest(identifier, password)
    setToken(token.access_token)
    try {
      const me = await fetchMe()
      setUser(me)
      setStatus('authed')
      return me
    } catch (error) {
      clearToken()
      throw error
    }
  }, [])

  const refresh = useCallback(async () => {
    setUser(await fetchMe())
  }, [])

  const value = useMemo(() => ({ user, status, login, logout: signOut, refresh }), [user, status, login, signOut, refresh])
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth(): AuthValue {
  const value = useContext(AuthContext)
  if (!value) throw new Error('useAuth phải nằm trong AuthProvider')
  return value
}
