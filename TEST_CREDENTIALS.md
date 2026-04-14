## Test User Credentials for SIMS

All passwords are hashed using **PBKDF2-HMAC-SHA512** (100,000 iterations).

### Password Criteria (Registration)
To create a strong password during registration, you must meet at least **3 of 5 criteria**:
- ✓ At least 8 characters
- ✓ Uppercase letter (A-Z)
- ✓ Lowercase letter (a-z)
- ✓ Number (0-9)
- ✓ Special character (!@#$%^&*...)

### Students (5 users)
| Username | Password | Role | Dept | CGPA | Year |
|----------|----------|------|------|------|------|
| rahul_k | Rahul@123 | Student | SCOPE | 9.20 | 2 |
| sneha_s | Sneha@123 | Student | SCOPE | 8.80 | 3 |
| amit_p | Amit@123 | Student | SITE | 7.50 | 4 |
| neha_g | Neha@123 | Student | SENSE | 8.10 | 2 |
| karan_s | Karan@123 | Student | SCOPE | 9.50 | 3 |

### Faculty (5 users)
| Username | Password | Role | Designation | Dept |
|----------|----------|------|-------------|------|
| rohan_m | Rohan@123 | Faculty | Assistant Professor | SCOPE |
| priya_n | Priya@123 | Faculty | Professor | SCOPE |
| vikram_r | Vikram@123 | Faculty | Associate Professor | SITE |
| anjali_d | Anjali@123 | Faculty | Lecturer | SENSE |
| suresh_i | Suresh@123 | Faculty | Professor | SCOPE |

### Admins (5 users)
| Username | Password | Role | Type |
|----------|----------|------|------|
| sys_admin | SysAdmin@123 | Admin | SuperAdmin |
| dept_admin1 | DeptAdmin@123 | Admin | DeptAdmin |
| dept_admin2 | DeptAdmin@123 | Admin | DeptAdmin |
| viewer1 | Viewer@123 | Admin | Viewer |
| viewer2 | Viewer@123 | Admin | Viewer |

### Backend Test Users (For `/auth/seed-test-users`)
| Username | Password | Role |
|----------|----------|------|
| admin@example.com | Admin123 | Admin |
| faculty@example.com | Faculty123 | Faculty |
| student@example.com | Student123 | Student |

---

**Notes:**
- SQL script users (15 total): For production/demo database seeding
- Backend test users (3 total): For quick testing via the `/auth/seed-test-users` endpoint
- All passwords are securely hashed; never stored in plaintext
- Email addresses use `@university.edu` domain for SQL users
- Email addresses use `@example.com` domain for backend test users
