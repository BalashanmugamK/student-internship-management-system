import { createContext, useEffect, useMemo, useState } from 'react'

export const AuthContext = createContext({
  user: null,
  login: () => {},
  logout: () => {},
  notification: null,
  setNotification: () => {},
  clearNotification: () => {},
  theme: 'light',
  toggleTheme: () => {},
})

export function AuthProvider({ children }) {
  const [user, setUser] = useState(() => {
    try {
      return JSON.parse(localStorage.getItem('sims_user'))
    } catch {
      return null
    }
  })

  const [theme, setTheme] = useState(() => {
    return localStorage.getItem('sims_theme') || 'light'
  })

  useEffect(() => {
    if (user) {
      localStorage.setItem('sims_user', JSON.stringify(user))
    } else {
      localStorage.removeItem('sims_user')
    }
  }, [user])

  useEffect(() => {
    localStorage.setItem('sims_theme', theme)
    document.documentElement.setAttribute('data-theme', theme)
  }, [theme])

  const [notification, setNotificationState] = useState(null)
  const [dismissTimer, setDismissTimer] = useState(null)

  const setNotification = (notif) => {
    if (dismissTimer) clearTimeout(dismissTimer)
    setNotificationState(notif)
    
    if (notif?.type === 'success' || notif?.type === 'info') {
      const timer = setTimeout(() => {
        setNotificationState(null)
      }, 5000)
      setDismissTimer(timer)
    }
  }

  const login = (userInfo) => setUser(userInfo)
  const logout = () => setUser(null)
  const clearNotification = () => {
    if (dismissTimer) clearTimeout(dismissTimer)
    setNotificationState(null)
    setDismissTimer(null)
  }
  const toggleTheme = () => setTheme(prev => prev === 'light' ? 'dark' : 'light')

  const value = useMemo(
    () => ({ user, login, logout, notification, setNotification, clearNotification, theme, toggleTheme }),
    [user, notification, theme],
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}
