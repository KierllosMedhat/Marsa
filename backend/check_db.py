import sqlite3

con = sqlite3.connect('marsa.db')
cur = con.cursor()
tables = cur.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()
print("Tables:", tables)

for (t,) in tables:
    cols = cur.execute(f"PRAGMA table_info({t})").fetchall()
    print(f"\nTable: {t}")
    for c in cols:
        print(f"  {c[1]} ({c[2]})")
