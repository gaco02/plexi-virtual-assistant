CREATE TABLE IF NOT EXISTS chat_messages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    content TEXT NOT NULL,
    is_user BOOLEAN NOT NULL,
    timestamp DATETIME NOT NULL,
    tool_used TEXT,
    tool_response TEXT,
    conversation_id TEXT,
    FOREIGN KEY (user_id) REFERENCES users(id)
); 