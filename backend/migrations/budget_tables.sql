-- Budget Allocations Table
CREATE TABLE IF NOT EXISTS budget_allocations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    month TEXT NOT NULL,
    monthly_salary REAL NOT NULL,
    needs_budget REAL NOT NULL,
    wants_budget REAL NOT NULL,
    savings_budget REAL NOT NULL,
    needs_spent REAL DEFAULT 0,
    wants_spent REAL DEFAULT 0,
    savings_actual REAL DEFAULT 0,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Budget Recommendations Table
CREATE TABLE IF NOT EXISTS budget_recommendations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    month TEXT NOT NULL,
    category TEXT CHECK(category IN ('needs', 'wants', 'savings')) NOT NULL,
    recommendation_type TEXT NOT NULL,
    message TEXT NOT NULL,
    suggested_action TEXT,
    potential_savings REAL,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_budget_allocations_user_month 
ON budget_allocations(user_id, month);

CREATE INDEX IF NOT EXISTS idx_budget_recommendations_user_month 
ON budget_recommendations(user_id, month); 