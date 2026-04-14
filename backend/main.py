import datetime
import hashlib
import secrets
from typing import Optional

import oracledb
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from db import get_connection

app = FastAPI(title="SIMS Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def serialize_row(row, cursor):
    cols = [col[0].lower() for col in cursor.description]
    result = {}
    for col, val in zip(cols, row):
        if isinstance(val, (datetime.datetime, datetime.date)):
            result[col] = val.isoformat()
        else:
            result[col] = val
    return result


def serialize_rows(rows, cursor):
    return [serialize_row(row, cursor) for row in rows]


def column_exists(connection, table_name: str, column_name: str) -> bool:
    cursor = connection.cursor()
    cursor.execute(
        "SELECT COUNT(*) FROM USER_TAB_COLUMNS WHERE TABLE_NAME = :1 AND COLUMN_NAME = :2",
        [table_name.upper(), column_name.upper()],
    )
    return cursor.fetchone()[0] > 0


def table_exists(connection, table_name: str) -> bool:
    cursor = connection.cursor()
    cursor.execute(
        "SELECT COUNT(*) FROM USER_TABLES WHERE TABLE_NAME = :1",
        [table_name.upper()],
    )
    return cursor.fetchone()[0] > 0


def get_password_backend(connection) -> str:
    if (
        table_exists(connection, 'LOGIN')
        and column_exists(connection, 'LOGIN', 'PASSWORD_HASH')
        and column_exists(connection, 'LOGIN', 'PASSWORD_SALT')
    ):
        return 'login'
    if column_exists(connection, 'USER_BASE', 'PASSWORD'):
        return 'user_base'
    return 'none'


def generate_salt() -> str:
    return secrets.token_hex(32).upper()


def hash_password(password: str) -> str:
    return hashlib.sha256(password.encode('utf-8')).hexdigest()


def hash_password_pbkdf2(password: str, salt: str) -> str:
    return hashlib.pbkdf2_hmac(
        'sha512',
        password.encode('utf-8'),
        bytes.fromhex(salt),
        100000,
    ).hex().upper()


def verify_password(password: str, stored_hash: str, salt: Optional[str] = None) -> bool:
    if salt:
        return hash_password_pbkdf2(password, salt) == stored_hash
    return hash_password(password) == stored_hash


def get_user_role(connection, user_id: int) -> str:
    cursor = connection.cursor()
    cursor.execute(
        """
        SELECT CASE
                 WHEN s.student_id IS NOT NULL THEN 'Student'
                 WHEN f.faculty_id IS NOT NULL THEN 'Faculty'
                 WHEN a.admin_id IS NOT NULL THEN 'Admin'
                 ELSE 'User'
               END AS role
        FROM USER_BASE u
        LEFT JOIN STUDENT s ON u.user_id = s.user_id
        LEFT JOIN FACULTY f ON u.user_id = f.user_id
        LEFT JOIN ADMIN a ON u.user_id = a.user_id
        WHERE u.user_id = :1
        """,
        [user_id],
    )
    row = cursor.fetchone()
    return row[0] if row else 'User'


def get_sequence_value(connection, sequence_name: str, table_name: str, key_column: str, fallback: Optional[int] = None) -> int:
    cursor = connection.cursor()
    cursor.execute(
        "SELECT COUNT(*) FROM user_sequences WHERE sequence_name = :1",
        [sequence_name.upper()],
    )
    if cursor.fetchone()[0] > 0:
        cursor.execute(f"SELECT {sequence_name}.NEXTVAL FROM dual")
        return cursor.fetchone()[0]
    cursor.execute(f"SELECT NVL(MAX({key_column}), 0) + 1 FROM {table_name}")
    row = cursor.fetchone()
    if row and row[0] is not None:
        return row[0]
    if fallback is not None:
        return fallback
    raise HTTPException(status_code=500, detail=f"Unable to determine ID for {sequence_name}")


class ApplicationRequest(BaseModel):
    student_id: int
    internship_id: int


class UpdateStatus(BaseModel):
    application_id: int
    status: str


class CompanyRequest(BaseModel):
    company_name: str
    city: str
    state: str


class InternshipRequest(BaseModel):
    title: str
    duration: str
    stipend: float
    company_id: int


class ApprovalRequest(BaseModel):
    application_id: int
    faculty_id: int
    revision_no: int
    approval_date: str
    decision: str


class ApprovalDecision(BaseModel):
    decision: str


class RemarkRequest(BaseModel):
    application_id: int
    faculty_id: int
    revision_no: int
    remark_type: str
    remark_text: str
    remark_date: str


class UserBaseRequest(BaseModel):
    first_name: str
    last_name: str
    email: str
    gender: str
    is_active: str = 'Y'


class StudentCreateRequest(UserBaseRequest):
    dept: str
    cgpa: float
    year_of_study: int


class FacultyCreateRequest(UserBaseRequest):
    designation: str
    dept: str


class AuthRequest(BaseModel):
    identifier: str
    password: Optional[str] = None


class AuthRegisterRequest(UserBaseRequest):
    role: str = 'Student'
    username: Optional[str] = None
    password: Optional[str] = None
    dept: Optional[str] = None
    cgpa: Optional[float] = None
    year_of_study: Optional[int] = None
    designation: Optional[str] = None


class ChangePasswordRequest(BaseModel):
    email: str
    current_password: str
    new_password: str


@app.post("/auth/login")
def auth_login(data: AuthRequest):
    try:
        with get_connection() as connection:
            backend = get_password_backend(connection)
            print(f"[DEBUG] Backend detected: {backend}")
            cursor = connection.cursor()
            if backend == 'login':
                cursor.execute(
                    """
                    SELECT b.user_id,
                           b.first_name,
                           b.last_name,
                           b.email,
                           b.gender,
                           b.is_active,
                           l.password_hash,
                           l.password_salt,
                           l.failed_attempts,
                           l.is_locked
                    FROM USER_BASE b
                    JOIN LOGIN l ON b.user_id = l.user_id
                    WHERE l.username = :1
                    """,
                    [data.identifier],
                )
                row = cursor.fetchone()
                if not row:
                    print(f"[DEBUG] User not found: {data.identifier}")
                    raise HTTPException(status_code=401, detail='Invalid credentials')

                (
                    user_id,
                    first_name,
                    last_name,
                    email,
                    gender,
                    is_active,
                    stored_hash,
                    stored_salt,
                    failed_attempts,
                    is_locked,
                ) = row
                
                print(f"[DEBUG] User found: {email}, hash length: {len(stored_hash) if stored_hash else 0}, salt length: {len(stored_salt) if stored_salt else 0}")

                if is_locked == 'Y':
                    raise HTTPException(status_code=403, detail='Account locked after too many failed attempts')
                if data.password is None:
                    raise HTTPException(status_code=400, detail='Password is required')
                if not stored_hash or not stored_salt:
                    print(f"[DEBUG] Missing hash or salt")
                    raise HTTPException(status_code=401, detail='Invalid credentials')
                
                computed_hash = hash_password_pbkdf2(data.password, stored_salt)
                print(f"[DEBUG] Computed hash: {computed_hash[:20]}..., Stored hash: {stored_hash[:20]}...")
                
                if not verify_password(data.password, stored_hash, stored_salt):
                    print(f"[DEBUG] Password verification failed")
                    cursor.execute(
                        "UPDATE LOGIN SET failed_attempts = NVL(failed_attempts, 0) + 1 WHERE user_id = :1",
                        [user_id],
                    )
                    connection.commit()
                    raise HTTPException(status_code=401, detail='Invalid credentials')

                print(f"[DEBUG] Password verification succeeded")
                cursor.execute(
                    "UPDATE LOGIN SET failed_attempts = 0, is_locked = 'N' WHERE user_id = :1",
                    [user_id],
                )
                connection.commit()
                user_data = {
                    'user_id': user_id,
                    'first_name': first_name,
                    'last_name': last_name,
                    'email': email,
                    'gender': gender,
                    'is_active': is_active,
                }
            elif backend == 'user_base':
                cursor.execute(
                    "SELECT user_id, first_name, last_name, email, gender, is_active, password FROM USER_BASE WHERE email = :1",
                    [data.identifier],
                )
                row = cursor.fetchone()
                if not row:
                    print(f"[DEBUG] User not found in USER_BASE: {data.identifier}")
                    raise HTTPException(status_code=401, detail='Invalid credentials')
                user_data = dict(zip(['user_id', 'first_name', 'last_name', 'email', 'gender', 'is_active', 'password'], row))
                print(f"[DEBUG] USER_BASE backend, user found: {user_data['email']}")
                if data.password is None:
                    raise HTTPException(status_code=400, detail='Password is required')
                if not verify_password(data.password, user_data['password']):
                    print(f"[DEBUG] Password verification failed in USER_BASE")
                    raise HTTPException(status_code=401, detail='Invalid credentials')
                print(f"[DEBUG] Password verification succeeded in USER_BASE")
            else:
                raise HTTPException(status_code=500, detail='Authentication backend not available')

            if user_data['is_active'] != 'Y':
                raise HTTPException(status_code=403, detail='User is inactive')

            role = get_user_role(connection, user_data['user_id'])
            result = {
                'user_id': user_data['user_id'],
                'first_name': user_data['first_name'],
                'last_name': user_data['last_name'],
                'email': user_data['email'],
                'gender': user_data['gender'],
                'is_active': user_data['is_active'],
                'role': role,
            }
            cursor.execute(
                "SELECT student_id FROM STUDENT WHERE user_id = :1",
                [user_data['user_id']],
            )
            student_row = cursor.fetchone()
            if student_row:
                result['student_id'] = student_row[0]
            cursor.execute(
                "SELECT faculty_id FROM FACULTY WHERE user_id = :1",
                [user_data['user_id']],
            )
            faculty_row = cursor.fetchone()
            if faculty_row:
                result['faculty_id'] = faculty_row[0]
            cursor.execute(
                "SELECT admin_id FROM ADMIN WHERE user_id = :1",
                [user_data['user_id']],
            )
            admin_row = cursor.fetchone()
            if admin_row:
                result['admin_id'] = admin_row[0]
            return {'user': result}
    except HTTPException:
        raise
    except oracledb.Error as error:
        print(f"[DEBUG] Database error: {error}")
        raise HTTPException(status_code=500, detail=str(error))


@app.post("/auth/register")
def auth_register(data: AuthRegisterRequest):
    if data.role not in ('Student', 'Faculty', 'Admin'):
        raise HTTPException(status_code=400, detail='Registration only supports Student, Faculty, or Admin')
    if not data.password:
        raise HTTPException(status_code=400, detail='Password is required')
    try:
        with get_connection() as connection:
            cursor = connection.cursor()
            cursor.execute(
                'SELECT user_id FROM USER_BASE WHERE email = :1',
                [data.email],
            )
            if cursor.fetchone():
                raise HTTPException(status_code=409, detail='Email already registered')

            backend = get_password_backend(connection)
            user_id = get_sequence_value(connection, 'seq_user', 'USER_BASE', 'user_id')
            insert_columns = ['user_id', 'first_name', 'last_name', 'email', 'gender', 'is_active']
            insert_values = [user_id, data.first_name, data.last_name, data.email, data.gender, data.is_active]
            if backend == 'user_base':
                insert_columns.append('password')
                insert_values.append(hash_password(data.password))
            insert_clause = ', '.join(insert_columns)
            placeholder_clause = ', '.join([f':{i + 1}' for i in range(len(insert_values))])
            cursor.execute(
                f'INSERT INTO USER_BASE ({insert_clause}) VALUES ({placeholder_clause})',
                insert_values,
            )

            if backend == 'login':
                login_id = get_sequence_value(connection, 'seq_login', 'LOGIN', 'login_id', fallback=user_id)
                username = data.username.strip() if data.username else data.email
                salt = generate_salt()
                password_hash = hash_password_pbkdf2(data.password, salt)
                cursor.execute(
                    'INSERT INTO LOGIN (login_id, username, password_hash, password_salt, user_id) VALUES (:1, :2, :3, :4, :5)',
                    [login_id, username, password_hash, salt, user_id],
                )

            if data.role == 'Student':
                if data.dept is None or data.cgpa is None or data.year_of_study is None:
                    raise HTTPException(status_code=400, detail='Student registration requires dept, cgpa, and year_of_study')
                student_id = get_sequence_value(connection, 'seq_student', 'STUDENT', 'student_id', fallback=user_id)
                cursor.execute(
                    'INSERT INTO STUDENT (student_id, user_id, dept, dob, cgpa, year_of_study) VALUES (:1, :2, :3, TO_DATE(:4, \'YYYY-MM-DD\'), :5, :6)',
                    [student_id, user_id, data.dept, '2000-01-01', data.cgpa, data.year_of_study],
                )
                created_id = student_id
            elif data.role == 'Faculty':
                if data.designation is None or data.dept is None:
                    raise HTTPException(status_code=400, detail='Faculty registration requires dept and designation')
                faculty_id = get_sequence_value(connection, 'seq_faculty', 'FACULTY', 'faculty_id', fallback=user_id)
                cursor.execute(
                    'INSERT INTO FACULTY (faculty_id, user_id, designation, dept) VALUES (:1, :2, :3, :4)',
                    [faculty_id, user_id, data.designation, data.dept],
                )
                created_id = faculty_id
            else:
                admin_id = get_sequence_value(connection, 'seq_admin', 'ADMIN', 'admin_id', fallback=user_id)
                cursor.execute(
                    'INSERT INTO ADMIN (admin_id, user_id, role) VALUES (:1, :2, :3)',
                    [admin_id, user_id, 'SuperAdmin'],
                )
                created_id = admin_id

            connection.commit()
            return {
                'message': f'{data.role} registered successfully',
                'user_id': user_id,
                'created_id': created_id,
            }
    except HTTPException:
        raise
    except oracledb.Error as error:
        raise HTTPException(status_code=500, detail=str(error))


@app.post('/auth/change-password')
def change_password(data: ChangePasswordRequest):
    try:
        with get_connection() as connection:
            backend = get_password_backend(connection)
            if backend == 'none':
                raise HTTPException(status_code=400, detail='Password change not supported')

            cursor = connection.cursor()
            if backend == 'login':
                cursor.execute(
                    "SELECT l.password_hash, l.password_salt, b.user_id FROM LOGIN l JOIN USER_BASE b ON l.user_id = b.user_id WHERE b.email = :1",
                    [data.email],
                )
                row = cursor.fetchone()
                if not row:
                    raise HTTPException(status_code=401, detail='Invalid current password')
                stored_hash, stored_salt, user_id = row
                if not verify_password(data.current_password, stored_hash, stored_salt):
                    raise HTTPException(status_code=401, detail='Invalid current password')
                new_salt = generate_salt()
                new_hash = hash_password_pbkdf2(data.new_password, new_salt)
                cursor.execute(
                    "UPDATE LOGIN SET password_hash = :1, password_salt = :2, failed_attempts = 0, is_locked = 'N' WHERE user_id = :3",
                    [new_hash, new_salt, user_id],
                )
            else:
                cursor.execute(
                    "SELECT password FROM USER_BASE WHERE email = :1",
                    [data.email],
                )
                row = cursor.fetchone()
                if not row or not verify_password(data.current_password, row[0]):
                    raise HTTPException(status_code=401, detail='Invalid current password')
                cursor.execute(
                    "UPDATE USER_BASE SET password = :1 WHERE email = :2",
                    [hash_password(data.new_password), data.email],
                )
            connection.commit()
            return {'message': 'Password changed successfully'}
    except HTTPException:
        raise
    except oracledb.Error as error:
        raise HTTPException(status_code=500, detail=str(error))


@app.post('/auth/seed-test-users')
def seed_test_users():
    try:
        with get_connection() as connection:
            cursor = connection.cursor()
            backend = get_password_backend(connection)
            users = [
                {
                    'role': 'Admin',
                    'first_name': 'Admin',
                    'last_name': 'User',
                    'email': 'admin@example.com',
                    'username': 'admin@example.com',
                    'gender': 'Male',
                    'password': 'Admin123',
                },
                {
                    'role': 'Faculty',
                    'first_name': 'Faculty',
                    'last_name': 'User',
                    'email': 'faculty@example.com',
                    'username': 'faculty@example.com',
                    'gender': 'Female',
                    'dept': 'Computer Science',
                    'designation': 'Professor',
                    'password': 'Faculty123',
                },
                {
                    'role': 'Student',
                    'first_name': 'Student',
                    'last_name': 'User',
                    'email': 'student@example.com',
                    'username': 'student@example.com',
                    'gender': 'Male',
                    'dept': 'Computer Science',
                    'cgpa': 8.5,
                    'year_of_study': 3,
                    'password': 'Student123',
                },
            ]
            results = []
            for user in users:
                cursor.execute('SELECT user_id FROM USER_BASE WHERE email = :1', [user['email']])
                user_row = cursor.fetchone()
                if user_row:
                    user_id = user_row[0]
                    # User exists in USER_BASE, ensure LOGIN record exists if using LOGIN backend
                    if backend == 'login':
                        cursor.execute('SELECT login_id FROM LOGIN WHERE user_id = :1', [user_id])
                        if not cursor.fetchone():
                            # LOGIN record missing, create it
                            login_id = get_sequence_value(connection, 'seq_login', 'LOGIN', 'login_id', fallback=user_id)
                            username = user.get('username', user['email'])
                            salt = generate_salt()
                            password_hash = hash_password_pbkdf2(user['password'], salt)
                            cursor.execute(
                                'INSERT INTO LOGIN (login_id, username, password_hash, password_salt, user_id) VALUES (:1, :2, :3, :4, :5)',
                                [login_id, username, password_hash, salt, user_id],
                            )
                            results.append({'email': user['email'], 'status': 'created LOGIN record'})
                        else:
                            results.append({'email': user['email'], 'status': 'already exists'})
                    else:
                        results.append({'email': user['email'], 'status': 'already exists'})
                    continue
                user_id = get_sequence_value(connection, 'seq_user', 'USER_BASE', 'user_id')
                columns = ['user_id', 'first_name', 'last_name', 'email', 'gender', 'is_active']
                values = [user_id, user['first_name'], user['last_name'], user['email'], user['gender'], 'Y']
                if backend == 'user_base':
                    columns.append('password')
                    values.append(hash_password(user['password']))
                cursor.execute(
                    f"INSERT INTO USER_BASE ({', '.join(columns)}) VALUES ({', '.join([f':{i + 1}' for i in range(len(values))])})",
                    values,
                )
                if backend == 'login':
                    login_id = get_sequence_value(connection, 'seq_login', 'LOGIN', 'login_id', fallback=user_id)
                    username = user.get('username', user['email'])
                    salt = generate_salt()
                    password_hash = hash_password_pbkdf2(user['password'], salt)
                    cursor.execute(
                        'INSERT INTO LOGIN (login_id, username, password_hash, password_salt, user_id) VALUES (:1, :2, :3, :4, :5)',
                        [login_id, username, password_hash, salt, user_id],
                    )
                if user['role'] == 'Admin':
                    admin_id = get_sequence_value(connection, 'seq_admin', 'ADMIN', 'admin_id', fallback=user_id)
                    cursor.execute('INSERT INTO ADMIN (admin_id, user_id, role) VALUES (:1, :2, :3)', [admin_id, user_id, 'SuperAdmin'])
                elif user['role'] == 'Faculty':
                    faculty_id = get_sequence_value(connection, 'seq_faculty', 'FACULTY', 'faculty_id', fallback=user_id)
                    cursor.execute(
                        'INSERT INTO FACULTY (faculty_id, user_id, designation, dept) VALUES (:1, :2, :3, :4)',
                        [faculty_id, user_id, user['designation'], user['dept']],
                    )
                else:
                    student_id = get_sequence_value(connection, 'seq_student', 'STUDENT', 'student_id', fallback=user_id)
                    cursor.execute(
                        'INSERT INTO STUDENT (student_id, user_id, dept, dob, cgpa, year_of_study) VALUES (:1, :2, :3, TO_DATE(:4, \'YYYY-MM-DD\'), :5, :6)',
                        [student_id, user_id, user['dept'], '2000-01-01', user['cgpa'], user['year_of_study']],
                    )
                results.append({'email': user['email'], 'status': 'created', 'role': user['role'], 'password': user['password']})
            connection.commit()
            return {'results': results}
    except oracledb.Error as error:
        raise HTTPException(status_code=500, detail=str(error))


@app.get("/applications/student/{student_id}")
def get_applications_for_student(student_id: int):
    try:
        with get_connection() as connection:
            cursor = connection.cursor()
            cursor.execute(
                """
                SELECT application_id, applied_date, status, student_id, internship_id
                FROM APPLICATION
                WHERE student_id = :1
                ORDER BY application_id DESC
                """,
                [student_id],
            )
            rows = cursor.fetchall()
            return {"data": serialize_rows(rows, cursor), "count": len(rows)}
    except oracledb.Error as error:
        raise HTTPException(status_code=500, detail=str(error))


@app.get("/approvals/faculty/{faculty_id}")
def get_approvals_for_faculty(faculty_id: int):
    try:
        with get_connection() as connection:
            cursor = connection.cursor()
            cursor.execute(
                """
                SELECT ap.application_id,
                       ap.faculty_id,
                       f.designation,
                       u.first_name || ' ' || u.last_name AS faculty_name,
                       ap.revision_no,
                       ap.approval_date,
                       ap.decision
                FROM APPROVAL ap
                JOIN FACULTY f ON ap.faculty_id = f.faculty_id
                JOIN USER_BASE u ON f.user_id = u.user_id
                WHERE ap.faculty_id = :1
                ORDER BY ap.application_id DESC
                """,
                [faculty_id],
            )
            rows = cursor.fetchall()
            return {"data": serialize_rows(rows, cursor), "count": len(rows)}
    except oracledb.Error as error:
        raise HTTPException(status_code=500, detail=str(error))


@app.get('/students/user/{user_id}')
def get_student_by_user_id(user_id: int):
    try:
        with get_connection() as connection:
            cursor = connection.cursor()
            cursor.execute(
                """
                SELECT s.student_id,
                       u.user_id,
                       u.first_name,
                       u.last_name,
                       u.email,
                       u.gender,
                       u.is_active,
                       s.dept,
                       s.cgpa,
                       s.year_of_study
                FROM STUDENT s
                JOIN USER_BASE u ON s.user_id = u.user_id
                WHERE u.user_id = :1
                """,
                [user_id],
            )
            row = cursor.fetchone()
            if not row:
                raise HTTPException(status_code=404, detail='Student not found')
            return serialize_row(row, cursor)
    except oracledb.Error as error:
        raise HTTPException(status_code=500, detail=str(error))


@app.get('/faculty/user/{user_id}')
def get_faculty_by_user_id(user_id: int):
    try:
        with get_connection() as connection:
            cursor = connection.cursor()
            cursor.execute(
                """
                SELECT f.faculty_id,
                       u.user_id,
                       u.first_name,
                       u.last_name,
                       u.email,
                       u.gender,
                       u.is_active,
                       f.designation,
                       f.dept
                FROM FACULTY f
                JOIN USER_BASE u ON f.user_id = u.user_id
                WHERE u.user_id = :1
                """,
                [user_id],
            )
            row = cursor.fetchone()
            if not row:
                raise HTTPException(status_code=404, detail='Faculty not found')
            return serialize_row(row, cursor)
    except oracledb.Error as error:
        raise HTTPException(status_code=500, detail=str(error))


@app.post("/apply")
def submit_application(data: ApplicationRequest):
    try:
        with get_connection() as connection:
            cursor = connection.cursor()
            cursor.execute(
                """
                INSERT INTO APPLICATION
                (application_id, applied_date, status, student_id, internship_id, created_at, updated_at)
                VALUES (seq_application.NEXTVAL, SYSDATE, 'Submitted', :1, :2, SYSTIMESTAMP, SYSTIMESTAMP)
                """,
                [data.student_id, data.internship_id],
            )
            connection.commit()
            return {"message": f"Application successfully submitted for Student {data.student_id}"}
    except oracledb.Error as error:
        raise HTTPException(status_code=500, detail=str(error))


@app.get("/applications")
def get_applications():
    try:
        with get_connection() as connection:
            cursor = connection.cursor()
            cursor.execute(
                """
                SELECT application_id, applied_date, status, student_id, internship_id
                FROM APPLICATION
                ORDER BY application_id DESC
                """
            )
            rows = cursor.fetchall()
            return {"data": serialize_rows(rows, cursor), "count": len(rows)}
    except oracledb.Error as error:
        raise HTTPException(status_code=500, detail=str(error))


@app.get("/applications/status/{status}")
def get_applications_by_status(status: str):
    try:
        with get_connection() as connection:
            cursor = connection.cursor()
            cursor.execute(
                """
                SELECT application_id, applied_date, status, student_id, internship_id
                FROM APPLICATION
                WHERE status = :1
                ORDER BY application_id DESC
                """,
                [status],
            )
            rows = cursor.fetchall()
            return {"data": serialize_rows(rows, cursor), "count": len(rows)}
    except oracledb.Error as error:
        raise HTTPException(status_code=500, detail=str(error))


@app.get("/applications/{app_id}/detail")
def get_application_detail(app_id: int):
    try:
        with get_connection() as connection:
            cursor = connection.cursor()
            cursor.execute(
                """
                SELECT a.application_id,
                       a.applied_date,
                       a.status,
                       a.student_id,
                       a.internship_id,
                       s.dept,
                       s.cgpa,
                       u.first_name || ' ' || u.last_name AS student_name,
                       i.title AS internship_title,
                       c.company_name
                FROM APPLICATION a
                JOIN STUDENT s ON a.student_id = s.student_id
                JOIN USER_BASE u ON s.user_id = u.user_id
                JOIN INTERNSHIP i ON a.internship_id = i.internship_id
                JOIN COMPANY c ON i.company_id = c.company_id
                WHERE a.application_id = :1
                """,
                [app_id],
            )
            row = cursor.fetchone()
            if not row:
                raise HTTPException(status_code=404, detail="Application not found")
            return serialize_row(row, cursor)
    except oracledb.Error as error:
        raise HTTPException(status_code=500, detail=str(error))


@app.put("/update")
def update_application(data: UpdateStatus):
    try:
        with get_connection() as connection:
            cursor = connection.cursor()
            cursor.execute(
                """
                UPDATE APPLICATION
                SET status = :1, updated_at = SYSTIMESTAMP
                WHERE application_id = :2
                """,
                [data.status, data.application_id],
            )
            if cursor.rowcount == 0:
                raise HTTPException(status_code=404, detail="Application ID not found")
            connection.commit()
            return {"message": f"Application {data.application_id} updated to {data.status}"}
    except oracledb.Error as error:
        raise HTTPException(status_code=500, detail=str(error))


@app.delete("/delete/{app_id}")
def delete_application(app_id: int):
    try:
        with get_connection() as connection:
            cursor = connection.cursor()
            cursor.execute(
                "DELETE FROM APPLICATION WHERE application_id = :1",
                [app_id],
            )
            if cursor.rowcount == 0:
                raise HTTPException(status_code=404, detail="Application ID not found")
            connection.commit()
            return {"message": f"Application {app_id} deleted successfully"}
    except oracledb.Error as error:
        raise HTTPException(status_code=500, detail=str(error))


@app.get("/companies")
def get_companies():
    try:
        with get_connection() as connection:
            cursor = connection.cursor()
            cursor.execute(
                "SELECT company_id, company_name, city, state, is_active FROM COMPANY ORDER BY company_id"
            )
            rows = cursor.fetchall()
            return {"data": serialize_rows(rows, cursor), "count": len(rows)}
    except oracledb.Error as error:
        raise HTTPException(status_code=500, detail=str(error))


@app.post("/companies")
def create_company(data: CompanyRequest):
    try:
        with get_connection() as connection:
            cursor = connection.cursor()
            cursor.execute(
                "INSERT INTO COMPANY (company_id, company_name, city, state) VALUES (seq_company.NEXTVAL, :1, :2, :3)",
                [data.company_name, data.city, data.state],
            )
            connection.commit()
            return {"message": "Company created successfully"}
    except oracledb.Error as error:
        raise HTTPException(status_code=500, detail=str(error))


@app.put("/companies/{company_id}/deactivate")
def deactivate_company(company_id: int):
    try:
        with get_connection() as connection:
            cursor = connection.cursor()
            cursor.execute(
                "UPDATE COMPANY SET is_active = 'N' WHERE company_id = :1",
                [company_id],
            )
            if cursor.rowcount == 0:
                raise HTTPException(status_code=404, detail="Company not found")
            connection.commit()
            return {"message": "Company deactivated"}
    except oracledb.Error as error:
        raise HTTPException(status_code=500, detail=str(error))


@app.get("/internships")
def get_internships():
    try:
        with get_connection() as connection:
            cursor = connection.cursor()
            cursor.execute(
                """
                SELECT i.internship_id,
                       i.title,
                       i.duration,
                       i.stipend,
                       i.is_active,
                       c.company_name,
                       c.city
                FROM INTERNSHIP i
                JOIN COMPANY c ON i.company_id = c.company_id
                ORDER BY i.internship_id
                """
            )
            rows = cursor.fetchall()
            return {"data": serialize_rows(rows, cursor), "count": len(rows)}
    except oracledb.Error as error:
        raise HTTPException(status_code=500, detail=str(error))


@app.post("/internships")
def create_internship(data: InternshipRequest):
    try:
        with get_connection() as connection:
            cursor = connection.cursor()
            cursor.execute(
                "INSERT INTO INTERNSHIP (internship_id, title, duration, stipend, company_id) VALUES (seq_internship.NEXTVAL, :1, :2, :3, :4)",
                [data.title, data.duration, data.stipend, data.company_id],
            )
            connection.commit()
            return {"message": "Internship created successfully"}
    except oracledb.Error as error:
        raise HTTPException(status_code=500, detail=str(error))


@app.get("/internships/{internship_id}/eligibility")
def get_internship_eligibility(internship_id: int):
    try:
        with get_connection() as connection:
            cursor = connection.cursor()
            cursor.execute(
                """
                SELECT 'year' AS type, TO_CHAR(eligible_year) AS value
                FROM INTERNSHIP_YEAR WHERE internship_id = :1
                UNION ALL
                SELECT 'dept' AS type, eligible_dept AS value
                FROM INTERNSHIP_DEPT WHERE internship_id = :1
                UNION ALL
                SELECT 'gender' AS type, eligible_gender AS value
                FROM INTERNSHIP_GENDER WHERE internship_id = :1
                UNION ALL
                SELECT 'min_cgpa' AS type, TO_CHAR(min_cgpa) AS value
                FROM INTERNSHIP_CGPA WHERE internship_id = :1
                """,
                [internship_id],
            )
            rows = cursor.fetchall()
            return {"data": serialize_rows(rows, cursor), "count": len(rows)}
    except oracledb.Error as error:
        raise HTTPException(status_code=500, detail=str(error))


@app.put("/internships/{internship_id}/toggle")
def toggle_internship(internship_id: int):
    try:
        with get_connection() as connection:
            cursor = connection.cursor()
            cursor.execute(
                """
                UPDATE INTERNSHIP
                SET is_active = CASE WHEN is_active = 'Y' THEN 'N' ELSE 'Y' END
                WHERE internship_id = :1
                """,
                [internship_id],
            )
            if cursor.rowcount == 0:
                raise HTTPException(status_code=404, detail="Internship not found")
            connection.commit()
            return {"message": "Internship active state toggled"}
    except oracledb.Error as error:
        raise HTTPException(status_code=500, detail=str(error))


@app.get("/approvals")
def get_approvals():
    try:
        with get_connection() as connection:
            cursor = connection.cursor()
            cursor.execute(
                """
                SELECT ap.application_id,
                       ap.faculty_id,
                       ap.revision_no,
                       ap.approval_date,
                       ap.decision,
                       u.first_name || ' ' || u.last_name AS faculty_name
                FROM APPROVAL ap
                JOIN FACULTY f ON ap.faculty_id = f.faculty_id
                JOIN USER_BASE u ON f.user_id = u.user_id
                ORDER BY ap.application_id, ap.revision_no
                """
            )
            rows = cursor.fetchall()
            return {"data": serialize_rows(rows, cursor), "count": len(rows)}
    except oracledb.Error as error:
        raise HTTPException(status_code=500, detail=str(error))


@app.post("/approvals")
def create_approval(data: ApprovalRequest):
    try:
        with get_connection() as connection:
            cursor = connection.cursor()
            cursor.execute(
                "INSERT INTO APPROVAL (application_id, faculty_id, revision_no, approval_date, decision) VALUES (:1, :2, :3, TO_DATE(:4,'YYYY-MM-DD'), :5)",
                [
                    data.application_id,
                    data.faculty_id,
                    data.revision_no,
                    data.approval_date,
                    data.decision,
                ],
            )
            connection.commit()
            return {"message": "Approval record created"}
    except oracledb.Error as error:
        raise HTTPException(status_code=500, detail=str(error))


@app.put("/approvals/{application_id}/{faculty_id}/{revision_no}")
def update_approval(application_id: int, faculty_id: int, revision_no: int, data: ApprovalDecision):
    try:
        with get_connection() as connection:
            cursor = connection.cursor()
            cursor.execute(
                "UPDATE APPROVAL SET decision = :1 WHERE application_id = :2 AND faculty_id = :3 AND revision_no = :4",
                [data.decision, application_id, faculty_id, revision_no],
            )
            if cursor.rowcount == 0:
                raise HTTPException(status_code=404, detail="Approval record not found")
            connection.commit()
            return {"message": "Approval decision updated"}
    except oracledb.Error as error:
        raise HTTPException(status_code=500, detail=str(error))


@app.get("/approvals/{application_id}/history")
def get_approval_history(application_id: int):
    try:
        with get_connection() as connection:
            cursor = connection.cursor()
            cursor.execute(
                """
                SELECT ap.application_id,
                       ap.faculty_id,
                       ap.revision_no,
                       ap.approval_date,
                       ap.decision,
                       u.first_name || ' ' || u.last_name AS faculty_name
                FROM APPROVAL ap
                JOIN FACULTY f ON ap.faculty_id = f.faculty_id
                JOIN USER_BASE u ON f.user_id = u.user_id
                WHERE ap.application_id = :1
                ORDER BY ap.revision_no
                """,
                [application_id],
            )
            rows = cursor.fetchall()
            return {"data": serialize_rows(rows, cursor), "count": len(rows)}
    except oracledb.Error as error:
        raise HTTPException(status_code=500, detail=str(error))


@app.get("/remarks/{application_id}/{faculty_id}/{revision_no}")
def get_remarks(application_id: int, faculty_id: int, revision_no: int):
    try:
        with get_connection() as connection:
            cursor = connection.cursor()
            cursor.execute(
                """
                SELECT remark_id, remark_type, remark_text, remark_date
                FROM REMARK
                WHERE application_id = :1 AND faculty_id = :2 AND revision_no = :3
                ORDER BY remark_id
                """,
                [application_id, faculty_id, revision_no],
            )
            rows = cursor.fetchall()
            return {"data": serialize_rows(rows, cursor), "count": len(rows)}
    except oracledb.Error as error:
        raise HTTPException(status_code=500, detail=str(error))


@app.post("/remarks")
def create_remark(data: RemarkRequest):
    try:
        with get_connection() as connection:
            cursor = connection.cursor()
            cursor.execute(
                "INSERT INTO REMARK (remark_id, application_id, faculty_id, revision_no, remark_type, remark_text, remark_date) VALUES (seq_remark.NEXTVAL, :1, :2, :3, :4, :5, TO_DATE(:6,'YYYY-MM-DD'))",
                [
                    data.application_id,
                    data.faculty_id,
                    data.revision_no,
                    data.remark_type,
                    data.remark_text,
                    data.remark_date,
                ],
            )
            connection.commit()
            return {"message": "Remark created successfully"}
    except oracledb.Error as error:
        raise HTTPException(status_code=500, detail=str(error))


@app.delete("/remarks/{remark_id}")
def delete_remark(remark_id: int):
    try:
        with get_connection() as connection:
            cursor = connection.cursor()
            cursor.execute(
                "DELETE FROM REMARK WHERE remark_id = :1",
                [remark_id],
            )
            if cursor.rowcount == 0:
                raise HTTPException(status_code=404, detail="Remark not found")
            connection.commit()
            return {"message": "Remark deleted successfully"}
    except oracledb.Error as error:
        raise HTTPException(status_code=500, detail=str(error))


@app.get("/dashboard/stats")
def get_dashboard_stats():
    try:
        with get_connection() as connection:
            cursor = connection.cursor()
            cursor.execute("SELECT COUNT(*) FROM STUDENT")
            total_students = cursor.fetchone()[0]
            cursor.execute("SELECT COUNT(*) FROM INTERNSHIP WHERE is_active = 'Y'")
            total_internships = cursor.fetchone()[0]
            cursor.execute("SELECT COUNT(*) FROM APPLICATION")
            total_applications = cursor.fetchone()[0]
            cursor.execute("SELECT COUNT(*) FROM APPROVAL")
            total_approvals = cursor.fetchone()[0]
            cursor.execute(
                "SELECT status, COUNT(*) AS count FROM APPLICATION GROUP BY status"
            )
            status_counts = [dict(status=row[0], count=row[1]) for row in cursor.fetchall()]
            return {
                "total_students": total_students,
                "total_internships": total_internships,
                "total_applications": total_applications,
                "total_approvals": total_approvals,
                "status_counts": status_counts,
            }
    except oracledb.Error as error:
        raise HTTPException(status_code=500, detail=str(error))


@app.get("/audit-log")
def get_audit_log():
    try:
        with get_connection() as connection:
            cursor = connection.cursor()
            cursor.execute(
                "SELECT audit_id, table_name, operation, record_id, changed_by, changed_at, old_values, new_values FROM AUDIT_LOG ORDER BY changed_at DESC FETCH FIRST 100 ROWS ONLY"
            )
            rows = cursor.fetchall()
            return {"data": serialize_rows(rows, cursor), "count": len(rows)}
    except oracledb.Error as error:
        raise HTTPException(status_code=500, detail=str(error))


@app.get("/users")
def get_users():
    try:
        with get_connection() as connection:
            cursor = connection.cursor()
            cursor.execute(
                """
                SELECT u.user_id,
                       u.first_name,
                       u.last_name,
                       u.email,
                       u.gender,
                       u.is_active,
                       CASE
                         WHEN s.student_id IS NOT NULL THEN 'Student'
                         WHEN f.faculty_id IS NOT NULL THEN 'Faculty'
                         WHEN a.admin_id IS NOT NULL THEN 'Admin'
                         ELSE 'Unknown'
                       END AS role
                FROM USER_BASE u
                LEFT JOIN STUDENT s ON u.user_id = s.user_id
                LEFT JOIN FACULTY f ON u.user_id = f.user_id
                LEFT JOIN ADMIN a ON u.user_id = a.user_id
                ORDER BY u.user_id
                """
            )
            rows = cursor.fetchall()
            return {"data": serialize_rows(rows, cursor), "count": len(rows)}
    except oracledb.Error as error:
        raise HTTPException(status_code=500, detail=str(error))


@app.put("/users/{user_id}/toggle")
def toggle_user(user_id: int):
    try:
        with get_connection() as connection:
            cursor = connection.cursor()
            cursor.execute(
                "UPDATE USER_BASE SET is_active = CASE WHEN is_active = 'Y' THEN 'N' ELSE 'Y' END WHERE user_id = :1",
                [user_id],
            )
            if cursor.rowcount == 0:
                raise HTTPException(status_code=404, detail="User not found")
            connection.commit()
            return {"message": "User active state toggled"}
    except oracledb.Error as error:
        raise HTTPException(status_code=500, detail=str(error))


@app.get("/students")
def get_students():
    try:
        with get_connection() as connection:
            cursor = connection.cursor()
            cursor.execute(
                """
                SELECT s.student_id,
                       s.dept,
                       s.cgpa,
                       s.year_of_study,
                       u.first_name || ' ' || u.last_name AS full_name,
                       u.email,
                       u.gender,
                       u.is_active
                FROM STUDENT s
                JOIN USER_BASE u ON s.user_id = u.user_id
                ORDER BY s.student_id
                """
            )
            rows = cursor.fetchall()
            return {"data": serialize_rows(rows, cursor), "count": len(rows)}
    except oracledb.Error as error:
        raise HTTPException(status_code=500, detail=str(error))


@app.get("/faculty")
def get_faculty():
    try:
        with get_connection() as connection:
            cursor = connection.cursor()
            cursor.execute(
                """
                SELECT f.faculty_id,
                       f.designation,
                       f.dept,
                       u.first_name || ' ' || u.last_name AS full_name,
                       u.email,
                       u.is_active
                FROM FACULTY f
                JOIN USER_BASE u ON f.user_id = u.user_id
                ORDER BY f.faculty_id
                """
            )
            rows = cursor.fetchall()
            return {"data": serialize_rows(rows, cursor), "count": len(rows)}
    except oracledb.Error as error:
        raise HTTPException(status_code=500, detail=str(error))


@app.get("/admin")
def get_admin():
    try:
        with get_connection() as connection:
            cursor = connection.cursor()
            cursor.execute(
                """
                SELECT a.admin_id,
                       a.role,
                       u.first_name || ' ' || u.last_name AS full_name,
                       u.email,
                       u.gender,
                       u.is_active
                FROM ADMIN a
                JOIN USER_BASE u ON a.user_id = u.user_id
                ORDER BY a.admin_id
                """
            )
            rows = cursor.fetchall()
            return {"data": serialize_rows(rows, cursor), "count": len(rows)}
    except oracledb.Error as error:
        raise HTTPException(status_code=500, detail=str(error))


@app.post("/students")
def create_student(data: StudentCreateRequest):
    try:
        with get_connection() as connection:
            cursor = connection.cursor()
            user_id = get_sequence_value(connection, 'seq_user', 'USER_BASE', 'user_id')
            cursor.execute(
                "INSERT INTO USER_BASE (user_id, first_name, last_name, email, gender, is_active) VALUES (:1, :2, :3, :4, :5, :6)",
                [user_id, data.first_name, data.last_name, data.email, data.gender, data.is_active],
            )
            cursor.execute("SELECT seq_student.NEXTVAL FROM dual")
            student_id = cursor.fetchone()[0]
            cursor.execute(
                "INSERT INTO STUDENT (student_id, user_id, dept, cgpa, year_of_study) VALUES (:1, :2, :3, :4, :5)",
                [student_id, user_id, data.dept, data.cgpa, data.year_of_study],
            )
            connection.commit()
            return {"message": "Student created successfully", "student_id": student_id}
    except oracledb.Error as error:
        raise HTTPException(status_code=500, detail=str(error))


@app.post("/faculty")
def create_faculty(data: FacultyCreateRequest):
    try:
        with get_connection() as connection:
            cursor = connection.cursor()
            user_id = get_sequence_value(connection, 'seq_user', 'USER_BASE', 'user_id')
            cursor.execute(
                "INSERT INTO USER_BASE (user_id, first_name, last_name, email, gender, is_active) VALUES (:1, :2, :3, :4, :5, :6)",
                [user_id, data.first_name, data.last_name, data.email, data.gender, data.is_active],
            )
            cursor.execute("SELECT seq_faculty.NEXTVAL FROM dual")
            faculty_id = cursor.fetchone()[0]
            cursor.execute(
                "INSERT INTO FACULTY (faculty_id, user_id, designation, dept) VALUES (:1, :2, :3, :4)",
                [faculty_id, user_id, data.designation, data.dept],
            )
            connection.commit()
            return {"message": "Faculty created successfully", "faculty_id": faculty_id}
    except oracledb.Error as error:
        raise HTTPException(status_code=500, detail=str(error))


@app.post("/admin")
def create_admin(data: UserBaseRequest):
    try:
        with get_connection() as connection:
            cursor = connection.cursor()
            user_id = get_sequence_value(connection, 'seq_user', 'USER_BASE', 'user_id')
            cursor.execute(
                "INSERT INTO USER_BASE (user_id, first_name, last_name, email, gender, is_active) VALUES (:1, :2, :3, :4, :5, :6)",
                [user_id, data.first_name, data.last_name, data.email, data.gender, data.is_active],
            )
            cursor.execute("SELECT seq_admin.NEXTVAL FROM dual")
            admin_id = cursor.fetchone()[0]
            cursor.execute(
                "INSERT INTO ADMIN (admin_id, user_id, role) VALUES (:1, :2, :3)",
                [admin_id, user_id, 'SuperAdmin'],
            )
            connection.commit()
            return {"message": "Admin created successfully", "admin_id": admin_id}
    except oracledb.Error as error:
        raise HTTPException(status_code=500, detail=str(error))


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="127.0.0.1", port=8001)
