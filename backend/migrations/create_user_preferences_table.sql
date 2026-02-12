-- Create user_preferences table
CREATE TABLE IF NOT EXISTS user_preferences (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL UNIQUE,
    monthly_salary REAL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create transactions table
CREATE TABLE IF NOT EXISTS transactions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    amount REAL NOT NULL,
    category TEXT NOT NULL,
    description TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES user_preferences(user_id)
);

-- Create budget_allocations table
CREATE TABLE IF NOT EXISTS budget_allocations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    month TEXT NOT NULL,
    monthly_salary REAL NOT NULL,
    needs_budget REAL NOT NULL,
    wants_budget REAL NOT NULL,
    savings_budget REAL NOT NULL,
    needs_spent REAL NOT NULL,
    wants_spent REAL NOT NULL,
    savings_actual REAL NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES user_preferences(user_id)
);

-- Create budget_recommendations table
CREATE TABLE IF NOT EXISTS budget_recommendations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    month TEXT NOT NULL,
    category TEXT NOT NULL,
    recommendation_type TEXT NOT NULL,
    message TEXT NOT NULL,
    suggested_action TEXT NOT NULL,
    potential_savings REAL NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES user_preferences(user_id)
); 