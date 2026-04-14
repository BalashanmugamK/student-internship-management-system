import { useContext, useEffect, useState } from 'react'
import api from '../api'
import { AuthContext } from '../AuthContext'

export default function Approvals() {
  const { user } = useContext(AuthContext)
  const [approvals, setApprovals] = useState([])
  const [history, setHistory] = useState([])
  const [form, setForm] = useState({ application_id: '', faculty_id: '', revision_no: '', approval_date: '', decision: 'Pending' })
  const [selectedApp, setSelectedApp] = useState(null)
  const [message, setMessage] = useState('')

  useEffect(() => {
    if (user) loadApprovals()
  }, [user])

  const loadApprovals = () => {
    const endpoint = user?.role === 'Faculty' && user.faculty_id ? `/approvals/faculty/${user.faculty_id}` : '/approvals'
    api.get(endpoint)
      .then((res) => setApprovals(res.data.data || []))
      .catch(() => setMessage('Unable to load approvals.'))
  }

  const submitApproval = () => {
    api.post('/approvals', {
      application_id: Number(form.application_id),
      faculty_id: Number(form.faculty_id),
      revision_no: Number(form.revision_no),
      approval_date: form.approval_date,
      decision: form.decision,
    })
      .then(() => {
        setMessage('Approval record created.')
        setForm({ application_id: '', faculty_id: '', revision_no: '', approval_date: '', decision: 'Pending' })
        loadApprovals()
      })
      .catch((err) => setMessage(err.response?.data?.detail || 'Create approval failed.'))
  }

  const updateDecision = (row, decision) => {
    api.put(`/approvals/${row.application_id}/${row.faculty_id}/${row.revision_no}`, { decision })
      .then(() => {
        setMessage('Decision updated.')
        loadApprovals()
      })
      .catch((err) => setMessage(err.response?.data?.detail || 'Decision update failed.'))
  }

  const viewHistory = (application_id) => {
    api.get(`/approvals/${application_id}/history`)
      .then((res) => {
        setHistory(res.data.data || [])
        setSelectedApp(application_id)
      })
      .catch(() => setMessage('Unable to load approval history.'))
  }

  return (
    <div className="page-shell">
      <div className="page-header">
        <h2>Approvals</h2>
        <p>Faculty review records and revision history for internship applications.</p>
      </div>

      {message && <div className="alert info">{message}</div>}

      <div className="panel-card small-panel">
        <h3>Add Approval</h3>
        <label>
          Application ID
          <input value={form.application_id} onChange={(e) => setForm({ ...form, application_id: e.target.value })} />
        </label>
        <label>
          Faculty ID
          <input
            value={form.faculty_id}
            onChange={(e) => setForm({ ...form, faculty_id: e.target.value })}
            placeholder={user?.role === 'Faculty' ? `Your faculty ID: ${user.faculty_id}` : ''}
          />
        </label>
        <label>
          Revision No
          <input value={form.revision_no} onChange={(e) => setForm({ ...form, revision_no: e.target.value })} />
        </label>
        <label>
          Decision
          <select value={form.decision} onChange={(e) => setForm({ ...form, decision: e.target.value })}>
            <option>Pending</option>
            <option>Approved</option>
            <option>Rejected</option>
          </select>
        </label>
        <label>
          Date
          <input type="date" value={form.approval_date} onChange={(e) => setForm({ ...form, approval_date: e.target.value })} />
        </label>
        <button onClick={submitApproval}>Create Approval</button>
      </div>

      <div className="section-card">
        <h3>Approval Records</h3>
        <div className="table-scroll">
          <table>
            <thead>
              <tr>
                <th>Application</th>
                <th>Faculty</th>
                <th>Revision</th>
                <th>Date</th>
                <th>Decision</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {approvals.map((row) => (
                <tr key={`${row.application_id}-${row.faculty_id}-${row.revision_no}`}>
                  <td>{row.application_id}</td>
                  <td>{row.faculty_name || row.faculty_id}</td>
                  <td>{row.revision_no}</td>
                  <td>{row.approval_date ? new Date(row.approval_date).toLocaleDateString() : ''}</td>
                  <td><span className={`badge decision ${row.decision.toLowerCase()}`}>{row.decision}</span></td>
                  <td>
                    <button className="secondary" onClick={() => updateDecision(row, 'Approved')}>Approve</button>
                    <button className="secondary" onClick={() => updateDecision(row, 'Rejected')}>Reject</button>
                    <button className="secondary" onClick={() => viewHistory(row.application_id)}>History</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {selectedApp && (
        <div className="section-card">
          <h3>Approval History for App {selectedApp}</h3>
          <div className="table-scroll">
            <table>
              <thead>
                <tr>
                  <th>Revision</th>
                  <th>Faculty</th>
                  <th>Date</th>
                  <th>Decision</th>
                </tr>
              </thead>
              <tbody>
                {history.map((row) => (
                  <tr key={`${row.faculty_id}-${row.revision_no}`}>
                    <td>{row.revision_no}</td>
                    <td>{row.faculty_name}</td>
                    <td>{row.approval_date ? new Date(row.approval_date).toLocaleDateString() : ''}</td>
                    <td>{row.decision}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  )
}
