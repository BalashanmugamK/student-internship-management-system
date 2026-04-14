-- ============================================================
-- STUDENT INTERNSHIP MANAGEMENT SYSTEM
-- BCSE302L - DATABASE SYSTEMS - DA-2
-- CORRECTED VERSION — 10 bugs fixed (see FIX comments)
-- WITH REAL PBKDF2-HMAC-SHA512 PASSWORD HASHES
-- ============================================================

SHOW CON_NAME;
SELECT name, open_mode FROM v$pdbs;
ALTER SESSION SET CONTAINER = XEPDB1;

-- ============================================================
-- SECTION 1: SEQUENCES  (must run BEFORE CREATE TABLE)
-- ============================================================
CREATE SEQUENCE seq_company      START WITH 101   INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_user         START WITH 10    INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_login        START WITH 1     INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_student      START WITH 24001 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_faculty      START WITH 5001  INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_admin        START WITH 1     INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_internship   START WITH 8001  INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_application  START WITH 9001  INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_remark       START WITH 1     INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_audit        START WITH 1     INCREMENT BY 1 NOCACHE NOCYCLE;

-- ============================================================
-- SECTION 2: CREATE TABLES
-- ============================================================

CREATE TABLE COMPANY (
    company_id   INT           DEFAULT seq_company.NEXTVAL PRIMARY KEY,
    company_name VARCHAR2(100) NOT NULL,
    city         VARCHAR2(50)  NOT NULL,
    state        VARCHAR2(50)  NOT NULL,
    is_active    CHAR(1)       DEFAULT 'Y' NOT NULL,
    created_at   TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT chk_company_name   CHECK (LENGTH(TRIM(company_name)) > 0),
    CONSTRAINT chk_company_active CHECK (is_active IN ('Y','N'))
);

