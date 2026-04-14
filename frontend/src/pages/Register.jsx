import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
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

const initial = {
  role: 'Student',
  username: '',
  first_name: '',
  last_name: '',
  email: '',
  gender: 'Male',
  password: '',
  confirmPassword: '',
  dept: '',
  designation: '',
  cgpa: '',
  year_of_study: '',
}

export default function Register() {
  const [form, setForm] = useState(initial)
  const [message, setMessage] = useState('')
  const [error, setError] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [showConfirmPassword, setShowConfirmPassword] = useState(false)
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

    if (form.password !== form.confirmPassword) {
      setError('Passwords do not match.')
      return
    }

    if (getPasswordStrength(form.password) < 3) {
      setError('Password is too weak. Use at least 8 characters with uppercase, lowercase, and numbers.')
      return
    }

    const payload = {
      role: form.role,
      username: form.username || undefined,
      first_name: form.first_name,
      last_name: form.last_name,
      email: form.email,
      gender: form.gender,
      password: form.password,
      dept: form.dept,
    }

    if (form.role === 'Student') {
      payload.cgpa = Number(form.cgpa)
      payload.year_of_study = Number(form.year_of_study)
    } else {
      payload.designation = form.designation
    }

    try {
      await api.post('/auth/register', payload)
      setMessage('Registration complete. Please login with your email.')
      setForm(initial)
      navigate('/login', { replace: true })
    } catch (err) {
      setError(err.response?.data?.detail || 'Registration failed.')
    }
  }

  return (
    <div className="login-shell">
      <div className="auth-card">
        <h2>Register</h2>
        <p>Create a new Student, Faculty, or Admin account for the portal.</p>

        {message && <div className="alert info">{message}</div>}
        {error && <div className="alert error">{error}</div>}

        <form onSubmit={handleSubmit}>
          <label>
            Role
            <select value={form.role} onChange={(e) => setForm({ ...form, role: e.target.value })}>
              <option value="Student">Student</option>
              <option value="Faculty">Faculty</option>
              <option value="Admin">Admin</option>
            </select>
          </label>

          <label>
            First Name
            <input value={form.first_name} onChange={(e) => setForm({ ...form, first_name: e.target.value })} required />
          </label>

          <label>
            Last Name
            <input value={form.last_name} onChange={(e) => setForm({ ...form, last_name: e.target.value })} required />
          </label>

          <label>
            Email
            <input type="email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} required />
          </label>

          <label>
            Username (optional)
            <input
              value={form.username}
              onChange={(e) => setForm({ ...form, username: e.target.value })}
              placeholder="Leave blank to use email (e.g. student@example.com)"
            />
          </label>

          <label>
            Password
            <div className="password-field">
              <input
                type={showPassword ? 'text' : 'password'}
                value={form.password}
                onChange={(e) => setForm({ ...form, password: e.target.value })}
                required
              />
              <button type="button" onClick={() => setShowPassword(!showPassword)} className="toggle-password">
                <PasswordToggleIcon visible={showPassword} />
              </button>
            </div>
            <div className="password-strength">
              <div className="password-strength-label">
                Strength: {form.password ? getPasswordStrengthLabel(form.password) : 'Too short'}
              </div>
              <div className="password-strength-meter">
                <div
                  className={`password-strength-bar strength-${strengthClasses[getPasswordStrength(form.password)]}`}
                  style={{ width: `${getPasswordStrengthPercent(form.password)}%` }}
                />
              </div>
              <div className="password-criteria">
                <div className={form.password.length >= 8 ? 'criteria met' : 'criteria'}>
                  {form.password.length >= 8 ? '✓' : '○'} At least 8 characters
                </div>
                <div className={/[A-Z]/.test(form.password) ? 'criteria met' : 'criteria'}>
                  {/[A-Z]/.test(form.password) ? '✓' : '○'} Uppercase letter
                </div>
                <div className={/[a-z]/.test(form.password) ? 'criteria met' : 'criteria'}>
                  {/[a-z]/.test(form.password) ? '✓' : '○'} Lowercase letter
                </div>
                <div className={/[0-9]/.test(form.password) ? 'criteria met' : 'criteria'}>
                  {/[0-9]/.test(form.password) ? '✓' : '○'} Number
                </div>
                <div className={/[^A-Za-z0-9]/.test(form.password) ? 'criteria met' : 'criteria'}>
                  {/[^A-Za-z0-9]/.test(form.password) ? '✓' : '○'} Special character
                </div>
              </div>
            </div>
          </label>

          <label>
            Confirm Password
            <div className="password-field">
              <input
                type={showConfirmPassword ? 'text' : 'password'}
                value={form.confirmPassword}
                onChange={(e) => setForm({ ...form, confirmPassword: e.target.value })}
                required
              />
              <button type="button" onClick={() => setShowConfirmPassword(!showConfirmPassword)} className="toggle-password">
                <PasswordToggleIcon visible={showConfirmPassword} />
              </button>
            </div>
          </label>

          <label>
            Gender
            <select value={form.gender} onChange={(e) => setForm({ ...form, gender: e.target.value })}>
              <option>Male</option>
              <option>Female</option>
              <option>Other</option>
            </select>
          </label>

          {form.role !== 'Admin' && (
            <label>
              Department
              <input value={form.dept} onChange={(e) => setForm({ ...form, dept: e.target.value })} required />
            </label>
          )}

          {form.role === 'Student' && (
            <>
              <label>
                CGPA
                <input type="number" step="0.01" value={form.cgpa} onChange={(e) => setForm({ ...form, cgpa: e.target.value })} required />
              </label>
              <label>
                Year of Study
                <input type="number" value={form.year_of_study} onChange={(e) => setForm({ ...form, year_of_study: e.target.value })} required />
              </label>
            </>
          )}

          {form.role === 'Faculty' && (
            <label>
              Designation
              <input value={form.designation} onChange={(e) => setForm({ ...form, designation: e.target.value })} required />
            </label>
          )}

          <button type="submit">Register</button>
        </form>

        <p className="auth-actions">
          Already registered? <Link to="/login">Login here</Link>
        </p>
      </div>
    </div>
  )
}
