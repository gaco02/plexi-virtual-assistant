from pydantic import BaseModel
from datetime import datetime
from typing import Optional, List

class Transaction(BaseModel):
    amount: float
    category: str
    description: str = ""
    date: Optional[datetime] = None
    timestamp: Optional[str] = None

class BudgetSummary(BaseModel):
    total_spent: float
    categories: dict[str, float]

class BudgetAllocation(BaseModel):
    user_id: str
    month: str  # Format: YYYY-MM
    monthly_salary: float
    needs_budget: float
    wants_budget: float
    savings_budget: float
    needs_spent: float = 0
    wants_spent: float = 0
    savings_actual: float = 0
    timestamp: datetime = datetime.now()

class BudgetRecommendation(BaseModel):
    user_id: str
    month: str
    category: str  # 'needs', 'wants', or 'savings'
    recommendation_type: str
    message: str
    suggested_action: str
    potential_savings: float
    timestamp: datetime = datetime.now()

class BudgetAnalysis(BaseModel):
    monthly_salary: float
    ideal_allocation: dict[str, float]
    actual_spending: dict[str, float]
    recommendations: List[BudgetRecommendation]
    summary: dict[str, float]

