import { useContext } from 'react'
import { BrowserRouter, Link, NavLink, Navigate, Route, Routes } from 'react-router-dom'
import { AuthProvider, AuthContext } from './AuthContext'
import Dashboard from './pages/Dashboard'
import Applications from './pages/Applications'
import Internships from './pages/Internships'
import Approvals from './pages/Approvals'
import Remarks from './pages/Remarks'
import Users from './pages/Users'
import Login from './pages/Login'
import Register from './pages/Register'
import ChangePassword from './pages/ChangePassword'
import './App.css'

const redirectPath = (user) => {
  if (!user) return '/login'
  if (user.role === 'Admin') return '/dashboard'
  if (user.role === 'Faculty') return '/approvals'
  return '/applications'
}

const PrivateRoute = ({ children }) => {
  const { user } = useContext(AuthContext)
  return user ? children : <Navigate to="/login" replace />
}

function AppRoutes() {
  const { user, logout, notification, clearNotification, setNotification, theme, toggleTheme } = useContext(AuthContext)

  const navItems = [
    { to: '/dashboard', label: '🏠 Dashboard', roles: ['Admin', 'Faculty', 'Student'] },
    { to: '/applications', label: '📋 Applications', roles: ['Admin', 'Faculty', 'Student'] },
    { to: '/internships', label: '🏢 Internships', roles: ['Admin', 'Faculty', 'Student'] },
    { to: '/approvals', label: '✅ Approvals', roles: ['Admin', 'Faculty'] },
    { to: '/remarks', label: '💬 Remarks', roles: ['Admin', 'Faculty', 'Student'] },
    { to: '/users', label: '👥 Users', roles: ['Admin'] },
  ]

  return (
    <div className={`app-frame ${user ? '' : 'auth-layout'}`}>
      {notification?.message && (
        <div className={`toast ${notification.type || 'info'}`} onClick={clearNotification}>
          {notification.message}
        </div>
      )}
      {user && (
        <aside className="sidebar">
          <div className="brand">
            <div className="brand-mark">SIMS</div>
            <div>
              <h1>Internship Portal</h1>
              <p>{user.role} Dashboard</p>
            </div>
          </div>

          <div className="user-summary">
            <p>Welcome, <strong>{user.first_name} {user.last_name}</strong></p>
            <p>{user.email}</p>
            <Link to="/change-password" className="change-password-link">Change Password</Link>
            <button
              className="secondary"
              onClick={() => {
                logout()
                setNotification({ message: 'Logged out successfully', type: 'info' })
              }}
            >
              Logout
            </button>
            <button className="theme-toggle" onClick={toggleTheme} title={`Switch to ${theme === 'light' ? 'dark' : 'light'} mode`}>
              {theme === 'light' ? '🌙 Dark' : '☀️ Light'}
            </button>
          </div>

          <nav>
            {navItems.filter((item) => item.roles.includes(user.role)).map((item) => (
              <NavLink key={item.to} to={item.to} className="nav-link">
                {item.label}
              </NavLink>
            ))}
          </nav>
        </aside>
      )}

      <main className="content-area">
        <Routes>
          <Route path="/login" element={user ? <Navigate to={redirectPath(user)} replace /> : <Login />} />
          <Route path="/register" element={user ? <Navigate to={redirectPath(user)} replace /> : <Register />} />
          <Route path="/change-password" element={<PrivateRoute><ChangePassword /></PrivateRoute>} />

          <Route path="/dashboard" element={<PrivateRoute><Dashboard /></PrivateRoute>} />
          <Route path="/applications" element={<PrivateRoute><Applications /></PrivateRoute>} />
          <Route path="/internships" element={<PrivateRoute><Internships /></PrivateRoute>} />
          <Route path="/approvals" element={<PrivateRoute><Approvals /></PrivateRoute>} />
          <Route path="/remarks" element={<PrivateRoute><Remarks /></PrivateRoute>} />
          <Route path="/users" element={<PrivateRoute><Users /></PrivateRoute>} />

          <Route path="*" element={<Navigate to={user ? redirectPath(user) : '/login'} replace />} />
        </Routes>
      </main>
    </div>
  )
}

function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <AppRoutes />
      </AuthProvider>
    </BrowserRouter>
  )
}

export default App
