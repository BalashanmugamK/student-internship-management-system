# Student Internship Management System (SIMS)

This project is a full-stack build for the Student Internship Management System (SIMS) developed for BCSE302L — Database Systems. The application connects a React+Vite frontend to a FastAPI backend and uses an existing Oracle XE database schema.

## Project Structure

```
sims/
├── backend/
│   ├── db.py
│   ├── main.py
│   └── requirements.txt
└── frontend/
    ├── package.json
    ├── vite.config.js
    └── src/
        ├── App.jsx
        ├── api.js
        ├── main.jsx
        ├── App.css
        ├── index.css
        └── pages/
            ├── Dashboard.jsx
            ├── Applications.jsx
            ├── Internships.jsx
            ├── Approvals.jsx
            ├── Remarks.jsx
            └── Users.jsx
```

## Run Instructions

### Backend

```bash
cd e:\sims\backend
pip install -r requirements.txt
python main.py
```

The backend starts at `http://127.0.0.1:8001`.

### Frontend

```bash
cd e:\sims\frontend
npm install
npm run dev
```

The frontend starts at `http://localhost:5173`.

## Notes

- The backend uses `python-oracledb` in thin mode and connects to the existing Oracle XE database on `localhost:1521/xepdb1`.
- The app does not recreate the Oracle schema. It uses read/write access through API endpoints only.
- React Router is used for navigation across dashboard, applications, internships, approvals, remarks, and users pages.
