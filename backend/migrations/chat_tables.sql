-- Chat Messages Table
CREATE TABLE IF NOT EXISTS chat_messages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    content TEXT NOT NULL,
    is_user BOOLEAN NOT NULL,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    tool_used TEXT,
    tool_response TEXT,
    conversation_id TEXT,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_chat_messages_user_id 
ON chat_messages(user_id);

CREATE INDEX IF NOT EXISTS idx_chat_messages_conversation_id 
ON chat_messages(conversation_id);

CREATE INDEX IF NOT EXISTS idx_chat_messages_timestamp 
ON chat_messages(timestamp); 