import oracledb
from contextlib import contextmanager

DSN = "localhost:1521/xepdb1"
USER = "system"
PASSWORD = "student"

@contextmanager
def get_connection():
    connection = oracledb.connect(user=USER, password=PASSWORD, dsn=DSN)
    try:
        yield connection
    finally:
        connection.close()
