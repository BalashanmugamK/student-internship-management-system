import { useContext, useEffect, useState } from 'react'
import api from '../api'
import { AuthContext } from '../AuthContext'

const badgeClass = (operation) => {
  if (operation === 'INSERT') return 'badge success'
  if (operation === 'UPDATE') return 'badge warning'
  if (operation === 'DELETE') return 'badge danger'
  return 'badge default'
}

export default function Dashboard() {
  const { user } = useContext(AuthContext)
  const [stats, setStats] = useState(null)
  const [audit, setAudit] = useState([])
  const [count, setCount] = useState(0)
  const [error, setError] = useState('')

  useEffect(() => {
    if (!user) return

    if (user.role === 'Admin') {
      api.get('/dashboard/stats')
        .then((res) => setStats(res.data))
        .catch(() => setError('Unable to load dashboard stats.'))

      api.get('/audit-log')
        .then((res) => setAudit(res.data.data || []))
        .catch(() => setError('Unable to load audit log.'))
    } else if (user.role === 'Student') {
      api.get(`/applications/student/${user.student_id}`)
        .then((res) => setCount(res.data.count || 0))
        .catch(() => setError('Unable to load student application summary.'))
    } else if (user.role === 'Faculty') {
      api.get(`/approvals/faculty/${user.faculty_id}`)
        .then((res) => setCount(res.data.count || 0))
        .catch(() => setError('Unable to load faculty approval summary.'))
    }
  }, [user])

  const headline = user?.role === 'Admin' ? 'Admin Dashboard' : `${user?.role} Home`
  const description = user?.role === 'Admin'
    ? 'Central monitoring for system activity and audit history.'
    : user?.role === 'Student'
      ? 'Review your submitted internship applications.'
      : 'Review your pending approval assignments.'

  return (
    <div className="page-shell">
      <div className="page-header">
        <h2>{headline}</h2>
        <p>{description}</p>
      </div>

      {error && <div className="alert error">{error}</div>}

      {user?.role === 'Admin' ? (
        <>
          <div className="stats-grid">
            {['total_students', 'total_internships', 'total_applications', 'total_approvals'].map((key) => (
              <div className="card" key={key}>
                <div className="card-label">{key.replace('total_', '').replace('_', ' ').toUpperCase()}</div>
                <div className="card-value">{stats?.[key] ?? '-'}</div>
              </div>
            ))}
          </div>

          <div className="section-card">
            <h3>Application Status Breakdown</h3>
            <table>
              <thead>
                <tr>
                  <th>Status</th>
                  <th>Count</th>
                </tr>
              </thead>
              <tbody>
                {stats?.status_counts?.map((item) => (
                  <tr key={item.status}>
                    <td>{item.status}</td>
                    <td>{item.count}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="section-card">
            <h3>Audit Log</h3>
            <div className="table-scroll">
              <table>
                <thead>
                  <tr>
                    <th>ID</th>
                    <th>Table</th>
                    <th>Operation</th>
                    <th>Record</th>
                    <th>By</th>
                    <th>Date</th>
                    <th>Old</th>
                    <th>New</th>
                  </tr>
                </thead>
                <tbody>
                  {audit.map((row) => (
                    <tr key={row.audit_id}>
                      <td>{row.audit_id}</td>
                      <td>{row.table_name}</td>
                      <td><span className={badgeClass(row.operation)}>{row.operation}</span></td>
                      <td>{row.record_id}</td>
                      <td>{row.changed_by}</td>
                      <td>{new Date(row.changed_at).toLocaleString()}</td>
                      <td>{row.old_values}</td>
                      <td>{row.new_values}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </>
      ) : (
        <div className="section-card">
          <h3>{user.role === 'Student' ? 'Applications submitted' : 'Approvals assigned'}</h3>
          <p>{count} records found for your account.</p>
        </div>
      )}
    </div>
  )
}
