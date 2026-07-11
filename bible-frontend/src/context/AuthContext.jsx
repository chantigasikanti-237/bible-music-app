import { createContext, useContext, useState, useEffect, useCallback } from 'react'
import { authApi, setToken, getToken } from '../api/client'

const AuthContext = createContext(null)

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null)
  const [loading, setLoading] = useState(true)

  const fetchMe = useCallback(async () => {
    if (!getToken()) { setLoading(false); return }
    try {
      const res = await authApi.getMe()
      setUser(res.data || res.user || res)
    } catch {
      setToken(null)
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchMe()
    const onLogout = () => { setUser(null); setToken(null) }
    window.addEventListener('auth:logout', onLogout)
    return () => window.removeEventListener('auth:logout', onLogout)
  }, [fetchMe])

  const login = async (email, password) => {
    const res = await authApi.login(email, password)
    setToken(res.accessToken || res.token)
    setUser(res.user)
    return res
  }

  const register = async (name, email, password) => {
    return authApi.register(name, email, password)
  }

  const logout = async () => {
    try { await authApi.logout() } catch (_) {}
    setToken(null)
    setUser(null)
  }

  return (
    <AuthContext.Provider value={{ user, loading, login, register, logout }}>
      {children}
    </AuthContext.Provider>
  )
}

export const useAuth = () => {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be inside AuthProvider')
  return ctx
}
