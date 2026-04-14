import { useState } from 'react'
import api from '../api'

export default function Remarks() {
  const [keys, setKeys] = useState({ application_id: '', faculty_id: '', revision_no: '' })
  const [remarks, setRemarks] = useState([])
  const [form, setForm] = useState({ application_id: '', faculty_id: '', revision_no: '', remark_type: 'General', remark_text: '', remark_date: '' })
  const [message, setMessage] = useState('')

  const loadRemarks = () => {
    api.get(`/remarks/${keys.application_id}/${keys.faculty_id}/${keys.revision_no}`)
      .then((res) => setRemarks(res.data.data || []))
      .catch((err) => setMessage(err.response?.data?.detail || 'Unable to load remarks.'))
  }

  const createRemark = () => {
    api.post('/remarks', form)
      .then(() => {
        setMessage('Remark added.')
        setForm({ ...form, remark_type: 'General', remark_text: '', remark_date: '' })
        setKeys({ application_id: form.application_id, faculty_id: form.faculty_id, revision_no: form.revision_no })
        loadRemarks()
      })
      .catch((err) => setMessage(err.response?.data?.detail || 'Create remark failed.'))
  }

  const deleteRemark = (id) => {
    api.delete(`/remarks/${id}`)
      .then(() => {
        setMessage('Remark deleted.')
        loadRemarks()
      })
      .catch((err) => setMessage(err.response?.data?.detail || 'Delete remark failed.'))
  }

  return (
    <div className="page-shell">
      <div className="page-header">
        <h2>Remarks</h2>
        <p>View and manage approval remarks linked to application revisions.</p>
      </div>

      {message && <div className="alert info">{message}</div>}

      <div className="panel-row">
        <div className="panel-card small-panel">
          <h3>Load Remarks</h3>
          <label>Application ID<input value={keys.application_id} onChange={(e) => setKeys({ ...keys, application_id: e.target.value })} /></label>
          <label>Faculty ID<input value={keys.faculty_id} onChange={(e) => setKeys({ ...keys, faculty_id: e.target.value })} /></label>
          <label>Revision No<input value={keys.revision_no} onChange={(e) => setKeys({ ...keys, revision_no: e.target.value })} /></label>
          <button onClick={loadRemarks}>Load Remarks</button>
        </div>
        <div className="panel-card small-panel">
          <h3>Add Remark</h3>
          <label>Application ID<input value={form.application_id} onChange={(e) => setForm({ ...form, application_id: e.target.value })} /></label>
          <label>Faculty ID<input value={form.faculty_id} onChange={(e) => setForm({ ...form, faculty_id: e.target.value })} /></label>
          <label>Revision No<input value={form.revision_no} onChange={(e) => setForm({ ...form, revision_no: e.target.value })} /></label>
          <label>Type<select value={form.remark_type} onChange={(e) => setForm({ ...form, remark_type: e.target.value })}>
            <option>General</option>
            <option>Correction</option>
            <option>Query</option>
            <option>Clarification</option>
            <option>Final</option>
          </select></label>
          <label>Text<textarea value={form.remark_text} onChange={(e) => setForm({ ...form, remark_text: e.target.value })} /></label>
          <label>Date<input type="date" value={form.remark_date} onChange={(e) => setForm({ ...form, remark_date: e.target.value })} /></label>
          <button onClick={createRemark}>Add Remark</button>
        </div>
      </div>

      <div className="section-card">
        <h3>Remark List</h3>
        <div className="table-scroll">
          <table>
            <thead>
              <tr>
                <th>ID</th>
                <th>Type</th>
                <th>Date</th>
                <th>Text</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
              {remarks.map((row) => (
                <tr key={row.remark_id}>
                  <td>{row.remark_id}</td>
                  <td>{row.remark_type}</td>
                  <td>{new Date(row.remark_date).toLocaleDateString()}</td>
                  <td>{row.remark_text}</td>
                  <td><button className="danger" onClick={() => deleteRemark(row.remark_id)}>Delete</button></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}