CREATE TABLE USER_BASE (
    user_id    INT           DEFAULT seq_user.NEXTVAL PRIMARY KEY,
    first_name VARCHAR2(50)  NOT NULL,
    last_name  VARCHAR2(50)  NOT NULL,
    email      VARCHAR2(100) NOT NULL,
    gender     VARCHAR2(10)  NOT NULL,
    is_active  CHAR(1)       DEFAULT 'Y' NOT NULL,
    created_at TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT uq_user_email   UNIQUE (email),
    CONSTRAINT chk_user_gender CHECK  (gender IN ('Male', 'Female', 'Other')),
    CONSTRAINT chk_user_active CHECK  (is_active IN ('Y','N')),
    CONSTRAINT chk_user_email  CHECK
        (REGEXP_LIKE(email, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'))
);

CREATE TABLE USER_PHONE (
    user_id      INT          NOT NULL,
    phone_number VARCHAR2(15) NOT NULL,
    PRIMARY KEY (user_id, phone_number),
    CONSTRAINT chk_phone_format CHECK (REGEXP_LIKE(phone_number, '^[0-9]{7,15}$')),
    FOREIGN KEY (user_id) REFERENCES USER_BASE(user_id) ON DELETE CASCADE
);

CREATE TABLE LOGIN (
    login_id        INT           DEFAULT seq_login.NEXTVAL PRIMARY KEY,
    username        VARCHAR2(50)  NOT NULL,
    password_hash   VARCHAR2(128) NOT NULL,
    password_salt   VARCHAR2(64)  NOT NULL,
    last_login      TIMESTAMP,
    failed_attempts INT           DEFAULT 0 NOT NULL,
    is_locked       CHAR(1)       DEFAULT 'N' NOT NULL,
    user_id         INT           NOT NULL,
    CONSTRAINT uq_login_username      UNIQUE (username),
    CONSTRAINT uq_login_user_id       UNIQUE (user_id),
    CONSTRAINT chk_username_len       CHECK  (LENGTH(username) >= 4),
    CONSTRAINT chk_password_hash      CHECK (
        LENGTH(password_hash) = 128 AND
        REGEXP_LIKE(password_hash, '^[A-F0-9]{128}$')
    ),
    CONSTRAINT chk_password_salt      CHECK (
        LENGTH(password_salt) = 64 AND
        REGEXP_LIKE(password_salt, '^[A-F0-9]{64}$')
    ),
    CONSTRAINT chk_failed_attempts    CHECK  (failed_attempts >= 0),
    CONSTRAINT chk_is_locked          CHECK  (is_locked IN ('Y','N')),
    CONSTRAINT chk_username_not_empty CHECK  (LENGTH(TRIM(username)) > 0),
    FOREIGN KEY (user_id) REFERENCES USER_BASE(user_id) ON DELETE CASCADE
);

CREATE TABLE STUDENT (
    student_id    INT           DEFAULT seq_student.NEXTVAL PRIMARY KEY,
    dept          VARCHAR2(50)  NOT NULL,
    dob           DATE          NOT NULL,
    cgpa          DECIMAL(3,2)  NOT NULL,
    year_of_study INT           NOT NULL,
    user_id       INT           NOT NULL,
    CONSTRAINT uq_student_user   UNIQUE (user_id),
    CONSTRAINT chk_student_cgpa  CHECK  (cgpa >= 0.00 AND cgpa <= 10.00),
    CONSTRAINT chk_year_of_study CHECK  (year_of_study BETWEEN 1 AND 4),
    -- NOTE: dob < SYSDATE cannot be a CHECK constraint in Oracle (ORA-02436).
    -- Enforced by trigger trg_validate_student_dob.
    FOREIGN KEY (user_id) REFERENCES USER_BASE(user_id) ON DELETE CASCADE
);

CREATE TABLE FACULTY (
    faculty_id  INT           DEFAULT seq_faculty.NEXTVAL PRIMARY KEY,
    designation VARCHAR2(50)  NOT NULL,
    dept        VARCHAR2(50)  NOT NULL,
    user_id     INT           NOT NULL,
    CONSTRAINT uq_faculty_user   UNIQUE (user_id),
    CONSTRAINT chk_faculty_desig CHECK (designation IN (
        'Professor','Associate Professor','Assistant Professor','Lecturer'
    )),
    FOREIGN KEY (user_id) REFERENCES USER_BASE(user_id) ON DELETE CASCADE
);

CREATE TABLE ADMIN (
    admin_id INT           DEFAULT seq_admin.NEXTVAL PRIMARY KEY,
    role     VARCHAR2(50)  NOT NULL,
    user_id  INT           NOT NULL,
    CONSTRAINT uq_admin_user  UNIQUE (user_id),
    CONSTRAINT chk_admin_role CHECK (role IN ('SuperAdmin','DeptAdmin','Viewer')),
    FOREIGN KEY (user_id) REFERENCES USER_BASE(user_id) ON DELETE CASCADE
);

CREATE TABLE INTERNSHIP (
    internship_id INT            DEFAULT seq_internship.NEXTVAL PRIMARY KEY,
    title         VARCHAR2(100)  NOT NULL,
    duration      VARCHAR2(20)   NOT NULL,
    stipend       DECIMAL(10,2)  DEFAULT 0.00 NOT NULL,
    is_active     CHAR(1)        DEFAULT 'Y' NOT NULL,
    company_id    INT            NOT NULL,
    created_at    TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT chk_internship_stipend CHECK (stipend >= 0),
    CONSTRAINT chk_internship_active  CHECK (is_active IN ('Y','N')),
    CONSTRAINT chk_duration_len       CHECK (LENGTH(TRIM(duration)) > 0),
    -- NOTE: ON DELETE RESTRICT is NOT valid Oracle SQL.
    -- Oracle default FK behavior (no ON DELETE clause) already restricts deletion.
    FOREIGN KEY (company_id) REFERENCES COMPANY(company_id)
);

CREATE TABLE INTERNSHIP_YEAR (
    internship_id INT NOT NULL,
    eligible_year INT NOT NULL,
    PRIMARY KEY (internship_id, eligible_year),
    CONSTRAINT chk_eligible_year CHECK (eligible_year BETWEEN 1 AND 4),
    FOREIGN KEY (internship_id) REFERENCES INTERNSHIP(internship_id) ON DELETE CASCADE
);

CREATE TABLE INTERNSHIP_DEPT (
    internship_id INT          NOT NULL,
    eligible_dept VARCHAR2(50) NOT NULL,
    PRIMARY KEY (internship_id, eligible_dept),
    CONSTRAINT chk_dept_len CHECK (LENGTH(TRIM(eligible_dept)) > 0),
    FOREIGN KEY (internship_id) REFERENCES INTERNSHIP(internship_id) ON DELETE CASCADE
);

CREATE TABLE INTERNSHIP_GENDER (
    internship_id   INT          NOT NULL,
    eligible_gender VARCHAR2(10) NOT NULL,
    PRIMARY KEY (internship_id, eligible_gender),
    CONSTRAINT chk_intern_gender CHECK (eligible_gender IN ('Male','Female','Other')),
    FOREIGN KEY (internship_id) REFERENCES INTERNSHIP(internship_id) ON DELETE CASCADE
);

CREATE TABLE INTERNSHIP_CGPA (
    internship_id INT           PRIMARY KEY,
    min_cgpa      DECIMAL(3,2)  NOT NULL,
    CONSTRAINT chk_min_cgpa CHECK (min_cgpa >= 0.00 AND min_cgpa <= 10.00),
    FOREIGN KEY (internship_id) REFERENCES INTERNSHIP(internship_id) ON DELETE CASCADE
);

CREATE TABLE APPLICATION (
    application_id INT           DEFAULT seq_application.NEXTVAL PRIMARY KEY,
    applied_date   DATE          NOT NULL,
    status         VARCHAR2(20)  DEFAULT 'Submitted' NOT NULL,
    student_id     INT           NOT NULL,
    internship_id  INT           NOT NULL,
    created_at     TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at     TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT uq_student_internship UNIQUE (student_id, internship_id),
    -- NOTE: applied_date <= SYSDATE cannot be a CHECK constraint in Oracle (ORA-02436).
    -- Enforced by trigger trg_validate_app_date.
    CONSTRAINT chk_app_status CHECK (status IN (
        'Submitted','Under Review','Approved','Rejected','Withdrawn'
    )),
    FOREIGN KEY (student_id)    REFERENCES STUDENT(student_id),
    FOREIGN KEY (internship_id) REFERENCES INTERNSHIP(internship_id)
);

CREATE TABLE APPROVAL (
    application_id INT           NOT NULL,
    faculty_id     INT           NOT NULL,
    revision_no    INT           NOT NULL,
    approval_date  DATE          NOT NULL,
    decision       VARCHAR2(20)  NOT NULL,
    PRIMARY KEY (application_id, faculty_id, revision_no),
    CONSTRAINT chk_revision_no CHECK (revision_no >= 1),
    CONSTRAINT chk_decision    CHECK (decision IN ('Approved','Rejected','Pending')),
    -- NOTE: approval_date <= SYSDATE cannot be a CHECK constraint in Oracle (ORA-02436).
    -- Enforced by trigger trg_validate_approval_date.
    FOREIGN KEY (application_id) REFERENCES APPLICATION(application_id) ON DELETE CASCADE,
    FOREIGN KEY (faculty_id)     REFERENCES FACULTY(faculty_id)
);

CREATE TABLE REMARK (
    remark_id      INT            DEFAULT seq_remark.NEXTVAL PRIMARY KEY,
    application_id INT            NOT NULL,
    faculty_id     INT            NOT NULL,
    revision_no    INT            NOT NULL,
    remark_type    VARCHAR2(30)   NOT NULL,
    remark_text    VARCHAR2(500)  NOT NULL,
    remark_date    DATE           NOT NULL,
    CONSTRAINT chk_remark_type CHECK (remark_type IN (
        'General','Correction','Query','Clarification','Final'
    )),
    -- NOTE: remark_date <= SYSDATE cannot be a CHECK constraint in Oracle (ORA-02436).
    -- Enforced by trigger trg_validate_remark_date.
    CONSTRAINT chk_remark_text CHECK (LENGTH(TRIM(remark_text)) > 0),
    FOREIGN KEY (application_id, faculty_id, revision_no)
        REFERENCES APPROVAL(application_id, faculty_id, revision_no) ON DELETE CASCADE
);

CREATE TABLE AUDIT_LOG (
    audit_id    INT            DEFAULT seq_audit.NEXTVAL PRIMARY KEY,
    table_name  VARCHAR2(50)   NOT NULL,
    operation   VARCHAR2(10)   NOT NULL,
    record_id   VARCHAR2(100)  NOT NULL,
    changed_by  VARCHAR2(50)   NOT NULL,
    changed_at  TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    old_values  VARCHAR2(2000),
    new_values  VARCHAR2(2000),
    CONSTRAINT chk_audit_op CHECK (operation IN ('INSERT','UPDATE','DELETE'))
);

-- ============================================================
-- SECTION 3: INSERT DATA
-- Order: COMPANY → USER_BASE → USER_PHONE → LOGIN
--        → STUDENT / FACULTY / ADMIN
--        → INTERNSHIP → eligibility tables
--        → APPLICATION → APPROVAL → REMARK
-- ============================================================

-- ============================================================
-- SECTION 3: INSERT DATA  (FULLY DYNAMIC VERSION)
-- IDs are never hardcoded. Every FK is resolved at runtime
-- using natural keys (email, company_name, internship title).
-- Order: COMPANY → USER_BASE → USER_PHONE → LOGIN
--        → STUDENT / FACULTY / ADMIN
--        → INTERNSHIP → eligibility tables
--        → APPLICATION → APPROVAL → REMARK
-- ============================================================

-- ---- COMPANY (seq starts at 101) ----
-- company_id is sequence-driven; no FK dependencies here.
INSERT INTO COMPANY (company_id, company_name, city, state) VALUES (seq_company.NEXTVAL, 'Global Tech Solutions', 'Chennai',   'Tamil Nadu');
INSERT INTO COMPANY (company_id, company_name, city, state) VALUES (seq_company.NEXTVAL, 'DataStream Inc.',       'Bangalore', 'Karnataka');
INSERT INTO COMPANY (company_id, company_name, city, state) VALUES (seq_company.NEXTVAL, 'CloudNet Systems',      'Hyderabad', 'Telangana');
INSERT INTO COMPANY (company_id, company_name, city, state) VALUES (seq_company.NEXTVAL, 'InnovateX',             'Pune',      'Maharashtra');
INSERT INTO COMPANY (company_id, company_name, city, state) VALUES (seq_company.NEXTVAL, 'FinTech Dynamics',      'Mumbai',    'Maharashtra');

-- ---- USER_BASE (seq starts at 10) ----
-- user_id is sequence-driven; email is the natural key used by
-- all downstream dynamic inserts.
INSERT INTO USER_BASE (user_id, first_name, last_name, email, gender) VALUES (seq_user.NEXTVAL, 'Rahul',  'Kumar',  'rahul.k@university.edu',  'Male');
INSERT INTO USER_BASE (user_id, first_name, last_name, email, gender) VALUES (seq_user.NEXTVAL, 'Sneha',  'Sharma', 'sneha.s@university.edu',  'Female');
INSERT INTO USER_BASE (user_id, first_name, last_name, email, gender) VALUES (seq_user.NEXTVAL, 'Amit',   'Patel',  'amit.p@university.edu',   'Male');
INSERT INTO USER_BASE (user_id, first_name, last_name, email, gender) VALUES (seq_user.NEXTVAL, 'Neha',   'Gupta',  'neha.g@university.edu',   'Female');
INSERT INTO USER_BASE (user_id, first_name, last_name, email, gender) VALUES (seq_user.NEXTVAL, 'Karan',  'Singh',  'karan.s@university.edu',  'Male');
INSERT INTO USER_BASE (user_id, first_name, last_name, email, gender) VALUES (seq_user.NEXTVAL, 'Rohan',  'Mehta',  'rohan.m@university.edu',  'Male');
INSERT INTO USER_BASE (user_id, first_name, last_name, email, gender) VALUES (seq_user.NEXTVAL, 'Priya',  'Nair',   'priya.n@university.edu',  'Female');
INSERT INTO USER_BASE (user_id, first_name, last_name, email, gender) VALUES (seq_user.NEXTVAL, 'Vikram', 'Rao',    'vikram.r@university.edu', 'Male');
INSERT INTO USER_BASE (user_id, first_name, last_name, email, gender) VALUES (seq_user.NEXTVAL, 'Anjali', 'Desai',  'anjali.d@university.edu', 'Female');
INSERT INTO USER_BASE (user_id, first_name, last_name, email, gender) VALUES (seq_user.NEXTVAL, 'Suresh', 'Iyer',   'suresh.i@university.edu', 'Male');
INSERT INTO USER_BASE (user_id, first_name, last_name, email, gender) VALUES (seq_user.NEXTVAL, 'System', 'Admin',  'admin@university.edu',    'Other');
INSERT INTO USER_BASE (user_id, first_name, last_name, email, gender) VALUES (seq_user.NEXTVAL, 'Dept',   'Admin1', 'dept1@university.edu',    'Other');
INSERT INTO USER_BASE (user_id, first_name, last_name, email, gender) VALUES (seq_user.NEXTVAL, 'Dept',   'Admin2', 'dept2@university.edu',    'Other');
INSERT INTO USER_BASE (user_id, first_name, last_name, email, gender) VALUES (seq_user.NEXTVAL, 'Audit',  'Viewer1','viewer1@university.edu',  'Other');
INSERT INTO USER_BASE (user_id, first_name, last_name, email, gender) VALUES (seq_user.NEXTVAL, 'Audit',  'Viewer2','viewer2@university.edu',  'Other');

-- ---- USER_PHONE (DYNAMIC: email → user_id) ----
-- No hardcoded user_ids. Each phone is linked via the owner's email.
INSERT INTO USER_PHONE (user_id, phone_number)
    SELECT user_id, '9876543210' FROM USER_BASE WHERE email = 'rahul.k@university.edu';
INSERT INTO USER_PHONE (user_id, phone_number)
    SELECT user_id, '9123456780' FROM USER_BASE WHERE email = 'sneha.s@university.edu';
INSERT INTO USER_PHONE (user_id, phone_number)
    SELECT user_id, '9988776655' FROM USER_BASE WHERE email = 'amit.p@university.edu';
INSERT INTO USER_PHONE (user_id, phone_number)
    SELECT user_id, '9876501234' FROM USER_BASE WHERE email = 'neha.g@university.edu';
INSERT INTO USER_PHONE (user_id, phone_number)
    SELECT user_id, '9000000000' FROM USER_BASE WHERE email = 'karan.s@university.edu';

-- ---- LOGIN (DYNAMIC: email → user_id) ----
-- password_hash = PBKDF2-HMAC-SHA512 (128-char uppercase hex)
-- password_salt = 32-byte random salt  (64-char uppercase hex)
-- Plaintext passwords are NEVER stored.
-- Test passwords: Username format creates password like Rahul@123, etc.
INSERT INTO LOGIN (login_id, username, password_hash, password_salt, last_login, user_id)
    SELECT seq_login.NEXTVAL, 'rahul_k',
           '6C0471674E77AC650D115EE75154423DBFB887310A44D45FAC6D163E8E0FEFF01AB66F4C17F20C223F010849D3BD3CF4D35D9DFCC55AB96197876751A3B718EB',
           '8A7BB0CF77B8A24875D1907D4DA891FD3B3551637DAEE02B465E389EDF58A9AD',
           TO_TIMESTAMP('2026-02-01 09:00:00','YYYY-MM-DD HH24:MI:SS'),
           user_id
    FROM USER_BASE WHERE email = 'rahul.k@university.edu';

INSERT INTO LOGIN (login_id, username, password_hash, password_salt, last_login, user_id)
    SELECT seq_login.NEXTVAL, 'sneha_s',
           '28EB34D966C7EA3DE44222CF1F2BB3359A9D47FF5974BECA66A2AD7C10A0B59D3AE421E274A2F448C02BC47CAD02EAD7629B7962B83DA7E4FEF7610F46064777',
           '3871E37754D653162BF3BA3024E4965ACA7949B9200BC5BBD0E219538A0D4AA5',
           TO_TIMESTAMP('2026-02-10 10:30:00','YYYY-MM-DD HH24:MI:SS'),
           user_id
    FROM USER_BASE WHERE email = 'sneha.s@university.edu';

INSERT INTO LOGIN (login_id, username, password_hash, password_salt, last_login, user_id)
    SELECT seq_login.NEXTVAL, 'amit_p',
           '59915A3D516D0EEDFF0A129063350BCCD0C69497A7D10B90C8030E010E32AE51574D003C95AAFF4265CBC3E7F3A04171C1F13E1E4F3A8A1819399848A7D8C3D5',
           'B2DB236790C6BFE03D8CB614EB409F8EF7430C31F9A7854DB8C3278B13E8E49F',
           TO_TIMESTAMP('2026-01-10 08:00:00','YYYY-MM-DD HH24:MI:SS'),
           user_id
    FROM USER_BASE WHERE email = 'amit.p@university.edu';

INSERT INTO LOGIN (login_id, username, password_hash, password_salt, last_login, user_id)
    SELECT seq_login.NEXTVAL, 'neha_g',
           'A9D13202DB8C2471CB815CBD91E3352D6BFB8E3C9C442227BDE0BEAAA6FBEE5354A3A0D6C299472EA2BE55F22EA267DF01E5F20E30E60839FCA731BAB7E6725C',
           '14EC878E8353A9C16A8F286BD48AB8B9160208A697120D0A81ABCA0C7F7E8860',
           TO_TIMESTAMP('2026-01-12 09:00:00','YYYY-MM-DD HH24:MI:SS'),
           user_id
    FROM USER_BASE WHERE email = 'neha.g@university.edu';

INSERT INTO LOGIN (login_id, username, password_hash, password_salt, last_login, user_id)
    SELECT seq_login.NEXTVAL, 'karan_s',
           '9E650694B18660F65449A13F06A933166349B7096953FAA41303B595071CFEB49A56EF5381D16D328DFB13CD2D80D49CDB27E95B35E5223DB8CB60DF1188A9D4',
           'D70236A2CB588F6FA9BC9E547786CC9909984E555DE9D700616B33F29D4926A7',
           TO_TIMESTAMP('2026-01-18 14:00:00','YYYY-MM-DD HH24:MI:SS'),
           user_id
    FROM USER_BASE WHERE email = 'karan.s@university.edu';

INSERT INTO LOGIN (login_id, username, password_hash, password_salt, last_login, user_id)
    SELECT seq_login.NEXTVAL, 'rohan_m',
           '7F3B4319D54F3BB3F3009C630BF279592A12561990923E14C47A56AC35ED9CD3E7AA77260A6BB53F942FA02B297034A8FD10D682E30F64E403E9B30C24B257A3',
           '75029BED8646F6819FFD34F4D19FA77F8C99B0081CB4C7997B6CC43C8A13FE1E',
           TO_TIMESTAMP('2026-01-15 08:45:00','YYYY-MM-DD HH24:MI:SS'),
           user_id
    FROM USER_BASE WHERE email = 'rohan.m@university.edu';

INSERT INTO LOGIN (login_id, username, password_hash, password_salt, last_login, user_id)
    SELECT seq_login.NEXTVAL, 'priya_n',
           '19DAF988C59993602B773D21436385CCEB2EB48E9CE450C6F0F1A2E2ADB0ED4A36AD4CCFB7E7414A35438B994F214BF332FF3F36AEA819BB7F210B00C8F2B9A5',
           'FD757B350EBDA819566ECBD9E81C13403F56878E31FBCDF275DB88F1E723F9C8',
           TO_TIMESTAMP('2026-01-20 11:00:00','YYYY-MM-DD HH24:MI:SS'),
           user_id
    FROM USER_BASE WHERE email = 'priya.n@university.edu';

INSERT INTO LOGIN (login_id, username, password_hash, password_salt, last_login, user_id)
    SELECT seq_login.NEXTVAL, 'vikram_r',
           '3A49DBA622233D648809C3C6D140EA270B9B61F29BC5A6EA9C03D9FB0ABCF3BF42A3C5A267ACA948CB4A6946BE99362DAC56656140D861868BAA3806FEEB66D3',
           '5E5C55B56794D54F6EF41241CBB33F6B285B5F1BDCA9D6529048391B6E4FF0FA',
           TO_TIMESTAMP('2026-01-22 10:00:00','YYYY-MM-DD HH24:MI:SS'),
           user_id
    FROM USER_BASE WHERE email = 'vikram.r@university.edu';

INSERT INTO LOGIN (login_id, username, password_hash, password_salt, last_login, user_id)
    SELECT seq_login.NEXTVAL, 'anjali_d',
           'F6237A8BFC328809B4240870786E3B2610BFB696E96C4CFADB50A1FE71B7AE52E1D890310BFD11AFE1CD276AFF61C8207AC0927516B974D88E52B87BCC655B42',
           'C0E4FD7B2850EA64E2BF087E171B6A3ABBCF816433D9DE1BDE9F981E863DE999',
           TO_TIMESTAMP('2026-01-25 09:30:00','YYYY-MM-DD HH24:MI:SS'),
           user_id
    FROM USER_BASE WHERE email = 'anjali.d@university.edu';

INSERT INTO LOGIN (login_id, username, password_hash, password_salt, last_login, user_id)
    SELECT seq_login.NEXTVAL, 'suresh_i',
           '59429D0137095DB8BE45CEFE050802D490B5856EB78006710D2451458ACC88B24DE35DDCDB9FA0A0085499DD523117202016C7774DCCCD38B411E1976E2AF8BD',
           '9CED59D78126C933586A8E4D50753841000F5359A74C67FB3EDC745B83AA101B',
           TO_TIMESTAMP('2026-01-28 11:00:00','YYYY-MM-DD HH24:MI:SS'),
           user_id
    FROM USER_BASE WHERE email = 'suresh.i@university.edu';

INSERT INTO LOGIN (login_id, username, password_hash, password_salt, last_login, user_id)
    SELECT seq_login.NEXTVAL, 'sys_admin',
           '8EA5C48C07AB9DDAEBC2A094433A441795BD15F305B2AD6FFDCDEB81F0BDCD8BE227C691DA8295E82C7A0E41801E1BA92C441343A8863484831B21422272E437',
           '1435F3EA373C11B7978C1719A1B83FB81C3CB809045D2650C8CAAB8F9C0650CB',
           TO_TIMESTAMP('2026-03-01 08:00:00','YYYY-MM-DD HH24:MI:SS'),
           user_id
    FROM USER_BASE WHERE email = 'admin@university.edu';

INSERT INTO LOGIN (login_id, username, password_hash, password_salt, last_login, user_id)
    SELECT seq_login.NEXTVAL, 'dept_admin1',
           '7A7030C178EF20507AA775BDA3A217045AF47EC3EA38CD5EA1DD96B05FB4EDABEBD3926079A3CADFF1B379C9C41F33B3B01FF188B7C3093734B7A7F07AB93395',
           '07C907F2783BC427F2B222718DAA2EAEB36F6042B2767A766DCDF4AD1CBB7E03',
           TO_TIMESTAMP('2026-02-15 10:00:00','YYYY-MM-DD HH24:MI:SS'),
           user_id
    FROM USER_BASE WHERE email = 'dept1@university.edu';

INSERT INTO LOGIN (login_id, username, password_hash, password_salt, last_login, user_id)
    SELECT seq_login.NEXTVAL, 'dept_admin2',
           'AF65D4DC38AE6D85FA4A0BFE911B4E31461E954E6524583516DF4AD8AB9448295DD6BECE2C8FE448D293661BB7A64CFA8E00238E37FAC91E069452DC97CCF78E',
           '43EA1DD5D139F27C4005F4EF70D018B58218C4CD6D88ACA4FF72AB838172C900',
           TO_TIMESTAMP('2026-02-16 10:00:00','YYYY-MM-DD HH24:MI:SS'),
           user_id
    FROM USER_BASE WHERE email = 'dept2@university.edu';

INSERT INTO LOGIN (login_id, username, password_hash, password_salt, last_login, user_id)
    SELECT seq_login.NEXTVAL, 'viewer1',
           'F249D870753AC44BF76A9708C809CD1BF3C980F15F7A7146D3FE4D3546BEFFE99DA711E011083D2FEF250E118A121225A45AA8FC191C11E3B401994AD1F7AD2E',
           'FD05E0AC685B4FFDE82695665A2D7AD1E364F7D8BE1B094E71A198A4855CB042',
           TO_TIMESTAMP('2026-02-18 09:00:00','YYYY-MM-DD HH24:MI:SS'),
           user_id
    FROM USER_BASE WHERE email = 'viewer1@university.edu';

INSERT INTO LOGIN (login_id, username, password_hash, password_salt, last_login, user_id)
    SELECT seq_login.NEXTVAL, 'viewer2',
           'BF082B2578663B8AC110126BEA898DCF15FE744309740F2EC1F8D41F62C0B3F441D9A6FD7961A0CB8B369A50E80832EF81BD8C09CAF910CD97276C46507F6FD9',
           '56C175E859201FEF01E53B09D74D47A74D792BD69D9176DF2008CBC5914FED2E',
           TO_TIMESTAMP('2026-02-19 09:00:00','YYYY-MM-DD HH24:MI:SS'),
           user_id
    FROM USER_BASE WHERE email = 'viewer2@university.edu';

-- ---- STUDENT (DYNAMIC: email → user_id) ----
INSERT INTO STUDENT (student_id, dept, dob, cgpa, year_of_study, user_id)
    SELECT seq_student.NEXTVAL, 'SCOPE', TO_DATE('2005-05-15','YYYY-MM-DD'), 9.20, 2, user_id
    FROM USER_BASE WHERE email = 'rahul.k@university.edu';

INSERT INTO STUDENT (student_id, dept, dob, cgpa, year_of_study, user_id)
    SELECT seq_student.NEXTVAL, 'SCOPE', TO_DATE('2004-11-20','YYYY-MM-DD'), 8.80, 3, user_id
    FROM USER_BASE WHERE email = 'sneha.s@university.edu';

INSERT INTO STUDENT (student_id, dept, dob, cgpa, year_of_study, user_id)
    SELECT seq_student.NEXTVAL, 'SITE', TO_DATE('2003-08-10','YYYY-MM-DD'), 7.50, 4, user_id
    FROM USER_BASE WHERE email = 'amit.p@university.edu';

INSERT INTO STUDENT (student_id, dept, dob, cgpa, year_of_study, user_id)
    SELECT seq_student.NEXTVAL, 'SENSE', TO_DATE('2005-01-25','YYYY-MM-DD'), 8.10, 2, user_id
    FROM USER_BASE WHERE email = 'neha.g@university.edu';

INSERT INTO STUDENT (student_id, dept, dob, cgpa, year_of_study, user_id)
    SELECT seq_student.NEXTVAL, 'SCOPE', TO_DATE('2004-03-30','YYYY-MM-DD'), 9.50, 3, user_id
    FROM USER_BASE WHERE email = 'karan.s@university.edu';

-- ---- FACULTY (DYNAMIC: email → user_id) ----
INSERT INTO FACULTY (faculty_id, designation, dept, user_id)
    SELECT seq_faculty.NEXTVAL, 'Assistant Professor', 'SCOPE', user_id
    FROM USER_BASE WHERE email = 'rohan.m@university.edu';

INSERT INTO FACULTY (faculty_id, designation, dept, user_id)
    SELECT seq_faculty.NEXTVAL, 'Professor', 'SCOPE', user_id
    FROM USER_BASE WHERE email = 'priya.n@university.edu';

INSERT INTO FACULTY (faculty_id, designation, dept, user_id)
    SELECT seq_faculty.NEXTVAL, 'Associate Professor', 'SITE', user_id
    FROM USER_BASE WHERE email = 'vikram.r@university.edu';

INSERT INTO FACULTY (faculty_id, designation, dept, user_id)
    SELECT seq_faculty.NEXTVAL, 'Lecturer', 'SENSE', user_id
    FROM USER_BASE WHERE email = 'anjali.d@university.edu';

INSERT INTO FACULTY (faculty_id, designation, dept, user_id)
    SELECT seq_faculty.NEXTVAL, 'Professor', 'SCOPE', user_id
    FROM USER_BASE WHERE email = 'suresh.i@university.edu';

-- ---- ADMIN (DYNAMIC: email → user_id) ----
-- FIX 6 preserved: SuperAdmin maps to admin@university.edu, not a student.
INSERT INTO ADMIN (admin_id, role, user_id)
    SELECT seq_admin.NEXTVAL, 'SuperAdmin', user_id
    FROM USER_BASE WHERE email = 'admin@university.edu';

INSERT INTO ADMIN (admin_id, role, user_id)
    SELECT seq_admin.NEXTVAL, 'DeptAdmin', user_id
    FROM USER_BASE WHERE email = 'dept1@university.edu';

INSERT INTO ADMIN (admin_id, role, user_id)
    SELECT seq_admin.NEXTVAL, 'DeptAdmin', user_id
    FROM USER_BASE WHERE email = 'dept2@university.edu';

INSERT INTO ADMIN (admin_id, role, user_id)
    SELECT seq_admin.NEXTVAL, 'Viewer', user_id
    FROM USER_BASE WHERE email = 'viewer1@university.edu';

INSERT INTO ADMIN (admin_id, role, user_id)
    SELECT seq_admin.NEXTVAL, 'Viewer', user_id
    FROM USER_BASE WHERE email = 'viewer2@university.edu';

-- ---- INTERNSHIP (DYNAMIC: company_name → company_id) ----
-- No hardcoded company_ids. Resolved at runtime via company_name.
INSERT INTO INTERNSHIP (internship_id, title, duration, stipend, company_id)
    SELECT seq_internship.NEXTVAL, 'Backend Developer', '3 Months', 15000.00, company_id
    FROM COMPANY WHERE company_name = 'Global Tech Solutions';

INSERT INTO INTERNSHIP (internship_id, title, duration, stipend, company_id)
    SELECT seq_internship.NEXTVAL, 'Data Analyst', '6 Months', 20000.00, company_id
    FROM COMPANY WHERE company_name = 'DataStream Inc.';

INSERT INTO INTERNSHIP (internship_id, title, duration, stipend, company_id)
    SELECT seq_internship.NEXTVAL, 'Cloud Engineer', '6 Months', 25000.00, company_id
    FROM COMPANY WHERE company_name = 'CloudNet Systems';

INSERT INTO INTERNSHIP (internship_id, title, duration, stipend, company_id)
    SELECT seq_internship.NEXTVAL, 'Frontend Intern', '2 Months', 10000.00, company_id
    FROM COMPANY WHERE company_name = 'InnovateX';

INSERT INTO INTERNSHIP (internship_id, title, duration, stipend, company_id)
    SELECT seq_internship.NEXTVAL, 'Security Analyst', '3 Months', 18000.00, company_id
    FROM COMPANY WHERE company_name = 'FinTech Dynamics';

-- ---- INTERNSHIP_YEAR (DYNAMIC: title → internship_id) ----
INSERT INTO INTERNSHIP_YEAR (internship_id, eligible_year)
    SELECT internship_id, 2 FROM INTERNSHIP WHERE title = 'Backend Developer';
INSERT INTO INTERNSHIP_YEAR (internship_id, eligible_year)
    SELECT internship_id, 3 FROM INTERNSHIP WHERE title = 'Backend Developer';
INSERT INTO INTERNSHIP_YEAR (internship_id, eligible_year)
    SELECT internship_id, 3 FROM INTERNSHIP WHERE title = 'Data Analyst';
INSERT INTO INTERNSHIP_YEAR (internship_id, eligible_year)
    SELECT internship_id, 4 FROM INTERNSHIP WHERE title = 'Cloud Engineer';
INSERT INTO INTERNSHIP_YEAR (internship_id, eligible_year)
    SELECT internship_id, 2 FROM INTERNSHIP WHERE title = 'Frontend Intern';

-- ---- INTERNSHIP_DEPT (DYNAMIC: title → internship_id) ----
INSERT INTO INTERNSHIP_DEPT (internship_id, eligible_dept)
    SELECT internship_id, 'SCOPE' FROM INTERNSHIP WHERE title = 'Backend Developer';
INSERT INTO INTERNSHIP_DEPT (internship_id, eligible_dept)
    SELECT internship_id, 'SCOPE' FROM INTERNSHIP WHERE title = 'Data Analyst';
INSERT INTO INTERNSHIP_DEPT (internship_id, eligible_dept)
    SELECT internship_id, 'SITE'  FROM INTERNSHIP WHERE title = 'Cloud Engineer';
INSERT INTO INTERNSHIP_DEPT (internship_id, eligible_dept)
    SELECT internship_id, 'SCOPE' FROM INTERNSHIP WHERE title = 'Frontend Intern';
INSERT INTO INTERNSHIP_DEPT (internship_id, eligible_dept)
    SELECT internship_id, 'SENSE' FROM INTERNSHIP WHERE title = 'Security Analyst';

-- ---- INTERNSHIP_GENDER (DYNAMIC: title → internship_id) ----
-- FIX 8 preserved: no duplicate rows.
INSERT INTO INTERNSHIP_GENDER (internship_id, eligible_gender)
    SELECT internship_id, 'Male'   FROM INTERNSHIP WHERE title = 'Backend Developer';
INSERT INTO INTERNSHIP_GENDER (internship_id, eligible_gender)
    SELECT internship_id, 'Female' FROM INTERNSHIP WHERE title = 'Backend Developer';
INSERT INTO INTERNSHIP_GENDER (internship_id, eligible_gender)
    SELECT internship_id, 'Male'   FROM INTERNSHIP WHERE title = 'Data Analyst';
INSERT INTO INTERNSHIP_GENDER (internship_id, eligible_gender)
    SELECT internship_id, 'Female' FROM INTERNSHIP WHERE title = 'Cloud Engineer';
INSERT INTO INTERNSHIP_GENDER (internship_id, eligible_gender)
    SELECT internship_id, 'Other'  FROM INTERNSHIP WHERE title = 'Frontend Intern';

-- ---- INTERNSHIP_CGPA (DYNAMIC: title → internship_id) ----
-- FIX 9 preserved: all 5 rows present.
INSERT INTO INTERNSHIP_CGPA (internship_id, min_cgpa)
    SELECT internship_id, 8.00 FROM INTERNSHIP WHERE title = 'Backend Developer';
INSERT INTO INTERNSHIP_CGPA (internship_id, min_cgpa)
    SELECT internship_id, 7.50 FROM INTERNSHIP WHERE title = 'Data Analyst';
INSERT INTO INTERNSHIP_CGPA (internship_id, min_cgpa)
    SELECT internship_id, 8.50 FROM INTERNSHIP WHERE title = 'Cloud Engineer';
INSERT INTO INTERNSHIP_CGPA (internship_id, min_cgpa)
    SELECT internship_id, 6.50 FROM INTERNSHIP WHERE title = 'Frontend Intern';
INSERT INTO INTERNSHIP_CGPA (internship_id, min_cgpa)
    SELECT internship_id, 8.00 FROM INTERNSHIP WHERE title = 'Security Analyst';

-- ---- APPLICATION (DYNAMIC: student email + internship title) ----
-- FIX 10 preserved: date format mask is 'YYYY-MM-DD'.
INSERT INTO APPLICATION (application_id, applied_date, status, student_id, internship_id)
    SELECT seq_application.NEXTVAL, TO_DATE('2026-02-20','YYYY-MM-DD'), 'Approved',
           s.student_id, i.internship_id
    FROM STUDENT s, INTERNSHIP i, USER_BASE u
    WHERE s.user_id = u.user_id AND u.email = 'rahul.k@university.edu'
    AND i.title = 'Backend Developer';

INSERT INTO APPLICATION (application_id, applied_date, status, student_id, internship_id)
    SELECT seq_application.NEXTVAL, TO_DATE('2026-02-22','YYYY-MM-DD'), 'Under Review',
           s.student_id, i.internship_id
    FROM STUDENT s, INTERNSHIP i, USER_BASE u
    WHERE s.user_id = u.user_id AND u.email = 'sneha.s@university.edu'
    AND i.title = 'Data Analyst';

INSERT INTO APPLICATION (application_id, applied_date, status, student_id, internship_id)
    SELECT seq_application.NEXTVAL, TO_DATE('2026-02-25','YYYY-MM-DD'), 'Submitted',
           s.student_id, i.internship_id
    FROM STUDENT s, INTERNSHIP i, USER_BASE u
    WHERE s.user_id = u.user_id AND u.email = 'amit.p@university.edu'
    AND i.title = 'Cloud Engineer';

INSERT INTO APPLICATION (application_id, applied_date, status, student_id, internship_id)
    SELECT seq_application.NEXTVAL, TO_DATE('2026-02-26','YYYY-MM-DD'), 'Rejected',
           s.student_id, i.internship_id
    FROM STUDENT s, INTERNSHIP i, USER_BASE u
    WHERE s.user_id = u.user_id AND u.email = 'neha.g@university.edu'
    AND i.title = 'Frontend Intern';

INSERT INTO APPLICATION (application_id, applied_date, status, student_id, internship_id)
    SELECT seq_application.NEXTVAL, TO_DATE('2026-02-28','YYYY-MM-DD'), 'Approved',
           s.student_id, i.internship_id
    FROM STUDENT s, INTERNSHIP i, USER_BASE u
    WHERE s.user_id = u.user_id AND u.email = 'karan.s@university.edu'
    AND i.title = 'Security Analyst';

-- ---- APPROVAL (DYNAMIC: student email + internship title + faculty email) ----
-- application_id and faculty_id are both resolved at runtime — no hardcoded IDs.
INSERT INTO APPROVAL (application_id, faculty_id, revision_no, approval_date, decision)
    SELECT a.application_id, f.faculty_id, 1,
           TO_DATE('2026-02-22','YYYY-MM-DD'), 'Approved'
    FROM APPLICATION a, STUDENT s, USER_BASE us, FACULTY f, USER_BASE uf, INTERNSHIP i
    WHERE a.student_id = s.student_id AND s.user_id = us.user_id
    AND us.email = 'rahul.k@university.edu'
    AND a.internship_id = i.internship_id AND i.title = 'Backend Developer'
    AND f.user_id = uf.user_id AND uf.email = 'rohan.m@university.edu';

INSERT INTO APPROVAL (application_id, faculty_id, revision_no, approval_date, decision)
    SELECT a.application_id, f.faculty_id, 1,
           TO_DATE('2026-02-23','YYYY-MM-DD'), 'Approved'
    FROM APPLICATION a, STUDENT s, USER_BASE us, FACULTY f, USER_BASE uf, INTERNSHIP i
    WHERE a.student_id = s.student_id AND s.user_id = us.user_id
    AND us.email = 'rahul.k@university.edu'
    AND a.internship_id = i.internship_id AND i.title = 'Backend Developer'
    AND f.user_id = uf.user_id AND uf.email = 'priya.n@university.edu';

INSERT INTO APPROVAL (application_id, faculty_id, revision_no, approval_date, decision)
    SELECT a.application_id, f.faculty_id, 1,
           TO_DATE('2026-02-24','YYYY-MM-DD'), 'Pending'
    FROM APPLICATION a, STUDENT s, USER_BASE us, FACULTY f, USER_BASE uf, INTERNSHIP i
    WHERE a.student_id = s.student_id AND s.user_id = us.user_id
    AND us.email = 'sneha.s@university.edu'
    AND a.internship_id = i.internship_id AND i.title = 'Data Analyst'
    AND f.user_id = uf.user_id AND uf.email = 'rohan.m@university.edu';

INSERT INTO APPROVAL (application_id, faculty_id, revision_no, approval_date, decision)
    SELECT a.application_id, f.faculty_id, 1,
           TO_DATE('2026-02-27','YYYY-MM-DD'), 'Rejected'
    FROM APPLICATION a, STUDENT s, USER_BASE us, FACULTY f, USER_BASE uf, INTERNSHIP i
    WHERE a.student_id = s.student_id AND s.user_id = us.user_id
    AND us.email = 'neha.g@university.edu'
    AND a.internship_id = i.internship_id AND i.title = 'Frontend Intern'
    AND f.user_id = uf.user_id AND uf.email = 'vikram.r@university.edu';

INSERT INTO APPROVAL (application_id, faculty_id, revision_no, approval_date, decision)
    SELECT a.application_id, f.faculty_id, 1,
           TO_DATE('2026-03-01','YYYY-MM-DD'), 'Approved'
    FROM APPLICATION a, STUDENT s, USER_BASE us, FACULTY f, USER_BASE uf, INTERNSHIP i
    WHERE a.student_id = s.student_id AND s.user_id = us.user_id
    AND us.email = 'karan.s@university.edu'
    AND a.internship_id = i.internship_id AND i.title = 'Security Analyst'
    AND f.user_id = uf.user_id AND uf.email = 'suresh.i@university.edu';

-- ---- REMARK (DYNAMIC: resolved through APPROVAL via student+internship+faculty email) ----
INSERT INTO REMARK (remark_id, application_id, faculty_id, revision_no, remark_type, remark_text, remark_date)
    SELECT seq_remark.NEXTVAL, ap.application_id, ap.faculty_id, ap.revision_no,
           'General', 'Good academic record.', TO_DATE('2026-02-22','YYYY-MM-DD')
    FROM APPROVAL ap, APPLICATION a, STUDENT s, USER_BASE us, FACULTY f, USER_BASE uf, INTERNSHIP i
    WHERE ap.application_id = a.application_id
    AND a.student_id = s.student_id AND s.user_id = us.user_id
    AND us.email = 'rahul.k@university.edu'
    AND a.internship_id = i.internship_id AND i.title = 'Backend Developer'
    AND ap.faculty_id = f.faculty_id AND f.user_id = uf.user_id
    AND uf.email = 'rohan.m@university.edu' AND ap.revision_no = 1;

INSERT INTO REMARK (remark_id, application_id, faculty_id, revision_no, remark_type, remark_text, remark_date)
    SELECT seq_remark.NEXTVAL, ap.application_id, ap.faculty_id, ap.revision_no,
           'Final', 'Approval confirmed.', TO_DATE('2026-02-23','YYYY-MM-DD')
    FROM APPROVAL ap, APPLICATION a, STUDENT s, USER_BASE us, FACULTY f, USER_BASE uf, INTERNSHIP i
    WHERE ap.application_id = a.application_id
    AND a.student_id = s.student_id AND s.user_id = us.user_id
    AND us.email = 'rahul.k@university.edu'
    AND a.internship_id = i.internship_id AND i.title = 'Backend Developer'
    AND ap.faculty_id = f.faculty_id AND f.user_id = uf.user_id
    AND uf.email = 'priya.n@university.edu' AND ap.revision_no = 1;

INSERT INTO REMARK (remark_id, application_id, faculty_id, revision_no, remark_type, remark_text, remark_date)
    SELECT seq_remark.NEXTVAL, ap.application_id, ap.faculty_id, ap.revision_no,
           'Query', 'Need updated resume.', TO_DATE('2026-02-24','YYYY-MM-DD')
    FROM APPROVAL ap, APPLICATION a, STUDENT s, USER_BASE us, FACULTY f, USER_BASE uf, INTERNSHIP i
    WHERE ap.application_id = a.application_id
    AND a.student_id = s.student_id AND s.user_id = us.user_id
    AND us.email = 'sneha.s@university.edu'
    AND a.internship_id = i.internship_id AND i.title = 'Data Analyst'
    AND ap.faculty_id = f.faculty_id AND f.user_id = uf.user_id
    AND uf.email = 'rohan.m@university.edu' AND ap.revision_no = 1;

INSERT INTO REMARK (remark_id, application_id, faculty_id, revision_no, remark_type, remark_text, remark_date)
    SELECT seq_remark.NEXTVAL, ap.application_id, ap.faculty_id, ap.revision_no,
           'Correction', 'CGPA is too low.', TO_DATE('2026-02-27','YYYY-MM-DD')
    FROM APPROVAL ap, APPLICATION a, STUDENT s, USER_BASE us, FACULTY f, USER_BASE uf, INTERNSHIP i
    WHERE ap.application_id = a.application_id
    AND a.student_id = s.student_id AND s.user_id = us.user_id
    AND us.email = 'neha.g@university.edu'
    AND a.internship_id = i.internship_id AND i.title = 'Frontend Intern'
    AND ap.faculty_id = f.faculty_id AND f.user_id = uf.user_id
    AND uf.email = 'vikram.r@university.edu' AND ap.revision_no = 1;

INSERT INTO REMARK (remark_id, application_id, faculty_id, revision_no, remark_type, remark_text, remark_date)
    SELECT seq_remark.NEXTVAL, ap.application_id, ap.faculty_id, ap.revision_no,
           'Final', 'Excellent portfolio.', TO_DATE('2026-03-01','YYYY-MM-DD')
    FROM APPROVAL ap, APPLICATION a, STUDENT s, USER_BASE us, FACULTY f, USER_BASE uf, INTERNSHIP i
    WHERE ap.application_id = a.application_id
    AND a.student_id = s.student_id AND s.user_id = us.user_id
    AND us.email = 'karan.s@university.edu'
    AND a.internship_id = i.internship_id AND i.title = 'Security Analyst'
    AND ap.faculty_id = f.faculty_id AND f.user_id = uf.user_id
    AND uf.email = 'suresh.i@university.edu' AND ap.revision_no = 1;

COMMIT;

-- ============================================================
-- SECTION 4: INDEXES
-- ============================================================
CREATE INDEX idx_user_phone_uid     ON USER_PHONE(user_id);
CREATE INDEX idx_internship_company ON INTERNSHIP(company_id);
CREATE INDEX idx_iyear_iid          ON INTERNSHIP_YEAR(internship_id);
CREATE INDEX idx_idept_iid          ON INTERNSHIP_DEPT(internship_id);
CREATE INDEX idx_igender_iid        ON INTERNSHIP_GENDER(internship_id);
CREATE INDEX idx_app_student        ON APPLICATION(student_id);
CREATE INDEX idx_app_internship     ON APPLICATION(internship_id);
CREATE INDEX idx_approval_faculty   ON APPROVAL(faculty_id);
CREATE INDEX idx_approval_appid     ON APPROVAL(application_id);
CREATE INDEX idx_remark_approval    ON REMARK(application_id, faculty_id, revision_no);
CREATE INDEX idx_app_status         ON APPLICATION(status);
CREATE INDEX idx_student_cgpa       ON STUDENT(cgpa);
CREATE INDEX idx_student_dept       ON STUDENT(dept);
CREATE INDEX idx_internship_active  ON INTERNSHIP(is_active);
CREATE INDEX idx_login_locked       ON LOGIN(is_locked);
CREATE INDEX idx_audit_table        ON AUDIT_LOG(table_name, changed_at);

-- ============================================================
-- SECTION 5: TRIGGERS
-- ============================================================

-- Trigger 1: Auto-update updated_at on USER_BASE
CREATE OR REPLACE TRIGGER trg_user_updated_at
BEFORE UPDATE ON USER_BASE FOR EACH ROW
BEGIN
    :NEW.updated_at := SYSTIMESTAMP;
END;
/

-- Trigger 2: Auto-update updated_at on APPLICATION
CREATE OR REPLACE TRIGGER trg_app_updated_at
BEFORE UPDATE ON APPLICATION FOR EACH ROW
BEGIN
    :NEW.updated_at := SYSTIMESTAMP;
END;
/

-- Trigger 3: Account lockout after 5 failed login attempts
CREATE OR REPLACE TRIGGER trg_account_lockout
BEFORE UPDATE OF failed_attempts ON LOGIN FOR EACH ROW
BEGIN
    IF :NEW.failed_attempts >= 5 THEN
        :NEW.is_locked := 'Y';
    END IF;
END;
/

-- Trigger 4: Audit log on APPLICATION (INSERT / UPDATE / DELETE)
CREATE OR REPLACE TRIGGER trg_audit_application
AFTER INSERT OR UPDATE OR DELETE ON APPLICATION
FOR EACH ROW
DECLARE v_op VARCHAR2(10); v_id VARCHAR2(100);
BEGIN
    IF INSERTING THEN
        v_op := 'INSERT'; v_id := TO_CHAR(:NEW.application_id);
        INSERT INTO AUDIT_LOG VALUES (seq_audit.NEXTVAL, 'APPLICATION',
            v_op, v_id, USER, SYSTIMESTAMP, NULL,
            'student='||:NEW.student_id||',status='||:NEW.status);
    ELSIF UPDATING THEN
        v_op := 'UPDATE'; v_id := TO_CHAR(:NEW.application_id);
        INSERT INTO AUDIT_LOG VALUES (seq_audit.NEXTVAL, 'APPLICATION',
            v_op, v_id, USER, SYSTIMESTAMP,
            'status='||:OLD.status, 'status='||:NEW.status);
    ELSIF DELETING THEN
        v_op := 'DELETE'; v_id := TO_CHAR(:OLD.application_id);
        INSERT INTO AUDIT_LOG VALUES (seq_audit.NEXTVAL, 'APPLICATION',
            v_op, v_id, USER, SYSTIMESTAMP,
            'student='||:OLD.student_id||',status='||:OLD.status, NULL);
    END IF;
END;
/

-- Trigger 5: Validate STUDENT.dob < SYSDATE
-- (ORA-02436 prevents SYSDATE in CHECK constraints; trigger enforces the same rule)
CREATE OR REPLACE TRIGGER trg_validate_student_dob
BEFORE INSERT OR UPDATE OF dob ON STUDENT
FOR EACH ROW
BEGIN
    IF :NEW.dob >= SYSDATE THEN
        RAISE_APPLICATION_ERROR(-20001,
            'dob must be in the past. Received: ' || TO_CHAR(:NEW.dob,'YYYY-MM-DD'));
    END IF;
END;
/

-- Trigger 6: Validate APPLICATION.applied_date <= SYSDATE
CREATE OR REPLACE TRIGGER trg_validate_app_date
BEFORE INSERT OR UPDATE OF applied_date ON APPLICATION
FOR EACH ROW
BEGIN
    IF :NEW.applied_date > SYSDATE THEN
        RAISE_APPLICATION_ERROR(-20002,
            'applied_date cannot be a future date. Received: ' || TO_CHAR(:NEW.applied_date,'YYYY-MM-DD'));
    END IF;
END;
/

-- Trigger 7: Validate APPROVAL.approval_date <= SYSDATE
CREATE OR REPLACE TRIGGER trg_validate_approval_date
BEFORE INSERT OR UPDATE OF approval_date ON APPROVAL
FOR EACH ROW
BEGIN
    IF :NEW.approval_date > SYSDATE THEN
        RAISE_APPLICATION_ERROR(-20003,
            'approval_date cannot be a future date. Received: ' || TO_CHAR(:NEW.approval_date,'YYYY-MM-DD'));
    END IF;
END;
/

-- Trigger 8: Validate REMARK.remark_date <= SYSDATE
CREATE OR REPLACE TRIGGER trg_validate_remark_date
BEFORE INSERT OR UPDATE OF remark_date ON REMARK
FOR EACH ROW
BEGIN
    IF :NEW.remark_date > SYSDATE THEN
        RAISE_APPLICATION_ERROR(-20004,
            'remark_date cannot be a future date. Received: ' || TO_CHAR(:NEW.remark_date,'YYYY-MM-DD'));
    END IF;
END;
/

-- Trigger 9: Audit log on APPROVAL (INSERT / UPDATE / DELETE)
CREATE OR REPLACE TRIGGER trg_audit_approval
AFTER INSERT OR UPDATE OR DELETE ON APPROVAL
FOR EACH ROW
DECLARE v_op VARCHAR2(10); v_id VARCHAR2(100);
BEGIN
    IF INSERTING THEN
        v_op := 'INSERT'; v_id := :NEW.application_id||','||:NEW.faculty_id||','||:NEW.revision_no;
        INSERT INTO AUDIT_LOG VALUES (seq_audit.NEXTVAL,'APPROVAL',v_op,v_id,USER,SYSTIMESTAMP,NULL,
            'decision='||:NEW.decision);
    ELSIF UPDATING THEN
        v_op := 'UPDATE'; v_id := :NEW.application_id||','||:NEW.faculty_id||','||:NEW.revision_no;
        INSERT INTO AUDIT_LOG VALUES (seq_audit.NEXTVAL,'APPROVAL',v_op,v_id,USER,SYSTIMESTAMP,
            'decision='||:OLD.decision,'decision='||:NEW.decision);
    ELSIF DELETING THEN
        v_op := 'DELETE'; v_id := :OLD.application_id||','||:OLD.faculty_id||','||:OLD.revision_no;
        INSERT INTO AUDIT_LOG VALUES (seq_audit.NEXTVAL,'APPROVAL',v_op,v_id,USER,SYSTIMESTAMP,
            'decision='||:OLD.decision,NULL);
    END IF;
END;
/

-- Trigger 10: Audit log on REMARK (INSERT / DELETE)
CREATE OR REPLACE TRIGGER trg_audit_remark
AFTER INSERT OR DELETE ON REMARK
FOR EACH ROW
DECLARE v_op VARCHAR2(10); v_id VARCHAR2(100);
BEGIN
    IF INSERTING THEN
        v_op := 'INSERT'; v_id := TO_CHAR(:NEW.remark_id);
        INSERT INTO AUDIT_LOG VALUES (seq_audit.NEXTVAL,'REMARK',v_op,v_id,USER,SYSTIMESTAMP,NULL,
            'type='||:NEW.remark_type||',text='||SUBSTR(:NEW.remark_text,1,50));
    ELSIF DELETING THEN
        v_op := 'DELETE'; v_id := TO_CHAR(:OLD.remark_id);
        INSERT INTO AUDIT_LOG VALUES (seq_audit.NEXTVAL,'REMARK',v_op,v_id,USER,SYSTIMESTAMP,
            'type='||:OLD.remark_type||',text='||SUBSTR(:OLD.remark_text,1,50),NULL);
    END IF;
END;
/

-- Trigger 11: Audit log on REMARK (UPDATE — kept separate to handle all three DML types)
CREATE OR REPLACE TRIGGER trg_audit_remark_update
AFTER UPDATE ON REMARK
FOR EACH ROW
BEGIN
    INSERT INTO AUDIT_LOG VALUES (
        seq_audit.NEXTVAL, 'REMARK', 'UPDATE', TO_CHAR(:NEW.remark_id),
        USER, SYSTIMESTAMP,
        'type='||:OLD.remark_type||',text='||SUBSTR(:OLD.remark_text,1,50),
        'type='||:NEW.remark_type||',text='||SUBSTR(:NEW.remark_text,1,50)
    );
END;
/

-- Trigger 12: Auto-update APPLICATION.status based on APPROVAL decisions
CREATE OR REPLACE TRIGGER trg_auto_application_status
AFTER INSERT OR UPDATE ON APPROVAL
FOR EACH ROW
DECLARE
    v_rejected NUMBER;
    v_pending  NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_rejected
    FROM APPROVAL
    WHERE application_id = :NEW.application_id AND decision = 'Rejected';

    SELECT COUNT(*) INTO v_pending
    FROM APPROVAL
    WHERE application_id = :NEW.application_id AND decision = 'Pending';

    IF v_rejected > 0 THEN
        UPDATE APPLICATION SET status = 'Rejected'
        WHERE application_id = :NEW.application_id;
    ELSIF v_pending > 0 THEN
        UPDATE APPLICATION SET status = 'Under Review'
        WHERE application_id = :NEW.application_id;
    ELSE
        UPDATE APPLICATION SET status = 'Approved'
        WHERE application_id = :NEW.application_id;
    END IF;
END;
/

-- Trigger 13: Update last_login when failed_attempts is reset to 0
-- FIX 11 (CRITICAL): Changed from AFTER trigger (which caused ORA-04091 mutating table
--         because it did UPDATE LOGIN inside an AFTER UPDATE ON LOGIN trigger) to a BEFORE
--         trigger that uses the :NEW pseudo-record assignment instead. This is safe and
--         idiomatic Oracle PL/SQL.
CREATE OR REPLACE TRIGGER trg_update_last_login
BEFORE UPDATE OF failed_attempts ON LOGIN
FOR EACH ROW
WHEN (NEW.failed_attempts = 0)
BEGIN
    :NEW.last_login := SYSTIMESTAMP;
END;
/

-- ============================================================
-- SECTION 6: ROLES AND PRIVILEGES  (Principle of Least Privilege)
-- ============================================================

CREATE ROLE student_role;
CREATE ROLE faculty_role;
CREATE ROLE admin_role;

-- student_role: browse internships, manage own applications only
GRANT SELECT               ON COMPANY           TO student_role;
GRANT SELECT               ON INTERNSHIP        TO student_role;
GRANT SELECT               ON INTERNSHIP_YEAR   TO student_role;
GRANT SELECT               ON INTERNSHIP_DEPT   TO student_role;
GRANT SELECT               ON INTERNSHIP_GENDER TO student_role;
GRANT SELECT               ON INTERNSHIP_CGPA   TO student_role;
GRANT SELECT, INSERT, UPDATE ON APPLICATION     TO student_role; 
GRANT SELECT               ON APPROVAL          TO student_role;
GRANT SELECT               ON REMARK            TO student_role;

-- faculty_role: manage approvals and remarks, read-only on applications
GRANT SELECT                 ON APPLICATION  TO faculty_role;
GRANT SELECT, INSERT, UPDATE ON APPROVAL     TO faculty_role;
GRANT SELECT, INSERT         ON REMARK       TO faculty_role;
GRANT SELECT                 ON STUDENT      TO faculty_role;
GRANT SELECT                 ON INTERNSHIP   TO faculty_role;

-- admin_role: full DML on all tables + read-only audit log
GRANT ALL PRIVILEGES ON COMPANY           TO admin_role;
GRANT ALL PRIVILEGES ON USER_BASE         TO admin_role;
GRANT ALL PRIVILEGES ON STUDENT           TO admin_role;
GRANT ALL PRIVILEGES ON FACULTY           TO admin_role;
GRANT ALL PRIVILEGES ON INTERNSHIP        TO admin_role;
GRANT ALL PRIVILEGES ON APPLICATION       TO admin_role;
GRANT ALL PRIVILEGES ON APPROVAL          TO admin_role;
GRANT ALL PRIVILEGES ON REMARK            TO admin_role;
GRANT ALL PRIVILEGES ON ADMIN             TO admin_role;
GRANT ALL PRIVILEGES ON LOGIN             TO admin_role;
GRANT ALL PRIVILEGES ON USER_PHONE        TO admin_role;
GRANT ALL PRIVILEGES ON INTERNSHIP_YEAR   TO admin_role;
GRANT ALL PRIVILEGES ON INTERNSHIP_DEPT   TO admin_role;
GRANT ALL PRIVILEGES ON INTERNSHIP_GENDER TO admin_role;
GRANT ALL PRIVILEGES ON INTERNSHIP_CGPA   TO admin_role;
GRANT SELECT         ON AUDIT_LOG         TO admin_role; 
COMMIT;

COMMIT;
