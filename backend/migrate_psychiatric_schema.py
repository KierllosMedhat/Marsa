import sqlite3

con = sqlite3.connect('marsa.db')
cur = con.cursor()

def add_col_if_not_exists(table, col, col_type):
    cols = [c[1] for c in cur.execute(f"PRAGMA table_info({table})").fetchall()]
    if col not in cols:
        print(f"Adding {col} ({col_type}) to {table}...")
        cur.execute(f"ALTER TABLE {table} ADD COLUMN {col} {col_type}")
    else:
        print(f"Column {col} already exists in {table}.")

# 1. Update patients
add_col_if_not_exists('patients', 'occupation', 'VARCHAR(255)')
add_col_if_not_exists('patients', 'marital_status', 'VARCHAR(100)')
add_col_if_not_exists('patients', 'children', 'VARCHAR(100)')
add_col_if_not_exists('patients', 'first_session_date', 'DATE')
add_col_if_not_exists('patients', 'last_session_date', 'DATE')

# 2. Update patient_clinical
add_col_if_not_exists('patient_clinical', 'history', 'TEXT')
add_col_if_not_exists('patient_clinical', 'psychiatric_examinations', 'TEXT')
add_col_if_not_exists('patient_clinical', 'physical_neurological_exam', 'TEXT')
add_col_if_not_exists('patient_clinical', 'risk_assessment', 'TEXT')
add_col_if_not_exists('patient_clinical', 'suicide_attempts', 'TEXT')
add_col_if_not_exists('patient_clinical', 'admitted_before', 'TEXT')
add_col_if_not_exists('patient_clinical', 'notes', 'TEXT')

# 3. Update sessions
add_col_if_not_exists('sessions', 'session_number', 'VARCHAR(50)')
add_col_if_not_exists('sessions', 'chief_complaint', 'TEXT')
add_col_if_not_exists('sessions', 'sleep', 'TEXT')
add_col_if_not_exists('sessions', 'appetite', 'TEXT')
add_col_if_not_exists('sessions', 'mood', 'TEXT')
add_col_if_not_exists('sessions', 'anxiety', 'TEXT')
add_col_if_not_exists('sessions', 'suicidal_self_harm_assessment', 'TEXT')
add_col_if_not_exists('sessions', 'substance_use', 'TEXT')
add_col_if_not_exists('sessions', 'mental_status_examination', 'TEXT')
add_col_if_not_exists('sessions', 'diagnosis', 'TEXT')
add_col_if_not_exists('sessions', 'treatment_plan', 'TEXT')
add_col_if_not_exists('sessions', 'follow_up', 'TEXT')

# 4. Update medications
add_col_if_not_exists('medications', 'duration', 'VARCHAR(100)')
add_col_if_not_exists('medications', 'date', 'DATE')

# 5. Create patient_files table
cur.execute('''
CREATE TABLE IF NOT EXISTS patient_files (
    file_id CHAR(32) PRIMARY KEY,
    patient_id CHAR(32) NOT NULL,
    file_name VARCHAR(255) NOT NULL,
    file_type VARCHAR(100) NOT NULL,
    file_location VARCHAR(500) NOT NULL,
    created_at DATETIME NOT NULL,
    uploaded_by CHAR(32),
    FOREIGN KEY(patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE,
    FOREIGN KEY(uploaded_by) REFERENCES staff(staff_id)
)
''')
print("Created/verified table: patient_files")

# 6. Create patient_notes table
cur.execute('''
CREATE TABLE IF NOT EXISTS patient_notes (
    note_id CHAR(32) PRIMARY KEY,
    patient_id CHAR(32) NOT NULL,
    note_text TEXT NOT NULL,
    last_modified DATETIME NOT NULL,
    author_id CHAR(32),
    FOREIGN KEY(patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE,
    FOREIGN KEY(author_id) REFERENCES staff(staff_id)
)
''')
print("Created/verified table: patient_notes")

con.commit()
con.close()
print("Migration completed successfully!")
