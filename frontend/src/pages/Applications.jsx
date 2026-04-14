import { useContext, useEffect, useState } from 'react'
import api from '../api'
import { AuthContext } from '../AuthContext'

const statusOptions = ['All', 'Submitted', 'Under Review', 'Approved', 'Rejected', 'Withdrawn']

export default function Applications() {
  const { user } = useContext(AuthContext)
  const [applications, setApplications] = useState([])
  const [filter, setFilter] = useState('All')
  const [selected, setSelected] = useState(null)
  const [newApp, setNewApp] = useState({ studentId: '', internshipId: '' })
  const [status, setStatus] = useState({ message: '', type: '' })

  useEffect(() => {
    if (user) {
      loadApplications()
      if (user.role === 'Student' && user.student_id) {
        setNewApp((prev) => ({ ...prev, studentId: user.student_id }))
      }
    }
  }, [user])

  const loadApplications = () => {
    let endpoint = '/applications'
    if (user?.role === 'Student' && user.student_id) {
      endpoint = `/applications/student/${user.student_id}`
    } else if (filter !== 'All') {
      endpoint = `/applications/status/${encodeURIComponent(filter)}`
    }

    api.get(endpoint)
      .then((res) => setApplications(res.data.data || []))
      .catch(() => setStatus({ type: 'error', message: 'Unable to load applications.' }))
  }

  const createApplication = () => {
    const studentId = user?.role === 'Student' ? user.student_id : Number(newApp.studentId)
    api.post('/apply', { student_id: Number(studentId), internship_id: Number(newApp.internshipId) })
      .then(() => {
        setStatus({ type: 'success', message: 'Application submitted.' })
        setNewApp((prev) => ({ ...prev, internshipId: '' }))
        loadApplications()
      })
      .catch((err) => setStatus({ type: 'error', message: err.response?.data?.detail || 'Create failed.' }))
  }

  const updateStatus = (application_id, newStatus) => {
    api.put('/update', { application_id, status: newStatus })
      .then(() => {
        setStatus({ type: 'success', message: 'Status updated.' })
        loadApplications()
      })
      .catch((err) => setStatus({ type: 'error', message: err.response?.data?.detail || 'Update failed.' }))
  }

  const deleteApplication = (id) => {
    api.delete(`/delete/${id}`)
      .then(() => {
        setStatus({ type: 'success', message: 'Application deleted.' })
        loadApplications()
      })
      .catch((err) => setStatus({ type: 'error', message: err.response?.data?.detail || 'Delete failed.' }))
  }

  const loadDetail = (id) => {
    api.get(`/applications/${id}/detail`)
      .then((res) => setSelected(res.data))
      .catch((err) => setStatus({ type: 'error', message: err.response?.data?.detail || 'Unable to load detail.' }))
  }

  return (
    <div className="page-shell">
      <div className="page-header">
        <h2>Applications</h2>
        <p>Submit new applications, filter by status, and inspect detail history.</p>
      </div>

      {status.message && <div className={`alert ${status.type}`}>{status.message}</div>}

      <div className="panel-row">
        <div className="panel-card small-panel">
          <h3>New Application</h3>
          <label>
            Student ID
            <input
              value={newApp.studentId}
              onChange={(e) => setNewApp({ ...newApp, studentId: e.target.value })}
              disabled={user?.role === 'Student'}
              placeholder={user?.role === 'Student' ? 'Your student ID is fixed' : 'Enter student ID'}
            />
          </label>
          <label>
            Internship ID
            <input value={newApp.internshipId} onChange={(e) => setNewApp({ ...newApp, internshipId: e.target.value })} />
          </label>
          <button onClick={createApplication}>Submit</button>
        </div>

        <div className="panel-card small-panel lower-filter">
          <h3>Filter</h3>
          <select value={filter} onChange={(e) => setFilter(e.target.value)}>
            {statusOptions.map((statusOption) => <option key={statusOption} value={statusOption}>{statusOption}</option>)}
          </select>
          <button onClick={loadApplications}>Apply Filter</button>
        </div>
      </div>

      <div className="section-card">
        <h3>Application Records</h3>
        <div className="table-scroll">
          <table>
            <thead>
              <tr>
                <th>App ID</th>
                <th>Student ID</th>
                <th>Internship ID</th>
                <th>Date</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {applications.map((row) => (
                <tr key={row.application_id}>
                  <td>
                    <button className="link-button" onClick={() => loadDetail(row.application_id)}>{row.application_id}</button>
                  </td>
                  <td>{row.student_id}</td>
                  <td>{row.internship_id}</td>
                  <td>{new Date(row.applied_date).toLocaleDateString()}</td>
                  <td><span className={`badge status ${row.status.toLowerCase().replace(/\s/g, '-')}`}>{row.status}</span></td>
                  <td>
                    <div className="action-cell">
                      <select onChange={(e) => updateStatus(row.application_id, e.target.value)} defaultValue="">
                        <option value="" disabled>Change</option>
                        {statusOptions.slice(1).map((statusOption) => (
                          <option key={statusOption} value={statusOption}>{statusOption}</option>
                        ))}
                      </select>
                      <button className="danger" onClick={() => deleteApplication(row.application_id)}>Delete</button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {selected && (
        <div className="section-card">
          <h3>Application Detail</h3>
          <div className="detail-grid">
            {Object.entries(selected).map(([key, value]) => (
              <div key={key} className="detail-row">
                <strong>{key.replace(/_/g, ' ')}</strong>
                <span>{String(value)}</span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}
