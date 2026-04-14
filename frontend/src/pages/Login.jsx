import { useContext, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import api from '../api'
import { AuthContext } from '../AuthContext'

const PasswordToggleIcon = ({ visible }) => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="18" height="18" aria-hidden="true">
    <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8S1 12 1 12z" fill="none" stroke="currentColor" strokeWidth="2" />
    {visible ? (
      <circle cx="12" cy="12" r="3" fill="currentColor" />
    ) : (
      <line x1="2" y1="2" x2="22" y2="22" stroke="currentColor" strokeWidth="2" />
    )}
  </svg>
)

const redirectForRole = (role) => {
  if (role === 'Admin') return '/dashboard'
  if (role === 'Faculty') return '/approvals'
  return '/applications'
}

export default function Login() {
  const { login, setNotification } = useContext(AuthContext)
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [error, setError] = useState('')
  const navigate = useNavigate()

  const handleSubmit = async (event) => {
    event.preventDefault()
    setError('')

    try {
      const res = await api.post('/auth/login', { identifier: username, password })
      const user = res.data.user
      login(user)
      setNotification({ message: `Logged in successfully as ${user.role}`, type: 'success' })
      navigate(redirectForRole(user.role), { replace: true })
    } catch (err) {
      setError(err.response?.data?.detail || 'Login failed. Check your credentials.')
    }
  }

  return (
    <div className="login-shell">
      <div className="auth-card">
        <h2>Login</h2>
        <p>Enter your registered username and password. Students, Faculty, and Admins can all log in here.</p>

        {error && <div className="alert error">{error}</div>}

        <form onSubmit={handleSubmit}>
          <label>
            Username
            <input
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              placeholder="username"
              required
            />
          </label>

          <label>
            Password
            <div className="password-field">
              <input
                type={showPassword ? 'text' : 'password'}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
              <button
                type="button"
                className="toggle-password"
                onClick={() => setShowPassword((prev) => !prev)}
              >
                <PasswordToggleIcon visible={showPassword} />
              </button>
            </div>
          </label>

          <button type="submit">Login</button>
        </form>

        <p className="auth-actions">
          New user? <Link to="/register">Create an account</Link>
        </p>
      </div>
    </div>
  )
}
