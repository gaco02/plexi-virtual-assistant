from pydantic import BaseModel, EmailStr
from datetime import datetime
from typing import Optional
from enum import Enum

class WeightGoal(str, Enum):
    LOSE = "lose"
    MAINTAIN = "maintain"
    GAIN = "gain"

class Sex(str, Enum):
    MALE = "male"
    FEMALE = "female"
    OTHER = "other"

class UserPreferences(BaseModel):
    monthly_salary: Optional[float]
    weight_goal: Optional[WeightGoal]
    current_weight: Optional[float]
    target_weight: Optional[float]
    daily_calorie_target: Optional[int]
    preferred_name: Optional[str]
    height: Optional[float]
    age: Optional[int]
    sex: Optional[Sex]

class User(BaseModel):
    id: str
    email: Optional[str] = None
    name: Optional[str] = None
    created_at: Optional[datetime] = None
    firebase_uid: str
    preferences: Optional[UserPreferences] = None
    
class UserCreate(BaseModel):
    email: EmailStr
    name: Optional[str] = None
    firebase_uid: str 