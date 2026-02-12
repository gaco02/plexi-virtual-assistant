from pydantic import BaseModel
from typing import Optional, Dict, Any, Union
from datetime import datetime

class FoodMacros(BaseModel):
    """Model for food macronutrient information"""
    food_item: str
    calories: int
    carbs: float = 0  # in grams
    protein: float = 0  # in grams
    fat: float = 0  # in grams
    quantity: float = 1
    unit: Optional[str] = None
    timestamp: Optional[str] = None

class CalorieSummary(BaseModel):
    """Model for calorie and macronutrient summary"""
    total_calories: int = 0
    total_carbs: float = 0
    total_protein: float = 0
    total_fat: float = 0
    items: Dict[str, Any] = {}

class CalorieEntry(BaseModel):
    """Model for adding calorie entries via direct API"""
    food_item: str
    calories: Any  # Accept any type and convert in the endpoint
    carbs: Optional[Any] = None  # Accept any type and convert in the endpoint
    protein: Optional[Any] = None  # Accept any type and convert in the endpoint
    fat: Optional[Any] = None  # Accept any type and convert in the endpoint
    quantity: Any = 1.0  # Accept any type and convert in the endpoint
    unit: str = "serving"
    timestamp: Optional[str] = None
