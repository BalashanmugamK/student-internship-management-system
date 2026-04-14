import { useEffect, useState } from 'react'
import api from '../api'

export default function Internships() {
  const [companies, setCompanies] = useState([])
  const [internships, setInternships] = useState([])
  const [tab, setTab] = useState('companies')
  const [companyForm, setCompanyForm] = useState({ company_name: '', city: '', state: '' })
  const [internshipForm, setInternshipForm] = useState({ title: '', duration: '', stipend: '', company_id: '' })
  const [eligibility, setEligibility] = useState([])
  const [selectedId, setSelectedId] = useState(null)
  const [status, setStatus] = useState('')

  useEffect(() => {
    fetchCompanies()
    fetchInternships()
  }, [])

  const fetchCompanies = () => api.get('/companies').then((res) => setCompanies(res.data.data || [])).catch(() => setStatus('Unable to load companies.'))
  const fetchInternships = () => api.get('/internships').then((res) => setInternships(res.data.data || [])).catch(() => setStatus('Unable to load internships.'))

  const createCompany = () => {
    api.post('/companies', companyForm)
      .then(() => {
        setStatus('Company added successfully.')
        setCompanyForm({ company_name: '', city: '', state: '' })
        fetchCompanies()
      })
      .catch((err) => setStatus(err.response?.data?.detail || 'Create company failed.'))
  }

  const deactivateCompany = (company_id) => {
    api.put(`/companies/${company_id}/deactivate`)
      .then(() => {
        setStatus('Company deactivated.')
        fetchCompanies()
      })
      .catch((err) => setStatus(err.response?.data?.detail || 'Deactivate failed.'))
  }

  const createInternship = () => {
    api.post('/internships', { ...internshipForm, stipend: Number(internshipForm.stipend), company_id: Number(internshipForm.company_id) })
      .then(() => {
        setStatus('Internship added.')
        setInternshipForm({ title: '', duration: '', stipend: '', company_id: '' })
        fetchInternships()
      })
      .catch((err) => setStatus(err.response?.data?.detail || 'Create internship failed.'))
  }

  const toggleInternship = (id) => {
    api.put(`/internships/${id}/toggle`)
      .then(() => {
        setStatus('Internship state toggled.')
        fetchInternships()
      })
      .catch((err) => setStatus(err.response?.data?.detail || 'Toggle failed.'))
  }

  const viewEligibility = (id) => {
    api.get(`/internships/${id}/eligibility`)
      .then((res) => {
        setEligibility(res.data.data || [])
        setSelectedId(id)
      })
      .catch(() => setStatus('Unable to load eligibility.'))
  }

  return (
    <div className="page-shell">
      <div className="page-header">
        <h2>Internships</h2>
        <p>Manage companies, internships, and eligibility requirements.</p>
      </div>

      {status && <div className="alert info">{status}</div>}

      <div className="tab-row">
        <button className={tab === 'companies' ? 'tab active' : 'tab'} onClick={() => setTab('companies')}>Companies</button>
        <button className={tab === 'internships' ? 'tab active' : 'tab'} onClick={() => setTab('internships')}>Internships</button>
      </div>

      {tab === 'companies' ? (
        <>
          <div className="panel-row">
            <div className="panel-card small-panel">
              <h3>Add Company</h3>
              <label>Name<input value={companyForm.company_name} onChange={(e) => setCompanyForm({ ...companyForm, company_name: e.target.value })} /></label>
              <label>City<input value={companyForm.city} onChange={(e) => setCompanyForm({ ...companyForm, city: e.target.value })} /></label>
              <label>State<input value={companyForm.state} onChange={(e) => setCompanyForm({ ...companyForm, state: e.target.value })} /></label>
              <button onClick={createCompany}>Add Company</button>
            </div>
          </div>

          <div className="section-card">
            <h3>Company List</h3>
            <div className="table-scroll">
              <table>
                <thead>
                  <tr>
                    <th>ID</th>
                    <th>Name</th>
                    <th>City</th>
                    <th>State</th>
                    <th>Active</th>
                    <th>Action</th>
                  </tr>
                </thead>
                <tbody>
                  {companies.map((row) => (
                    <tr key={row.company_id}>
                      <td>{row.company_id}</td>
                      <td>{row.company_name}</td>
                      <td>{row.city}</td>
                      <td>{row.state}</td>
                      <td>{row.is_active}</td>
                      <td><button className="danger" onClick={() => deactivateCompany(row.company_id)}>Deactivate</button></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </>
      ) : (
        <>
          <div className="panel-row">
            <div className="panel-card small-panel">
              <h3>Add Internship</h3>
              <label>Title<input value={internshipForm.title} onChange={(e) => setInternshipForm({ ...internshipForm, title: e.target.value })} /></label>
              <label>Duration<input value={internshipForm.duration} onChange={(e) => setInternshipForm({ ...internshipForm, duration: e.target.value })} /></label>
              <label>Stipend<input type="number" value={internshipForm.stipend} onChange={(e) => setInternshipForm({ ...internshipForm, stipend: e.target.value })} /></label>
              <label>Company<select value={internshipForm.company_id} onChange={(e) => setInternshipForm({ ...internshipForm, company_id: e.target.value })}>
                <option value="">Select company</option>
                {companies.map((company) => <option key={company.company_id} value={company.company_id}>{company.company_name}</option>)}
              </select></label>
              <button onClick={createInternship}>Add Internship</button>
            </div>
          </div>

          <div className="section-card">
            <h3>Internship List</h3>
            <div className="table-scroll">
              <table>
                <thead>
                  <tr>
                    <th>ID</th>
                    <th>Title</th>
                    <th>Duration</th>
                    <th>Stipend</th>
                    <th>Company</th>
                    <th>Active</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {internships.map((row) => (
                    <tr key={row.internship_id}>
                      <td>{row.internship_id}</td>
                      <td>{row.title}</td>
                      <td>{row.duration}</td>
                      <td>{row.stipend}</td>
                      <td>{row.company_name}</td>
                      <td>{row.is_active}</td>
                      <td>
                        <button className="secondary" onClick={() => toggleInternship(row.internship_id)}>Toggle</button>
                        <button className="secondary" onClick={() => viewEligibility(row.internship_id)}>Eligibility</button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>

          {selectedId && (
            <div className="section-card">
              <h3>Eligibility for Internship {selectedId}</h3>
              <div className="chips">
                {eligibility.map((item, index) => (
                  <span key={`${item.type}-${index}`} className="chip">{item.type}: {item.value}</span>
                ))}
              </div>
            </div>
          )}
        </>
      )}
    </div>
  )
}
