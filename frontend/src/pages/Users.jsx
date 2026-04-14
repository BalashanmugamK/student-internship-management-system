import { useEffect, useState } from 'react'
import api from '../api'

const defaultStudent = {
  first_name: '',
  last_name: '',
  email: '',
  gender: 'Male',
  dept: '',
  cgpa: '',
  year_of_study: '',
}

const defaultFaculty = {
  first_name: '',
  last_name: '',
  email: '',
  gender: 'Male',
  dept: '',
  designation: '',
}

const defaultAdmin = {
  first_name: '',
  last_name: '',
  email: '',
  gender: 'Male',
}

export default function Users() {
  const [users, setUsers] = useState([])
  const [students, setStudents] = useState([])
  const [faculty, setFaculty] = useState([])
  const [admins, setAdmins] = useState([])
  const [tab, setTab] = useState('all')
  const [message, setMessage] = useState('')
  const [studentForm, setStudentForm] = useState(defaultStudent)
  const [facultyForm, setFacultyForm] = useState(defaultFaculty)
  const [adminForm, setAdminForm] = useState(defaultAdmin)

  const refresh = () => {
    api.get('/users').then((res) => setUsers(res.data.data || [])).catch(() => setMessage('Unable to load users.'))
    api.get('/students').then((res) => setStudents(res.data.data || [])).catch(() => setMessage('Unable to load students.'))
    api.get('/faculty').then((res) => setFaculty(res.data.data || [])).catch(() => setMessage('Unable to load faculty.'))
    api.get('/admin').then((res) => setAdmins(res.data.data || [])).catch(() => setMessage('Unable to load admins.'))
  }

  useEffect(() => {
    refresh()
  }, [])

  const toggleUser = (user_id) => {
    api.put(`/users/${user_id}/toggle`)
      .then(() => {
        setMessage('User status toggled.')
        refresh()
      })
      .catch((err) => setMessage(err.response?.data?.detail || 'Toggle failed.'))
  }

  const createStudent = () => {
    api.post('/students', {
      ...studentForm,
      cgpa: Number(studentForm.cgpa),
      year_of_study: Number(studentForm.year_of_study),
    })
      .then(() => {
        setMessage('Student created successfully.')
        setStudentForm(defaultStudent)
        refresh()
      })
      .catch((err) => setMessage(err.response?.data?.detail || 'Failed to create student.'))
  }

  const createFaculty = () => {
    api.post('/faculty', facultyForm)
      .then(() => {
        setMessage('Faculty created successfully.')
        setFacultyForm(defaultFaculty)
        refresh()
      })
      .catch((err) => setMessage(err.response?.data?.detail || 'Failed to create faculty.'))
  }

  const createAdmin = () => {
    api.post('/admin', adminForm)
      .then(() => {
        setMessage('Admin created successfully.')
        setAdminForm(defaultAdmin)
        refresh()
      })
      .catch((err) => setMessage(err.response?.data?.detail || 'Failed to create admin.'))
  }

  const renderTable = () => {
    if (tab === 'students') {
      return (
        <>
          <div className="panel-card small-panel">
            <h3>Add Student</h3>
            <label>First Name<input value={studentForm.first_name} onChange={(e) => setStudentForm({ ...studentForm, first_name: e.target.value })} /></label>
            <label>Last Name<input value={studentForm.last_name} onChange={(e) => setStudentForm({ ...studentForm, last_name: e.target.value })} /></label>
            <label>Email<input value={studentForm.email} onChange={(e) => setStudentForm({ ...studentForm, email: e.target.value })} /></label>
            <label>Gender<select value={studentForm.gender} onChange={(e) => setStudentForm({ ...studentForm, gender: e.target.value })}>
              <option>Male</option>
              <option>Female</option>
              <option>Other</option>
            </select></label>
            <label>Dept<input value={studentForm.dept} onChange={(e) => setStudentForm({ ...studentForm, dept: e.target.value })} /></label>
            <label>CGPA<input type="number" step="0.01" value={studentForm.cgpa} onChange={(e) => setStudentForm({ ...studentForm, cgpa: e.target.value })} /></label>
            <label>Year<input type="number" value={studentForm.year_of_study} onChange={(e) => setStudentForm({ ...studentForm, year_of_study: e.target.value })} /></label>
            <button onClick={createStudent}>Add Student</button>
          </div>

          <div className="section-card">
            <h3>Student List</h3>
            <div className="table-scroll">
              <table>
                <thead>
                  <tr>
                    <th>Student ID</th>
                    <th>Name</th>
                    <th>Email</th>
                    <th>Dept</th>
                    <th>CGPA</th>
                    <th>Year</th>
                    <th>Active</th>
                  </tr>
                </thead>
                <tbody>
                  {students.map((user) => (
                    <tr key={user.student_id}>
                      <td>{user.student_id}</td>
                      <td>{user.full_name}</td>
                      <td>{user.email}</td>
                      <td>{user.dept}</td>
                      <td>{user.cgpa}</td>
                      <td>{user.year_of_study}</td>
                      <td>{user.is_active}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </>
      )
    }

    if (tab === 'faculty') {
      return (
        <>
          <div className="panel-card small-panel">
            <h3>Add Faculty</h3>
            <label>First Name<input value={facultyForm.first_name} onChange={(e) => setFacultyForm({ ...facultyForm, first_name: e.target.value })} /></label>
            <label>Last Name<input value={facultyForm.last_name} onChange={(e) => setFacultyForm({ ...facultyForm, last_name: e.target.value })} /></label>
            <label>Email<input value={facultyForm.email} onChange={(e) => setFacultyForm({ ...facultyForm, email: e.target.value })} /></label>
            <label>Gender<select value={facultyForm.gender} onChange={(e) => setFacultyForm({ ...facultyForm, gender: e.target.value })}>
              <option>Male</option>
              <option>Female</option>
              <option>Other</option>
            </select></label>
            <label>Dept<input value={facultyForm.dept} onChange={(e) => setFacultyForm({ ...facultyForm, dept: e.target.value })} /></label>
            <label>Designation<input value={facultyForm.designation} onChange={(e) => setFacultyForm({ ...facultyForm, designation: e.target.value })} /></label>
            <button onClick={createFaculty}>Add Faculty</button>
          </div>

          <div className="section-card">
            <h3>Faculty List</h3>
            <div className="table-scroll">
              <table>
                <thead>
                  <tr>
                    <th>Faculty ID</th>
                    <th>Name</th>
                    <th>Email</th>
                    <th>Dept</th>
                    <th>Designation</th>
                    <th>Active</th>
                  </tr>
                </thead>
                <tbody>
                  {faculty.map((user) => (
                    <tr key={user.faculty_id}>
                      <td>{user.faculty_id}</td>
                      <td>{user.full_name}</td>
                      <td>{user.email}</td>
                      <td>{user.dept}</td>
                      <td>{user.designation}</td>
                      <td>{user.is_active}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </>
      )
    }

    if (tab === 'admin') {
      return (
        <>
          <div className="panel-card small-panel">
            <h3>Add Admin</h3>
            <label>First Name<input value={adminForm.first_name} onChange={(e) => setAdminForm({ ...adminForm, first_name: e.target.value })} /></label>
            <label>Last Name<input value={adminForm.last_name} onChange={(e) => setAdminForm({ ...adminForm, last_name: e.target.value })} /></label>
            <label>Email<input value={adminForm.email} onChange={(e) => setAdminForm({ ...adminForm, email: e.target.value })} /></label>
            <label>Gender<select value={adminForm.gender} onChange={(e) => setAdminForm({ ...adminForm, gender: e.target.value })}>
              <option>Male</option>
              <option>Female</option>
              <option>Other</option>
            </select></label>
            <button onClick={createAdmin}>Add Admin</button>
          </div>

          <div className="section-card">
            <h3>Admin List</h3>
            <div className="table-scroll">
              <table>
                <thead>
                  <tr>
                    <th>Admin ID</th>
                    <th>Name</th>
                    <th>Email</th>
                    <th>Gender</th>
                    <th>Role</th>
                    <th>Active</th>
                  </tr>
                </thead>
                <tbody>
                  {admins.map((user) => (
                    <tr key={user.admin_id}>
                      <td>{user.admin_id}</td>
                      <td>{user.full_name}</td>
                      <td>{user.email}</td>
                      <td>{user.gender}</td>
                      <td>{user.role}</td>
                      <td>{user.is_active}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </>
      )
    }

    return (
      <div className="section-card">
        <div className="table-scroll">
          <table>
            <thead>
              <tr>
                <th>User ID</th>
                <th>Name</th>
                <th>Email</th>
                <th>Gender</th>
                <th>Role</th>
                <th>Active</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
              {users.map((user) => (
                <tr key={user.user_id}>
                  <td>{user.user_id}</td>
                  <td>{`${user.first_name} ${user.last_name}`}</td>
                  <td>{user.email}</td>
                  <td>{user.gender}</td>
                  <td>{user.role}</td>
                  <td>{user.is_active}</td>
                  <td><button className="secondary" onClick={() => toggleUser(user.user_id)}>Toggle</button></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    )
  }

  return (
    <div className="page-shell">
      <div className="page-header">
        <h2>Users</h2>
        <p>View all users, students, faculty, and admin records from the Oracle schema.</p>
      </div>

      {message && <div className="alert info">{message}</div>}

      <div className="tab-row">
        <button className={tab === 'all' ? 'tab active' : 'tab'} onClick={() => setTab('all')}>All Users</button>
        <button className={tab === 'students' ? 'tab active' : 'tab'} onClick={() => setTab('students')}>Students</button>
        <button className={tab === 'faculty' ? 'tab active' : 'tab'} onClick={() => setTab('faculty')}>Faculty</button>
        <button className={tab === 'admin' ? 'tab active' : 'tab'} onClick={() => setTab('admin')}>Admin</button>
      </div>

      {renderTable()}
    </div>
  )
}
