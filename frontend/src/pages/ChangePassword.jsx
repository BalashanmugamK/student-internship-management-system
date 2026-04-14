import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import api from '../api'

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

export default function ChangePassword() {
  const [form, setForm] = useState({
    currentPassword: '',
    newPassword: '',
    confirmPassword: '',
  })
  const [message, setMessage] = useState('')
  const [error, setError] = useState('')
  const [showCurrent, setShowCurrent] = useState(false)
  const [showNew, setShowNew] = useState(false)
  const navigate = useNavigate()

  const getPasswordStrength = (password) => {
    let strength = 0
    if (password.length >= 8) strength++
    if (/[A-Z]/.test(password)) strength++
    if (/[a-z]/.test(password)) strength++
    if (/[0-9]/.test(password)) strength++
    if (/[^A-Za-z0-9]/.test(password)) strength++
    return strength
  }

  const strengthLabels = ['Very Weak', 'Weak', 'Fair', 'Good', 'Strong', 'Very Strong']
  const strengthClasses = ['very-weak', 'weak', 'fair', 'good', 'strong', 'very-strong']

  const getPasswordStrengthLabel = (password) => strengthLabels[getPasswordStrength(password)]
  const getPasswordStrengthPercent = (password) => Math.min((getPasswordStrength(password) / 4) * 100, 100)

  const handleSubmit = async (event) => {
    event.preventDefault()
    setMessage('')
    setError('')

    if (form.newPassword !== form.confirmPassword) {
      setError('New passwords do not match.')
      return
    }

    if (getPasswordStrength(form.newPassword) < 3) {
      setError('New password is too weak. Use at least 8 characters with uppercase, lowercase, and numbers.')
      return
    }

    try {
      await api.post('/auth/change-password', {
        email: JSON.parse(localStorage.getItem('user')).email,
        current_password: form.currentPassword,
        new_password: form.newPassword,
      })
      setMessage('Password changed successfully.')
      setForm({ currentPassword: '', newPassword: '', confirmPassword: '' })
    } catch (err) {
      setError(err.response?.data?.detail || 'Password change failed.')
    }
  }

  return (
    <div className="login-shell">
      <div className="auth-card">
        <h2>Change Password</h2>
        <p>Update your account password.</p>

        {message && <div className="alert info">{message}</div>}
        {error && <div className="alert error">{error}</div>}

        <form onSubmit={handleSubmit}>
          <label>
            Current Password
            <div className="password-field">
              <input
                type={showCurrent ? 'text' : 'password'}
                value={form.currentPassword}
                onChange={(e) => setForm({ ...form, currentPassword: e.target.value })}
                required
              />
              <button type="button" onClick={() => setShowCurrent(!showCurrent)} className="toggle-password">
                <PasswordToggleIcon visible={showCurrent} />
              </button>
            </div>
          </label>

          <label>
            New Password
            <div className="password-field">
              <input
                type={showNew ? 'text' : 'password'}
                value={form.newPassword}
                onChange={(e) => setForm({ ...form, newPassword: e.target.value })}
                required
              />
              <button type="button" onClick={() => setShowNew(!showNew)} className="toggle-password">
                <PasswordToggleIcon visible={showNew} />
              </button>
            </div>
            <div className="password-strength">
              <div className="password-strength-label">
                Strength: {form.newPassword ? getPasswordStrengthLabel(form.newPassword) : 'Too short'}
              </div>
              <div className="password-strength-meter">
                <div
                  className={`password-strength-bar strength-${strengthClasses[getPasswordStrength(form.newPassword)]}`}
                  style={{ width: `${getPasswordStrengthPercent(form.newPassword)}%` }}
                />
              </div>
              <div className="password-criteria">
                <div className={form.newPassword.length >= 8 ? 'criteria met' : 'criteria'}>
                  {form.newPassword.length >= 8 ? '✓' : '○'} At least 8 characters
                </div>
                <div className={/[A-Z]/.test(form.newPassword) ? 'criteria met' : 'criteria'}>
                  {/[A-Z]/.test(form.newPassword) ? '✓' : '○'} Uppercase letter
                </div>
                <div className={/[a-z]/.test(form.newPassword) ? 'criteria met' : 'criteria'}>
                  {/[a-z]/.test(form.newPassword) ? '✓' : '○'} Lowercase letter
                </div>
                <div className={/[0-9]/.test(form.newPassword) ? 'criteria met' : 'criteria'}>
                  {/[0-9]/.test(form.newPassword) ? '✓' : '○'} Number
                </div>
                <div className={/[^A-Za-z0-9]/.test(form.newPassword) ? 'criteria met' : 'criteria'}>
                  {/[^A-Za-z0-9]/.test(form.newPassword) ? '✓' : '○'} Special character
                </div>
              </div>
            </div>
          </label>

          <label>
            Confirm New Password
            <input
              type="password"
              value={form.confirmPassword}
              onChange={(e) => setForm({ ...form, confirmPassword: e.target.value })}
              required
            />
          </label>

          <button type="submit">Change Password</button>
        </form>

        <button onClick={() => navigate(-1)} className="back-button">Back</button>
      </div>
    </div>
  )
}