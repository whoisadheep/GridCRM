import sqlite3

def upgrade():
    try:
        conn = sqlite3.connect('app.db')
        cursor = conn.cursor()
        cursor.execute("ALTER TABLE technician ADD COLUMN fcm_token VARCHAR(255)")
        conn.commit()
        print("Successfully added fcm_token to technician table")
    except Exception as e:
        print("Error or already exists:", e)
    finally:
        conn.close()

if __name__ == '__main__':
    upgrade()
