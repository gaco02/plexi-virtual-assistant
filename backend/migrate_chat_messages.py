import sqlite3
import os

# Paths to the databases (relative to this script's directory)
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OLD_DB = os.path.join(SCRIPT_DIR, 'virtual_assistant.db')
NEW_DB = os.path.join(SCRIPT_DIR, 'data', 'virtual_assistant.db')

def migrate_chat_messages():
    # Connect to both databases
    old_conn = sqlite3.connect(OLD_DB)
    new_conn = sqlite3.connect(NEW_DB)
    
    try:
        # Get all chat messages from old database
        old_cursor = old_conn.cursor()
        old_cursor.execute('SELECT * FROM chat_messages')
        messages = old_cursor.fetchall()
        
        # Insert messages into new database
        new_cursor = new_conn.cursor()
        for message in messages:
            new_cursor.execute('''
                INSERT INTO chat_messages 
                (id, user_id, content, is_user, timestamp, tool_used, tool_response, conversation_id)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ''', message)
        
        new_conn.commit()
        print(f"Successfully migrated {len(messages)} chat messages")
        
    except Exception as e:
        print(f"Error during migration: {e}")
    finally:
        old_conn.close()
        new_conn.close()

if __name__ == "__main__":
    migrate_chat_messages() 